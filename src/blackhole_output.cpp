#include "blackhole_output.h"
#include <iostream>
#include <cstring>
#include <cmath>

BlackHoleOutput::BlackHoleOutput()
    : output_unit_(nullptr)
    , initialized_(false)
    , audio_started_(false)
    , sample_rate_(48000)
    , channels_(2)
    , max_frames_per_callback_(0)
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
    
    // 🔧 OPTIMISATION: Buffer de 1.5 secondes pour latence faible (Whisper Streaming)
    // Un buffer de 1.5s offre un bon compromis entre stabilité et latence faible pour le streaming
    // en temps réel. Suffisant pour absorber les variations de timing sans latence excessive.
    unsigned int buffer_size = sample_rate_ * channels_ * sizeof(float) * 1.5; // 1.5 secondes
    if (rb_init(&audio_ringbuffer_, buffer_size) != 0) {
        std::cerr << "❌ Erreur initialisation ring buffer" << std::endl;
        AudioUnitUninitialize(output_unit_);
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
        return false;
    }
    
    // 🔧 CORRECTION CRITIQUE: Initialiser le buffer avec des zéros propres
    // Le buffer malloc() peut contenir des données résiduelles. On doit le nettoyer
    // pour éviter de lire des "garbage" au premier callback.
    memset(audio_ringbuffer_.buf, 0, buffer_size);
    std::cerr << "✅ BlackHole: Ring buffer initialisé et nettoyé (" << buffer_size << " bytes)" << std::endl;
    
    // 🔧 OPTIMISATION: Pré-allouer les buffers de conversion pour le callback temps-réel
    // Allocation typique maximale: 4096 frames (valeur courante dans les logs)
    max_frames_per_callback_ = 8192; // Prendre une marge de sécurité
    render_buffer_.resize(max_frames_per_callback_ * channels_);
    temp_read_buffer_.resize(max_frames_per_callback_ * channels_ * sizeof(float));
    std::cerr << "✅ BlackHole: Buffers pré-alloués pour " << max_frames_per_callback_ 
              << " frames (" << (temp_read_buffer_.size() / 1024) << " KB)" << std::endl;
    
    // 🔧 CORRECTION CRITIQUE: NE PAS démarrer l'AudioUnit maintenant !
    // On va le démarrer dans send() quand on aura des vraies données audio.
    // Cela évite de lire du silence au démarrage.
    audio_started_ = false;
    std::cerr << "✅ BlackHole: AudioUnit prêt (sera démarré au premier envoi de données)" << std::endl;
    
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
    // 🔧 CORRECTION: Le ring buffer a son propre mutex interne, donc nous n'avons pas besoin
    // de notre propre mutex. Cela évite les deadlocks et améliore les performances.
    // Le thread audio a la priorité et le mutex interne du ring buffer est optimisé.
    
    static int render_count = 0;
    static float last_samples[2] = {0.0f, 0.0f}; // Derniers échantillons pour fade-out
    static bool was_underrun = false;
    
    // 🔧 Logs minimaux en production (3 premiers callbacks seulement)
    if (render_count++ < 3) {
        int filled = rb_filled(&audio_ringbuffer_);
        std::cerr << "BlackHole::render: inNumberFrames=" << inNumberFrames 
                  << ", ringbuffer_filled=" << filled << " bytes" << std::endl;
    }
    
    // Vérifier que le nombre de buffers correspond au nombre de canaux
    if (ioData->mNumberBuffers != static_cast<UInt32>(channels_)) {
        if (render_count < 5) {
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
    
    // 🔧 OPTIMISATION PROFESSIONNELLE: Maintenir un niveau de buffer minimum pour éviter les artefacts
    // Pour une qualité professionnelle (Audition), on veut toujours avoir au moins 2x les données nécessaires
    // Cela garantit une lecture fluide sans interruptions
    size_t min_buffer_level = required_bytes * 2; // Au moins 2x les données nécessaires
    bool is_underrun = (filled < static_cast<int>(required_bytes));
    bool is_low_buffer = (filled < static_cast<int>(min_buffer_level));
    
    if (is_underrun) {
        if (render_count < 5) {
            std::cerr << "BlackHole::render: Not enough data! Have " << filled 
                      << " bytes, need " << required_bytes << std::endl;
        }
        
        // 🔧 OPTIMISATION: Utiliser le buffer pré-alloué pour l'underrun aussi
        // Initialiser le buffer avec des zéros
        std::fill(render_buffer_.begin(), render_buffer_.begin() + (inNumberFrames * channels_), 0.0f);
        
        // Lire ce qui est disponible (même si incomplet)
        if (filled > 0) {
            unsigned int bytes_to_read = (filled < static_cast<int>(required_bytes)) ? filled : required_bytes;
            rb_read_len(&audio_ringbuffer_, 
                       reinterpret_cast<char*>(render_buffer_.data()), 
                       bytes_to_read);
        }
        
        // 🔧 CORRECTION: Fade-out progressif pour éviter les clics
        // Appliquer un fade-out sur les dernières frames si on passe d'un état plein à un underrun
        if (!was_underrun && filled > 0) {
            // Fade-out sur les 10 dernières frames disponibles
            int available_frames = filled / (channels_ * sizeof(float));
            int fade_frames = (available_frames < 10) ? available_frames : 10;
            for (int i = 0; i < fade_frames; i++) {
                float fade_factor = 1.0f - (float)i / (float)fade_frames;
                for (int ch = 0; ch < channels_; ch++) {
                    int idx = (available_frames - fade_frames + i) * channels_ + ch;
                    if (idx < static_cast<int>(inNumberFrames * channels_)) {
                        render_buffer_[idx] *= fade_factor;
                    }
                }
            }
        }
        
        // Convertir interleaved vers non-interleaved avec fade-out (optimisé par canal)
        for (int ch = 0; ch < channels_; ch++) {
            float* channel_data = static_cast<float*>(ioData->mBuffers[ch].mData);
            
            for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
                float sample = render_buffer_[frame * channels_ + ch];
                
                // Fade-out progressif si on est en underrun
                if (is_underrun && frame >= (inNumberFrames - 10)) {
                    float fade_factor = 1.0f - (float)(frame - (inNumberFrames - 10)) / 10.0f;
                    sample *= fade_factor;
                }
                
                channel_data[frame] = sample;
                
                if (frame >= inNumberFrames - 1) {
                    last_samples[ch] = sample;
                }
            }
        }
        
        was_underrun = true;
        return noErr;
    }
    
    // Buffer suffisant - lecture normale
    was_underrun = false;
    
    // 🔧 OPTIMISATION PROFESSIONNELLE: Si le buffer est vraiment trop bas, ne pas répéter les échantillons
    // car cela cause des cliquetis. Mieux vaut lire ce qui est disponible et compléter avec fade.
    // On ne bloque que si on n'a vraiment rien à lire.
    if (is_low_buffer && filled < static_cast<int>(required_bytes)) {
        // Buffer trop bas mais on a quand même des données - on les lira avec fade
        // Ne pas retourner ici, continuer pour lire ce qui est disponible
    }
    
    // 🔧 OPTIMISATION: Utiliser les buffers pré-alloués au lieu d'allocations répétées
    // Cela élimine les allocations mémoire dans le callback temps-réel (meilleure performance)
    
    // Vérifier que les buffers sont assez grands (normalement toujours vrai grâce à la marge de sécurité)
    if (inNumberFrames > max_frames_per_callback_) {
        std::cerr << "⚠️  BlackHole::render: inNumberFrames (" << inNumberFrames 
                  << ") > max_frames_per_callback_ (" << max_frames_per_callback_ << ")" << std::endl;
        // Envoyer du silence en cas de dépassement
        for (UInt32 ch = 0; ch < ioData->mNumberBuffers; ch++) {
            memset(ioData->mBuffers[ch].mData, 0, ioData->mBuffers[ch].mDataByteSize);
        }
        return noErr;
    }
    
    // Utiliser les buffers pré-alloués (pas d'allocation !)
    unsigned int bytes_read = 0;
    unsigned int bytes_read_result = rb_read_len(&audio_ringbuffer_, temp_read_buffer_.data(), required_bytes);
    
    if (bytes_read_result > 0) {
        bytes_read = bytes_read_result;
        
        // Copier les données lues dans le buffer interleaved pré-alloué
        memcpy(render_buffer_.data(), temp_read_buffer_.data(), bytes_read);
        
        // 🔧 Logs minimaux en production
        if (render_count < 3) {
            float max_read = 0.0f;
            int non_zero_count = 0;
            size_t samples_to_check = bytes_read / sizeof(float);
            if (samples_to_check > 100) samples_to_check = 100;
            
            for (size_t i = 0; i < samples_to_check; i++) {
                float abs_val = fabs(render_buffer_[i]);
                if (abs_val > max_read) max_read = abs_val;
                if (abs_val > 0.0001f) non_zero_count++;
            }
            
            int available = rb_filled(&audio_ringbuffer_);
            std::cerr << "🔍 BlackHole::render: Read " << bytes_read << " bytes, "
                      << "max_sample=" << max_read 
                      << ", non_zero_samples=" << non_zero_count << "/" << samples_to_check
                      << ", available=" << available << std::endl;
            
            if (max_read < 0.0001f && bytes_read > 0) {
                std::cerr << "⚠️  BlackHole::render: CRITICAL! Read " << bytes_read 
                          << " bytes but all data is zero! available=" << available 
                          << ", required=" << required_bytes << std::endl;
                
                // Diagnostic hex désactivé en production (déjà validé)
            }
        }
    } else {
        if (render_count < 5) {
            int available = rb_filled(&audio_ringbuffer_);
            std::cerr << "⚠️  BlackHole::render: rb_read_len returned 0! available=" << available 
                      << ", required=" << required_bytes << std::endl;
        }
    }
    
    // Si on n'a pas lu assez de données, remplir avec fade depuis les derniers échantillons
    if (bytes_read < required_bytes) {
        if (render_count < 5) {
            std::cerr << "BlackHole::render: Not enough data! Read " << bytes_read 
                      << " bytes, need " << required_bytes << std::endl;
        }
        // Remplir le reste avec fade depuis les derniers échantillons pour éviter les clics
        int missing_bytes = required_bytes - bytes_read;
        int missing_frames = missing_bytes / (channels_ * sizeof(float));
        int start_frame = bytes_read / (channels_ * sizeof(float));
        
        for (int i = 0; i < missing_frames; i++) {
            float fade_factor = 1.0f - (float)i / (float)missing_frames;
            for (int ch = 0; ch < channels_; ch++) {
                int idx = (start_frame + i) * channels_ + ch;
                if (idx < static_cast<int>(render_buffer_.size())) {
                    render_buffer_[idx] = last_samples[ch] * fade_factor;
                }
            }
        }
    }
    
    // 🔧 OPTIMISATION: Conversion interleaved→non-interleaved optimisée par canal
    // Traiter par canal améliore la localité du cache CPU (meilleure performance)
    float max_output = 0.0f;
    
    for (int ch = 0; ch < channels_; ch++) {
        float* channel_data = static_cast<float*>(ioData->mBuffers[ch].mData);
        
        // Traiter toutes les frames pour ce canal d'un coup (meilleure localité cache)
        for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
            float sample = render_buffer_[frame * channels_ + ch];
            
            // 🔧 Vérification de validité pour éviter les valeurs NaN ou infinies
            if (!std::isfinite(sample)) {
                sample = 0.0f;
            }
            
            // 🔧 Limitation douce pour éviter la distorsion
            if (sample > 1.0f) sample = 1.0f;
            if (sample < -1.0f) sample = -1.0f;
            
            channel_data[frame] = sample;
            
            // Sauvegarder le dernier échantillon de chaque canal
            if (frame >= inNumberFrames - 1) {
                last_samples[ch] = sample;
            }
            
            // Calculer l'amplitude maximale
            float abs_val = fabs(sample);
            if (abs_val > max_output) {
                max_output = abs_val;
            }
        }
    }
    
    if (render_count < 3) {
        int new_filled = rb_filled(&audio_ringbuffer_);
        std::cerr << "✅ BlackHole::render: Copied " << inNumberFrames << " frames, max=" 
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
    
    // 🔧 CORRECTION: Le ring buffer a son propre mutex interne, donc nous n'avons pas besoin
    // de notre propre mutex. Cela évite les deadlocks et améliore les performances.
    // Vérifier s'il y a assez d'espace dans le ring buffer
    int space = rb_space(&audio_ringbuffer_);
    int filled = rb_filled(&audio_ringbuffer_);
    
    // 🔧 Logs minimaux en production (3 premiers envois)
    static int send_count = 0;
    if (send_count++ < 3) {
        std::cerr << "BlackHole::send: num_frames=" << num_frames 
                  << ", has_audio=" << has_audio 
                  << ", max_amplitude=" << max_amplitude
                  << ", ringbuffer_filled=" << filled 
                  << ", ringbuffer_space=" << space << std::endl;
        
        // Diagnostic hex désactivé en production (déjà validé)
    }
    
    // 🔧 CORRECTION: rb_write ne vérifie pas l'espace disponible - il écrase les données
    // si nécessaire. Nous devons donc vérifier l'espace et supprimer les anciennes données
    // si nécessaire pour éviter d'écraser des données non lues.
    if (space < static_cast<int>(data_size)) {
        // Pas assez d'espace, supprimer les données les plus anciennes
        int to_remove = static_cast<int>(data_size) - space;
        if (send_count < 3) {
            std::cerr << "⚠️  BlackHole::send: Ring buffer full! Removing " << to_remove 
                      << " bytes to make space" << std::endl;
        }
        // Lire et jeter les données les plus anciennes
        std::vector<char> temp(to_remove);
        rb_read_len(&audio_ringbuffer_, temp.data(), to_remove);
    }
    
    // 🔧 CORRECTION CRITIQUE: Écrire directement sans copie supplémentaire
    // rb_write() ne modifie pas les données source (malgré la signature non-const)
    // Écrire directement dans le ring buffer
    // Note: rb_write retourne 0 en cas de succès, -1 en cas d'erreur (pas le nombre d'octets)
    int result = rb_write(&audio_ringbuffer_, 
                         const_cast<char*>(reinterpret_cast<const char*>(audio_data)), 
                         static_cast<unsigned int>(data_size));
    
    if (result != 0) {
        if (send_count < 3) {
            std::cerr << "❌ BlackHole::send: Error writing to ring buffer! result=" << result << std::endl;
        }
        return false;
    }
    
    if (send_count < 3) {
        int new_filled = rb_filled(&audio_ringbuffer_);
        std::cerr << "✅ BlackHole::send: Wrote " << data_size << " bytes, filled=" 
                  << new_filled << std::endl;
    }
    
    // 🔧 CORRECTION CRITIQUE: Démarrer l'AudioUnit seulement quand on a assez de données
    // Attendre d'avoir au moins 500ms de données audio réelles avant de démarrer
    // Cela garantit un buffer suffisant pour éviter de lire des données garbage au premier callback
    if (!audio_started_ && has_audio) {
        int filled_now = rb_filled(&audio_ringbuffer_);
        int min_data_before_start = sample_rate_ * channels_ * sizeof(float) * 0.5; // 500ms
        
        if (filled_now >= min_data_before_start) {
            // 🔧 CORRECTION: Calcul en float pour afficher correctement les secondes
            float seconds = (float)filled_now / (float)(sample_rate_ * channels_ * sizeof(float));
            
            OSStatus status = AudioOutputUnitStart(output_unit_);
            if (status == noErr) {
                audio_started_ = true;
                std::cerr << "🎵 BlackHole: AudioUnit démarré avec " << filled_now 
                          << " bytes de données (" << seconds << " secondes)" << std::endl;
            } else {
                std::cerr << "❌ BlackHole: Erreur démarrage AudioUnit: " << status << std::endl;
            }
        } else {
            // Diagnostic: afficher la progression
            static int wait_count = 0;
            if (wait_count++ % 10 == 0) {
                float progress = (float)filled_now / (float)min_data_before_start * 100.0f;
                std::cerr << "⏳ BlackHole: Accumulation... " << filled_now 
                          << "/" << min_data_before_start << " bytes (" 
                          << (int)progress << "%)" << std::endl;
            }
        }
    }
    
    return true;
}

bool BlackHoleOutput::sendInterleaved(const float* audio_data, int num_frames) {
    return send(audio_data, num_frames);
}

void BlackHoleOutput::close() {
    if (output_unit_) {
        if (audio_started_) {
            AudioOutputUnitStop(output_unit_);
            audio_started_ = false;
        }
        AudioUnitUninitialize(output_unit_);
        AudioComponentInstanceDispose(output_unit_);
        output_unit_ = nullptr;
    }
    
    // Vider le ring buffer
    {
        // Le ring buffer a son propre mutex interne, pas besoin de notre mutex externe
        rb_clear(&audio_ringbuffer_);
        rb_free(&audio_ringbuffer_);
        memset(&audio_ringbuffer_, 0, sizeof(audio_ringbuffer_));
    }
    
    initialized_ = false;
}

