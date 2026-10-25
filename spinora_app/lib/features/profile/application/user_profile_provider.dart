import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const _kDisplayName = 'profile_display_name';
const _kVibeSubtitle = 'profile_vibe_subtitle';
const _kAvatarPath = 'profile_avatar_path';
const _kOnboardingDone = 'profile_onboarding_done';

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

class UserProfile {
  const UserProfile({
    this.displayName = 'Music Lover',
    this.vibeSubtitle = 'Finding my frequency',
    this.avatarPath,
    this.hasCompletedOnboarding = false,
  });

  final String displayName;
  final String vibeSubtitle;
  final String? avatarPath;
  final bool hasCompletedOnboarding;

  UserProfile copyWith({
    String? displayName,
    String? vibeSubtitle,
    String? avatarPath,
    bool clearAvatarPath = false,
    bool? hasCompletedOnboarding,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      vibeSubtitle: vibeSubtitle ?? this.vibeSubtitle,
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  late SharedPreferences _prefs;

  @override
  Future<UserProfile> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _load();
  }

  UserProfile _load() {
    return UserProfile(
      displayName: _prefs.getString(_kDisplayName) ?? 'Music Lover',
      vibeSubtitle: _prefs.getString(_kVibeSubtitle) ?? 'Finding my frequency',
      avatarPath: _prefs.getString(_kAvatarPath),
      hasCompletedOnboarding: _prefs.getBool(_kOnboardingDone) ?? false,
    );
  }

  Future<void> updateProfile({
    String? displayName,
    String? vibeSubtitle,
    String? avatarPath,
    bool clearAvatarPath = false,
  }) async {
    final current = state.value ?? const UserProfile();

    if (displayName != null) {
      await _prefs.setString(_kDisplayName, displayName.trim());
    }
    if (vibeSubtitle != null) {
      await _prefs.setString(_kVibeSubtitle, vibeSubtitle.trim());
    }
    if (clearAvatarPath) {
      await _prefs.remove(_kAvatarPath);
    } else if (avatarPath != null) {
      await _prefs.setString(_kAvatarPath, avatarPath);
    }

    state = AsyncData(
      current.copyWith(
        displayName: displayName,
        vibeSubtitle: vibeSubtitle,
        avatarPath: avatarPath,
        clearAvatarPath: clearAvatarPath,
      ),
    );
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_kOnboardingDone, true);
    final current = state.value ?? const UserProfile();
    state = AsyncData(current.copyWith(hasCompletedOnboarding: true));
  }

  /// Resets onboarding so the flow shows again (for testing / settings).
  Future<void> resetOnboarding() async {
    await _prefs.setBool(_kOnboardingDone, false);
    final current = state.value ?? const UserProfile();
    state = AsyncData(current.copyWith(hasCompletedOnboarding: false));
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile>(
      UserProfileNotifier.new,
    );
