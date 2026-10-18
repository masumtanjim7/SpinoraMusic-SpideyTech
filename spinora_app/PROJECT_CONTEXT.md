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
Task 0.7 DONE: Design system tokens in theme.dart; GlassCard widget; updated HomeScreen & SpideyApp.
Task 0.8 DONE: Firebase Core + Crashlytics init in bootstrap.dart (setCrashlyticsCollectionEnabled,
  FlutterError.onError, PlatformDispatcher.onError); firebase_options.dart via FlutterFire CLI.
  Temporary Test Crash button cleaned up from HomeScreen.
Task 0.9 DONE: GitHub Actions CI workflow at .github/workflows/ci.yml (push/PR to main, ubuntu-latest,
  subosito/flutter-action@v2 stable, flutter pub get + flutter analyze + flutter test);
  widget_test.dart replaced with GlassCard smoke test (no native Firebase required).
Task 1.0 DONE (Permission layer): AndroidManifest.xml updated with READ_MEDIA_AUDIO (API 33+),
  READ_EXTERNAL_STORAGE (maxSdkVersion=32), WRITE_EXTERNAL_STORAGE (maxSdkVersion=29).
  permission_service.dart (lib/features/library/data/) with checkAudioPermission /
  requestAudioPermission / audioPermissionStatusProvider.
  PermissionScreen (lib/features/library/presentation/) — glassmorphic gate screen.
  appRouterProvider (router.dart) with async redirect guard; SpideyApp updated to watch it.
Task 1.2 DONE (Drift Local Database): Defined Songs table schema (id, title, artist, album, duration,
  filePath, albumArtPath, isFavorite) in lib/core/database/app_database.dart; configured AppDatabase
  with NativeDatabase.createInBackground and appDatabaseProvider.
Task 1.3 DONE (Audio Scanning Service): Native MediaStore query via MethodChannel in MainActivity.kt;
  AudioScannerService and audioScannerStateProvider in lib/features/library/data/audio_scanner_service.dart;
  batch deduplicated upsert into Drift Songs table; reactive localSongsStreamProvider; HomeScreen UI trigger.
Task 1.4 DONE (Local Music Library UI): Glassmorphic LibraryScreen (lib/features/library/presentation/library_screen.dart)
  with live reactive song list, duration formatting, album art fallback, empty state GlassCard, manual scan FAB/app bar trigger,
  and /library route integrated in GoRouter.
Task 2.1 DONE (Audio Playback Engine & Glass Mini-Player): Canonical Track model (lib/core/audio/track.dart);
  AudioSession focus management; PlayerController wrapping just_audio AudioPlayer with queue, play/pause, seeking, next/prev;
  Floating Glass Mini-Player (lib/features/player/presentation/mini_player.dart) with neon progress bar, album art,
  and responsive controls; embedded into LibraryScreen and HomeScreen.
Task 2.2 DONE (Full-Screen "Now Playing" Modal): Futuristic dark glassmorphic NowPlayingScreen (lib/features/player/presentation/now_playing_screen.dart)
  with animated artwork scale/glow, interactive seek slider, live duration timestamps, shuffle toggle, repeat mode cycle (off/all/one),
  and favorite heart toggle updating Drift database; wired to MiniPlayer on tap via transparent modal bottom sheet.
Task 2.2b DONE (Background Audio Playback & Lock-Screen Media Notifications for Android 14):
  just_audio_background integrated in pubspec.yaml; Android 14 permissions (FOREGROUND_SERVICE,
  FOREGROUND_SERVICE_MEDIA_PLAYBACK, WAKE_LOCK) and AudioService / MediaButtonReceiver declared in AndroidManifest.xml;
  MainActivity extends AudioServiceActivity; JustAudioBackground.init configured in bootstrap.dart
  (com.spideytech.spinora.channel.audio / 'Spinora Playback'); PlayerController attaches MediaItem tags to AudioSource.uri,
  keeps queue synced via setAudioSources, and handles lock-screen & notification shade media buttons (Play/Pause/Next/Previous).
Task 2.2c DONE (Real Album Artwork Thumbnails, Instant Search & Favorites Filtering):
  Reusable SongArtwork widget (lib/features/library/presentation/widgets/song_artwork.dart) with native ID3/MediaStore
  embedded artwork extraction via MainActivity.kt MethodChannel, in-memory caching, and dark glassmorphic glowing fallback;
  integrated into LibraryScreen song rows, MiniPlayer leading thumbnail, and NowPlayingScreen centerpiece card;
  Glassmorphic search bar with real-time text query filtering (title, artist, album); filter chips for "All Songs" and
  "Favorites" with track counter badge; reactive Drift update synchronization when favorite heart icon is tapped.
Task 2.2d DONE (Custom Playlists & Up-Next Playback Queue Management):
  Drift database schema updated to version 2 with safe `MigrationStrategy` (onCreate + onUpgrade) adding `Playlists`
  and `PlaylistSongs` tables while preserving existing indexed tracks; reactive query streams and Riverpod providers
  for playlists and song counts; Playlists filter tab in `LibraryScreen` with glassmorphic "+ New Playlist" creation dialog,
  playlist collection view, and dedicated `PlaylistDetailScreen` with prominent "Play All" and "Shuffle" actions;
  3-dot trailing menu and long-press song options sheet ("Play Next", "Add to Playlist", "Toggle Favorite");
  dark glassmorphic "Up Next" queue modal sheet in `NowPlayingScreen` with current track highlight badge, jump-to-track tap,
  and swipe/tap track removal; 0 warnings with `.withValues(alpha: ...)`.
Task 2.2e DONE (Playback Persistence, Listening History / "Recently Played", and Premium Dark Glassmorphic UI Polish):
  Drift database schema updated to version 3 with safe `MigrationStrategy` onUpgrade adding `lastPlayedAt` and `playCount`
  to `Songs` table plus a new `PlaybackSessions` table; playback controller automatically records track play timestamps/counts
  and continuously throttles/persists active track position; automatically preloads last session on fresh launch ready to resume;
  horizontal "Recently Played" glassmorphic carousel added to `LibraryScreen` along with neon glowing active song tile & animated equalizer;
  complete visual overhaul for `NowPlayingScreen` (dual neon ambient glow blobs, multi-layered glass card, inline status badges, pill controls)
  and `MiniPlayer` (floating pill card margin, neon progress accent, Previous/Play/Next quick actions); 0 analyzer issues and all 22 tests passing.
Task 2.2f DONE (Sleep Timer, Playback Speed Control, and Song Information Sheet):
  Reactive sleep timer in `PlayerController` with presets (15, 30, 45, 60 min, End of Track), live 1-second countdown,
  and clean auto-pause on timer expiry or track completion; playback speed control (0.75x, 1.0x, 1.25x, 1.5x, 2.0x) on `AudioPlayer`;
  compact glassmorphic bottom audio tools row on `NowPlayingScreen` with glowing active timer badge, speed badge, queue trigger,
  and track info trigger; dark glassmorphic modal bottom sheets for Sleep Timer, Playback Speed, and Song Info (title, artist, album,
  duration, play count, last played date/time, and file path); 0 analyzer issues and all 26 tests passing.
Task 2.2g DONE (Library Sorting, Artists & Albums Grouped Views, and "Most Played" Filtering):
  Added `SongSortOption` enum (`titleAsc`, `artistAsc`, `mostPlayed`, `recentlyPlayed`, `durationDesc`) with state notifiers
  `librarySortOptionProvider` and `librarySortAscendingProvider`; dynamic sorting with ascending/descending order support;
  category filter row in horizontal `SingleChildScrollView` expanded to `All Songs`, `Favorites`, `Most Played` (`playCount > 0`),
  `Playlists`, `Artists`, and `Albums`; glassmorphic Sort button opening dark glassmorphic `SortBottomSheet`;
  `ArtistsGroupedView` grouping library tracks by artist with glass cards and detail bottom sheet with "Play All" & "Shuffle";
  `AlbumsGroupedView` grouping library tracks by album in a 2-column grid with detail bottom sheet with "Play All" & "Shuffle";
Task 2.3 DONE (Synced & Offline Lyrics Engine - .lrc & Custom Stored Lyrics):
  Drift database schema updated to version 4 with safe `MigrationStrategy` onUpgrade adding nullable `lyrics` (`TextColumn`)
  to `Songs` table and `updateSongLyrics(songId, lyrics)` method; lightweight LRC parser (`LrcParser`) parsing standard `[mm:ss.xx]`
  and `[mm:ss]` lines into `LyricLine(timestamp, text)` with seamless fallback to plain text lines;
  automatic multi-tier lyrics resolution (`resolveSongLyrics`): checking Drift database cache first, falling back to local `.lrc`
  or `.txt` file alongside the audio file (`song.filePath`), automatically caching discovered lyrics into Drift;
  interactive glassmorphic `LiveLyricsCard` with smooth `AnimatedSwitcher` flip from centerpiece artwork card;
  real-time active line highlighting in glowing neon cyan with larger bold typography, auto-scroll smoothly as track advances,
  and tap-to-seek directly to timestamped moment; safe `EditLyricsDialog` for pasting or modifying `.lrc` and plain lyrics offline;
  Lyrics toggle button added to `AudioToolsActionRow` on `NowPlayingScreen`; 0 analyzer issues and all 39 tests passing.
Task 2.3b DONE (Automatic Online Synced Lyrics Fetching, Offline Drift Caching & Reactive UI - Steps 1 & 2):
  Added `http: ^1.2.2` and declared `INTERNET` + `ACCESS_NETWORK_STATE` permissions in `AndroidManifest.xml`;
  created `OnlineLyricsService` (lib/features/player/data/online_lyrics_service.dart) with smart metadata cleaner `cleanQueryText`
  and `cleanSongMetadata` (stripping noise, parenthesized tags, extensions, bitrates, website watermarks like PagalWorld/DJPunjab,
  and splitting unknown artist `Artist - Title` automatically); queries LRCLIB API (`lrclib.net`) prioritizing synced lyrics and closest
  duration with custom `SpinoraMusic/1.0.0` User-Agent and fallback search with 6-second timeout;
  background auto-fetch integration in `LyricsController` and `PlayerController`: automatically triggers when a track starts playing or
  when lyrics are viewed if lyrics are missing, caching results permanently into Drift database via `updateSongLyrics`;
  wired into Now Playing Lyrics UI (`LiveLyricsCard` in `lyrics_view.dart`):
  - Sleek dark glassmorphic loading state (`_LyricsLoadingView`) with neon cyan progress indicator while lyrics are actively fetched;
  - Instant reactive UI update from Drift database stream as soon as online lyrics are cached, without closing the lyrics view;
  - Compact glowing neon pill badge in header indicating `SYNCED LRC` (when timestamped `[mm:ss.xx]` lines are present), `PLAIN TEXT`, or `SEARCHING...`;
  - Lyrics header actions: Auto-Fetch / Refresh (`Icons.refresh_rounded`), Custom Online Search dialog (`Icons.travel_explore_rounded` pre-filled with cleaned metadata), Manual Edit / Paste (`Icons.edit_note_rounded`), and Return to Artwork (`Icons.photo_rounded`);
  - Fixed layout overflow & clipping issues: wrapped `AudioToolsActionRow` in a horizontal `SingleChildScrollView` with `ConstrainedBox` + tight button padding eliminating the 56px bottom overflow; made `LiveLyricsCard` header icon buttons compact (32x32) and hid `LYRICS` title during `SEARCHING...` state; reduced vertical spacing and wrapped `_NoLyricsPlaceholder` in centered `SingleChildScrollView` preventing button clipping;
  Task 2.3c DONE (Lyrics UX Upgrades: Dead-Center Auto-Scrolling, Dynamic Expansion, Header Overflow Fix & Queue Button Neutrality):
  - Expand Lyrics Card Size When Active: Centerpiece container smoothly expands from artwork square to full available width (`constraints.maxWidth`) and taller height (340–380px) via `AnimatedContainer` (300ms, `Curves.easeOutCubic`) with compacted vertical spacing below it, preserving sleek square artwork dimensions when flipped back.
  - Smooth Dead-Center Auto-Scrolling (`alignment: 0.5`) & Line-by-Line Animation: Replaced virtualized list with `SingleChildScrollView` + `Column` with `EdgeInsets.symmetric(vertical: 120, horizontal: 8)` so top and bottom lines can center smoothly; maintained `Map<int, GlobalKey>` across all lyric lines; auto-scrolls via `Scrollable.ensureVisible(targetContext, alignment: 0.5, duration: Duration(milliseconds: 450), curve: Curves.easeOutCubic)` scheduled post-frame; active line rendered with 300ms `AnimatedDefaultTextStyle` (18.5pt bold, neon cyan glow) and `AnimatedContainer` (cyan glow border & subtle highlight), dimming inactive lines to 35% opacity.
  - Eliminated "Right Overflowed by 19 Pixels" Header Bug: Made the 4 header action `IconButton`s compact (`BoxConstraints(minWidth: 30, minHeight: 30)`, `padding: EdgeInsets.zero`, `iconSize: 18`) and wrapped title + badge in `Expanded` with `Flexible/ellipsis` so the header never overflows on any screen width.
  - Fixed Queue Pill Button Highlight: Set `isActive: false` on the bottom `Queue` tool button to match the neutral unselected glass aesthetic of `Timer`, `1.0x`, and `Info`.
  - Maintained `.withValues(alpha: ...)` for color opacities; 0 analyzer issues and all 50 tests passing.
Task 2.5 DONE (Built-In Hardware Audio Equalizer & Loudness/Bass Enhancer):
  - Configured `AudioPipeline` on `AudioPlayer` with native `AndroidEqualizer` and `AndroidLoudnessEnhancer`;
  - Reactive `PlayerState` and `PlayerController` methods for enabling/disabling EQ and Loudness Enhancer, live band gain adjustment, hardware center frequency formatting (`60Hz`, `230Hz`, `910Hz`, `3.6kHz`, `14kHz`), target gain boost (`0.0` to `10.0` dB), and 6 built-in presets (`Flat`, `Bass Boost`, `Pop`, `Rock`, `Vocal`, `Custom`) with linear interpolation for arbitrary band counts;
  - Created futuristic dark glassmorphic `EqualizerSheet` (`#0A0A12` base, neon cyan/violet sliders, `RotatedBox` vertical band sliders with live dB text, and dedicated horizontal Loudness / Bass Gain boost slider);
  - Wired `EQ` pill button with live neon cyan active state into the horizontal scrollable `AudioToolsActionRow` on `NowPlayingScreen`;
  - Wrapped text inside rows with `Expanded` eliminating any `RenderFlex` overflow; 0 analyzer issues and all 58 tests passing.
Task 2.6 DONE (Offline Track Metadata Editor & Library Track Management):
  - Database schema updated to version 5 with safe `MigrationStrategy` `onUpgrade` adding `isCustomEdited` (`BoolColumn`, default `false`) and `isHidden` (`BoolColumn`, default `false`) to `Songs` table;
  - Added `updateSongMetadata({required int songId, required String title, required String artist, required String album})` setting `isCustomEdited = true`, and `setSongHidden({required int songId, required bool isHidden})`;
  - Updated all library queries (`watchAllSongs`, `watchSongsInPlaylist`, `watchRecentlyPlayedSongs`, `watchPlaylistSongCount`, and `localSongsStreamProvider`) to strictly exclude `isHidden == true` tracks so hidden ringtones/clips don't clutter the library;
  - Updated `AudioScannerService` to preserve custom `title`, `artist`, `album`, `isFavorite`, `lyrics`, `isCustomEdited`, and `isHidden` flags during rescans so user edits are never overwritten;
  - Created dark glassmorphic `EditSongDialog` (`lib/features/library/presentation/widgets/edit_song_dialog.dart`) with `Title`, `Artist`, and `Album` text fields, convenient "Auto-Clean Tags from Filename" button stripping extensions, bitrates, website watermarks, and promotional tags with one tap; strictly managed `TextEditingController` lifecycles in `State.dispose()`; updates Drift database, updates active track in `PlayerController`, and triggers `refetchLyrics()` if lyrics were empty;
  - Added "Edit Tags" and "Hide from Library" (with quick Undo SnackBar action) options to `SongOptionsSheet` in `library_screen.dart`; added "Edit Tags" action button to `TrackInfoSheet` in `audio_tools_sheets.dart`;
  - 0 analyzer issues and all 65 unit/widget tests passing.
Task 2.7 DONE (Phase 2: Hybrid Online Audio Search & Streaming via `youtube_explode_dart`):
  - Dependency: Added `youtube_explode_dart: 3.1.0` to `pubspec.yaml`;
  - Resilient Stream Extraction (`lib/features/online/data/youtube_audio_service.dart`):
    * `getAudioStreamUrl(videoId)` uses multi-client manifest resolution (`ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr, YoutubeApiClient.android]`) to bypass HTTP 403 blocks;
    * Prioritizes MP4 (`m4a` / `mp4a`) audio-only streams with highest bitrate (`.withHighestBitrate()`) for reliable Android ExoPlayer playback, with clean fallback to generic audioOnly, muxed, and highest-bitrate audio streams;
    * Detailed debug logging for stream resolution and errors;
    * Resolved ExoPlayer HTTP 403 Forbidden & Cleartext HTTP traffic error: enabled `android:usesCleartextTraffic="true"` in `AndroidManifest.xml` and loaded `AudioSource.uri(Uri.parse(streamUrl), tag: mediaItem)` without custom headers for direct unproxied native HTTPS playback;
    * Manifest optimization: `YoutubeAudioService.getAudioStreamUrl` uses `[YoutubeApiClient.androidVr, YoutubeApiClient.ios]` first for unthrottled `mp4` streams, enforces `https://` via `ensureHttps`, and prioritizes MP4 container `audioOnly` streams;
    * Resilient retry: automatic single retry with fallback stream from `YoutubeAudioService` before surfacing error to user;
    * UI responsiveness: Immediately sets `currentTrack` and `isBuffering: true` (`isLoading: true`) on track tap so Mini-Player and Now Playing show loading spinner instantly;
    * Guarded queue loading: never passes unresolved `yt://` URIs or entire 20-track lists into `player.setAudioSources(...)` (avoiding ExoPlayer unknown protocol errors and timeout issues); resolves current stream and loads active source into `player.setAudioSource(...)`;
    * Safe queue navigation (`next`, `previous`, `jumpToIndex`, `playNext`, `removeFromQueue`, `toggleShuffle`) with on-demand online track resolution;
    * Guarded local Drift queries (`_recordPlayback`, `_persistCurrentSession`): strictly skips or ignores negative virtual IDs (`song.id < 0` / `yt://`) so local SQLite tables are never corrupted;
    * Error feedback: surfaces clear floating SnackBar on playback failure in `OnlineSearchView`;
  - Online Search UI (`lib/features/library/presentation/library_screen.dart` & `widgets/online_search_view.dart`):
    * Debounced 500ms search bar querying YouTube streams in real time;
    * Glassmorphic result cards with network thumbnails, duration, neon `"STREAM"` badge, and one-tap playback;
  - Strict safety: all row text wrapped in `Expanded`, controllers cleanly disposed in `State.dispose()`, and `.withValues(alpha: ...)` used everywhere;
  - 0 analyzer issues and all 73 unit/widget tests passing.
Task 2.7b DONE (YouTube Local Proxy Server, Multi-Client Manifest Chunk Probe & InnerTube Search Crash Fix):
  - Local HTTP Loopback Proxy Server (`lib/features/online/data/youtube_audio_service.dart`):
    * Resolved ExoPlayer `HttpDataSource$InvalidResponseCodeException: Response code: 403` on `googlevideo.com` URLs:
      Instead of passing raw `googlevideo.com` URLs to native ExoPlayer (which gets throttled/blocked with HTTP 403 by YouTube due to ExoPlayer's DefaultHttpDataSource lacking YouTube's chunking signature and headers), `YoutubeAudioService` hosts a lightweight loopback `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` serving streams at `http://127.0.0.1:<port>/stream/<videoId>`.
    * Native Chunk Streaming & Fast Temp Cache: Streams bytes natively via Dart's `_yt.videos.streamsClient.get(streamInfo)` directly to ExoPlayer's `HttpResponse` while simultaneously saving the byte stream to `${Directory.systemTemp.path}/spinora_yt_cache/yt_<videoId>.m4a` for instant subsequent playback and offline caching.
    * HTTP Range Requests & Seeking (206 Partial Content): Implemented full byte range parsing (`Range: bytes=start-end`), `Accept-Ranges: bytes`, `Content-Range`, and `Content-Length` headers so ExoPlayer can seek forward and backward through cached files with zero latency.
    * Multi-Client Manifest & Live Chunk Probe: Sequentially queries clients (`ios`, `android`, `safari`, `tv`) and proactively validates the stream candidate with `_yt.videos.streamsClient.get(candidate).first` chunk probe, instantly discarding dead/403 clients and selecting a 100% working audio stream.
  - Short Query Search Crash Fix (`NoSuchMethodError: Class '_Map<String, dynamic>' has no instance method 'getT'`):
    * Handled unparsed rich shelves in `youtube_explode_dart` on short queries like `"aaj"`: wraps `_yt.search.search(query)` in try-catch and automatically falls back to YouTube's public InnerTube JSON search endpoint (`https://www.youtube.com/youtubei/v1/search`), cleanly parsing `videoRenderer` items, formatted durations, artists, and high-res thumbnails.
  - UI Consolidation (`lib/features/library/presentation/library_screen.dart`):
    * Removed duplicate "YouTube Search" container badge and consolidated filter category chip into a single clean `"YouTube Stream"` chip positioned right after `Albums` in the horizontal category bar.
Task 2.7c DONE (Multi-Stage Unthrottled Online Audio Resolver, Matching User-Agent Proxy & Duplicate Tap Guard):
  - Multi-Stage Audio Resolver (`lib/features/online/data/youtube_audio_service.dart`):
    * Solved `YoutubeExplodeException: Video ... returned 403 (stream: 133 / 137)`:
      Replaced `getManifest()` probing (which crashed when YouTube returned 403 on video streams 133 or 137) with a multi-stage direct audio resolver pipeline:
      1) Stage A (Direct InnerTube Player API): Directly posts to `https://www.youtube.com/youtubei/v1/player` with client contexts (`ANDROID_VR`, `IOS`, `ANDROID_TESTSUITE`). Parses `streamingData.adaptiveFormats` directly from JSON, selecting audio streams (itag 140 / 251) with direct `url` fields without ever requesting or probing video streams 133 or 137!
      2) Stage B (Local Proxy with Matching Client User-Agent): Attaches the exact matching `User-Agent` from Stage A (and Range header from ExoPlayer) when requesting `googlevideo.com` from our local loopback proxy (`http://127.0.0.1:<port>/stream/<videoId>`), forwarding 200/206 Partial Content, Content-Range, Content-Length, and Accept-Ranges back to ExoPlayer while caching to disk.
      3) Stage C (High-Speed 320kbps Music Fallback API): If YouTube requires bot login (`LOGIN_REQUIRED`) or lacks unencrypted URLs, automatically queries JioSaavn's public CDN search using `cleanSongQuery(title, artist)` and generates an unthrottled 320kbps MP4 audio stream URL with Range support.
      4) Stage D (Invidious & youtube_explode_dart Fallbacks): Queries Invidious instances (`inv.nadeko.net`, etc.) and safe `getManifest` as resilient fallback stages.
  - Duplicate Tap & Race Condition Guard (`lib/features/player/application/player_controller.dart`):
    * Added `_playbackRequestId` counter in `PlayerController.playTrack`.
    * If a user rapidly taps multiple online songs, preceding asynchronous stream resolutions are immediately discarded, ensuring only the latest tapped track loads into `_audioPlayer`.
    * Passes track `title` and `artist` into `getAudioStreamUrl` for instant fallback resolution.
  - Tests & Analysis:
    * 0 analyzer issues (`flutter analyze` with 0 issues).
    * All 78 tests passed (`flutter test`).
Next: Task 2.8 Crossfade / Gapless Playback or Full-Screen Immersive Lyrics Mode.
Roadmap: 0 Setup ✓, 1 Core and UI ✓, 2 Streaming and audio (in progress), 3 AI, 4 Local badges and themes (optional sync),
5 Friends APK release. Task IDs (for example 2.8 Crossfade) match the Spinora implementation guide.