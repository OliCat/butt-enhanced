#include "blackhole_output.h"
#include <iostream>
#include <cstring>

BlackHoleOutput::BlackHoleOutput()
    : output_unit_(nullptr)
    , initialized_(false)
    , sample_rate_(48000)
    , channels_(2)
{
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
    
    // Configurer le format audio
    AudioStreamBasicDescription format = {
        .mSampleRate = static_cast<Float64>(sample_rate_),
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
        .mBytesPerPacket = sizeof(float),
        .mFramesPerPacket = 1,
        .mBytesPerFrame = sizeof(float),
        .mChannelsPerFrame = static_cast<UInt32>(channels_),
        .mBitsPerChannel = 32
    };
    
    status = AudioUnitSetProperty(
        output_unit_,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &format,
        sizeof(format)
    );
    
    if (status != noErr) {
        std::cerr << "❌ Erreur configuration format: " << status << std::endl;
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
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
    
    // Démarrer l'AudioUnit
    status = AudioOutputUnitStart(output_unit_);
    if (status != noErr) {
        std::cerr << "❌ Erreur démarrage AudioUnit: " << status << std::endl;
        AudioUnitUninitialize(output_unit_);
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    initialized_ = true;
    std::cout << "✅ BlackHole initialisé pour Whisper Streaming (sample_rate: " << sample_rate_ 
              << ", channels: " << channels_ << ")" << std::endl;
    
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
    std::lock_guard<std::mutex> lock(queue_mutex_);
    
    // Si pas de données disponibles, envoyer du silence
    if (audio_queue_.empty()) {
        for (UInt32 ch = 0; ch < ioData->mNumberBuffers; ch++) {
            memset(ioData->mBuffers[ch].mData, 0, ioData->mBuffers[ch].mDataByteSize);
        }
        return noErr;
    }
    
    // Récupérer les données du buffer
    std::vector<float>& data = audio_queue_.front();
    
    // Vérifier que nous avons assez de données
    if (data.size() < inNumberFrames * channels_) {
        // Pas assez de données, envoyer du silence
        for (UInt32 ch = 0; ch < ioData->mNumberBuffers; ch++) {
            memset(ioData->mBuffers[ch].mData, 0, ioData->mBuffers[ch].mDataByteSize);
        }
        audio_queue_.pop();
        return noErr;
    }
    
    // Convertir interleaved vers non-interleaved
    for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
        for (int ch = 0; ch < channels_; ch++) {
            float* channel_data = static_cast<float*>(ioData->mBuffers[ch].mData);
            channel_data[frame] = data[frame * channels_ + ch];
        }
    }
    
    audio_queue_.pop();
    return noErr;
}

bool BlackHoleOutput::send(const float* audio_data, int num_frames) {
    if (!initialized_ || !output_unit_) {
        return false;
    }
    
    std::lock_guard<std::mutex> lock(queue_mutex_);
    
    // Limiter la taille de la queue pour éviter l'accumulation
    if (audio_queue_.size() > 10) {
        audio_queue_.pop(); // Supprimer l'ancien buffer
    }
    
    // Copier les données dans la queue
    std::vector<float> buffer(audio_data, audio_data + (num_frames * channels_));
    audio_queue_.push(std::move(buffer));
    
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
    
    // Vider la queue
    {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        while (!audio_queue_.empty()) {
            audio_queue_.pop();
        }
    }
    
    initialized_ = false;
}

