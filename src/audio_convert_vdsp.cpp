#include "audio_convert_vdsp.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/time.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_MAC
#include <Accelerate/Accelerate.h>
#define HAS_VDSP 1
#endif
#endif

#ifndef HAS_VDSP
#define HAS_VDSP 0
#endif

// Configuration par défaut
static audio_convert_config_t default_config = {
    .dither_type = DITHER_TPDF,
    .use_vdsp = true,
    .clip_protection = true,
    .noise_floor_db = -144.0f
};

// State global pour le générateur de bruit dithering
static uint32_t dither_rng_state = 1;

// Générateur de bruit TPDF (Triangular Probability Density Function)
static inline float generate_tpdf_noise(void) {
    // LFSR simple pour génération de bruit
    dither_rng_state = (dither_rng_state * 1664525U + 1013904223U) & 0xFFFFFFFFU;
    float rand1 = (float)(dither_rng_state >> 16) / 65535.0f;
    
    dither_rng_state = (dither_rng_state * 1664525U + 1013904223U) & 0xFFFFFFFFU;
    float rand2 = (float)(dither_rng_state >> 16) / 65535.0f;
    
    // TPDF = rand1 + rand2 - 1.0, amplitude = 1 LSB pour 16-bit
    return (rand1 + rand2 - 1.0f) * (1.0f / 32768.0f);
}

// Générateur de bruit RPDF (Rectangular Probability Density Function)
static inline float generate_rpdf_noise(void) {
    dither_rng_state = (dither_rng_state * 1664525U + 1013904223U) & 0xFFFFFFFFU;
    float rand_val = (float)(dither_rng_state >> 16) / 65535.0f;
    
    // RPDF = rand - 0.5, amplitude = 1 LSB pour 16-bit
    return (rand_val - 0.5f) * (1.0f / 32768.0f);
}

// Conversion float vers L24 big-endian optimisée avec vDSP
int audio_convert_float_to_l24_vdsp(const float* input, uint8_t* output, 
                                    size_t samples, const audio_convert_config_t* config) {
    if (!input || !output || samples == 0) {
        return -1;
    }
    
    const audio_convert_config_t* cfg = config ? config : &default_config;
    const float scale = 8388607.0f; // 2^23 - 1 pour L24
    
#if HAS_VDSP
    if (cfg->use_vdsp) {
        // Utiliser vDSP pour la conversion vectorisée
        float* temp_scaled = (float*)malloc(samples * sizeof(float));
        if (!temp_scaled) {
            return -1;
        }
        
        // Étape 1: Clamping avec vDSP
        float min_val = -1.0f, max_val = 1.0f;
        if (cfg->clip_protection) {
            vDSP_vclip(input, 1, &min_val, &max_val, temp_scaled, 1, (vDSP_Length)samples);
        } else {
            memcpy(temp_scaled, input, samples * sizeof(float));
        }
        
        // Étape 2: Mise à l'échelle vectorisée
        vDSP_vsmul(temp_scaled, 1, &scale, temp_scaled, 1, (vDSP_Length)samples);
        
        // Étape 3: Conversion vers entiers 32-bit puis packing L24 big-endian
        int32_t* temp_int32 = (int32_t*)malloc(samples * sizeof(int32_t));
        if (!temp_int32) {
            free(temp_scaled);
            return -1;
        }
        
        vDSP_vfix32(temp_scaled, 1, temp_int32, 1, (vDSP_Length)samples);
        
        // Packing manuel en L24 big-endian (3 octets par échantillon)
        for (size_t i = 0; i < samples; i++) {
            int32_t sample = temp_int32[i];
            
            // Clamping final pour L24
            if (sample > 8388607) sample = 8388607;
            else if (sample < -8388608) sample = -8388608;
            
            // Packing big-endian: MSB first
            output[i * 3 + 0] = (uint8_t)((sample >> 16) & 0xFF); // MSB
            output[i * 3 + 1] = (uint8_t)((sample >> 8) & 0xFF);  // Middle
            output[i * 3 + 2] = (uint8_t)(sample & 0xFF);         // LSB
        }
        
        free(temp_scaled);
        free(temp_int32);
        return 0;
    }
#endif
    
    // Fallback: conversion sans vDSP
    for (size_t i = 0; i < samples; i++) {
        float sample = input[i];
        
        // Protection contre l'écrêtage
        if (cfg->clip_protection) {
            sample = fmaxf(-1.0f, fminf(1.0f, sample));
        }
        
        // Conversion vers L24
        int32_t pcm_sample = (int32_t)(sample * scale);
        
        // Clamping final
        if (pcm_sample > 8388607) pcm_sample = 8388607;
        else if (pcm_sample < -8388608) pcm_sample = -8388608;
        
        // Packing big-endian conforme RFC 3190
        output[i * 3 + 0] = (uint8_t)((pcm_sample >> 16) & 0xFF); // MSB
        output[i * 3 + 1] = (uint8_t)((pcm_sample >> 8) & 0xFF);  // Middle
        output[i * 3 + 2] = (uint8_t)(pcm_sample & 0xFF);         // LSB
    }
    
    return 0;
}

// Conversion float vers PCM16 avec dithering TPDF
int audio_convert_float_to_pcm16_vdsp(const float* input, int16_t* output, 
                                      size_t samples, const audio_convert_config_t* config) {
    if (!input || !output || samples == 0) {
        return -1;
    }
    
    const audio_convert_config_t* cfg = config ? config : &default_config;
    const float scale = 32767.0f; // 2^15 - 1 pour PCM16
    
#if HAS_VDSP
    if (cfg->use_vdsp && cfg->dither_type == DITHER_NONE) {
        // Version vDSP optimisée sans dithering
        float* temp_scaled = (float*)malloc(samples * sizeof(float));
        if (!temp_scaled) {
            return -1;
        }
        
        // Clamping et mise à l'échelle
        float min_val = -1.0f, max_val = 1.0f;
        if (cfg->clip_protection) {
            vDSP_vclip(input, 1, &min_val, &max_val, temp_scaled, 1, (vDSP_Length)samples);
        } else {
            memcpy(temp_scaled, input, samples * sizeof(float));
        }
        
        vDSP_vsmul(temp_scaled, 1, &scale, temp_scaled, 1, (vDSP_Length)samples);
        vDSP_vfix16(temp_scaled, 1, output, 1, (vDSP_Length)samples);
        
        free(temp_scaled);
        return 0;
    }
#endif
    
    // Conversion avec dithering (fallback ou avec dithering activé)
    for (size_t i = 0; i < samples; i++) {
        float sample = input[i];
        
        // Protection contre l'écrêtage
        if (cfg->clip_protection) {
            sample = fmaxf(-1.0f, fminf(1.0f, sample));
        }
        
        // Ajout du dithering si demandé
        if (cfg->dither_type == DITHER_TPDF) {
            sample += generate_tpdf_noise();
        } else if (cfg->dither_type == DITHER_RPDF) {
            sample += generate_rpdf_noise();
        }
        
        // Conversion vers PCM16
        int32_t pcm_sample = (int32_t)(sample * scale);
        
        // Clamping final
        if (pcm_sample > 32767) pcm_sample = 32767;
        else if (pcm_sample < -32768) pcm_sample = -32768;
        
        output[i] = (int16_t)pcm_sample;
    }
    
    return 0;
}

// Initialisation du mini-PLL
int audio_pll_init(audio_pll_t* pll, double target_sample_rate, double window_duration_s) {
    if (!pll || target_sample_rate <= 0 || window_duration_s <= 0) {
        return -1;
    }
    
    memset(pll, 0, sizeof(*pll));
    pll->target_sample_rate = target_sample_rate;
    pll->window_duration_s = window_duration_s;
    
    // Paramètres de PLL conservateurs pour stabilité
    pll->pll_kp = 0.1;   // Gain proportionnel
    pll->pll_ki = 0.01;  // Gain intégral
    
    pll->measured_rate = target_sample_rate;
    pll->initialized = false;
    
    return 0;
}

// Mise à jour du mini-PLL avec horodatage et nombre d'échantillons
int audio_pll_update(audio_pll_t* pll, uint64_t timestamp_ns, size_t samples) {
    if (!pll || samples == 0) {
        return -1;
    }
    
    if (!pll->initialized) {
        pll->last_timestamp_ns = timestamp_ns;
        pll->window_start_ns = timestamp_ns;
        pll->accumulated_samples = samples;
        pll->window_samples = samples;
        pll->initialized = true;
        return 0;
    }
    
    pll->accumulated_samples += samples;
    pll->window_samples += samples;
    
    // Calcul de dérive sur fenêtre glissante
    uint64_t window_dt_ns = timestamp_ns - pll->window_start_ns;
    double window_dt_s = window_dt_ns * 1e-9;
    
    if (window_dt_s >= pll->window_duration_s && pll->window_samples > 0) {
        // Calculer le taux mesuré sur la fenêtre
        double measured_rate = pll->window_samples / window_dt_s;
        
        // Erreur en PPM
        double error_ppm = ((measured_rate - pll->target_sample_rate) / pll->target_sample_rate) * 1e6;
        
        // PLL: mise à jour de l'erreur et de l'intégrale
        pll->pll_error = error_ppm;
        pll->pll_integral += error_ppm * window_dt_s;
        
        // Saturation de l'intégrale pour éviter le wind-up
        if (pll->pll_integral > 100.0) pll->pll_integral = 100.0;
        else if (pll->pll_integral < -100.0) pll->pll_integral = -100.0;
        
        pll->measured_rate = measured_rate;
        
        // Réinitialiser la fenêtre
        pll->window_start_ns = timestamp_ns;
        pll->window_samples = 0;
    }
    
    pll->last_timestamp_ns = timestamp_ns;
    return 0;
}

// Obtenir la correction PLL en PPM
double audio_pll_get_correction_ppm(const audio_pll_t* pll) {
    if (!pll || !pll->initialized) {
        return 0.0;
    }
    
    // Sortie PLL: Kp * erreur + Ki * intégrale
    double correction = pll->pll_kp * pll->pll_error + pll->pll_ki * pll->pll_integral;
    
    // Limitation de la correction pour éviter instabilité
    if (correction > 50.0) correction = 50.0;
    else if (correction < -50.0) correction = -50.0;
    
    return -correction; // Inversion pour correction
}

// Reset du PLL
void audio_pll_reset(audio_pll_t* pll) {
    if (!pll) return;
    
    pll->pll_error = 0.0;
    pll->pll_integral = 0.0;
    pll->accumulated_samples = 0;
    pll->window_samples = 0;
    pll->measured_rate = pll->target_sample_rate;
    pll->initialized = false;
}

// Obtenir timestamp monotonique en nanosecondes
uint64_t audio_get_monotonic_time_ns(void) {
#ifdef __APPLE__
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
#endif
}

// Vérifier la disponibilité de vDSP
bool audio_vdsp_available(void) {
#if HAS_VDSP
    return true;
#else
    return false;
#endif
}

// Initialisation du module
int audio_convert_init(void) {
    // Initialiser le générateur de bruit avec timestamp
    struct timeval tv;
    gettimeofday(&tv, NULL);
    dither_rng_state = (uint32_t)(tv.tv_usec ^ tv.tv_sec);
    
    printf("Audio Convert: Module initialisé, vDSP disponible: %s\n", 
           audio_vdsp_available() ? "Oui" : "Non");
    return 0;
}

// Nettoyage du module
void audio_convert_cleanup(void) {
    // Rien à nettoyer pour l'instant
}
