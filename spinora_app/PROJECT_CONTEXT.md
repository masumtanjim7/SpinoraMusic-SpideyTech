# PROJECT_CONTEXT.md: Spinora Music (read fully before every task)

## What we are building
Spinora Music is an Android music player (Flutter) by SpideyTech. Solo developer, zero budget, no paid services.
It plays local MP3s and licensed online tracks (Audius first) in ONE queue, with background play, lock-screen
controls, synced lyrics (LRC, LRCLIB), equalizer, crossfade, a dark glassmorphism UI with colors from album
art, on-device mood detection and hand gestures (camera, foreground only), local achievement badges, and
secret themes. Optional later: a Django sync backend. Karaoke, iOS and paid services are OUT of scope for v1.0.

## Tech stack (fixed)
Flutter stable, Dart null safety, flutter_riverpod, go_router, just_audio + audio_service, Drift (SQLite),
dio, tflite_flutter, google_mlkit_face_detection, MediaPipe hand landmarker, Firebase Crashlytics/Analytics.
Android only. Flavors: dev and prod. Entry points: lib/main_dev.dart and lib/main_prod.dart.
Gradle uses Kotlin DSL (build.gradle.kts).

## Architecture
lib/app (app widget, router, theme, flavor config)
lib/core/{audio, database, network, utils}
lib/features/<name>/{data, domain, presentation}   names: library, player, online, lyrics, equalizer,
                                                   playlists, ai_mood, ai_gesture, achievements, settings
lib/shared (glass widgets, buttons, loaders)

## Hard rules
1. UI reads Riverpod providers only. No database or network calls inside widgets.
2. Every track, local or online, uses the common Track model (id, title, artist, album, durationMs,
   artworkUri, source, uri). The player only knows Track.
3. Online sources implement MusicSource { search(query), resolveStream(track) }.
   NEVER use YouTube stream extraction or unofficial YouTube libraries.
4. Camera and ML: on-device only, foreground only, 5 to 10 fps, nothing saved or uploaded,
   always a toggle and a consent dialog.
5. No Marvel, Spider-Man or Venom names, logos or art. Original names for themes and badges.
6. Do not add a package without asking me first and explaining why. Check that it exists on pub.dev and
   is maintained. Never invent APIs or package names.
7. Heavy work (library scan, ML) runs in isolates. Limit BackdropFilter usage. Support a Reduce effects setting.
8. Small functions, null safety, clear names. Write tests for logic (parsers, queue, gesture rules, crossfade math).
9. Never create, edit or print secrets: keystores, key.properties, .env, google-services.json, API keys.
10. Do NOT touch backend, Docker, the Firebase console, git commits or remotes, and do not run installs,
    unless I explicitly ask. Give me the exact command and I will run it.

## Division of work
Claude (you): write and edit code, config files and tests in this repository.
Me: accounts, Firebase console, Docker, backend, flutter pub add, running on device, git, Kaggle/Colab training.

## How to answer every task
1. Restate the task in 2 lines and list the files you will create or change.
   If something is unclear, ask at most 3 questions BEFORE coding.
2. Work in small steps. Prefer editing existing files over creating new ones.
3. When finished, reply with: (a) files changed, (b) exact commands I must run (pub get, build_runner,
   flutter analyze, flutter test, flutter run --flavor dev -t lib/main_dev.dart), (c) how to verify on a
   real phone, (d) the Done when check, (e) anything I must do manually.
4. Do not start the next task. Stop and wait for me.

## Status (update after each task)
Phase 0: project created (com.spideytech.spinora), lib folder skeleton done.
Task 0.5 DONE: dev/prod flavors in build.gradle.kts; AppFlavor enum + Riverpod provider; bootstrap;
  main_dev.dart, main_prod.dart; SpideyApp (go_router + dark theme); placeholder HomeScreen.
Next: Task 1 – Core & UI (Track model, Drift DB, audio service, glass widget library).
Roadmap: 0 Setup ✓, 1 Core and UI, 2 Streaming and audio, 3 AI, 4 Local badges and themes (optional sync),
5 Friends APK release. Task IDs (for example 2.8 Crossfade) match the Spinora implementation guide.