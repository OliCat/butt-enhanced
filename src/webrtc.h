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

#ifndef WEBRTC_H
#define WEBRTC_H

enum {
    WEBRTC_OK = 0,
    WEBRTC_RETRY = 1,
    WEBRTC_ABORT = 2,
    WEBRTC_ASK = 3,
};

int webrtc_update_song(char *song_name);
int webrtc_connect(void);
int webrtc_send(char *buf, int buf_len);
void webrtc_disconnect(void);
int webrtc_get_listener_count(void);

#endif
