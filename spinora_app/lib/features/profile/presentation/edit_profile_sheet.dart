import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../profile/application/user_profile_provider.dart';

// ---------------------------------------------------------------------------
// Edit Profile Bottom Sheet
// ---------------------------------------------------------------------------

/// A glassmorphic bottom sheet for editing display name and vibe subtitle.
/// TextEditingControllers are strictly disposed in State.dispose().
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();

  /// Shows the sheet and returns when dismissed.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileSheet(),
    );
  }
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _nameCtrl = TextEditingController();
  final _vibeCtrl = TextEditingController();
  String? _pendingAvatarPath;
  bool _clearAvatar = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vibeCtrl.dispose();
    super.dispose();
  }

  void _initControllers(UserProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile.displayName;
    _vibeCtrl.text = profile.vibeSubtitle;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() {
          _pendingAvatarPath = file.path;
          _clearAvatar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grant gallery access in device Settings.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeAvatar() {
    setState(() {
      _pendingAvatarPath = null;
      _clearAvatar = true;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await ref
        .read(userProfileProvider.notifier)
        .updateProfile(
          displayName: _nameCtrl.text.trim().isEmpty
              ? null
              : _nameCtrl.text.trim(),
          vibeSubtitle: _vibeCtrl.text.trim().isEmpty
              ? null
              : _vibeCtrl.text.trim(),
          avatarPath: _pendingAvatarPath,
          clearAvatarPath: _clearAvatar,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value ?? const UserProfile();
    _initControllers(profile);

    final currentAvatarPath = _pendingAvatarPath ?? profile.avatarPath;
    final showAvatar = !_clearAvatar && currentAvatarPath != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F111A);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF5C6275);
    final sheetBg = isDark
        ? const Color(0xFF0D0C18)
        : Colors.white.withValues(alpha: 0.94);
    final sheetBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: sheetBorderColor),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 24),

              // Avatar picker row
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: showAvatar
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        image: showAvatar
                            ? DecorationImage(
                                image: FileImage(File(currentAvatarPath)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.4),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: showAvatar
                          ? null
                          : const Center(
                              child: Icon(
                                Icons.add_a_photo_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: _pickAvatar,
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            size: 16,
                          ),
                          label: const Text('Change photo'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8B5CF6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        if (showAvatar)
                          TextButton.icon(
                            onPressed: _removeAvatar,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                            ),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: secondaryTextColor,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Name field
              _ProfileTextField(
                controller: _nameCtrl,
                label: 'Display name',
                hint: 'Music Lover',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Vibe field
              _ProfileTextField(
                controller: _vibeCtrl,
                label: 'Vibe tag',
                hint: 'Finding my frequency',
                icon: Icons.music_note_outlined,
                isDark: isDark,
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758F), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: _isSaving ? null : _save,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable text field widget
// ---------------------------------------------------------------------------

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF5C6275);
    final textColor = isDark ? Colors.white : const Color(0xFF0F111A);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : const Color(0xFF8E95A8);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF5C6275);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: labelColor,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor, fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: iconColor),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: fillColor,
          ),
        ),
      ],
    );
  }
}
