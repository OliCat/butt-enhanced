#ifndef STEREO_TOOL_H
#define STEREO_TOOL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>

// Forward declarations
typedef struct gStereoTool gStereoTool;

// StereoTool integration status
typedef enum {
    STEREO_TOOL_DISABLED = 0,
    STEREO_TOOL_ENABLED = 1,
    STEREO_TOOL_ERROR = -1
} stereo_tool_status_t;

// StereoTool instance data
typedef struct {
    gStereoTool *instance;
    char *license_key;
    char *preset_file;
    int sample_rate;
    int channels;
    int latency;
    stereo_tool_status_t status;
    bool license_valid;
    bool preset_loaded;
    pthread_mutex_t mutex;  // Protection thread-safety
} stereo_tool_t;

// Global instances
extern stereo_tool_t st_stream;
extern stereo_tool_t st_record;

// Function declarations
int stereo_tool_init(void);
void stereo_tool_cleanup(void);

int stereo_tool_create_instance(stereo_tool_t *st, const char *license_key, int sample_rate, int channels);
void stereo_tool_destroy_instance(stereo_tool_t *st);

int stereo_tool_load_preset(stereo_tool_t *st, const char *preset_file);
int stereo_tool_process_samples(stereo_tool_t *st, float *samples, int num_samples);

bool stereo_tool_is_available(void);
const char *stereo_tool_get_version_string(void);

// Utility functions
int stereo_tool_get_latency(stereo_tool_t *st);
int stereo_tool_get_latency_ms(stereo_tool_t *st, int sample_rate);
void stereo_tool_update_config_latency(void);
bool stereo_tool_check_license(stereo_tool_t *st);
int stereo_tool_test_license_key(const char* license);
const char *stereo_tool_get_status_string(stereo_tool_status_t status);

#ifdef __cplusplus
}
#endif

#endif // STEREO_TOOL_H 