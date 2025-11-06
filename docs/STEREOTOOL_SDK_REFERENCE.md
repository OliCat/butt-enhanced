# 📚 Référence SDK StereoTool
## Guide Rapide des Fonctions Disponibles

---

**Date :** 9 octobre 2025  
**SDK Version :** Compatible API v9.92+  
**Licence :** StereoTool PRO (licence requise pour utilisation commerciale)

---

## 📖 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Fonctions Actuellement Utilisées](#fonctions-actuellement-utilisées)
3. [Fonctions Disponibles Non Utilisées](#fonctions-disponibles-non-utilisées)
4. [Exemples d'Utilisation](#exemples-dutilisation)
5. [Ressources](#ressources)

---

## 📊 Vue d'Ensemble

### Fichiers SDK
```
src/stereo_tool_sdk/
├── Generic_StereoTool.h    ← Déclarations principales
├── ParameterEnum.h         ← Énumérations ID paramètres
└── libStereoTool64.dylib   ← Bibliothèque dynamique
```

### Architecture Actuelle
```cpp
// Chargement dynamique dans stereo_tool.cpp
static void *st_library = NULL;  // Handle bibliothèque
gStereoTool* st_instance;        // Instance StereoTool

// Chargement des symboles
dlopen("libStereoTool64.dylib", RTLD_LAZY);
dlsym(st_library, "stereoTool_Create");
```

---

## ✅ Fonctions Actuellement Utilisées

### Construction et Destruction
```cpp
gStereoTool* stereoTool_Create(const char* key = NULL)
void stereoTool_Delete(gStereoTool* st_instance)
```
**Usage actuel :**
- Création dans `stereo_tool_init()`
- Destruction dans `stereo_tool_cleanup()`

---

### Traitement Audio
```cpp
void stereoTool_Process(gStereoTool* st_instance, 
                       float* samples, 
                       int32_t numsamples, 
                       int32_t channels, 
                       int32_t samplerate)
```
**Usage actuel :**
- Appelé dans `port_audio.cpp` callback audio
- Traite les buffers avant streaming/enregistrement

---

### Gestion Presets
```cpp
bool stereoTool_LoadPreset(gStereoTool* st_instance, 
                          const char* filename, 
                          int loadsave_type)
```
**Usage actuel :**
- Chargement fichiers .sts depuis disque
- loadsave_type = ID_SAVE_ALLSETTINGS

---

### Licence et Version
```cpp
bool stereoTool_CheckLicenseValid(gStereoTool* st_instance)
int stereoTool_GetSoftwareVersion(void)
int stereoTool_GetApiVersion(void)
bool stereoTool_GetUnlicensedUsedFeatures(gStereoTool* st_instance, 
                                         char* text, int text_maxlen)
int stereoTool_GetLatency2(gStereoTool* st_instance, 
                          int32_t samplerate, bool feed_silence)
```
**Usage actuel :**
- Vérification licence au démarrage
- Affichage version dans logs
- Calcul latence pour synchronisation

---

## ❌ Fonctions Disponibles NON Utilisées

### 📊 Monitoring Audio (HAUTE PRIORITÉ)

#### Lecture Niveaux Mono
```cpp
bool stereoTool_ReadMonoLevel(gStereoTool* st_instance, 
                             int id,              // ID du compteur
                             float latency,       // Latence à compenser
                             bool& modified,      // Changement depuis dernier appel
                             float& actual,       // Niveau actuel
                             float& gray,         // Seuil gris
                             float& black,        // Seuil noir
                             float& median,       // Valeur médiane
                             int& color)          // Couleur (0=vert, 1=jaune, 2=rouge)
```

**IDs Disponibles :**
- 0 : Input Level
- 1 : Output Level
- 2 : Compressor Gain Reduction
- 3+ : Autres (voir doc SDK complète)

**Exemple :**
```cpp
float actual, gray, black, median;
int color;
bool modified;

if (stereoTool_ReadMonoLevel(st_instance, 2, 0.0f, modified, 
                             actual, gray, black, median, color)) {
    printf("Compressor GR: %.1f dB (color: %d)\n", actual, color);
}
```

---

#### Lecture Niveaux Stéréo
```cpp
bool stereoTool_ReadStereoLevel(gStereoTool* st_instance, 
                               int id, 
                               float latency, 
                               bool& modified, 
                               float actual[2],    // [left, right]
                               float gray[2], 
                               float black[2], 
                               float median[2], 
                               int color[2])
```

**Exemple :**
```cpp
float actual[2], gray[2], black[2], median[2];
int color[2];
bool modified;

if (stereoTool_ReadStereoLevel(st_instance, 1, 0.0f, modified,
                               actual, gray, black, median, color)) {
    printf("Output L: %.1f dB, R: %.1f dB\n", actual[0], actual[1]);
}
```

---

#### Analyseur de Spectre
```cpp
void stereoTool_UpdateSpectrum(gStereoTool* st_instance)

int stereoTool_GetSpectrum(gStereoTool* st_instance,
                          int where,              // 0=input, 1=output
                          int channel,            // 0=left, 1=right, 2=mono mix
                          float latency,
                          int bands_per_octave,   // Résolution (1-12)
                          float first_band_freq,  // Freq de départ (Hz)
                          int number_of_elements, // Taille arrays
                          float* output_frequencies,
                          float* output_values)   // Valeurs en dB
```

**Exemple :**
```cpp
float frequencies[128];
float values[128];

stereoTool_UpdateSpectrum(st_instance);

int num_bands = stereoTool_GetSpectrum(st_instance,
                                       1,        // Output
                                       2,        // Mono mix
                                       0.0f,
                                       3,        // 3 bands/octave
                                       20.0f,    // Start at 20Hz
                                       128,
                                       frequencies,
                                       values);

for (int i = 0; i < num_bands; i++) {
    printf("%.0f Hz: %.1f dB\n", frequencies[i], values[i]);
}
```

---

### 🎚️ Presets Intégrés (HAUTE PRIORITÉ)

#### Énumération Presets Built-in
```cpp
bool stereoTool_GetBuiltInPresetName(gStereoTool* st_instance,
                                    int pos,        // Position dans la liste
                                    int* level,     // Niveau d'indentation
                                    bool* is_preset,// true=preset, false=catégorie
                                    char* name)     // Nom (buffer fourni)
```

**Exemple :**
```cpp
int pos = 0;
int level;
bool is_preset;
char name[256];

while (stereoTool_GetBuiltInPresetName(st_instance, pos, 
                                       &level, &is_preset, name)) {
    if (is_preset) {
        printf("%*sPreset: %s\n", level * 2, "", name);
    } else {
        printf("%*s--- %s ---\n", level * 2, "", name);
    }
    pos++;
}
```

---

#### Application Preset Built-in
```cpp
bool stereoTool_SetBuiltInPreset(gStereoTool* st_instance, int pos)
```

**Exemple :**
```cpp
// pos = numéro récupéré via GetBuiltInPresetName
if (stereoTool_SetBuiltInPreset(st_instance, 42)) {
    printf("Preset appliqué avec succès\n");
}
```

---

#### Sauvegarde Preset
```cpp
bool stereoTool_SavePreset(gStereoTool* st_instance,
                          const char* filename,
                          int loadsave_type)
```

**loadsave_type :**
- `ID_SAVE_TOTALINI` : Tous les paramètres
- `ID_SAVE_ALLSETTINGS` : Tous sauf config
- `ID_SAVE_AUDIO` : Audio uniquement
- `ID_SAVE_PROCESSING` : Processing uniquement

---

### 📏 Normalisation R128 (HAUTE PRIORITÉ)

#### Configuration R128
```cpp
void stereoTool_SetR128Mode(gStereoTool* st_instance,
                           int mode,           // 0=off, 1=normalize, 2=clip only
                           float r128_truepeak,// True peak limit (dB)
                           float gain)         // Gain initial
```

**Exemple :**
```cpp
// Activer R128 avec target -23 LUFS
stereoTool_SetR128Mode(st_instance, 1, -23.0f, 1.0f);
```

---

#### Lecture Gain R128
```cpp
float stereoTool_GetR128Gain(gStereoTool* st_instance, 
                            float r128_target)  // Target LUFS
```

**Exemple :**
```cpp
float gain = stereoTool_GetR128Gain(st_instance, -23.0f);

if (gain > 0.99f && gain < 1.01f) {
    // Niveau optimal atteint (±0.1dB)
    printf("R128: Target atteint\n");
} else {
    printf("R128: Gain correction = %.2f\n", gain);
}
```

---

### 📻 RDS (Radio Data System)

#### RDS PS (Program Service)
```cpp
void stereoTool_SetRdsPs(gStereoTool* st_instance,
                        const char* texts,  // Max 8 caractères
                        bool now)           // Appliquer immédiatement
```

**Exemple :**
```cpp
stereoTool_SetRdsPs(st_instance, "MYRADIO ", true);
```

---

#### RDS RT (RadioText)
```cpp
void stereoTool_SetRdsRt(gStereoTool* st_instance,
                        bool on,            // Enable/disable
                        const char* texts,  // Max 64 caractères
                        bool now)
```

**Exemple :**
```cpp
stereoTool_SetRdsRt(st_instance, true, 
                   "Artist Name - Song Title", true);
```

---

#### RDS TA (Traffic Announcement)
```cpp
void stereoTool_SetRdsTa(gStereoTool* st_instance,
                        bool tp,    // Traffic Program
                        bool ta)    // Traffic Announcement
```

**Exemple :**
```cpp
stereoTool_SetRdsTa(st_instance, true, false);
```

---

### 🔧 Paramètres Individuels

#### Lecture Paramètre
```cpp
bool stereoTool_GetStsValue(gStereoTool* st_instance,
                           int index,
                           int subindex,
                           const char** value)  // Pointeur vers string (interne)
```

**Exemple :**
```cpp
const char* value;
if (stereoTool_GetStsValue(st_instance, 100, 0, &value)) {
    printf("Valeur: %s\n", value);
}
```

---

#### Modification Paramètre
```cpp
bool stereoTool_SetStsValue(gStereoTool* st_instance,
                           int index,
                           int subindex,
                           const char* value)
```

**Exemple :**
```cpp
if (stereoTool_SetStsValue(st_instance, 100, 0, "1.5")) {
    printf("Paramètre modifié\n");
}
```

---

### 📡 Sortie FM/MPX

```cpp
void stereoTool_ProcessFM(gStereoTool* st_instance,
                         float* samples,          // Audio input
                         float* fm_samples,       // MPX output
                         int32_t numsamples,
                         int32_t channels,
                         int32_t samplerate,
                         int32_t* fm_oversampling,// Facteur oversampling
                         int32_t* samples_fm_size)// Taille output MPX
```

**Exemple :**
```cpp
float audio_buffer[2048];
float mpx_buffer[8192];  // Buffer plus grand pour oversampling
int32_t oversampling;
int32_t mpx_size;

stereoTool_ProcessFM(st_instance,
                     audio_buffer,
                     mpx_buffer,
                     1024,      // 1024 samples audio
                     2,         // Stereo
                     48000,
                     &oversampling,
                     &mpx_size);

printf("MPX: %d samples à %d Hz\n", mpx_size, 48000 * oversampling);
```

---

### 🖥️ GUI Native (macOS)

```cpp
gStereoToolGUI* stereoTool_GUI_Create(gStereoTool* st_instance)
void stereoTool_GUI_Show(gStereoToolGUI* gui, void* hwnd)
void stereoTool_GUI_Hide(gStereoToolGUI* gui)
void stereoTool_GUI_SetSize(gStereoToolGUI* gui, int width, int height)
void stereoTool_GUI_Delete(gStereoToolGUI* gui)
```

**Exemple :**
```cpp
// Créer GUI
gStereoToolGUI* gui = stereoTool_GUI_Create(st_instance);

// Afficher (hwnd = NULL pour fenêtre standalone)
stereoTool_GUI_Show(gui, NULL);

// Redimensionner
stereoTool_GUI_SetSize(gui, 800, 600);

// Masquer
stereoTool_GUI_Hide(gui);

// Nettoyer
stereoTool_GUI_Delete(gui);
```

---

### 🔄 Réinitialisation

```cpp
void stereoTool_Reset(gStereoTool* st_instance, int loadsave_type)
```

**Exemple :**
```cpp
// Reset complet
stereoTool_Reset(st_instance, ID_SAVE_TOTALINI);

// Reset audio processing uniquement
stereoTool_Reset(st_instance, ID_SAVE_PROCESSING);
```

---

## 💡 Exemples d'Utilisation

### Exemple 1 : VU-Mètre Temps Réel
```cpp
void update_vu_meters_callback(void* userdata) {
    gStereoTool* st = (gStereoTool*)userdata;
    
    float actual[2], median[2], gray[2], black[2];
    int color[2];
    bool modified;
    
    // Lire output level
    if (stereoTool_ReadStereoLevel(st, 1, 0.0f, modified,
                                   actual, gray, black, median, color)) {
        // Mettre à jour widgets
        update_vu_widget(0, actual[0], color[0]);  // Left
        update_vu_widget(1, actual[1], color[1]);  // Right
    }
    
    // Rappeler dans 50ms
    Fl::repeat_timeout(0.05, update_vu_meters_callback, userdata);
}
```

---

### Exemple 2 : Menu Déroulant Presets
```cpp
void populate_preset_menu(Fl_Choice* choice, gStereoTool* st) {
    int pos = 0;
    int level;
    bool is_preset;
    char name[256];
    
    while (stereoTool_GetBuiltInPresetName(st, pos, &level, &is_preset, name)) {
        if (is_preset) {
            // Ajouter preset avec pos comme user_data
            choice->add(name, 0, preset_callback, (void*)(intptr_t)pos);
        } else {
            // Ajouter catégorie (disabled)
            char category[256];
            snprintf(category, sizeof(category), "--- %s ---", name);
            choice->add(category, 0, NULL, NULL, FL_MENU_INACTIVE);
        }
        pos++;
    }
}

void preset_callback(Fl_Widget* w, void* v) {
    int preset_pos = (intptr_t)v;
    if (stereoTool_SetBuiltInPreset(st_stream.instance, preset_pos)) {
        print_info("Preset appliqué", 0);
    }
}
```

---

### Exemple 3 : Normalisation R128 Automatique
```cpp
void enable_r128_normalization(gStereoTool* st, float target_lufs) {
    // Activer mode R128
    stereoTool_SetR128Mode(st, 1, target_lufs, 1.0f);
    
    // Après chaque traitement de fichier, vérifier le gain
    float gain = stereoTool_GetR128Gain(st, target_lufs);
    
    if (gain < 0.99f || gain > 1.01f) {
        // Retraiter avec le gain calculé
        printf("R128: Retraitement nécessaire, gain = %.2f\n", gain);
        
        // Appliquer en mode "clip only"
        stereoTool_SetR128Mode(st, 2, target_lufs, gain);
        
        // Retraiter audio...
    } else {
        printf("R128: Niveau optimal atteint (%.1f LUFS)\n", target_lufs);
    }
}
```

---

### Exemple 4 : RDS Synchronisé avec Métadonnées
```cpp
void update_metadata_and_rds(const char* artist, const char* title) {
    // Mettre à jour interface
    update_song_display(artist, title);
    
    // Mettre à jour RDS si activé
    if (cfg.stereotool.rds_enabled) {
        char rds_rt[65];
        
        if (artist && title) {
            snprintf(rds_rt, sizeof(rds_rt), "%s - %s", artist, title);
        } else if (title) {
            snprintf(rds_rt, sizeof(rds_rt), "%s", title);
        }
        
        stereoTool_SetRdsRt(st_stream.instance, true, rds_rt, true);
        
        printf("RDS RT: %s\n", rds_rt);
    }
}
```

---

## 📚 Ressources

### Documentation Officielle
- **Site :** https://www.stereotool.com/
- **Documentation SDK :** Incluse dans le package SDK
- **Support :** support@stereotool.com

### Documents Connexes
- **QUICK_WINS_STEREOTOOL.md** - Top 5 des Quick Wins
- **IMPLEMENTATION_SUMMARY.md** - Architecture actuelle
- **src/stereo_tool.cpp** - Code d'intégration

### Fichiers SDK
```
src/stereo_tool_sdk/
├── Generic_StereoTool.h    ← Toutes les déclarations
├── ParameterEnum.h         ← IDs des paramètres
└── libStereoTool64.dylib   ← Bibliothèque (macOS Universal)
```

---

## ⚠️ Notes Importantes

### Licence
- **Licence PRO requise** pour utilisation commerciale
- Vérifier via `stereoTool_CheckLicenseValid()`
- Fonctionnalités limitées en mode trial

### Thread Safety
- **Les fonctions ne sont PAS thread-safe**
- Utiliser mutex pour accès concurrent
- Exemple dans `stereo_tool.cpp` : `pthread_mutex_t st_stream.mutex`

### Latence
- Le traitement introduit une latence (voir `GetLatency2`)
- Latence typique : 10-50ms selon preset
- Compenser pour synchronisation audio/vidéo

### Performance
- Optimisé pour temps réel
- CPU usage : 5-15% par instance (dépend du preset)
- Supporte multi-instance (jusqu'à 8 simultanées)

---

**Document créé le :** 9 octobre 2025  
**Auteur :** Documentation technique BUTT-Enhanced  
**Statut :** Référence complète v1.0

---

*Pour des exemples d'implémentation complets, voir `QUICK_WINS_STEREOTOOL.md`*

