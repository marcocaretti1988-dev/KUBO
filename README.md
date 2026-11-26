# KUBO RUN (Godot 4.7)

Port fedele della versione HTML di Kubo Run. Sviluppato da RUSTENGINE.

## Struttura
- `scenes/Main.tscn` – scena principale
- `scripts/main.gd` – menu, villaggio, storia, video, negozio, HUD, input touch
- `scripts/game.gd` – livelli (stesso seme dell'HTML), fisica, rampino, nemici, boss, disegno
- `scripts/ctx.gd` – motore di disegno compatibile con il Canvas 2D dell'HTML
- `scripts/k.gd` – Kubo, facce, cappelli, Re Ombra, chiave, gabbia, Divoratore
- `scripts/bake.gd` + `shaders/` – sfondi realistici generati dalla GPU
- `scripts/audio.gd` – musica chiptune ed effetti sintetizzati
- `data/data.json` – mondi, amici, skin, testi

## APK automatico
Ogni push su `main` costruisce l'APK su GitHub (Actions → APK Android → Artifacts → KuboRun-apk).
