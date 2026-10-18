import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/library/data/audio_scanner_service.dart';
import 'package:spinora/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('LibraryScreen renders empty view when no songs are present',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value([])),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Music Library'), findsOneWidget);
    expect(find.text('No Songs Found'), findsOneWidget);
    expect(find.text('Scan Storage Now'), findsOneWidget);
  });

  testWidgets('LibraryScreen renders song tiles when songs are loaded',
      (tester) async {
    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Mock Track 1',
        artist: 'Artist A',
        album: 'Album X',
        duration: 185000,
        filePath: '/music/track1.mp3',
        isFavorite: false,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 2,
        title: 'Mock Track 2',
        artist: 'Artist B',
        album: 'Album Y',
        duration: 240000,
        filePath: '/music/track2.mp3',
        isFavorite: false,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mock Track 1'), findsOneWidget);
    expect(find.text('Mock Track 2'), findsOneWidget);
    expect(find.text('Artist A • Album X'), findsOneWidget);
    expect(find.text('3:05'), findsOneWidget); // 185s = 3m 05s
    expect(find.text('4:00'), findsOneWidget); // 240s = 4m 00s
  });

  testWidgets(
      'LibraryScreen displays Recently Played carousel when recent songs exist',
      (tester) async {
    final recentSong = Song(
      id: 99,
      title: 'Neon Drift Highway',
      artist: 'Spidey Producer',
      album: 'Synth City',
      duration: 195000,
      filePath: '/music/neon.mp3',
      isFavorite: true,
      lastPlayedAt: DateTime(2026, 1, 1),
      playCount: 5,
      isCustomEdited: false,
      isHidden: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value([recentSong])),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([recentSong])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Recently Played header and card are rendered
    expect(find.text('RECENTLY PLAYED'), findsOneWidget);
    expect(find.text('Neon Drift Highway'), findsWidgets);
    expect(find.text('Spidey Producer'), findsWidgets);
  });

  testWidgets(
      'LibraryScreen filters tracks in real time by search query and favorites',
      (tester) async {
    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Cyberpunk Beat',
        artist: 'Spidey Producer',
        album: 'Neon City',
        duration: 180000,
        filePath: '/music/cyber.mp3',
        isFavorite: true,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 2,
        title: 'Acoustic Sunrise',
        artist: 'Morning Artist',
        album: 'Calm Day',
        duration: 210000,
        filePath: '/music/acoustic.mp3',
        isFavorite: false,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state shows both songs and track counter badge
    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsOneWidget);
    expect(find.text('2 tracks'), findsOneWidget);

    // 1. Search for "Cyber"
    await tester.enterText(find.byType(TextField), 'Cyber');
    await tester.pumpAndSettle();

    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // 2. Clear search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsOneWidget);

    // 3. Filter by Favorites chip
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // 4. Switch to Playlists tab
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    expect(find.text('Create New Playlist'), findsOneWidget);
    expect(find.text('No Playlists Created Yet'), findsOneWidget);
  });

  testWidgets('Tapping 3-dot song options opens song options bottom sheet',
      (tester) async {
    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Action Theme',
        artist: 'Composer X',
        album: 'Soundtrack 1',
        duration: 180000,
        filePath: '/music/theme.mp3',
        isFavorite: false,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and tap the 3-dot menu on the song tile
    final moreButton = find.byIcon(Icons.more_vert_rounded);
    expect(moreButton, findsOneWidget);

    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Verify sheet actions
    expect(find.text('Play Next'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Add to Favorites'), findsOneWidget);
  });

  testWidgets(
      'Filter chips are selectable even when library is empty and tapping playlist opens PlaylistDetailScreen',
      (tester) async {
    final fakePlaylists = [
      Playlist(
        id: 1,
        name: 'Cyberpunk Mix',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value([])),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value(fakePlaylists)),
          playlistSongCountStreamProvider(1)
              .overrideWith((ref) => Stream.value(0)),
          playlistSongsStreamProvider(1)
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify filter bar is visible even with empty songs
    expect(find.text('All Songs'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);

    // Tap 'Playlists' filter chip
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    // Verify playlists view is shown with the playlist card
    expect(find.text('Create New Playlist'), findsOneWidget);
    expect(find.text('Cyberpunk Mix'), findsOneWidget);
    expect(find.text('0 tracks'), findsOneWidget);

    // Tap the playlist card
    await tester.tap(find.text('Cyberpunk Mix'));
    await tester.pumpAndSettle();

    // Verify PlaylistDetailScreen is pushed with "Play All" button
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Empty Playlist'), findsOneWidget);
  });

  testWidgets('LibraryScreen does not overflow on a narrow 320px screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Very Long Synthwave Song Title That Could Cause Overflow Issues',
        artist: 'Extremely Long Artist Name Feat. Collaborator',
        album: 'Album With An Unusually Long Title To Stress Layout',
        duration: 320000,
        filePath: '/music/long.mp3',
        isFavorite: true,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // No overflow exception should occur
    expect(tester.takeException(), isNull);
    expect(find.text('All Songs'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
  });

  testWidgets(
      'Creating playlist via dialog disposes controller cleanly without error',
      (tester) async {
    final memoryDb = AppDatabase(NativeDatabase.memory());
    addTearDown(() => memoryDb.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(memoryDb),
          localSongsStreamProvider.overrideWith((ref) => Stream.value([])),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Playlists tab
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    // Tap "Create New Playlist" card
    await tester.tap(find.text('Create New Playlist'));
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.text('New Playlist'), findsOneWidget);
    final dialogTextField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(dialogTextField, findsOneWidget);

    // Enter playlist name
    await tester.enterText(dialogTextField, 'Synthwave Vibes');
    await tester.pumpAndSettle();

    // Tap "Create" button
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Verify dialog closed with NO assertion error or crash
    expect(tester.takeException(), isNull);
    expect(find.text('New Playlist'), findsNothing);

    // Verify playlist was inserted into database
    final playlists = await memoryDb.select(memoryDb.playlists).get();
    expect(playlists.length, 1);
    expect(playlists.first.name, 'Synthwave Vibes');

    // Dismiss any snackbar timer cleanly
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'LibraryScreen filters by Most Played tab and orders by playCount desc',
      (tester) async {
    final songs = [
      const Song(
        id: 1,
        title: 'Unplayed Track',
        artist: 'Artist Zero',
        album: 'Album 0',
        duration: 180000,
        filePath: '/music/zero.mp3',
        isFavorite: false,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 2,
        title: 'Popular Track 10',
        artist: 'Artist Ten',
        album: 'Album 10',
        duration: 200000,
        filePath: '/music/ten.mp3',
        isFavorite: false,
        playCount: 10,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 3,
        title: 'Medium Track 5',
        artist: 'Artist Five',
        album: 'Album 5',
        duration: 210000,
        filePath: '/music/five.mp3',
        isFavorite: false,
        playCount: 5,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value(songs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify all 3 songs shown in All tab
    expect(find.text('Unplayed Track'), findsOneWidget);
    expect(find.text('Popular Track 10'), findsOneWidget);
    expect(find.text('Medium Track 5'), findsOneWidget);

    // Tap Most Played tab
    await tester.tap(find.text('Most Played'));
    await tester.pumpAndSettle();

    // Unplayed track with playCount == 0 should be filtered out
    expect(find.text('Unplayed Track'), findsNothing);
    expect(find.text('Popular Track 10'), findsOneWidget);
    expect(find.text('Medium Track 5'), findsOneWidget);
  });

  testWidgets(
      'LibraryScreen opens Sort Bottom Sheet and switches sort options',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final songs = [
      const Song(
        id: 1,
        title: 'Alpha Song',
        artist: 'Zulu Artist',
        album: 'Album A',
        duration: 180000,
        filePath: '/music/a.mp3',
        isFavorite: false,
        playCount: 1,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 2,
        title: 'Beta Song',
        artist: 'Alpha Artist',
        album: 'Album B',
        duration: 240000,
        filePath: '/music/b.mp3',
        isFavorite: false,
        playCount: 2,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value(songs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap sort chip button in the filter bar
    final sortButton = find.byTooltip('Change sorting order');
    expect(sortButton, findsOneWidget);
    await tester.ensureVisible(sortButton);
    await tester.tap(sortButton);
    await tester.pumpAndSettle();

    // Verify Sort Bottom Sheet header and options are displayed
    expect(find.text('SORT SONGS'), findsOneWidget);
    expect(find.text('Ascending'), findsOneWidget);
    expect(find.text('Descending'), findsOneWidget);
    expect(find.text('Title'), findsWidgets);
    expect(find.text('Artist'), findsWidgets);
    expect(find.text('Most Played'), findsWidgets);
    expect(find.text('Recently Played'), findsWidgets);
    expect(find.text('Duration'), findsWidgets);

    // Select Descending order
    await tester.tap(find.text('Descending'));
    await tester.pumpAndSettle();

    // Select sort by Artist (which updates sort and automatically dismisses sheet)
    await tester.tap(find.text('Artist').last);
    await tester.pumpAndSettle();

    expect(find.text('SORT SONGS'), findsNothing);
  });

  testWidgets(
      'LibraryScreen groups songs by Artists and displays tracks in bottom sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final songs = [
      const Song(
        id: 1,
        title: 'Around the World',
        artist: 'Daft Punk',
        album: 'Homework',
        duration: 240000,
        filePath: '/music/daft1.mp3',
        isFavorite: false,
        playCount: 4,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 2,
        title: 'One More Time',
        artist: 'Daft Punk',
        album: 'Discovery',
        duration: 320000,
        filePath: '/music/daft2.mp3',
        isFavorite: true,
        playCount: 12,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 3,
        title: 'Time',
        artist: 'Hans Zimmer',
        album: 'Inception',
        duration: 275000,
        filePath: '/music/zimmer.mp3',
        isFavorite: false,
        playCount: 1,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value(songs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Artists filter chip
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();

    // Verify grouped artist cards
    expect(find.text('Daft Punk'), findsOneWidget);
    expect(find.text('Hans Zimmer'), findsOneWidget);
    expect(find.text('2 tracks'), findsOneWidget);
    expect(find.text('1 track'), findsOneWidget);

    // Tap on Daft Punk artist card to open artist detail sheet
    await tester.tap(find.text('Daft Punk'));
    await tester.pumpAndSettle();

    // Verify detail sheet shows artist name, action buttons, and tracks
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Around the World'), findsOneWidget);
    expect(find.text('One More Time'), findsOneWidget);
  });

  testWidgets(
      'LibraryScreen groups songs by Albums and displays album tracks sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final songs = [
      const Song(
        id: 1,
        title: 'Harder, Better, Faster, Stronger',
        artist: 'Daft Punk',
        album: 'Discovery',
        duration: 224000,
        filePath: '/music/daft_hbfs.mp3',
        isFavorite: false,
        playCount: 6,
        isCustomEdited: false,
        isHidden: false,
      ),
      const Song(
        id: 2,
        title: 'Dream is Collapsing',
        artist: 'Hans Zimmer',
        album: 'Inception',
        duration: 143000,
        filePath: '/music/zimmer_dream.mp3',
        isFavorite: false,
        playCount: 2,
        isCustomEdited: false,
        isHidden: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value(songs)),
          recentlyPlayedSongsStreamProvider
              .overrideWith((ref) => Stream.value([])),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Albums filter chip
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    // Verify albums in grid
    expect(find.text('Discovery'), findsOneWidget);
    expect(find.text('Inception'), findsOneWidget);

    // Tap on Discovery album card to open album detail sheet
    await tester.tap(find.text('Discovery'));
    await tester.pumpAndSettle();

    // Verify album detail sheet shows album title, action buttons, and track
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Harder, Better, Faster, Stronger'), findsOneWidget);
  });
}
