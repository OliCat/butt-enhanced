// lame encoding functions for butt
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

#include <stdlib.h>
#include <lame/lame.h>

#include "gettext.h"
#include "lame_encode.h"
#include "fl_funcs.h"

int lame_enc_init(lame_enc *lame)
{
    int rc;
    char info_buf[256];

    lame->gfp = lame_init();

    lame_set_num_channels(lame->gfp, lame->channel);
    lame_set_in_samplerate(lame->gfp, lame->samplerate_in);
    lame_set_out_samplerate(lame->gfp, lame->samplerate_out);
    lame_set_brate(lame->gfp, lame->bitrate);
    lame_set_quality(lame->gfp, lame->enc_quality);
    lame_set_VBR_q(lame->gfp, lame->vbr_quality);
    lame_set_VBR_min_bitrate_kbps(lame->gfp, lame->vbr_min_bitrate);
    lame_set_VBR_mean_bitrate_kbps(lame->gfp, lame->bitrate);
    lame_set_VBR_max_bitrate_kbps(lame->gfp, lame->vbr_max_bitrate);
    lame_set_VBR_hard_min(lame->gfp, lame->vbr_force_min_bitrate);

    if (lame->stereo_mode > -1) {
        lame_set_mode(lame->gfp, (MPEG_mode)lame->stereo_mode);
    }

    if (lame->bitrate_mode == 0) { // CBR
        lame_set_VBR(lame->gfp, vbr_off);
    }

    if (lame->bitrate_mode == 1) { // VBR
        lame_set_VBR(lame->gfp, vbr_default);
    }

    if (lame->bitrate_mode == 2) { // ABR
        lame_set_VBR(lame->gfp, vbr_abr);
    }

    if (lame->lowpass_freq > 0) {
        lame_set_lowpassfreq(lame->gfp, lame->lowpass_freq * 1000);
    }

    if (lame->lowpass_width > 0) {
        lame_set_lowpasswidth(lame->gfp, lame->lowpass_width * 1000);
    }

    if (lame->highpass_freq > 0) {
        lame_set_highpassfreq(lame->gfp, lame->highpass_freq * 1000);
    }

    if (lame->highpass_width > 0) {
        lame_set_highpasswidth(lame->gfp, lame->highpass_width * 1000);
    }

    if ((rc = lame_init_params(lame->gfp)) < 0) {
        snprintf(info_buf, sizeof(info_buf), _("unable to init lame params %d"), rc);

        print_info(info_buf, 1);
        return 1;
    }

    /*
    printf("MP3 Quality: %d\n", lame_get_quality(lame->gfp));
    printf("MP3 Stereo Mode: %d\n", lame_get_mode(lame->gfp));
    printf("MP3 Bitrate Mode: %d\n", lame_get_VBR(lame->gfp));
    printf("MP3 vbr: %d\n", lame_get_VBR(lame->gfp));
    printf("MP3 vbr quality: %d\n", lame_get_VBR_q(lame->gfp));
    printf("MP3 vbr mean bitrate: %d\n", lame_get_VBR_mean_bitrate_kbps(lame->gfp));
    printf("MP3 vbr min bitrate: %d\n", lame_get_VBR_min_bitrate_kbps(lame->gfp));
    printf("MP3 vbr max bitrate: %d\n", lame_get_VBR_max_bitrate_kbps(lame->gfp));
    printf("MP3 lowpass freq: %d\n", lame_get_lowpassfreq(lame->gfp));
    printf("MP3 lowpass width: %d\n", lame_get_lowpasswidth(lame->gfp));
    printf("MP3 highpass freq: %d\n", lame_get_highpassfreq(lame->gfp));
    printf("MP3 highpass width: %d\n", lame_get_highpasswidth(lame->gfp));
    printf("MP3 output sample rate: %d\n", lame_get_out_samplerate(lame->gfp));
    printf("MP3 vbr force min br: %d\n", lame_get_VBR_hard_min(lame->gfp));
    printf("\n");
    */

    // printf("MP3 bitrate: %d\n", lame->bitrate);

    lame->state = LAME_READY;
    return 0;
}

int lame_enc_reinit(lame_enc *lame)
{
    if (lame != NULL) {
        lame_enc_close(lame);
        return lame_enc_init(lame);
    }
    return 1;
}

int lame_enc_get_samplerate(lame_enc *lame)
{
    return lame_get_out_samplerate(lame->gfp);
}

int lame_enc_flush_file(lame_enc *lame, FILE *file)
{
    int bytes_flushed;
    unsigned char buf[8192];

    lame->state = LAME_BUSY;
    bytes_flushed = lame_encode_flush(lame->gfp, (unsigned char *)buf, sizeof(buf));

    if (bytes_flushed > 0) {
        fwrite(buf, 1, bytes_flushed, file);
        //    lame_mp3_tags_fid(lame->gfp, file);
        //    lame_init_bitstream(lame->gfp);
    }

    lame->state = LAME_READY;
    return bytes_flushed;
}

void lame_enc_close(lame_enc *lame)
{
    while (lame->state == LAME_BUSY)
        ;

    if (lame->gfp != NULL) {
        lame_close(lame->gfp);
    }

    lame->gfp = NULL;
}

int lame_enc_encode(lame_enc *lame, float *pcm_buf, char *enc_buf, int samples, int buf_size)
{
    int rc;

    if (samples == 0 || lame->gfp == NULL) {
        return 0;
    }

    lame->state = LAME_BUSY;

    if (lame->channel == 2) { // stereo
        rc = lame_encode_buffer_interleaved_ieee_float(lame->gfp, pcm_buf, samples, (unsigned char *)enc_buf, buf_size);
    }
    else { // mono
        rc = lame_encode_buffer_ieee_float(lame->gfp, pcm_buf, pcm_buf, samples, (unsigned char *)enc_buf, buf_size);
    }

    lame->state = LAME_READY;

    return rc;
}
