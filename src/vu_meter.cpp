// vu-meter functions for butt
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
//
#include <math.h>
#include "flgui.h"

#include "vu_meter.h"

void vu_left_peak_timer(void *);
void vu_right_peak_timer(void *);

float left_peak_dB;
float right_peak_dB;

void vu_init(void)
{
    left_peak_dB = -90;
    right_peak_dB = -90;
}
void vu_meter(float left, float right, float l_peak, float r_peak)
{
    float left_dB;
    float right_dB;
    float l_peak_dB;
    float r_peak_dB;

    left_dB = left > 0 ? 20 * log10(left) : -90;
    right_dB = right > 0 ? 20 * log10(right) : -90;

    l_peak_dB = l_peak > 0 ? 20 * log10(l_peak) : -90;
    r_peak_dB = r_peak > 0 ? 20 * log10(r_peak) : -90;

    if (l_peak_dB > left_peak_dB) {
        left_peak_dB = l_peak_dB;
        Fl::remove_timeout(&vu_left_peak_timer);
        Fl::add_timeout(1.5 /*second*/, &vu_left_peak_timer);
    }

    if (r_peak_dB > right_peak_dB) {
        right_peak_dB = r_peak_dB;
        Fl::remove_timeout(&vu_right_peak_timer);
        Fl::add_timeout(1.5 /*second*/, &vu_right_peak_timer);
    }

    fl_g->vumeter->value(left_dB, right_dB, left_peak_dB, right_peak_dB);
}

void vu_left_peak_timer(void *)
{
    left_peak_dB = -90;
}

void vu_right_peak_timer(void *)
{
    right_peak_dB = -90;
}
