// Patch alternatif pour Mac Pro Intel - VU-meter timing
// Ce fichier peut remplacer fl_timer_funcs.cpp pour tester différents paramètres

// Fonction modifiée avec timing ajusté pour Mac Pro Intel
void vu_meter_timer_intel_patch(void *)
{
    static int cleared = 0;
    static int no_new_frames_cnt = 0;
    static int frame_skip_counter = 0; // Nouveau: skip frames pour Mac Intel

    // Mac Intel: Traiter seulement 1 frame sur 3 pour réduire la sensibilité
    frame_skip_counter++;
    if (frame_skip_counter < 3) {
        Fl::repeat_timeout(0.05, &vu_meter_timer_intel_patch);
        return;
    }
    frame_skip_counter = 0;

    if (pa_new_frames) {
        snd_update_vu(0);
        no_new_frames_cnt = 0;
        cleared = 0;
    }
    else if (no_new_frames_cnt < 15) { // Augmenté de 10 à 15 pour Mac Intel
        no_new_frames_cnt++;
    }
    else if (cleared == 0) {
        snd_update_vu(1);
        cleared = 1;
    }

    if (g_stop_vu_meter_timer == 1) {
        g_vu_meter_timer_is_active = 0;
    }
    else {
        // Timing plus lent pour Mac Intel : 0.08s au lieu de 0.05s
        Fl::repeat_timeout(0.08, &vu_meter_timer_intel_patch);
    }
} 