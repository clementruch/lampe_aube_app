# Lampe Aube – Application Flutter

Application mobile Flutter pour piloter une **lampe connectée intelligente** (projet Systèmes Embarqués / IoT).

## Fonctionnalités prévues
- Simulation de lever du soleil (réveil progressif).
- Modes prédéfinis : Lecture / Relax / Nuit.
- Éclairage adaptatif via capteur de luminosité.
- Suivi des données capteurs (Température, Luminosité).
- Pilotage manuel (on/off, intensité, couleur).
- Multi-utilisateurs / multi-lampes via API + stockage serveur.

## Installation & lancement

### 1. Pré-requis
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio (SDK + émulateur) ou un smartphone Android connecté en USB.
- VS Code (ou Android Studio) avec les extensions **Flutter** et **Dart**.

### 2. Créer et lancer le projet
```bash
flutter pub get       # télécharge les dépendances
flutter run           # lance l'app sur l'émulateur ou le téléphone
