#ifndef BLACKHOLE_OUTPUT_H
#define BLACKHOLE_OUTPUT_H

#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioUnit/AudioUnit.h>
#include <vector>
#include <queue>
#include <mutex>

class BlackHoleOutput {
public:
    BlackHoleOutput();
    ~BlackHoleOutput();
    
    // Initialiser la sortie BlackHole
    bool initialize(int sample_rate = 48000, int channels = 2);
    
    // Envoyer des données audio vers BlackHole
    bool send(const float* audio_data, int num_frames);
    
    // Envoyer des données audio depuis un buffer interleaved
    bool sendInterleaved(const float* audio_data, int num_frames);
    
    // Vérifier si BlackHole est initialisé
    bool isInitialized() const { return initialized_; }
    
    // Fermer la sortie BlackHole
    void close();

private:
    AudioUnit output_unit_;
    bool initialized_;
    int sample_rate_;
    int channels_;
    
    // Queue pour stocker les données audio
    std::queue<std::vector<float>> audio_queue_;
    std::mutex queue_mutex_;
    
    // Trouver l'ID du périphérique BlackHole
    AudioDeviceID findBlackHoleDevice();
    
    // Callback pour le rendu audio
    static OSStatus renderCallback(
        void* inRefCon,
        AudioUnitRenderActionFlags* ioActionFlags,
        const AudioTimeStamp* inTimeStamp,
        UInt32 inBusNumber,
        UInt32 inNumberFrames,
        AudioBufferList* ioData
    );
    
    // Méthode instance pour le callback
    OSStatus render(
        AudioUnitRenderActionFlags* ioActionFlags,
        const AudioTimeStamp* inTimeStamp,
        UInt32 inBusNumber,
        UInt32 inNumberFrames,
        AudioBufferList* ioData
    );
};

#endif // BLACKHOLE_OUTPUT_H

