// ringbuffer functions for butt
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include "ringbuffer.h"

int rb_init(ringbuf_t *rb, unsigned int len)
{
    rb->buf = (char *)malloc(len * sizeof(char));
    if (!rb->buf) {
        return -1;
    }

    rb->r_ptr = rb->buf;
    rb->w_ptr = rb->buf;
    rb->size = len;
    rb->full = 0;

    pthread_mutex_init(&rb->mutex, NULL);

    return 0;
}

int rb_filled(ringbuf_t *rb)
{
    int filled;
    char *end_ptr;

    pthread_mutex_lock(&rb->mutex);

    if (rb->w_ptr == rb->r_ptr && rb->full) {
        filled = rb->size;
    }
    else if (rb->w_ptr == rb->r_ptr && !rb->full) {
        filled = 0;
    }
    else if (rb->w_ptr > rb->r_ptr) {
        filled = rb->w_ptr - rb->r_ptr;
    }
    else {
        end_ptr = rb->buf + rb->size;
        filled = end_ptr - rb->r_ptr;
        filled += rb->w_ptr - rb->buf;
    }

    pthread_mutex_unlock(&rb->mutex);

    return filled;
}

int rb_space(ringbuf_t *rb)
{
    int space;
    char *end_ptr;

    pthread_mutex_lock(&rb->mutex);

    if (rb->r_ptr == rb->w_ptr && rb->full) {
        space = 0;
    }
    else if (rb->r_ptr == rb->w_ptr && !rb->full) {
        space = rb->size;
    }
    else if (rb->r_ptr > rb->w_ptr) {
        space = rb->r_ptr - rb->w_ptr;
    }
    else {
        end_ptr = rb->buf + rb->size;
        space = end_ptr - rb->w_ptr;
        space += rb->r_ptr - rb->buf;
    }

    pthread_mutex_unlock(&rb->mutex);

    return space;
}

unsigned int rb_read(ringbuf_t *rb, char *dest)
{
    unsigned int len = 0;
    char *end_ptr;

    if (!dest || !rb->buf) {
        return 0;
    }
    if (len > rb->size) {
        return 0;
    }

    len = rb_filled(rb);

    pthread_mutex_lock(&rb->mutex);

    end_ptr = rb->buf + rb->size;

    if (rb->r_ptr + len < end_ptr) {
        memcpy(dest, rb->r_ptr, len);
        rb->r_ptr += len;
    }
    /*buf content crosses the start point of the ring*/
    else {
        /*copy from r_ptr to start of ringbuffer*/
        memcpy(dest, rb->r_ptr, end_ptr - rb->r_ptr);
        /*copy from start of ringbuffer to w_ptr*/
        memcpy(dest + (end_ptr - rb->r_ptr), rb->buf, len - (end_ptr - rb->r_ptr));
        rb->r_ptr = rb->buf + (len - (end_ptr - rb->r_ptr));
    }

    // 🔧 CORRECTION CRITIQUE: Mettre à jour rb->full AVANT de déverrouiller le mutex
    // Cela évite la race condition avec rb_write()
    if (rb->w_ptr == rb->r_ptr) {
        rb->full = 0;
    }

    pthread_mutex_unlock(&rb->mutex);

    return len;
}

unsigned int rb_read_len(ringbuf_t *rb, char *dest, unsigned int len)
{
    char *end_ptr;
    unsigned int available;

    if (!dest || !rb->buf) {
        return 0;
    }
    if (len > rb->size) {
        return 0;
    }

    pthread_mutex_lock(&rb->mutex);

    // 🔧 CORRECTION CRITIQUE: Vérifier les données disponibles AVANT de lire
    // Calculer les données disponibles sans déverrouiller le mutex
    if (rb->w_ptr == rb->r_ptr && rb->full) {
        available = rb->size;
    }
    else if (rb->w_ptr == rb->r_ptr && !rb->full) {
        available = 0;
    }
    else if (rb->w_ptr > rb->r_ptr) {
        available = rb->w_ptr - rb->r_ptr;
    }
    else {
        end_ptr = rb->buf + rb->size;
        available = end_ptr - rb->r_ptr;
        available += rb->w_ptr - rb->buf;
    }

    // Ne lire que ce qui est réellement disponible
    if (len > available) {
        len = available;
    }

    if (len == 0) {
        pthread_mutex_unlock(&rb->mutex);
        return 0;
    }

    end_ptr = rb->buf + rb->size;

    if (rb->r_ptr + len < end_ptr) {
        memcpy(dest, rb->r_ptr, len);
        rb->r_ptr += len;
    }
    /*buf content crosses the start point of the ring*/
    else {
        unsigned int first_part = end_ptr - rb->r_ptr;
        unsigned int second_part = len - first_part;
        /*copy from r_ptr to start of ringbuffer*/
        memcpy(dest, rb->r_ptr, first_part);
        /*copy from start of ringbuffer to w_ptr (only what's available)*/
        if (second_part > 0) {
            memcpy(dest + first_part, rb->buf, second_part);
        }
        rb->r_ptr = rb->buf + second_part;
    }

    // 🔧 CORRECTION CRITIQUE: Mettre à jour rb->full AVANT de déverrouiller le mutex
    // Cela évite la race condition avec rb_write()
    if (rb->w_ptr == rb->r_ptr) {
        rb->full = 0;
    }

    pthread_mutex_unlock(&rb->mutex);

    return len;
}

int rb_write(ringbuf_t *rb, char *src, unsigned int len)
{
    char *end_ptr;

    if (!src || !rb->buf) {
        return -1;
    }
    if (len > rb->size) {
        return -1;
    }
    if (len == 0) {
        return 0;
    }

    pthread_mutex_lock(&rb->mutex);

    end_ptr = rb->buf + rb->size;

    if (rb->w_ptr + len < end_ptr) {
        memcpy(rb->w_ptr, src, len);
        rb->w_ptr += len;
    }
    else {
        memcpy(rb->w_ptr, src, end_ptr - rb->w_ptr);
        memcpy(rb->buf, src + (end_ptr - rb->w_ptr), len - (end_ptr - rb->w_ptr));
        rb->w_ptr = rb->buf + (len - (end_ptr - rb->w_ptr));
    }

    if (rb->w_ptr == rb->r_ptr) {
        rb->full = 1;
    }

    pthread_mutex_unlock(&rb->mutex);

    return 0;
}

int rb_clear(ringbuf_t *rb)
{
    pthread_mutex_lock(&rb->mutex);
    rb->r_ptr = rb->buf;
    rb->w_ptr = rb->buf;
    rb->full = 0;
    pthread_mutex_unlock(&rb->mutex);

    return 0;
}

int rb_free(ringbuf_t *rb)
{
    free(rb->buf);
    pthread_mutex_destroy(&rb->mutex);
    return 0;
}
