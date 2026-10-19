import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/library/data/audio_scanner_service.dart';
import 'package:spinora/features/player/application/player_controller.dart';
import 'package:spinora/features/profile/application/stats_provider.dart';
import 'package:spinora/features/profile/application/user_profile_provider.dart';
import 'package:spinora/features/profile/presentation/profile_screen.dart';

class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier([this._profile = const UserProfile()]);
  final UserProfile _profile;

  @override
  Future<UserProfile> build() async => _profile;
}

class FakePlayerController extends PlayerController {
  @override
  PlayerState build() => const PlayerState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Song makeSong({
    required int id,
    required String title,
    required String artist,
    int duration = 180,
    int playCount = 0,
    bool isFavorite = false,
    DateTime? lastPlayedAt,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Test Album',
      duration: duration,
      filePath: '/storage/emulated/0/Music/$title.mp3',
      isFavorite: isFavorite,
      playCount: playCount,
      lastPlayedAt: lastPlayedAt,
      isCustomEdited: false,
      isHidden: false,
    );
  }

  group('statsProvider and business logic', () {
    test('calculateListeningStats returns safe zero defaults on empty songs list', () {
      final stats = calculateListeningStats([]);

      expect(stats.totalSongs, equals(0));
      expect(stats.totalPlayedTracks, equals(0));
      expect(stats.totalPlayCount, equals(0));
      expect(stats.totalListeningHours, equals(0.0));
      expect(stats.formattedHours, equals('0.0'));
      expect(stats.topArtists, isEmpty);
      expect(stats.topSongs, isEmpty);
      expect(stats.activitySlots, isNotEmpty);
      expect(stats.streakDays, equals(1));
    });

    test('calculateListeningStats aggregates plays, duration and artists correctly', () {
      final songs = [
        makeSong(
          id: 1,
          title: 'Sunflower',
          artist: 'Post Malone',
          duration: 200,
          playCount: 10,
          isFavorite: true,
          lastPlayedAt: DateTime(2026, 10, 19, 14, 0), // afternoon
        ),
        makeSong(
          id: 2,
          title: 'Circles',
          artist: 'Post Malone',
          duration: 210,
          playCount: 5,
          isFavorite: false,
          lastPlayedAt: DateTime(2026, 10, 19, 9, 0), // morning
        ),
        makeSong(
          id: 3,
          title: 'Starboy',
          artist: 'The Weeknd',
          duration: 230,
          playCount: 0,
          isFavorite: true,
        ),
      ];

      final stats = calculateListeningStats(songs);

      expect(stats.totalSongs, equals(3));
      expect(stats.totalPlayedTracks, equals(2));
      expect(stats.totalPlayCount, equals(15));
      expect(stats.totalFavorites, equals(2));
      // Total duration: (200 * 10) + (210 * 5) = 2000 + 1050 = 3050 seconds = ~0.84 hours
      expect(stats.totalDurationSeconds, equals(3050));
      expect(stats.listeningHours, closeTo(0.847, 0.01));
      expect(stats.topArtists.first.artist, equals('Post Malone'));
      expect(stats.topArtists.first.playCount, equals(15));
      expect(stats.topSongs.first.title, equals('Sunflower'));
      expect(stats.streakDays, greaterThanOrEqualTo(1));
    });
  });

  group('ProfileScreen UI Widget Tests', () {
    testWidgets('renders loading skeleton gracefully without blank screen', (tester) async {
      final loadingStreamController = StreamController<List<Song>>();
      addTearDown(loadingStreamController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localSongsStreamProvider.overrideWith((ref) => loadingStreamController.stream),
            userProfileProvider.overrideWith(() => FakeUserProfileNotifier(const UserProfile(displayName: 'Peter Parker'))),
            playerControllerProvider.overrideWith(FakePlayerController.new),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Check header renders
      expect(find.text('INSIGHTS'), findsOneWidget);
      // Check loading skeleton shows syncing banner
      expect(find.text('SYNCING LISTENING INSIGHTS...'), findsOneWidget);
    });

    testWidgets('renders guarded dashboard on error without blank screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localSongsStreamProvider.overrideWith((ref) => Stream.error('Database connection failed')),
            userProfileProvider.overrideWith(() => FakeUserProfileNotifier(const UserProfile(displayName: 'Miles Morales'))),
            playerControllerProvider.overrideWith(FakePlayerController.new),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header renders
      expect(find.text('INSIGHTS'), findsOneWidget);
      // Check error fallback notice renders
      expect(find.text('Insights Inactive'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Check user profile hero and safe fallback stats render
      expect(find.text('Miles Morales'), findsOneWidget);
      expect(find.text('LISTENING METRICS'), findsOneWidget);
    });

    testWidgets('renders complete empty state dashboard when library has 0 songs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localSongsStreamProvider.overrideWith((ref) => Stream.value(<Song>[])),
            userProfileProvider.overrideWith(() => FakeUserProfileNotifier(const UserProfile(displayName: 'Gwen Stacy'))),
            playerControllerProvider.overrideWith(FakePlayerController.new),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('INSIGHTS'), findsOneWidget);
      // Hero Card
      expect(find.text('Gwen Stacy'), findsOneWidget);
      expect(find.text('Hours Logged'), findsOneWidget);
      expect(find.text('0.0'), findsWidgets);
      // Metrics
      expect(find.text('Total Songs Played'), findsOneWidget);
      expect(find.text('Favorite Artists'), findsOneWidget);
      // Empty insight placeholders
      expect(find.text('No Artists in Orbit Yet'), findsOneWidget);
      expect(find.text('No Heavy Rotation Yet'), findsOneWidget);
    });

    testWidgets('renders active listening stats and lists when songs have plays', (tester) async {
      final songs = [
        makeSong(id: 1, title: 'Mockingbird', artist: 'Eminem', playCount: 42, isFavorite: true),
        makeSong(id: 2, title: 'Stan', artist: 'Eminem', playCount: 18),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localSongsStreamProvider.overrideWith((ref) => Stream.value(songs)),
            userProfileProvider.overrideWith(() => FakeUserProfileNotifier(const UserProfile(displayName: 'Spider-Man'))),
            playerControllerProvider.overrideWith(FakePlayerController.new),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('INSIGHTS'), findsOneWidget);
      expect(find.text('Spider-Man'), findsOneWidget);
      expect(find.text('Eminem'), findsOneWidget);
      expect(find.text('Mockingbird'), findsOneWidget);
      expect(find.textContaining('42 plays'), findsOneWidget);
    });
  });
}
