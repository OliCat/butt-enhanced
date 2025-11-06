#ifndef AUDIO_CONVERT_VDSP_H
#define AUDIO_CONVERT_VDSP_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Options de dithering pour PCM16
typedef enum {
    DITHER_NONE = 0,
    DITHER_TPDF = 1,    // Triangular Probability Density Function
    DITHER_RPDF = 2     // Rectangular Probability Density Function
} dither_type_t;

// Configuration pour les conversions audio optimisées
typedef struct {
    dither_type_t dither_type;
    bool use_vdsp;                  // Utiliser vDSP si disponible
    bool clip_protection;           // Protection contre l'écrêtage
    float noise_floor_db;           // Plancher de bruit pour le dithering (ex: -144dB)
} audio_convert_config_t;

// Fonctions de conversion optimisées avec vDSP
int audio_convert_float_to_l24_vdsp(const float* input, uint8_t* output, 
                                    size_t samples, const audio_convert_config_t* config);

int audio_convert_float_to_pcm16_vdsp(const float* input, int16_t* output, 
                                      size_t samples, const audio_convert_config_t* config);

// Mini-PLL pour stabilisation de cadence sans PTP
typedef struct {
    double target_sample_rate;
    double measured_rate;
    double pll_error;
    double pll_integral;
    double pll_kp;                  // Gain proportionnel
    double pll_ki;                  // Gain intégral
    uint64_t last_timestamp_ns;
    uint64_t accumulated_samples;
    bool initialized;
    
    // Fenêtre de mesure
    double window_duration_s;       // Durée de fenêtre pour mesurer la dérive
    uint64_t window_start_ns;
    uint64_t window_samples;
} audio_pll_t;

// Fonctions de mini-PLL
int audio_pll_init(audio_pll_t* pll, double target_sample_rate, double window_duration_s);
int audio_pll_update(audio_pll_t* pll, uint64_t timestamp_ns, size_t samples);
double audio_pll_get_correction_ppm(const audio_pll_t* pll);
void audio_pll_reset(audio_pll_t* pll);

// Fonctions utilitaires
uint64_t audio_get_monotonic_time_ns(void);
bool audio_vdsp_available(void);

// Initialisation et nettoyage
int audio_convert_init(void);
void audio_convert_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // AUDIO_CONVERT_VDSP_H
