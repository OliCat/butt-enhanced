# Changelog - BUTT Enhanced

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [1.45.0-Enhanced] - 2025-01-XX

### ✨ Ajouté

#### BlackHole Output
- **Sortie BlackHole** : Intégration complète de la sortie audio virtuelle BlackHole
- **Ring buffer** : Buffer de 2 secondes pour fluidité audio
- **Initialisation automatique** : Détection et initialisation automatique au démarrage
- **Support Whisper Streaming** : Compatible avec Whisper AI et autres applications
- **Logs de débogage** : Logs détaillés pour diagnostic

#### AES67 Output
- **Sortie AES67** : Diffusion audio professionnelle sur réseau IP
- **Multicast UDP** : Support multicast avec TTL configurable
- **PTP** : Synchronisation temporelle précise
- **SAP** : Découverte automatique des sessions
- **Format audio** : PCM 24-bit, 48 kHz, stéréo

#### StereoTool SDK
- **Intégration SDK** : Support StereoTool PRO
- **Bypass on silence** : Désactivation automatique sur silence
- **VU meters** : Pré et post traitement
- **Configuration par preset** : Chargement de presets StereoTool

### 🔧 Modifié

#### BlackHole Output
- **Amélioration de la gestion des buffers** : Remplacement de la queue simple par un ring buffer
- **Correction du son saccadé** : Synchronisation améliorée entre l'envoi et la consommation
- **Gestion des buffers partiels** : Meilleure gestion des cas où il n'y a pas assez de données
- **Vérification du format audio** : Obtention et vérification du format du périphérique BlackHole

#### Documentation
- **Documentation complète** : Création de `docs/DOCUMENTATION_COMPLETE.md`
- **Nettoyage** : Suppression des fichiers intermédiaires de développement
- **Organisation** : Réorganisation de la documentation par thème

### 🐛 Corrigé

#### BlackHole Output
- **Fichier WAV vide** : Correction de la consommation des données dans le callback `render()`
- **Son saccadé** : Remplacement de la queue simple par un ring buffer pour fluidité
- **Erreur de compilation** : Correction du cast pour `rb_write` qui attend un `char *` non-const

### 📚 Documentation

- **Nouvelle documentation** : `docs/DOCUMENTATION_COMPLETE.md` - Documentation complète et à jour
- **README docs** : `docs/README.md` - Index de la documentation
- **Script de nettoyage** : `scripts/cleanup_docs.sh` - Script pour nettoyer la documentation

### 🗑️ Supprimé

- **Fichiers intermédiaires** : Suppression des fichiers de correction, résumés, et roadmaps intermédiaires
- **Duplicatas** : Suppression des fichiers dupliqués

---

## [1.45.0] - 2024-XX-XX

### Version de base BUTT

Version originale de BUTT (Broadcast Using This Tool) par Daniel Nöthen.

---

## Format du Changelog

### Types de modifications

- **✨ Ajouté** : Nouvelles fonctionnalités
- **🔧 Modifié** : Modifications de fonctionnalités existantes
- **🐛 Corrigé** : Corrections de bugs
- **🗑️ Supprimé** : Fonctionnalités supprimées
- **📚 Documentation** : Modifications de la documentation
- **🔒 Sécurité** : Corrections de sécurité

---

**Note** : Ce changelog est maintenu manuellement. Les dates sont approximatives.

