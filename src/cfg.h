// config functions for butt
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

#ifndef CFG_H
#define CFG_H

#ifndef BUILD_CLIENT
#include "port_audio.h"
#endif
#include "parseconfig.h"

enum {
    SHOUTCAST = 0,
    ICECAST = 1,
    RADIOCO = 2,
    WEBRTC = 3,
};

enum {
    ICECAST_PROTOCOL_PUT = 0,
    ICECAST_PROTOCOL_SOURCE = 1,
};

enum {
    CHOICE_STEREO = 0,
    CHOICE_MONO = 1,
};

enum {
    CHOICE_MP3 = 0,
    CHOICE_OGG = 1,
    CHOICE_OPUS = 2,
    CHOICE_AAC = 3,
    CHOICE_FLAC = 4,
    CHOICE_WAV = 5,
};

enum {
    CHOICE_CBR = 0,
    CHOICE_VBR = 1,
    CHOICE_ABR = 2,
};

enum {
    CHOICE_TYPE_MUSIC = 0,
    CHOICE_TYPE_SPEECH = 1,
};

enum {
    CHOICE_AAC_PROFILE_AUTO = 0,
    CHOICE_AAC_PROFILE_AAC_LC = 1,
    CHOICE_AAC_PROFILE_HE_AACv1 = 2,
    CHOICE_AAC_PROFILE_HE_AACv2 = 3,
};

enum {
    CHOICE_MP3_RESAMPLING_DISABLED = 0,
    CHOICE_MP3_RESAMPLING_8000 = 1,
    CHOICE_MP3_RESAMPLING_11025 = 2,
    CHOICE_MP3_RESAMPLING_12000 = 3,
    CHOICE_MP3_RESAMPLING_16000 = 4,
    CHOICE_MP3_RESAMPLING_22050 = 5,
    CHOICE_MP3_RESAMPLING_24000 = 6,
    CHOICE_MP3_RESAMPLING_32000 = 7,
    CHOICE_MP3_RESAMPLING_44100 = 8,
    CHOICE_MP3_RESAMPLING_48000 = 9,
};

enum {
    LANG_MAPPING_OLD = 0,
    LANG_MAPPING_NEW = 1,
};

enum {
    LANG_COUNT = 8,
};

enum {
    MIDI_COMMANDS_COUNT = 14,
};

enum {
    APP_ARTIST_FIRST = 0,
    APP_TITLE_FIRST = 1,
};

enum {
    VU_MODE_GRADIENT = 0,
    VU_MODE_SOLID = 1,
};

enum {
    REMEMBER_BY_ID = 0,
    REMEMBER_BY_NAME = 1,
};

extern const char *lang_array_new[];
extern const char *lang_array_old[];
extern const char CONFIG_FILE[];

typedef struct {
    char *name;
    char *addr;
    char *pwd;
    char *mount;       // mountpoint for icecast server
    char *usr;         // user for icecast server
    char *cert_hash;   // sha256 hash of trusted certificate
    char *webrtc_ice;  // ICE server for WebRTC
    char *webrtc_whip; // WHIP URL for WebRTC
    char *webrtc_auth; // WHIP URL Bearer Token for WebRTC
    char *custom_listener_url;
    char *custom_listener_mount;
    int port;
    int type;             // SHOUTCAST, ICECAST or WEBRTC
    int tls;              // use tls: 0 = no, 1 = yes
    int icecast_protocol; // Icecast protocol: 0 = PUT, 1 = SOURCE
} server_t;

typedef struct {
    int enabled;
    int channel;       // Any, or 1-16
    int msg_num;       // CC number
    int msg_type;      // Currently unused
    int mode;          // CC Mode. Absolute or relative
    int soft_takeover; // If active, value jumps are prevented
    int picked_up;     // 0 = not picked up, 1 = picked up (Only relevant if soft_takeover is active)
} midi_command_t;

typedef struct {
    char *name;
    char *desc; // description
    char *genre;
    char *url;
    char *irc;
    char *icq;
    char *aim;
    char *pub;
    int expand_variables;
} icy_t;

typedef struct {
    int selected_srv;
    int selected_icy;

    struct {
        char *srv;
        char *icy;
        char *srv_ent;
        char *icy_ent;
        char *song;
        char *song_path;
        FILE *song_fd;
        char *song_prefix;
        char *song_suffix;
        int song_delay;
        int song_update; // 1 = song info will be read from file
        int read_last_line;
        int app_update;
        int app_update_service;
        int app_artist_title_order;
        char *song_update_url;
        int song_update_url_active;
        int song_update_url_interval;
        int num_of_srv;
        int num_of_icy;
        int bg_color, txt_color;
        int connect_at_startup;
        int force_reconnecting;
        int reconnect_delay;
        float silence_threshold; // timeout duration of automatic stream stop
        float signal_threshold;  // timeout duration of automatic stream start
        int signal_detection;
        int silence_detection;
        int check_for_update;
        int start_agent;
        int minimize_to_tray;
        float gain;
        char *log_file;
        char *ic_charset;
    } main;

    struct {
        int dev_count;
        int dev_num;
        int dev2_num;
        char *dev_name;
        char *dev2_name;
        int dev_remember; // Remember device by ID or Name
        snd_dev_t **pcm_list;
        int samplerate;
        int resolution;
        int channel;
        int left_ch;
        int right_ch;
        int left_ch2;
        int right_ch2;
        int bitrate;
        int buffer_ms;
        int resample_mode;
        float silence_level;
        float signal_level;
        int disable_dithering;
        char *codec;
    } audio;

    struct {
        char *dev_name;
        midi_command_t commands[MIDI_COMMANDS_COUNT];
    } midi;

    struct {
        int channel;
        int bitrate;
        int quality;
        int samplerate;
        char *codec;
        char *filename;
        char *folder;
        char *path;
        FILE *fd;
        int start_rec;
        int stop_rec;
        int overwrite_files;
        int rec_after_launch;
        int split_time;
        int sync_to_hour;
        float silence_threshold;
        float signal_threshold;
        int signal_detection;
        int silence_detection;
    } rec;

    struct {
        char *cert_file;
        char *cert_dir;
    } tls;

    struct {
        int equalizer_stream;
        int equalizer_rec;
        char *eq_preset;
        double eq_gain[10];
        int compressor_stream;
        int compressor_rec;
        int aggressive_mode;
        double threshold, ratio, attack, release, makeup_gain;
    } dsp;

    struct {
        double primary_device_gain;
        int primary_device_muted;
        int secondary_device_muted;
        double secondary_device_gain;
        double streaming_gain;
        double recording_gain;
        double cross_fader;
        float primary_X_fader;
        float secondary_X_fader;
    } mixer;

    struct {
        int attach;
        int ontop;
        int lcd_auto;
        int default_stream_info;
        int hide_log_window;
        int remember_pos;
        int window_height;
        int x_pos, y_pos;
        char *lang_str;
        int vu_mode;
        int always_show_vu_tabs;
        int vu_low_color;
        int vu_mid_color;
        int vu_high_color;
        int vu_mid_range_start;
        int vu_high_range_start;
        int start_minimized;
        int disable_gain_slider;
        int show_listeners;
        int listeners_update_rate;
        char *window_title;
    } gui;

    struct {
        int enc_quality;
        int stereo_mode;
        int bitrate_mode;
        int vbr_quality;
        int vbr_min_bitrate;
        int vbr_max_bitrate;
        int vbr_force_min_bitrate;
        int resampling_freq;
        int lowpass_freq_active;
        float lowpass_freq;
        int lowpass_width_active;
        float lowpass_width;
        int highpass_freq_active;
        float highpass_freq;
        int highpass_width_active;
        float highpass_width;

    } mp3_codec_stream;

    struct {
        int enc_quality;
        int stereo_mode;
        int bitrate_mode;
        int vbr_quality;
        int vbr_min_bitrate;
        int vbr_max_bitrate;
        int vbr_force_min_bitrate;
        int resampling_freq;
        int lowpass_freq_active;
        float lowpass_freq;
        int lowpass_width_active;
        float lowpass_width;
        int highpass_freq_active;
        float highpass_freq;
        int highpass_width_active;
        float highpass_width;
    } mp3_codec_rec;

    struct {
        int bitrate_mode;
        int vbr_quality;
        int vbr_min_bitrate;
        int vbr_max_bitrate;
    } vorbis_codec_stream;

    struct {
        int bitrate_mode;
        int vbr_quality;
        int vbr_min_bitrate;
        int vbr_max_bitrate;
    } vorbis_codec_rec;

    struct {
        int bitrate_mode;
        int quality;
        int audio_type;
        int bandwidth;
    } opus_codec_stream;

    struct {
        int bitrate_mode;
        int quality;
        int audio_type;
        int bandwidth;
    } opus_codec_rec;

    struct {
        int bitrate_mode;
        int profile;
        int afterburner;
    } aac_codec_stream;

    struct {
        int bitrate_mode;
        int profile;
        int afterburner;
    } aac_codec_rec;

    struct {
        int bit_depth;
    } flac_codec_stream;

    struct {
        int bit_depth;
    } flac_codec_rec;

    struct {
        int bit_depth;
    } wav_codec_rec;

    struct {
        int enabled_stream;      // Enable StereoTool for streaming
        int enabled_rec;         // Enable StereoTool for recording
        int replace_dsp;         // Replace built-in DSP (1) or use in addition (0)
        char *license_key;       // License key for StereoTool
        char *preset_file_stream; // Preset file for streaming
        char *preset_file_rec;   // Preset file for recording
        int latency_compensation; // Automatic latency compensation
        int bypass_on_silence;   // Bypass processing on silence
        float bypass_threshold;  // Silence threshold for bypass
        int latency_ms;          // Latence interne exposée (lecture seule)
    } stereo_tool;

    struct {
        int use_vdsp;            // Utiliser vDSP pour conversions audio (0/1)
        int dither_type;         // Type de dithering: 0=none, 1=TPDF, 2=RPDF
        int pll_enabled;         // Mini-PLL activé pour stabilisation sans PTP
        float pll_window_s;      // Fenêtre de mesure PLL en secondes
        int clip_protection;     // Protection contre l'écrêtage (0/1)
    } audio_perf;

    server_t **srv;
    icy_t **icy;

    struct {
        int active;      // AES67 output enabled (0/1) - MUST BE FIRST for persistence
        char *ip;        // destination IP
        int port;        // destination port
        int ttl;         // multicast TTL
        int dscp;        // DSCP value
        char *iface;     // outgoing interface IP
        int loopback;    // multicast loopback (0/1)
        int ptp;         // PTP enabled (0/1)
        int sap;         // SAP enabled (0/1)
    } aes67;

} config_t;

extern char *cfg_path; // Path to config file
extern config_t cfg;   // Holds config parameters

int cfg_write_file(char *path); // Writes current config_t struct to path or cfg_path if path is NULL
int cfg_set_values(char *path); // Reads config file from path or cfg_path if path is NULL and fills the config_t struct
int cfg_create_default(void);   // Creates a default config file, if there isn't one yet

#endif
