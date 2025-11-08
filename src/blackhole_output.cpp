#include "blackhole_output.h"
#include <iostream>
#include <cstring>

BlackHoleOutput::BlackHoleOutput()
    : output_unit_(nullptr)
    , initialized_(false)
    , sample_rate_(48000)
    , channels_(2)
{
    memset(&audio_ringbuffer_, 0, sizeof(audio_ringbuffer_));
}

BlackHoleOutput::~BlackHoleOutput() {
    close();
}

AudioDeviceID BlackHoleOutput::findBlackHoleDevice() {
    AudioDeviceID device_id = 0;
    UInt32 property_size = 0;
    
    // Obtenir le nombre de périphériques audio
    AudioObjectPropertyAddress property_address = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    OSStatus status = AudioObjectGetPropertyDataSize(
        kAudioObjectSystemObject,
        &property_address,
        0,
        nullptr,
        &property_size
    );
    
    if (status != noErr) {
        return 0;
    }
    
    UInt32 num_devices = property_size / sizeof(AudioDeviceID);
    std::vector<AudioDeviceID> devices(num_devices);
    
    status = AudioObjectGetPropertyData(
        kAudioObjectSystemObject,
        &property_address,
        0,
        nullptr,
        &property_size,
        devices.data()
    );
    
    if (status != noErr) {
        return 0;
    }
    
    // Chercher BlackHole dans la liste des périphériques
    for (UInt32 i = 0; i < num_devices; i++) {
        CFStringRef device_name = nullptr;
        property_address.mSelector = kAudioObjectPropertyName;
        property_address.mScope = kAudioObjectPropertyScopeGlobal;
        property_size = sizeof(CFStringRef);
        
        status = AudioObjectGetPropertyData(
            devices[i],
            &property_address,
            0,
            nullptr,
            &property_size,
            &device_name
        );
        
        if (status == noErr && device_name) {
            char name_cstr[256];
            CFStringGetCString(device_name, name_cstr, sizeof(name_cstr), kCFStringEncodingUTF8);
            
            if (strstr(name_cstr, "BlackHole") != nullptr) {
                device_id = devices[i];
                CFRelease(device_name);
                break;
            }
            
            CFRelease(device_name);
        }
    }
    
    return device_id;
}

bool BlackHoleOutput::initialize(int sample_rate, int channels) {
    if (initialized_) {
        close();
    }
    
    sample_rate_ = sample_rate;
    channels_ = channels;
    
    // Trouver le périphérique BlackHole
    AudioDeviceID blackhole_id = findBlackHoleDevice();
    if (blackhole_id == 0) {
        std::cerr << "❌ BlackHole non trouvé. Installez-le avec: brew install blackhole-2ch" << std::endl;
        return false;
    }
    
    // Créer un AudioComponent pour la sortie
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_HALOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    
    AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
    if (!comp) {
        std::cerr << "❌ AudioComponent non trouvé" << std::endl;
        return false;
    }
    
    OSStatus status = AudioComponentInstanceNew(comp, &output_unit_);
    if (status != noErr) {
        std::cerr << "❌ Erreur création AudioComponent: " << status << std::endl;
        return false;
    }
    
    // Activer la sortie (output)
    UInt32 enable_io = 1;
    status = AudioUnitSetProperty(
        output_unit_,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Output,
        0, // Output element
        &enable_io,
        sizeof(enable_io)
    );
    
    if (status != noErr) {
        std::cerr << "❌ Erreur activation I/O: " << status << std::endl;
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // Sélectionner BlackHole comme périphérique
    status = AudioUnitSetProperty(
        output_unit_,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &blackhole_id,
        sizeof(blackhole_id)
    );
    
    if (status != noErr) {
        std::cerr << "❌ Erreur sélection périphérique: " << status << std::endl;
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // Obtenir le format du périphérique BlackHole
    AudioStreamBasicDescription device_format;
    UInt32 property_size = sizeof(device_format);
    AudioObjectPropertyAddress property_address = {
        kAudioDevicePropertyStreamFormat,
        kAudioDevicePropertyScopeOutput,
        0
    };
    
    status = AudioObjectGetPropertyData(
        blackhole_id,
        &property_address,
        0,
        nullptr,
        &property_size,
        &device_format
    );
    
    if (status != noErr) {
        std::cerr << "⚠️  Impossible d'obtenir le format du périphérique, utilisation du format par défaut" << std::endl;
        // Utiliser un format par défaut si on ne peut pas obtenir le format du périphérique
        device_format.mSampleRate = static_cast<Float64>(sample_rate_);
        device_format.mFormatID = kAudioFormatLinearPCM;
        device_format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
        device_format.mBytesPerPacket = sizeof(float);
        device_format.mFramesPerPacket = 1;
        device_format.mBytesPerFrame = sizeof(float);
        device_format.mChannelsPerFrame = static_cast<UInt32>(channels_);
        device_format.mBitsPerChannel = 32;
    } else {
        std::cerr << "✅ Format du périphérique BlackHole: sample_rate=" << device_format.mSampleRate 
                  << ", channels=" << device_format.mChannelsPerFrame 
                  << ", format_flags=0x" << std::hex << device_format.mFormatFlags << std::dec << std::endl;
        
        // Ajuster le sample rate et le nombre de canaux si nécessaire
        if (device_format.mSampleRate != static_cast<Float64>(sample_rate_)) {
            std::cerr << "⚠️  Sample rate mismatch: périphérique=" << device_format.mSampleRate 
                      << ", demandé=" << sample_rate_ << std::endl;
        }
        if (device_format.mChannelsPerFrame != static_cast<UInt32>(channels_)) {
            std::cerr << "⚠️  Channel count mismatch: périphérique=" << device_format.mChannelsPerFrame 
                      << ", demandé=" << channels_ << std::endl;
        }
        
        // Forcer le format à float non-interleaved pour notre usage
        device_format.mSampleRate = static_cast<Float64>(sample_rate_);
        device_format.mFormatID = kAudioFormatLinearPCM;
        device_format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
        device_format.mBytesPerPacket = sizeof(float);
        device_format.mFramesPerPacket = 1;
        device_format.mBytesPerFrame = sizeof(float);
        device_format.mChannelsPerFrame = static_cast<UInt32>(channels_);
        device_format.mBitsPerChannel = 32;
    }
    
    // Configurer le format audio
    status = AudioUnitSetProperty(
        output_unit_,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &device_format,
        sizeof(device_format)
    );
    
    if (status != noErr) {
        std::cerr << "❌ Erreur configuration format: " << status << std::endl;
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // Vérifier que le format a été correctement configuré
    AudioStreamBasicDescription actual_format;
    property_size = sizeof(actual_format);
    status = AudioUnitGetProperty(
        output_unit_,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &actual_format,
        &property_size
    );
    
    if (status == noErr) {
        std::cerr << "✅ Format configuré: sample_rate=" << actual_format.mSampleRate 
                  << ", channels=" << actual_format.mChannelsPerFrame 
                  << ", format_flags=0x" << std::hex << actual_format.mFormatFlags << std::dec << std::endl;
    }
    
    // Définir le callback de rendu
    AURenderCallbackStruct callback_struct;
    callback_struct.inputProc = renderCallback;
    callback_struct.inputProcRefCon = this;
    
    status = AudioUnitSetProperty(
        output_unit_,
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Input,
        0,
        &callback_struct,
        sizeof(callback_struct)
    );
    
    if (status != noErr) {
        std::cerr << "❌ Erreur configuration callback: " << status << std::endl;
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // Initialiser l'AudioUnit
    status = AudioUnitInitialize(output_unit_);
    if (status != noErr) {
        std::cerr << "❌ Erreur initialisation AudioUnit: " << status << std::endl;
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // Initialiser le ring buffer (taille = 2 secondes de données)
    unsigned int buffer_size = sample_rate_ * channels_ * sizeof(float) * 2; // 2 secondes
    if (rb_init(&audio_ringbuffer_, buffer_size) != 0) {
        std::cerr << "❌ Erreur initialisation ring buffer" << std::endl;
        AudioUnitUninitialize(output_unit_);
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // Démarrer l'AudioUnit
    status = AudioOutputUnitStart(output_unit_);
    if (status != noErr) {
        std::cerr << "❌ Erreur démarrage AudioUnit: " << status << std::endl;
        rb_free(&audio_ringbuffer_);
        AudioUnitUninitialize(output_unit_);
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    initialized_ = true;
    std::cout << "✅ BlackHole initialisé pour Whisper Streaming (sample_rate: " << sample_rate_ 
              << ", channels: " << channels_ << ", buffer_size=" << buffer_size << " bytes)" << std::endl;
    
    return true;
}

OSStatus BlackHoleOutput::renderCallback(
    void* inRefCon,
    AudioUnitRenderActionFlags* ioActionFlags,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList* ioData
) {
    BlackHoleOutput* self = static_cast<BlackHoleOutput*>(inRefCon);
    return self->render(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
}

OSStatus BlackHoleOutput::render(
    AudioUnitRenderActionFlags* ioActionFlags,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList* ioData
) {
    std::lock_guard<std::mutex> lock(ringbuffer_mutex_);
    
    static int render_count = 0;
    if (render_count++ < 10) {
        int filled = rb_filled(&audio_ringbuffer_);
        std::cerr << "BlackHole::render: inNumberFrames=" << inNumberFrames 
                  << ", ringbuffer_filled=" << filled << " bytes" << std::endl;
    }
    
    // Vérifier que le nombre de buffers correspond au nombre de canaux
    if (ioData->mNumberBuffers != static_cast<UInt32>(channels_)) {
        if (render_count < 10) {
            std::cerr << "BlackHole::render: Buffer count mismatch! ioData->mNumberBuffers=" 
                      << ioData->mNumberBuffers << ", channels_=" << channels_ << std::endl;
        }
        // Envoyer du silence si le nombre de buffers ne correspond pas
        for (UInt32 ch = 0; ch < ioData->mNumberBuffers; ch++) {
            memset(ioData->mBuffers[ch].mData, 0, ioData->mBuffers[ch].mDataByteSize);
        }
        return noErr;
    }
    
    // Calculer la taille des données nécessaires
    size_t required_bytes = inNumberFrames * channels_ * sizeof(float);
    int filled = rb_filled(&audio_ringbuffer_);
    
    // Si pas assez de données disponibles, envoyer du silence
    if (filled < static_cast<int>(required_bytes)) {
        if (render_count < 10) {
            std::cerr << "BlackHole::render: Not enough data! Have " << filled 
                      << " bytes, need " << required_bytes << std::endl;
        }
        for (UInt32 ch = 0; ch < ioData->mNumberBuffers; ch++) {
            memset(ioData->mBuffers[ch].mData, 0, ioData->mBuffers[ch].mDataByteSize);
        }
        return noErr;
    }
    
    // Lire les données depuis le ring buffer (format interleaved)
    std::vector<float> interleaved_data(inNumberFrames * channels_);
    unsigned int bytes_read = rb_read_len(&audio_ringbuffer_, 
                                          reinterpret_cast<char*>(interleaved_data.data()), 
                                          static_cast<unsigned int>(required_bytes));
    
    if (bytes_read < required_bytes) {
        if (render_count < 10) {
            std::cerr << "BlackHole::render: Read less than expected! Read " << bytes_read 
                      << " bytes, expected " << required_bytes << std::endl;
        }
        // Remplir le reste avec du silence
        memset(interleaved_data.data() + (bytes_read / sizeof(float)), 0, 
               required_bytes - bytes_read);
    }
    
    // Convertir interleaved vers non-interleaved
    float max_output = 0.0f;
    for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
        for (int ch = 0; ch < channels_; ch++) {
            float* channel_data = static_cast<float*>(ioData->mBuffers[ch].mData);
            float sample = interleaved_data[frame * channels_ + ch];
            channel_data[frame] = sample;
            float abs_val = fabs(sample);
            if (abs_val > max_output) {
                max_output = abs_val;
            }
        }
    }
    
    if (render_count < 20) {
        int new_filled = rb_filled(&audio_ringbuffer_);
        std::cerr << "BlackHole::render: Copied " << inNumberFrames << " frames, max_output=" 
                  << max_output << ", remaining=" << new_filled << " bytes" << std::endl;
    }
    
    return noErr;
}

bool BlackHoleOutput::send(const float* audio_data, int num_frames) {
    if (!initialized_ || !output_unit_) {
        static int error_count = 0;
        if (error_count++ < 5) {
            std::cerr << "BlackHole::send: Not initialized or output_unit_ is null!" << std::endl;
        }
        return false;
    }
    
    // Vérifier que les données ne sont pas toutes à zéro (silence)
    bool has_audio = false;
    float max_amplitude = 0.0f;
    for (int i = 0; i < num_frames * channels_; i++) {
        float abs_val = fabs(audio_data[i]);
        if (abs_val > max_amplitude) {
            max_amplitude = abs_val;
        }
        if (abs_val > 0.0001f) {
            has_audio = true;
        }
    }
    
    size_t data_size = num_frames * channels_ * sizeof(float);
    
    static int send_count = 0;
    if (send_count++ < 20) {
        int filled = rb_filled(&audio_ringbuffer_);
        int space = rb_space(&audio_ringbuffer_);
        std::cerr << "BlackHole::send: num_frames=" << num_frames 
                  << ", has_audio=" << has_audio 
                  << ", max_amplitude=" << max_amplitude
                  << ", ringbuffer_filled=" << filled 
                  << ", ringbuffer_space=" << space << std::endl;
    }
    
    std::lock_guard<std::mutex> lock(ringbuffer_mutex_);
    
    // Vérifier s'il y a assez d'espace dans le ring buffer
    int space = rb_space(&audio_ringbuffer_);
    if (space < static_cast<int>(data_size)) {
        // Pas assez d'espace, supprimer les données les plus anciennes
        int to_remove = static_cast<int>(data_size) - space;
        if (send_count < 20) {
            std::cerr << "BlackHole::send: Ring buffer full! Removing " << to_remove 
                      << " bytes to make space" << std::endl;
        }
        // Lire et jeter les données les plus anciennes
        std::vector<char> temp(to_remove);
        rb_read_len(&audio_ringbuffer_, temp.data(), to_remove);
    }
    
    // Écrire les données dans le ring buffer
    // Note: rb_write attend char* (non-const), mais on a const float*
    // Le cast est sûr car on ne modifie pas les données source
    int written = rb_write(&audio_ringbuffer_, 
                          const_cast<char*>(reinterpret_cast<const char*>(audio_data)), 
                          static_cast<unsigned int>(data_size));
    
    if (written < static_cast<int>(data_size)) {
        if (send_count < 20) {
            std::cerr << "BlackHole::send: Warning! Only wrote " << written 
                      << " bytes out of " << data_size << std::endl;
        }
    }
    
    if (send_count < 20) {
        int new_filled = rb_filled(&audio_ringbuffer_);
        std::cerr << "BlackHole::send: Wrote " << written << " bytes, new filled=" 
                  << new_filled << std::endl;
    }
    
    return true;
}

bool BlackHoleOutput::sendInterleaved(const float* audio_data, int num_frames) {
    return send(audio_data, num_frames);
}

void BlackHoleOutput::close() {
    if (output_unit_) {
        AudioOutputUnitStop(output_unit_);
        AudioUnitUninitialize(output_unit_);
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
    }
    
    // Vider le ring buffer
    {
        std::lock_guard<std::mutex> lock(ringbuffer_mutex_);
        rb_clear(&audio_ringbuffer_);
        rb_free(&audio_ringbuffer_);
        memset(&audio_ringbuffer_, 0, sizeof(audio_ringbuffer_));
    }
    
    initialized_ = false;
}

