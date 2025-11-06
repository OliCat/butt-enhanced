#include "stereo_tool.h"
#include "cfg.h"
#include "butt.h"
#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
#include <errno.h>
#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

// Define macOS compatibility for StereoTool SDK
#define _ST_MAC

// Include StereoTool SDK headers
#include "stereo_tool_sdk/Generic_StereoTool.h"
#include "stereo_tool_sdk/ParameterEnum.h"

// Global instances
stereo_tool_t st_stream = {0};
stereo_tool_t st_record = {0};

// Dynamic library handle
static void *st_library = NULL;

// Function pointers for dynamic loading
static gStereoTool* (*stereoTool_Create_ptr)(const char* key) = NULL;
static void (*stereoTool_Delete_ptr)(gStereoTool* st_instance) = NULL;
static void (*stereoTool_Process_ptr)(gStereoTool* st_instance, float* samples, int32_t numsamples, int32_t channels, int32_t samplerate) = NULL;
static bool (*stereoTool_LoadPreset_ptr)(gStereoTool* st_instance, const char* filename, int loadsave_type) = NULL;
static bool (*stereoTool_CheckLicenseValid_ptr)(gStereoTool* st_instance) = NULL;
static int (*stereoTool_GetLatency2_ptr)(gStereoTool* st_instance, int32_t samplerate, bool feed_silence) = NULL;
static int (*stereoTool_GetSoftwareVersion_ptr)(void) = NULL;
static int (*stereoTool_GetApiVersion_ptr)(void) = NULL;
static bool (*stereoTool_GetUnlicensedUsedFeatures_ptr)(gStereoTool* st_instance, char* buffer, int buffersize) = NULL;

// Get the bundle's Framework directory path
static char* get_bundle_framework_path(void) {
    static char bundle_path[1024];
    
    // Get the executable path
    char exec_path[1024];
    uint32_t size = sizeof(exec_path);
    if (_NSGetExecutablePath(exec_path, &size) == 0) {
        // Navigate from MacOS/BUTT to Frameworks/
        char* last_slash = strrchr(exec_path, '/');
        if (last_slash) {
            *last_slash = '\0'; // Remove executable name
            snprintf(bundle_path, sizeof(bundle_path), "%s/../Frameworks", exec_path);
            return bundle_path;
        }
    }
    return NULL;
}

// Load the dynamic library and function pointers
static int load_stereo_tool_library(void) {
    if (st_library) {
        return 0; // Already loaded
    }
    
    // Get bundle framework path
    char* bundle_fw_path = get_bundle_framework_path();
    char bundle_lib_path[1024];
    if (bundle_fw_path) {
        snprintf(bundle_lib_path, sizeof(bundle_lib_path), "%s/libStereoTool64.dylib", bundle_fw_path);
    }
    
    // Try to load the library - Bundle first, then development paths
    const char* lib_paths[] = {
        bundle_fw_path ? bundle_lib_path : NULL,
        "../libStereoTool_992/libStereoTool64.dylib",
        "../libStereoTool_1051/lib/macOS/Universal/64/libStereoTool_64.dylib",
        "/usr/local/lib/libStereoTool.dylib",
        "/opt/homebrew/lib/libStereoTool.dylib",
        NULL
    };
    
    for (int i = 0; lib_paths[i]; i++) {
        st_library = dlopen(lib_paths[i], RTLD_LAZY);
        if (st_library) {
            char info_msg[256];
            snprintf(info_msg, sizeof(info_msg), "StereoTool: Loaded library from %s", lib_paths[i]);
            print_info(info_msg, 0);
            break;
        }
    }
    
    if (!st_library) {
        char info_msg[256];
        snprintf(info_msg, sizeof(info_msg), "StereoTool: Could not load library: %s", dlerror());
        print_info(info_msg, 0);
        return -1;
    }
    
    // Load function pointers
    stereoTool_Create_ptr = (gStereoTool* (*)(const char*))dlsym(st_library, "stereoTool_Create");
    stereoTool_Delete_ptr = (void (*)(gStereoTool*))dlsym(st_library, "stereoTool_Delete");
    stereoTool_Process_ptr = (void (*)(gStereoTool*, float*, int32_t, int32_t, int32_t))dlsym(st_library, "stereoTool_Process");
    stereoTool_LoadPreset_ptr = (bool (*)(gStereoTool*, const char*, int))dlsym(st_library, "stereoTool_LoadPreset");
    stereoTool_CheckLicenseValid_ptr = (bool (*)(gStereoTool*))dlsym(st_library, "stereoTool_CheckLicenseValid");
    stereoTool_GetLatency2_ptr = (int (*)(gStereoTool*, int32_t, bool))dlsym(st_library, "stereoTool_GetLatency2");
    stereoTool_GetSoftwareVersion_ptr = (int (*)(void))dlsym(st_library, "stereoTool_GetSoftwareVersion");
    stereoTool_GetApiVersion_ptr = (int (*)(void))dlsym(st_library, "stereoTool_GetApiVersion");
    stereoTool_GetUnlicensedUsedFeatures_ptr = (bool (*)(gStereoTool*, char*, int))dlsym(st_library, "stereoTool_GetUnlicensedUsedFeatures");
    
    if (!stereoTool_Create_ptr || !stereoTool_Delete_ptr || !stereoTool_Process_ptr || !stereoTool_LoadPreset_ptr) {
        print_info("StereoTool: Failed to load required functions", 0);
        dlclose(st_library);
        st_library = NULL;
        return -1;
    }
    
    return 0;
}

int stereo_tool_init(void) {
    print_info("StereoTool: Initializing...", 0);
    
    // Load the dynamic library
    if (load_stereo_tool_library() != 0) {
        print_info("StereoTool: Library loading failed", 0);
        return -1;
    }
    
    // Initialize instances
    memset(&st_stream, 0, sizeof(st_stream));
    memset(&st_record, 0, sizeof(st_record));
    
    st_stream.status = STEREO_TOOL_DISABLED;
    st_record.status = STEREO_TOOL_DISABLED;
    
    // Initialize mutexes for thread safety
    if (pthread_mutex_init(&st_stream.mutex, NULL) != 0) {
        print_info("StereoTool: Failed to initialize stream mutex", 0);
        return -1;
    }
    if (pthread_mutex_init(&st_record.mutex, NULL) != 0) {
        print_info("StereoTool: Failed to initialize record mutex", 0);
        pthread_mutex_destroy(&st_stream.mutex);
        return -1;
    }
    
    // Print version information
    if (stereoTool_GetSoftwareVersion_ptr && stereoTool_GetApiVersion_ptr) {
        int sw_version = stereoTool_GetSoftwareVersion_ptr();
        int api_version = stereoTool_GetApiVersion_ptr();
        char info_msg[256];
        snprintf(info_msg, sizeof(info_msg), "StereoTool: Software version %d, API version %d", sw_version, api_version);
        print_info(info_msg, 0);
    }
    
    return 0;
}

void stereo_tool_cleanup(void) {
    print_info("StereoTool: Cleanup", 0);

    // Forcer l'arrêt des threads actifs avant de nettoyer les instances
    // Cela évite les deadlocks si les threads détiennent encore les mutex
    st_stream.status = STEREO_TOOL_DISABLED;
    st_record.status = STEREO_TOOL_DISABLED;

    // Attendre un peu que les threads se terminent
    usleep(100000); // 100ms

    // Clean up instances avec gestion d'erreur robuste
    stereo_tool_destroy_instance(&st_stream);
    stereo_tool_destroy_instance(&st_record);

    // Destroy mutexes avec gestion d'erreur (ignorer les erreurs car les threads sont arrêtés)
    // Les mutex peuvent être détruits même si des threads les détiennent encore
    int ret1 = pthread_mutex_destroy(&st_stream.mutex);
    int ret2 = pthread_mutex_destroy(&st_record.mutex);

    if (ret1 != 0 && ret1 != EBUSY) {
        printf("StereoTool: Warning - Failed to destroy stream mutex: %d\n", ret1);
    }
    if (ret2 != 0 && ret2 != EBUSY) {
        printf("StereoTool: Warning - Failed to destroy record mutex: %d\n", ret2);
    }

    if (st_library) {
        int dlclose_result = dlclose(st_library);
        if (dlclose_result != 0) {
            printf("StereoTool: Warning - dlclose failed: %s\n", dlerror());
        }
        st_library = NULL;
    }

    printf("StereoTool: Cleanup completed\n");
}

bool stereo_tool_is_available(void) {
    return (st_library != NULL);
}

const char *stereo_tool_get_version_string(void) {
    if (stereoTool_GetSoftwareVersion_ptr) {
        static char version_str[64];
        int version = stereoTool_GetSoftwareVersion_ptr();
        snprintf(version_str, sizeof(version_str), "StereoTool SDK v%d.%02d", version / 100, version % 100);
        return version_str;
    }
    return "StereoTool SDK (version unknown)";
}

int stereo_tool_create_instance(stereo_tool_t *st, const char *license_key, int sample_rate, int channels) {
    if (!st || !stereoTool_Create_ptr) {
        return -1;
    }
    
    // Lock mutex for thread safety
    pthread_mutex_lock(&st->mutex);
    
    // Clean up existing instance if any
    if (st->instance) {
        // Temporarily unlock to avoid deadlock in destroy_instance
        pthread_mutex_unlock(&st->mutex);
        stereo_tool_destroy_instance(st);
        pthread_mutex_lock(&st->mutex);
    }
    
    // Create StereoTool instance
    st->instance = stereoTool_Create_ptr(license_key);
    if (!st->instance) {
        print_info("StereoTool: Failed to create instance", 0);
        st->status = STEREO_TOOL_ERROR;
        return -1;
    }
    
    // Store parameters
    if (license_key) {
        st->license_key = strdup(license_key);
    }
    st->sample_rate = sample_rate;
    st->channels = channels;
    st->status = STEREO_TOOL_ENABLED;
    
    // Check license validity
    if (stereoTool_CheckLicenseValid_ptr) {
        st->license_valid = stereoTool_CheckLicenseValid_ptr(st->instance);
        if (!st->license_valid) {
            print_info("StereoTool: Invalid or missing license", 0);
            if (stereoTool_GetUnlicensedUsedFeatures_ptr) {
                char unlicensed_features[1024];
                if (stereoTool_GetUnlicensedUsedFeatures_ptr(st->instance, unlicensed_features, sizeof(unlicensed_features))) {
                    char info_msg[1280];
                    snprintf(info_msg, sizeof(info_msg), "StereoTool: Unlicensed features: %s", unlicensed_features);
                    print_info(info_msg, 0);
                }
            }
        } else {
            print_info("StereoTool: Valid license", 0);
        }
    }
    
    // Get latency
    if (stereoTool_GetLatency2_ptr) {
        st->latency = stereoTool_GetLatency2_ptr(st->instance, sample_rate, true);
        char info_msg[256];
        snprintf(info_msg, sizeof(info_msg), "StereoTool: Latency: %d samples", st->latency);
        print_info(info_msg, 0);
    }
    
    // Unlock mutex
    pthread_mutex_unlock(&st->mutex);
    
    return 0;
}

void stereo_tool_destroy_instance(stereo_tool_t *st) {
    if (!st) return;
    
    // Lock mutex for thread safety
    pthread_mutex_lock(&st->mutex);
    
    if (st->instance && stereoTool_Delete_ptr) {
        stereoTool_Delete_ptr(st->instance);
        st->instance = NULL;
    }
    
    if (st->license_key) {
        free(st->license_key);
        st->license_key = NULL;
    }
    
    if (st->preset_file) {
        free(st->preset_file);
        st->preset_file = NULL;
    }
    
    // Ne pas memset la structure: le mutex resterait invalide et l'unlock bloquerait.
    // Réinitialiser proprement les champs gérés et marquer désactivé.
    st->status = STEREO_TOOL_DISABLED;
    st->sample_rate = 0;
    st->channels = 0;
    st->latency = 0;
    st->license_valid = false;
    
    // Unlock mutex en conservant un mutex valide
    pthread_mutex_unlock(&st->mutex);
}

int stereo_tool_load_preset(stereo_tool_t *st, const char *preset_file) {
    if (!st || !preset_file || !st->instance || !stereoTool_LoadPreset_ptr) {
        return -1;
    }
    
    // Load the preset
    if (!stereoTool_LoadPreset_ptr(st->instance, preset_file, ID_SAVE_ALLSETTINGS)) {
        char info_msg[512];
        snprintf(info_msg, sizeof(info_msg), "StereoTool: Failed to load preset: %s", preset_file);
        print_info(info_msg, 0);
        return -1;
    }
    
    // Update preset file path
    if (st->preset_file) {
        free(st->preset_file);
    }
    st->preset_file = strdup(preset_file);
    st->preset_loaded = true;
    
    // Update latency after loading preset
    if (stereoTool_GetLatency2_ptr) {
        st->latency = stereoTool_GetLatency2_ptr(st->instance, st->sample_rate, true);
    }
    
    char info_msg[512];
    snprintf(info_msg, sizeof(info_msg), "StereoTool: Loaded preset: %s", preset_file);
    print_info(info_msg, 0);
    return 0;
}

int stereo_tool_process_samples(stereo_tool_t *st, float *samples, int num_samples) {
    static int process_debug_counter = 0;
    
    if (!st || !samples || num_samples <= 0) {
        if (process_debug_counter == 0) {
            printf("DEBUG: stereo_tool_process_samples() - Invalid params: st=%p, samples=%p, num_samples=%d\n", 
                   st, samples, num_samples);
            fflush(stdout);
        }
        return -1;
    }
    
    // Lock mutex for thread safety
    pthread_mutex_lock(&st->mutex);
    
    if (st->status != STEREO_TOOL_ENABLED || !st->instance || !stereoTool_Process_ptr) {
        if (process_debug_counter == 0) {
            printf("DEBUG: stereo_tool_process_samples() - Not ready: status=%d, instance=%p, process_ptr=%p\n", 
                   st->status, st->instance, stereoTool_Process_ptr);
            fflush(stdout);
        }
        pthread_mutex_unlock(&st->mutex);
        return -1;
    }
    
    process_debug_counter++;
    if (process_debug_counter == 100) {
        printf("DEBUG: stereo_tool_process_samples() - Processing %d samples\n", num_samples);
        fflush(stdout);
        process_debug_counter = 0;
    }
    
    // Process samples with StereoTool
    stereoTool_Process_ptr(st->instance, samples, num_samples, st->channels, st->sample_rate);
    
    // Unlock mutex
    pthread_mutex_unlock(&st->mutex);
    
    return 0;
}

int stereo_tool_get_latency(stereo_tool_t *st) {
    if (!st) return 0;
    return st->latency;
}

int stereo_tool_get_latency_ms(stereo_tool_t *st, int sample_rate) {
    if (!st || sample_rate <= 0) return 0;
    return (st->latency * 1000) / sample_rate;
}

void stereo_tool_update_config_latency(void) {
    // Mettre à jour la latence dans la config globale
    int latency_samples = 0;
    
    if (cfg.stereo_tool.enabled_stream && st_stream.status == STEREO_TOOL_ENABLED) {
        latency_samples = latency_samples > st_stream.latency ? latency_samples : st_stream.latency;
    }
    
    if (cfg.stereo_tool.enabled_rec && st_record.status == STEREO_TOOL_ENABLED) {
        latency_samples = latency_samples > st_record.latency ? latency_samples : st_record.latency;
    }
    
    // Convertir en millisecondes
    cfg.stereo_tool.latency_ms = (latency_samples * 1000) / cfg.audio.samplerate;
    
    printf("StereoTool: Latence mise à jour: %d échantillons (%d ms)\n", 
           latency_samples, cfg.stereo_tool.latency_ms);
}

bool stereo_tool_check_license(stereo_tool_t *st) {
    if (!st) return false;
    return st->license_valid;
}

const char *stereo_tool_get_status_string(stereo_tool_status_t status) {
    switch (status) {
        case STEREO_TOOL_DISABLED: return "Disabled";
        case STEREO_TOOL_ENABLED: return "Enabled";
        case STEREO_TOOL_ERROR: return "Error";
        default: return "Unknown";
    }
}

int stereo_tool_test_license_key(const char* license) {
    if (!license || !stereoTool_Create_ptr || !stereoTool_Delete_ptr) {
        return -1; // Error
    }
    
    // Create a temporary instance to test the license
    gStereoTool* temp_instance = stereoTool_Create_ptr(license);
    if (!temp_instance) {
        return -1; // Error creating instance
    }
    
    int result = 1; // Assume demo mode
    
    // Check if license is valid
    if (stereoTool_CheckLicenseValid_ptr) {
        if (stereoTool_CheckLicenseValid_ptr(temp_instance)) {
            result = 0; // Valid license
        }
    }
    
    // Clean up temporary instance
    stereoTool_Delete_ptr(temp_instance);
    
    return result;
} 