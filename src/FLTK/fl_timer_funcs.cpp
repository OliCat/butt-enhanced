// FLTK GUI related functions
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
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/stat.h>
#include <pthread.h>

#ifndef WIN32
#include <sys/wait.h>
#endif

#ifdef WIN32
#include "tray_agent.h"
#endif

#include "gettext.h"
#include "config.h"

#include "atom.h"
#include "cfg.h"
#include "butt.h"
#include "util.h"
#include "port_audio.h"
#include "timer.h"
#include "flgui.h"
#include "fl_funcs.h"
#include "shoutcast.h"
#include "icecast.h"
#include "webrtc.h"
#include "strfuncs.h"
#include "fl_timer_funcs.h"
#include "logos.h"
#include "Fl_LED.h"
#include "command.h"
#include "url.h"
#ifdef WITH_RADIOCO
#include "radioco.h"
#endif

#if __APPLE__ && __MACH__
#include "CurrentTrackOSX.h"
#endif

const char *(*current_track_app)(int);

void split_recording_file(void);

pthread_t split_recording_file_thread_detached;
pthread_t request_listener_count_thread_detached;
pthread_t url_song_update_thread_detached;

ATOM_NEW_INT(url_song_update_thread_running, 0);
ATOM_NEW_INT(request_listener_count_thread_running, 0);
ATOM_NEW_INT(g_listener_count, -1);
ATOM_NEW_INT(failed_get_listener_tries, 0);

int g_vu_meter_timer_is_active = 0;
int g_stop_vu_meter_timer = 0;

void set_threshold_input_from_command(command_t *command, Fl_Value_Input *input, Fl_Check_Button *checkbox)
{
    if (command->param != NULL) {
        float val = *(float *)command->param;
        if (val <= 0) {
            checkbox->value(0);
            checkbox->do_callback();
        }
        else {
            checkbox->value(1);
            checkbox->do_callback();
            input->value(val);
            input->do_callback();
        }
        free(command->param);
    }
}

void cmd_timer(void *)
{
    command_t command;
    if (command_get_cmd_from_fifo(&command) < (int)sizeof(command_t)) {
        Fl::repeat_timeout(0.25, &cmd_timer);
        return;
    }

    switch (command.cmd) {
    case CMD_CONNECT:
        if (!connected) {
            if (command.param_size > 0) {
                char *srv_name = (char *)command.param;
                int idx;
                if ((idx = fl_g->choice_cfg_act_srv->find_index(srv_name)) != -1) {
                    fl_g->choice_cfg_act_srv->value(idx);
                    fl_g->choice_cfg_act_srv->do_callback();
                    Fl::add_timeout(0.25, &cmd_timer);
                    button_connect_cb();
                }
                else {
                    Fl::repeat_timeout(0.25, &cmd_timer);
                }

                if (command.param != NULL) {
                    free(command.param);
                }
            }
            else {
                Fl::add_timeout(0.25, &cmd_timer);
                button_connect_cb();
            }
        }
        else {
            Fl::repeat_timeout(0.25, &cmd_timer);
        }
        break;
    case CMD_DISCONNECT:
        if (connected == true) {
            button_disconnect_cb(false);
        }
        else {
            try_to_connect = 0;
        }
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_START_RECORDING:
        if (!recording) {
            button_record_cb(false);
        }
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_STOP_RECORDING:
        stop_recording(false);
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_SPLIT_RECORDING:
        split_recording_file();
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_QUIT:
        window_main_close_cb(false);
        break;
    case CMD_UPDATE_SONGNAME:
        /* cfg.main.song = (char*)realloc(cfg.main.song, command.param_size+1);
         strcpy(cfg.main.song, (char*)command.param);
         Fl::add_timeout(cfg.main.song_delay, &update_song);*/
        fl_g->input_cfg_song->value((const char *)command.param);
        fl_g->button_cfg_song_go->do_callback();
        Fl::repeat_timeout(0.25, &cmd_timer);
        if (command.param != NULL) {
            free(command.param);
        }
        break;
    case CMD_SET_STREAM_SIGNAL_THRESHOLD:
        set_threshold_input_from_command(&command, fl_g->input_cfg_signal, fl_g->check_stream_signal);
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_SET_STREAM_SILENCE_THRESHOLD:
        set_threshold_input_from_command(&command, fl_g->input_cfg_silence, fl_g->check_stream_silence);
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_SET_RECORD_SIGNAL_THRESHOLD:
        set_threshold_input_from_command(&command, fl_g->input_rec_signal, fl_g->check_rec_signal);
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_SET_RECORD_SILENCE_THRESHOLD:
        set_threshold_input_from_command(&command, fl_g->input_rec_silence, fl_g->check_rec_silence);
        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    case CMD_GET_STATUS:
        status_packet_t status_packet;
        status_packet.version = STATUS_PACKET_VERSION;

        status_packet.status = (1 << STATUS_EXTENDED_PACKET) | (connected << STATUS_CONNECTED) | (try_to_connect << STATUS_CONNECTING) |
                               (recording << STATUS_RECORDING) | (signal_detected << STATUS_SIGNAL_DETECTED) | (silence_detected << STATUS_SILENCE_DETECTED);

        status_packet.volume_left = round(10 * fl_g->vumeter->left_dB);
        status_packet.volume_right = round(10 * fl_g->vumeter->right_dB);

        if (connected == 1) {
            status_packet.stream_seconds = (uint32_t)timer_get_elapsed_time(&stream_timer);
            status_packet.stream_kByte = kbytes_sent;
            status_packet.listener_count = atom_get_int(&g_listener_count);
        }
        else {
            status_packet.stream_seconds = 0;
            status_packet.stream_kByte = 0;
            status_packet.listener_count = -1;
        }

        if (recording == 1) {
            status_packet.record_seconds = (uint32_t)timer_get_elapsed_time(&rec_timer);
            status_packet.record_kByte = kbytes_written;
            status_packet.rec_path = strdup(cfg.rec.path);
#ifdef WIN32
            // Replace '/' with '\\'
            // Note: strrpl(&status_packet.rec_path,...) must not be used at this point because addresses of packed struct members may be unaligned
            char *p;
            while ((p = strchr(status_packet.rec_path, '/')) != NULL) {
                *p = '\\';
            }
#endif
        }
        else {
            status_packet.record_seconds = 0;
            status_packet.record_kByte = 0;
            status_packet.rec_path = strdup("");
        }
        status_packet.rec_path_len = strlen(status_packet.rec_path) + 1;

        if (cfg.main.song != NULL) {
            status_packet.song = strdup(cfg.main.song);
        }
        else {
            status_packet.song = strdup("");
        }
        status_packet.song_len = strlen(status_packet.song) + 1;

        command_send_status_reply(&status_packet);

        free(status_packet.song);
        free(status_packet.rec_path);

        Fl::repeat_timeout(0.25, &cmd_timer);
        break;
    default:
        Fl::repeat_timeout(0.25, &cmd_timer);
    }
}

void agent_watchdog_timer(void *)
{
#ifdef WIN32
    int is_iconfied = fl_g->window_main->shown() && !fl_g->window_main->visible();

    if (cfg.main.minimize_to_tray == 1 && is_iconfied == 1 && tray_agent_is_running(NULL) == 0) {
        fl_g->window_main->show();
    }
    else {
        Fl::repeat_timeout(1, &agent_watchdog_timer);
    }
#endif
}

void has_agent_been_started_timer(void *)
{
#ifdef WIN32
    if (tray_agent_is_running(NULL) != 1) {
        fl_alert("Agent could not be started.");
    }
#endif
}

void has_agent_been_stopped_timer(void *)
{
#ifdef WIN32
    if (tray_agent_is_running(NULL) != 0) {
        fl_alert("Agent could not be stopped.");
    }
#endif
}

// Ajouts pour métriques AES67
#include "../aes67_output.h"
#include <chrono>

void vu_meter_timer(void *)
{
    static int cleared = 0;
    static int no_new_frames_cnt = 0;

    if (pa_new_frames) {
        snd_update_vu(0);
        no_new_frames_cnt = 0;
        cleared = 0;
    }
    else if (no_new_frames_cnt < 10) {
        no_new_frames_cnt++;
    }
    else if (cleared == 0) {
        snd_update_vu(1);
        cleared = 1;
    }

    if (g_stop_vu_meter_timer == 1) {
        g_vu_meter_timer_is_active = 0;
        return;
    } else {
        // Mettre à jour le statut AES67 via la nouvelle fonction
        update_aes67_status_display();
        
        // Ancienne logique conservée pour compatibilité
        aes67_output_t* aes67 = aes67_output_get_global_instance();
        if (aes67 && aes67->initialized) {
            static unsigned long long last_bytes = 0;
            static unsigned long long last_packets = 0;
            static double last_time = 0.0;
            static auto last_tp = std::chrono::steady_clock::now();
            auto now_tp = std::chrono::steady_clock::now();
            double dt = std::chrono::duration<double>(now_tp - last_tp).count();
            if (dt > 0.0) {
                unsigned long long dbytes = (aes67->bytes_sent > last_bytes) ? (aes67->bytes_sent - last_bytes) : 0ULL;
                unsigned long long dpkts  = (aes67->packets_sent > last_packets) ? (aes67->packets_sent - last_packets) : 0ULL;
                double kbps = (double)dbytes * 8.0 / 1000.0 / dt;
                double pps  = (double)dpkts / dt;
                // Jitter estimé (placeholder simple, à affiner): 0 en l’état
                double jitter_us = 0.0;
                char buf[256];
                snprintf(buf, sizeof(buf), "Status: %s | %.0f pps | %.1f kbps | jitter %.0f µs",
                         (aes67->config.active ? "Connected" : "Inactive"), pps, kbps, jitter_us);
                if (fl_g && fl_g->label_aes67_status) {
                    fl_g->label_aes67_status->label(buf);
                    fl_g->label_aes67_status->redraw();
                }
                last_bytes = aes67->bytes_sent;
                last_packets = aes67->packets_sent;
                last_tp = now_tp;
                last_time = 1.0; // marqué non nul
            } else {
                last_tp = now_tp;
            }
        }
        if (g_stop_vu_meter_timer != 1) {
            Fl::repeat_timeout(0.05, &vu_meter_timer);
        } else {
            g_vu_meter_timer_is_active = 0;
        }
    }
}

void display_info_timer(void *reset)
{
    char lcd_text_buf[33];

    if (try_to_connect == 1) {
        Fl::repeat_timeout(0.2, &display_info_timer);
        return;
    }

    if (reset != NULL && *(int *)reset == 1) {
        atom_set_int(&g_listener_count, -1);
    }

    if (display_info == SENT_DATA) {
        snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("stream sent\n%0.2lfMB"), kbytes_sent / 1024);
        print_lcd(lcd_text_buf, strlen(lcd_text_buf), 0, 1);
    }

    if (display_info == STREAM_TIME && timer_is_elapsed(&stream_timer)) {
        snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("stream time\n%s"), timer_get_time_str(&stream_timer));
        print_lcd(lcd_text_buf, strlen(lcd_text_buf), 0, 1);
    }

    if (display_info == STREAM_STATE && connected == true) {
        if (cfg.gui.show_listeners == true && atom_get_int(&g_listener_count) > -1) {
            if (atom_get_int(&g_listener_count) <= 99999) {
                snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("On Air\nListeners %5d"), atom_get_int(&g_listener_count));
            }
            else {
                snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("On Air\nListeners>%5d"), atom_get_int(&g_listener_count));
            }
        }
        else {
            snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("On Air"));
        }
        print_lcd(lcd_text_buf, strlen(lcd_text_buf), 0, 1);
    }

    if (display_info == REC_TIME && timer_is_elapsed(&rec_timer)) {
        snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("record time\n%s"), timer_get_time_str(&rec_timer));
        print_lcd(lcd_text_buf, strlen(lcd_text_buf), 0, 1);
    }

    if (display_info == REC_DATA) {
        snprintf(lcd_text_buf, sizeof(lcd_text_buf), _("record size\n%0.2lfMB"), kbytes_written / 1024);
        print_lcd(lcd_text_buf, strlen(lcd_text_buf), 0, 1);
    }

    if (cfg.gui.show_listeners == true) {
        if (display_info == STREAM_STATE) {
            fl_g->label_current_listeners->hide();
        }
        else if (connected && cfg.srv[cfg.selected_srv]->type != WEBRTC && atom_get_int(&g_listener_count) > -1) {
            fl_g->label_current_listeners->show();
        }
    }

    Fl::repeat_timeout(0.2, &display_info_timer);
}

void rotate_sponsor_logo_timer(void *)
{
    static int current_logo = rand() % 2;
    static Fl_Image *sponsor_logo = NULL;

    if (sponsor_logo != NULL) {
        delete sponsor_logo;
    }

    if (current_logo == 0) {
        sponsor_logo = new Fl_RGB_Image(radio_co_logo, 124, 61, 4, 0);
        fl_g->sponsor_logo->callback([](Fl_Widget *w, void *u) {
            fl_open_uri("https://radio.co/?utm_source=butt&utm_medium=app");
        });
        current_logo = 1;
    }
    else if (current_logo == 1) {
        sponsor_logo = new Fl_RGB_Image(live365_logo, 124, 61, 4, 0);
        fl_g->sponsor_logo->callback([](Fl_Widget *w, void *u) {
            fl_open_uri("https://live365.com/broadcaster/radio-broadcasting?utm_source=butt&utm_medium=click&utm_campaign=onestopshop");
        });
        current_logo = 0;
    }

    fl_g->sponsor_logo->image(sponsor_logo);
    fl_g->sponsor_logo->redraw();

    Fl::repeat_timeout(10, &rotate_sponsor_logo_timer);
}

void display_rotate_timer(void *)
{
    if (!connected && !recording) {
        goto exit;
    }

    if (!cfg.gui.lcd_auto) {
        goto exit;
    }

    switch (display_info) {
    case STREAM_STATE:
    case STREAM_TIME:
        display_info = SENT_DATA;
        break;
    case SENT_DATA:
        if (recording) {
            display_info = REC_TIME;
        }
        else {
            display_info = STREAM_TIME;
        }
        break;
    case REC_TIME:
        display_info = REC_DATA;
        break;
    case REC_DATA:
        if (connected) {
            display_info = STREAM_TIME;
        }
        else {
            display_info = REC_TIME;
        }
        break;
    default:
        break;
    }

exit:
    Fl::repeat_timeout(5, &display_rotate_timer);
}

void reconnect_timer(void *)
{
    if (disconnect == 1) {
        return;
    }
    button_connect_cb();
}

void is_connected_timer(void *)
{
    if (!connected) {
        if (cfg.srv[cfg.selected_srv]->type == ICECAST) {
            ic_disconnect();
        }
#ifdef HAVE_LIBDATACHANNEL
        else if (cfg.srv[cfg.selected_srv]->type == WEBRTC) {
            webrtc_disconnect();
        }
#endif
        else {
            sc_disconnect();
        }

#ifdef WIN32
        tray_agent_send_cmd(TA_CONNECT_STATE);
#endif

        Fl::remove_timeout(&display_info_timer);
        Fl::remove_timeout(&is_connected_timer);
        fl_g->button_connect->color(FL_BACKGROUND_COLOR);
        fl_g->button_connect->redraw();

        if (disconnect == 1) {
            return;
        }

        // Initiate delayed reconnect
        if (cfg.main.reconnect_delay > 1) {
            char text_buf[256];
            fl_g->lcd->clear();
            fl_g->lcd->print((const uchar *)_("idle"), strlen(_("idle")));
            fl_g->sponsor_logo->show();
            fl_g->sponsor_logo->redraw();
            snprintf(text_buf, sizeof(text_buf), _("ERROR: Connection lost\nreconnecting in %d seconds..."), cfg.main.reconnect_delay);
            print_info(text_buf, 0);
        }
        else {
            print_info(_("ERROR: Connection lost\nreconnecting..."), 1);
        }
        Fl::add_timeout(cfg.main.reconnect_delay, &reconnect_timer);

        return;
    }

    Fl::repeat_timeout(0.5, &is_connected_timer);
}

void cfg_win_pos_timer(void *)
{
#ifdef WIN32
    fl_g->window_cfg->position(fl_g->window_main->x() + fl_g->window_main->w() + 0, fl_g->window_main->y());
#else // UNIX
    fl_g->window_cfg->position(fl_g->window_main->x() + fl_g->window_main->w(), fl_g->window_main->y());
#endif

    Fl::repeat_timeout(0.1, &cfg_win_pos_timer);
}

void *split_recording_file_thread_func(void *init)
{
    int synced_to_full_hour;
    time_t start_time;

    time_t current_time;
    struct tm *current_time_tm;

    int split_time_seconds = 60 * cfg.rec.split_time;

    struct timespec wait_400ms;
    wait_400ms.tv_sec = 0;
    wait_400ms.tv_nsec = (400 * 1000 * 1000);

    start_time = time(NULL);
    synced_to_full_hour = 0;

    set_max_thread_priority();

    while (recording) {
        current_time = time(NULL);
        current_time_tm = localtime(&current_time);

        if ((cfg.rec.sync_to_hour == 1) && (synced_to_full_hour == 0) && (current_time_tm->tm_min == 0) && (current_time_tm->tm_sec >= 0)) {
            start_time = current_time - current_time_tm->tm_sec;
            synced_to_full_hour = 1;
            split_recording_file();
        }
        else if (current_time - start_time >= split_time_seconds) {
            start_time = current_time;
            split_recording_file();
        }

        nanosleep(&wait_400ms, NULL);
    }

    // Detach thread (free ressources) because no one will call pthread_join() on it
    pthread_detach(pthread_self());

    return NULL;
}

void *request_listener_count_thread_func(void *reset)
{
    int listeners;
    static int got_listener_count = 0;

    atom_set_int(&request_listener_count_thread_running, 1);

    if (reset != NULL && *(int *)reset == 1) {
        got_listener_count = 0;
    }

    if (cfg.srv[cfg.selected_srv]->custom_listener_url != NULL && strlen(cfg.srv[cfg.selected_srv]->custom_listener_url) > 0) {
        if (strstr(cfg.srv[cfg.selected_srv]->custom_listener_url, "/status-json.xsl") != NULL ||
            strstr(cfg.srv[cfg.selected_srv]->custom_listener_url, "/7.xsl") != NULL) {
            char *mount;
            if (cfg.srv[cfg.selected_srv]->custom_listener_mount != NULL && strlen(cfg.srv[cfg.selected_srv]->custom_listener_mount) > 0) {
                mount = cfg.srv[cfg.selected_srv]->custom_listener_mount;
            }
            else {
                if (cfg.srv[cfg.selected_srv]->type == ICECAST) {
                    mount = cfg.srv[cfg.selected_srv]->mount;
                }
                else {
                    mount = NULL;
                }
            }
            listeners = ic_get_listener_count_from_url(cfg.srv[cfg.selected_srv]->custom_listener_url, mount);
        }
        else if (strstr(cfg.srv[cfg.selected_srv]->custom_listener_url, "/stats?sid") != NULL ||
                 strstr(cfg.srv[cfg.selected_srv]->custom_listener_url, "/7.html") != NULL) {
            listeners = sc_get_listener_count_from_url(cfg.srv[cfg.selected_srv]->custom_listener_url);
        }
        else {
            listeners = -1;
        }
    }
    else if (cfg.srv[cfg.selected_srv]->type == ICECAST) {
        listeners = ic_get_listener_count();
    }
    else if (cfg.srv[cfg.selected_srv]->type == SHOUTCAST) {
        listeners = sc_get_listener_count();
    }
#ifdef HAVE_LIBDATACHANNEL
    else if (cfg.srv[cfg.selected_srv]->type == WEBRTC) {
        listeners = webrtc_get_listener_count();
    }
#endif
    else { // if (cfg.srv[cfg.selected_srv]->type == RADIOCO)
        listeners = -1;
    }

    // Increase failed_tries only if we never got a listener count for this session
    if (listeners == -1 && got_listener_count == 0) {
        int failed_tries = atom_get_int(&failed_get_listener_tries);
        atom_set_int(&failed_get_listener_tries, ++failed_tries);
        goto return_thread;
    }

    Fl::lock();
    if (listeners >= 0) {
        char listener_label[32];
        if (display_info != STREAM_STATE) {
            snprintf(listener_label, sizeof(listener_label), "%s: %d", _("Listeners"), listeners);
            fl_g->label_current_listeners->copy_label(listener_label);
            fl_g->label_current_listeners->show();
        }
        got_listener_count = 1;
        atom_set_int(&g_listener_count, listeners);
    }
    else {
        fl_g->label_current_listeners->hide();
        atom_set_int(&g_listener_count, -1);
    }
    Fl::unlock();

return_thread:
    // Detach thread (free ressources) because no one will call pthread_join() on it
    pthread_detach(pthread_self());

    atom_set_int(&request_listener_count_thread_running, 0);

    return NULL;
}

void request_listener_count_timer(void *reset)
{
    if (reset != NULL && *(int *)reset == 1) {
        atom_set_int(&failed_get_listener_tries, 0);
        atom_set_int(&g_listener_count, -1);
    }

    if (connected == 0 || atom_get_int(&failed_get_listener_tries) > 3) {
        fl_g->label_current_listeners->hide();
        return;
    }

    if (atom_get_int(&request_listener_count_thread_running) == 0) {
        if (pthread_create(&request_listener_count_thread_detached, NULL, request_listener_count_thread_func, reset) != 0) {
            print_info("Fatal error: Could not launch request listeners thread. Please restart BUTT", 1);
            return;
        }
    }

    Fl::repeat_timeout(cfg.gui.listeners_update_rate, &request_listener_count_timer);
}

void split_recording_file_timer(void)
{
    if (pthread_create(&split_recording_file_thread_detached, NULL, split_recording_file_thread_func, NULL) != 0) {
        print_info("Fatal error: Could not launch split recording thread. Please restart BUTT", 1);
        return;
    }
}

void split_recording_file(void)
{
    char *p_ext;
    char *insert_pos;
    char ext[64];
    char file_num_str[12];
    char *original_path;

    if (!recording) {
        return;
    }

    p_ext = util_get_file_extension(cfg.rec.filename);
    if (p_ext == NULL) {
        print_info(_("Could not find a file extension in current filename\n"
                     "Automatic file splitting is deactivated"),
                   0);
        return;
    }

    if (eval_record_path(1) != 0) {
        return;
    }

    if (fl_access(cfg.rec.path, F_OK) == 0) { // File exists
        original_path = strdup(cfg.rec.path);
        snprintf(ext, sizeof(ext), "%s", p_ext);
        // increment the index until we find a filename that doesn't exist yet
        for (uint32_t i = 1; /*inf*/; i++) { // index_loop

            snprintf(file_num_str, sizeof(file_num_str), "-%d", i);

            // find beginning of the file extension
            insert_pos = strrstr(cfg.rec.path, ext) - 1;

            // Put index between end of file name end beginning of extension
            strinsrt(&cfg.rec.path, file_num_str, insert_pos);

            if (fl_access(cfg.rec.path, F_OK) < 0) { // Found non-existing file name
                free(original_path);
                break;
            }

            if (i == 0xFFFFFFFF) { // 2^32-1
                print_info(_("Could not find a valid filename for next file"
                             "\nbutt keeps recording to current file"),
                           0);
                free(original_path);
                return;
            }

            free(cfg.rec.path);
            cfg.rec.path = strdup(original_path);
        }
    }

    if ((next_fd = fl_fopen(cfg.rec.path, "wb+")) == NULL) {
        fl_alert(_("Could not open:\n%s"), cfg.rec.path);
        return;
    }

    print_info(_("Recording to:"), 0);
    print_info(cfg.rec.path, 0);

    next_file = 1;
}

void reset_stream_signal_detection_timer(void)
{
    if (cfg.main.signal_detection == 1 && cfg.main.signal_threshold > 0) {
        Fl::remove_timeout(&stream_signal_timer);
        Fl::add_timeout(1, &stream_signal_timer);
    }
}

void stream_signal_timer(void *)
{
    // printf("stream_signal_timer\n");
    static timer_ms_t signal_timer;

    if (signal_detected == true) {
        if (signal_timer.is_running == false) {
            timer_init(&signal_timer, cfg.main.signal_threshold);
            timer_start(&signal_timer);
        }

        if (timer_is_elapsed(&signal_timer)) {
            button_connect_cb();
            timer_stop(&signal_timer);
            return;
        }
    }
    else {
        timer_stop(&signal_timer);
    }

    Fl::repeat_timeout(0.1, &stream_signal_timer);
}

void reset_record_signal_detection_timer(void)
{
    if (cfg.rec.signal_detection == 1 && cfg.rec.signal_threshold > 0) {
        Fl::remove_timeout(&record_signal_timer);
        Fl::add_timeout(1, &record_signal_timer);
    }
}

void record_signal_timer(void *)
{
    // printf("record_signal_timer\n");

    static timer_ms_t signal_timer;
    if (signal_detected == true) {
        if (signal_timer.is_running == false) {
            timer_init(&signal_timer, cfg.rec.signal_threshold);
            timer_start(&signal_timer);
        }

        if (timer_is_elapsed(&signal_timer)) {
            // print_info("Audio signal detected", 0);
            button_record_cb(false);
            timer_stop(&signal_timer);
            return;
        }
    }
    else {
        timer_stop(&signal_timer);
    }

    Fl::repeat_timeout(0.1, &record_signal_timer);
}

void reset_stream_silence_detection_timer(void)
{
    if (cfg.main.silence_detection == 1 && cfg.main.silence_threshold > 0) {
        Fl::remove_timeout(&stream_silence_timer);
        Fl::add_timeout(1, &stream_silence_timer);
    }
}

void stream_silence_timer(void *)
{
    // printf("stream_silence_timer\n");

    static timer_ms_t silence_timer;
    if (silence_detected == true) {
        if (silence_timer.is_running == false) {
            timer_init(&silence_timer, cfg.main.silence_threshold);
            timer_start(&silence_timer);
        }

        if (timer_is_elapsed(&silence_timer)) {
            // print_info("Streaming silence threshold has been reached", 0);
            if (connected == 1 || try_to_connect == 1) {
                button_disconnect_cb(false);
            }
            timer_stop(&silence_timer);
            return;
        }
    }
    else {
        timer_stop(&silence_timer);
    }

    Fl::repeat_timeout(0.1, &stream_silence_timer);
}

void reset_record_silence_detection_timer(void)
{
    if (cfg.rec.silence_detection == 1 && cfg.rec.silence_threshold > 0) {
        Fl::remove_timeout(&record_silence_timer);
        Fl::add_timeout(1, &record_silence_timer);
    }
}

void record_silence_timer(void *)
{
    // printf("record_silence_timer\n");

    static timer_ms_t silence_timer;
    if (silence_detected == true) {
        if (silence_timer.is_running == false) {
            timer_init(&silence_timer, cfg.rec.silence_threshold);
            timer_start(&silence_timer);
        }

        if (timer_is_elapsed(&silence_timer)) {
            // print_info("Recording silence threshold has been reached", 0);
            stop_recording(false);
            timer_stop(&silence_timer);
            return;
        }
    }
    else {
        timer_stop(&silence_timer);
    }

    Fl::repeat_timeout(0.1, &record_silence_timer);
}

void wait_for_radioco_timer(void *)
{
#ifdef WITH_RADIOCO
    int error;

    if (radioco_get_state() == RADIOCO_STATE_WAITING) {
        goto exit;
    }

    error = radioco_get_thread_error();

    if (error == RADIOCO_ERR_OK) {
        error = radioco_request_station_list();
        if (error == RADIOCO_ERR_OK) {
            radioco_stations_t stations;
            radioco_get_station_list(&stations);
            int nitems = fl_g->browser_add_srv_station_list->nitems();
            for (int i = 0; i < stations.num_of_stations; i++) {
                bool exists = false;
                for (int j = 0; j < nitems; j++) {
                    char *list_name = fl_g->browser_add_srv_station_list->text(j + 1);
                    if (!strcmp(list_name, stations.name[i])) {
                        exists = true;
                        break;
                    }
                }

                if (exists == false) {
                    fl_g->browser_add_srv_station_list->add(stations.name[i], 1);
                }
            }
            fl_g->browser_add_srv_station_list->redraw();
            return;
        }
        else {
            fl_alert("Error during radioco stations request (%d).\nPlease try again.", error);
            return;
        }
    }
    else if (error == RADIOCO_ERR_CANCELED) {
        return;
    }
    else {
        fl_alert("Error in radioco thread (%d).\nPlease try again.", error);
        return;
    }

exit:
    Fl::repeat_timeout(1, &wait_for_radioco_timer);
#endif
}

void songfile_timer(void *user_data)
{
    size_t len;
    int num_of_lines;
    int num_of_newlines;
    char song[501];
    char msg[100];
    char *fgets_ret;
    float repeat_time = 1;

    int reset;
    if (user_data != NULL) {
        reset = *((int *)user_data);
    }
    else {
        reset = 0;
    }

#ifdef WIN32
    struct _stat s;
#else
#ifdef __USE_LARGEFILE64
    struct stat64 s; // Fixes fl_stat() on Raspberry PI OS (32 bit)
#else
    struct stat s;
#endif
#endif

    static time_t old_t;

    if (reset == 1) {
        old_t = 0;
    }

    char *last_line = NULL;

    if ((cfg.main.song_path == NULL) || (connected == 0)) {
        goto exit;
    }

    if (fl_stat(cfg.main.song_path, (struct stat *)&s) != 0) {
        // File was probably locked by another application
        // retry in 5 seconds
        repeat_time = 5;
        goto exit;
    }

    if (old_t == s.st_mtime) { // file hasn't changed
        goto exit;
    }

    if ((cfg.main.song_fd = fl_fopen(cfg.main.song_path, "rb")) == NULL) {
        snprintf(msg, sizeof(msg), _("Warning\nCould not open: %s.\nWill retry in 5 seconds"), cfg.main.song_path);

        print_info(msg, 1);
        repeat_time = 5;
        goto exit;
    }

    old_t = s.st_mtime;

    if (cfg.main.read_last_line == 1) {
        /* Read last line instead of first */

        fseek(cfg.main.song_fd, -100, SEEK_END);
        len = fread(song, sizeof(char), 100, cfg.main.song_fd);

        // Count number of lines within the last 100 characters of the file
        // Some programs add a new line to the end of the file and some don't
        // We have to take this into account when counting the number of lines
        num_of_newlines = 0;
        for (uint32_t i = 0; i < len; i++) {
            if (song[i] == '\n') {
                num_of_newlines++;
            }
        }

        if (num_of_newlines == 0) {
            num_of_lines = 1;
        }
        else if (num_of_newlines > 0 && song[len - 1] != '\n') {
            num_of_lines = num_of_newlines + 1;
        }
        else {
            num_of_lines = num_of_newlines;
        }

        if (num_of_lines > 1) { // file has multiple lines
            // Remove newlines at end of file
            if (song[len - 2] == '\r') { // Windows
                song[len - 2] = '\0';
            }
            else if (song[len - 1] == '\n') { // OSX, Linux
                song[len - 1] = '\0';
            }
            else {
                song[len] = '\0';
            }

            last_line = strrchr(song, '\n') + 1;
        }
        else { // file has only one line
            // Remove newlines at end of file
            if (len > 1 && song[len - 2] == '\r') { // Windows
                song[len - 2] = '\0';
            }
            else if (len > 0 && song[len - 1] == '\n') { // OSX, Linux
                song[len - 1] = '\0';
            }
            else {
                song[len] = '\0';
            }

            last_line = song;
        }

        // Remove UTF-8 BOM
        if ((uint8_t)last_line[0] == 0xEF && (uint8_t)last_line[1] == 0xBB && (uint8_t)last_line[2] == 0xBF) {
            cfg.main.song = (char *)realloc(cfg.main.song, strlen(last_line) + 1);
            strcpy(cfg.main.song, last_line + 3);
        }
        else {
            cfg.main.song = (char *)realloc(cfg.main.song, strlen(last_line) + 1);
            strcpy(cfg.main.song, last_line);
        }

        Fl::add_timeout(cfg.main.song_delay, &update_song);
    }
    else {
        // read first line
        fgets_ret = fgets(song, 500, cfg.main.song_fd);

        if (fgets_ret == NULL && feof(cfg.main.song_fd) != 0) { // file is empty (0 bytes)
            len = 0;
        }
        else if (fgets_ret != NULL) { // Normal case
            len = strlen(song);
        }
        else { // Some error occurred
            fclose(cfg.main.song_fd);
            goto exit;
        }

        // remove newline character
        if (len > 1 && song[len - 2] == '\r') { // Windows
            song[len - 2] = '\0';
        }
        else if (len > 0 && song[len - 1] == '\n') { // OSX, Linux
            song[len - 1] = '\0';
        }
        else {
            song[len] = '\0';
        }

        // Remove UTF-8 BOM
        if ((uint8_t)song[0] == 0xEF && (uint8_t)song[1] == 0xBB && (uint8_t)song[2] == 0xBF) {
            cfg.main.song = (char *)realloc(cfg.main.song, strlen(song) + 1);
            strcpy(cfg.main.song, song + 3);
        }
        else {
            cfg.main.song = (char *)realloc(cfg.main.song, strlen(song) + 1);
            strcpy(cfg.main.song, song);
        }

        Fl::add_timeout(cfg.main.song_delay, &update_song);
    }

    fclose(cfg.main.song_fd);

exit:
    Fl::repeat_timeout(repeat_time, &songfile_timer);
}

void *url_song_update_thread_func(void *user_data)
{
    char song[1024];
    char *new_line;

    atom_set_int(&url_song_update_thread_running, 1);

    uint32_t ret = url_get(cfg.main.song_update_url, NULL, song, sizeof(song));
    if (ret <= 0) {
        goto return_thread;
    }

    // Remove new line characters
    new_line = strchr(song, '\r');
    if (new_line != NULL) {
        *new_line = '\0';
    }
    new_line = strchr(song, '\n');
    if (new_line != NULL) {
        *new_line = '\0';
    }

    if (cfg.main.song != NULL) {
        if (strncmp(song, cfg.main.song, sizeof(song)) == 0) {
            goto return_thread;
        }
    }

    cfg.main.song = (char *)realloc(cfg.main.song, strlen(song) + 1);
    strcpy(cfg.main.song, song);

    // Call Fl::add_timeout from main thread
    Fl::awake([](void *) -> void {
        Fl::add_timeout(cfg.main.song_delay, &update_song);
    });

return_thread:
    // Detach thread (free ressources) because no one will call pthread_join() on it
    pthread_detach(pthread_self());

    atom_set_int(&url_song_update_thread_running, 0);

    return NULL;
}

void song_url_timer(void *user_data)
{
    if (atom_get_int(&url_song_update_thread_running) == 0) {
        if (pthread_create(&url_song_update_thread_detached, NULL, url_song_update_thread_func, user_data) != 0) {
            print_info("Fatal error: Could not launch url song update thread. Please restart BUTT", 1);
            return;
        }
    }

    Fl::repeat_timeout(cfg.main.song_update_url_interval, &song_url_timer);
}

void app_timer(void *user_data)
{
    int reset;

    if (user_data != NULL) {
        reset = *((int *)user_data);
    }
    else {
        reset = 0;
    }

    if (current_track_app != NULL) {
        const char *track = current_track_app(cfg.main.app_artist_title_order);
        if (track != NULL) {
            if (cfg.main.song == NULL || strcmp(cfg.main.song, track) || reset == 1) {
                cfg.main.song = (char *)realloc(cfg.main.song, strlen(track) + 1);
                strcpy(cfg.main.song, track);
                Fl::add_timeout(cfg.main.song_delay, &update_song);
            }
            free((void *)track);
        }
        else {
            if (cfg.main.song != NULL && strcmp(cfg.main.song, "")) {
                cfg.main.song = (char *)realloc(cfg.main.song, 1);
                strcpy(cfg.main.song, "");
                Fl::add_timeout(cfg.main.song_delay, &update_song);
            }
        }
    }

    Fl::repeat_timeout(1, &app_timer);
}
