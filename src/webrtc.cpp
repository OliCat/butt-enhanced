// webrtc functions for butt
//
// Copyright 2007-2018 by Daniel Noethen.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//

#include <config.h>

#ifdef HAVE_LIBDATACHANNEL

#include <rtc/rtc.h>
#include "butt.h"
#include "cfg.h"
#include "timer.h"
#include "webrtc.h"
#include "gettext.h"
#include "fl_funcs.h"
#include "url.h"
#include "atom.h"

ATOM_NEW_COND(gathering_cond);
ATOM_NEW_COND(track_cond);

unsigned char _payloadType = 111;
unsigned int _ssrc = 1;
char _name[] = "audio-stream";
char _msid[] = "stream1";

bool _logger_prepared = false;
void _prepare_logger(void);
void _logWindow(rtcLogLevel level, const char *message);
void _logFile(rtcLogLevel level, const char *message);

int peer, track, packetiser;
float last_sample_time, last_report_time;

void _on_state_change(int pc, rtcState state, void *ptr);
void _on_gathering_state_change(int pc, rtcGatheringState state, void *ptr);

void _on_track_open(int id, void *ptr);
void _on_track_closed(int id, void *ptr);
void _on_track_error(int id, const char *error, void *ptr);
void _on_track_message(int id, const char *message, int size, void *ptr);

int _negotiate(void);

// TODO: handle trickled ICE candidates - rtcAddRemoteCandidate(...)

int webrtc_connect(void)
{
    atom_cond_init(&gathering_cond);
    atom_cond_init(&track_cond);

    // Make the libdatachannel logger print to the BUTT console
    _prepare_logger();

    // Create the peer connection
    const char *iceServer = cfg.srv[cfg.selected_srv]->webrtc_ice;

    rtcConfiguration peer_config = {};

    if (iceServer != NULL && strlen(iceServer) > 0) {
        peer_config.iceServers = &iceServer;
        peer_config.iceServersCount = 1;
        peer_config.disableAutoNegotiation = true;
    }

    peer = rtcCreatePeerConnection(&peer_config);
    if (peer < 0) {
        return WEBRTC_ABORT;
    }

    rtcSetStateChangeCallback(peer, _on_state_change);
    rtcSetGatheringStateChangeCallback(peer, _on_gathering_state_change);

    // Work out a good profile
    // (mainly stereo or mono)
    int is_stereo = (cfg.audio.channel == 2 ? 1 : 0);

    char profile[256];
    snprintf(profile, sizeof(profile), "minptime=10;stereo=%d;sprop-stereo=%d;useinbandfec=1", is_stereo, is_stereo);

    // Add an audio track
    rtcTrackInit track_config = {};
    track_config.direction = RTC_DIRECTION_SENDONLY;
    track_config.codec = RTC_CODEC_OPUS;
    track_config.payloadType = _payloadType;
    track_config.ssrc = _ssrc;
    track_config.name = _name;
    track_config.msid = _msid;
    track_config.trackId = _name;
    track_config.profile = profile;

    track = rtcAddTrackEx(peer, &track_config);
    if (track < 0) {
        return WEBRTC_ABORT;
    }

    rtcSetOpenCallback(track, _on_track_open);
    rtcSetClosedCallback(track, _on_track_closed);
    rtcSetErrorCallback(track, _on_track_error);
    rtcSetMessageCallback(track, _on_track_message);

    // Configure the packetiser chain
    unsigned int sample_rate = opus_enc_get_samplerate(&opus_stream);
    if (sample_rate != 48000) {
        return WEBRTC_ABORT; // WebRTC using Opus must be 48k
    }

    rtcPacketizerInit packetiser_config = {};
    packetiser_config.ssrc = _ssrc;
    packetiser_config.cname = _name;
    packetiser_config.payloadType = _payloadType;
    packetiser_config.clockRate = sample_rate;

    packetiser = rtcSetOpusPacketizer(track, &packetiser_config);
    if (packetiser < 0) {
        return WEBRTC_ABORT;
    }

    if (rtcChainRtcpSrReporter(track) < 0) {
        return WEBRTC_ABORT;
    }

    if (rtcChainRtcpNackResponder(track, 512 /* default nack size */) < 0) {
        return WEBRTC_ABORT;
    }
    // Create the offer and wait to complete ICE gathering before negotiating
    rtcSetLocalDescription(peer, "offer");
    atom_cond_wait(&gathering_cond);

    // Negotiate with the WHIP endpoint
    int negotiation_ret = _negotiate();
    if (negotiation_ret > 0) {
        return negotiation_ret;
    }

    // Wait for the negotiation to complete and the track to open
    atom_cond_wait(&track_cond);

    connected = 1;

    timer_init(&stream_timer, 1); // starts the "online" timer
    timer_start(&stream_timer);
    last_sample_time = last_report_time = timer_get_elapsed_time(&stream_timer);

    return WEBRTC_OK;
}

int webrtc_send(char *buf, int buf_len)
{
    // Bail if the track isn't open
    if (!rtcIsOpen(track)) {
        print_info("WebRTC tried to send packets on closed track", 1);
        return buf_len;
    }

    // Increment the RTP timestamp
    unsigned int track_timestamp;
    rtcGetCurrentTrackTimestamp(track, &track_timestamp);

    unsigned int current_timestamp = track_timestamp + OPUS_FRAME_SIZE;
    rtcSetTrackRtpTimestamp(track, current_timestamp);

    // Work out if we need to to send another RTCP sender report
    unsigned int reported_timestamp;
    rtcGetLastTrackSenderReportTimestamp(track, &reported_timestamp);

    unsigned int time_since_report = current_timestamp - reported_timestamp;

    double seconds_since_report;
    rtcTransformTimestampToSeconds(track, time_since_report, &seconds_since_report);

    if (seconds_since_report > 1) {
        rtcSetNeedsToSendRtcpSr(track);
    }

    // Send the audio data
    // NOTE: Shoutcast/Icecast need the Opus data wrapped in a container, and
    // opus_enc_encode() does it with Ogg but WebRTC and RTP in general require
    // the raw unwrapped Opus, so we'll grab that directly from opus_stream
    // which gets set by opus_enc_encode() separately to the Ogg wrapping.
    buf = (char *)opus_stream.buffer;
    buf_len = opus_stream.buffer_len;
    if (rtcSendMessage(track, buf, buf_len) < 0) {
        return -1;
    }

    return buf_len;
}

int webrtc_update_song(char *song_name)
{
    // not supported
    return WEBRTC_OK;
}

int webrtc_get_listener_count(void)
{
    // not supported
    return -1;
}

void webrtc_disconnect(void)
{
    if (track > 0) {
        rtcDeleteTrack(track);
    }
    if (peer > 0) {
        rtcDeletePeerConnection(peer);
    }
}

void _prepare_logger(void)
{
    if (_logger_prepared) {
        return;
    }
    else {
        _logger_prepared = true;
    }

    rtcInitLogger(RTC_LOG_NONE, _logFile);
    rtcInitLogger(RTC_LOG_FATAL, _logWindow);
    rtcInitLogger(RTC_LOG_ERROR, _logWindow);
    rtcInitLogger(RTC_LOG_WARNING, _logFile);
    // rtcInitLogger(RTC_LOG_INFO, _logFile);
    // rtcInitLogger(RTC_LOG_DEBUG, _logFile);
    //  rtcInitLogger(RTC_LOG_VERBOSE, _logFile);
}

void _logWindow(rtcLogLevel level, const char *message)
{
    print_info(message, level);
}

void _logFile(rtcLogLevel level, const char *message)
{
    write_log(message);
}

void _on_state_change(int pc, rtcState state, void *ptr)
{
    char log[256];

    const char *state_str;
    switch (state) {
    case RTC_NEW:
        state_str = "RTC_NEW";
        break;
    case RTC_CONNECTING:
        state_str = "RTC_CONNECTING";
        break;
    case RTC_CONNECTED:
        state_str = "RTC_CONNECTED";
        break;
    case RTC_DISCONNECTED:
        state_str = "RTC_DISCONNECTED";
        break;
    case RTC_FAILED:
        state_str = "RTC_FAILED";
        break;
    case RTC_CLOSED:
        state_str = "RTC_CLOSED";
        break;
    default:
        state_str = "??";
        break;
    }

    // snprintf(log, sizeof(log), "WebRTC state change: %i %s", state, state_str);
    // print_info(log, 1);

    if (state == RTC_DISCONNECTED || state == RTC_FAILED || state == RTC_CLOSED) {
        connected = 0;
    }
}

void _on_gathering_state_change(int pc, rtcGatheringState state, void *ptr)
{
    char log[256];

    const char *state_str;
    switch (state) {
    case RTC_GATHERING_NEW:
        state_str = "RTC_GATHERING_NEW";
        break;
    case RTC_GATHERING_INPROGRESS:
        state_str = "RTC_GATHERING_INPROGRESS";
        break;
    case RTC_GATHERING_COMPLETE:
        state_str = "RTC_GATHERING_COMPLETE";
        break;
    default:
        state_str = "??";
        break;
    }

    // snprintf(log, sizeof(log), "WebRTC gathering state change: %i %s", state, state_str);
    // print_info(log, 1);

    if (state == RTC_GATHERING_COMPLETE) {
        // Signal to webrtc_init() that the network's ready
        atom_cond_signal(&gathering_cond);
        atom_cond_destroy(&gathering_cond);
    }
}

void _on_track_open(int id, void *ptr)
{
    write_log("WebRTC track open");

    atom_cond_signal(&track_cond);
    atom_cond_destroy(&track_cond);
}

void _on_track_closed(int id, void *ptr)
{
    write_log("WebRTC track closed");
}

void _on_track_error(int id, const char *error, void *ptr)
{
    char log[256];

    snprintf(log, sizeof(log), "WebRTC track error: %s", error);
    print_info(log, 1);
}

void _on_track_message(int id, const char *message, int size, void *ptr)
{
    // char log[256];

    // snprintf(log, sizeof(log), "WebRTC track message (%i): %s", size, message);
    // print_info(log, 1);
}

int _negotiate(void)
{
    // Get our local SDP out of the peer
    char local_sdp[4096];
    if (rtcGetLocalDescription(peer, local_sdp, sizeof(local_sdp)) < 0) {
        return WEBRTC_ABORT;
    }

    // print_info("Local SDP offer:", 1);
    // print_info(local_sdp, 1);

    // Send it to the WHIP endpoint and get their answer
    char remote_sdp[4096] = {0};
    if (true) {
        // Fetch the remote SDP answer from the WHIP endpoint
        if (url_post_sdp(cfg.srv[cfg.selected_srv]->webrtc_whip, cfg.srv[cfg.selected_srv]->webrtc_auth, local_sdp, remote_sdp, sizeof(remote_sdp)) < 1) {
            return WEBRTC_ABORT;
        }
    }
    else {
        // Ask the user to paste the remote SDP answer into console (useful for debug)
        char remote_sdp_input[4096] = {0};
        while (true) {
            if (fgets(remote_sdp_input, 4096, stdin) != NULL) {
                int input_len = strlen(remote_sdp_input);
                if (input_len > 1) {
                    strcat(remote_sdp, remote_sdp_input);
                }
                else {
                    break;
                }
            }
        }
    }

    // print_info("Remote SDP answer:", 1);
    // print_info(remote_sdp, 1);

    // Plug the remote SDP into the peer
    if (rtcSetRemoteDescription(peer, remote_sdp, "answer") < 0) {
        return WEBRTC_ABORT;
    }

    return WEBRTC_OK;
}
#endif
