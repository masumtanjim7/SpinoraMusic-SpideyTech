import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../player/application/lyrics_controller.dart';
import '../../../player/application/player_controller.dart';
import '../../../player/data/online_lyrics_service.dart';
import 'song_artwork.dart';

// ---------------------------------------------------------------------------
// Edit Song Dialog Launcher Helper
// ---------------------------------------------------------------------------

/// Opens the dark glassmorphic song metadata editor dialog.
void showEditSongDialog({required BuildContext context, required Song song}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (dialogContext) => EditSongDialog(song: song),
  );
}

// ---------------------------------------------------------------------------
// Dark Glassmorphic Edit Song Dialog
// ---------------------------------------------------------------------------

class EditSongDialog extends ConsumerStatefulWidget {
  const EditSongDialog({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<EditSongDialog> createState() => _EditSongDialogState();
}

class _EditSongDialogState extends ConsumerState<EditSongDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album ?? '');
  }

  @override
  void dispose() {
    // Strictly manage TextEditingController lifecycles in dispose only.
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  /// Automatically cleans title and artist tags using metadata cleaning regexes.
  void _autoCleanTags() {
    // Determine raw filename without path
    String filename = widget.song.filePath;
    final separatorIndex = filename.lastIndexOf(RegExp(r'[/\\]'));
    if (separatorIndex != -1) {
      filename = filename.substring(separatorIndex + 1);
    }

    final rawTitleToClean = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : filename;

    final cleaned = cleanSongMetadataHelper(
      rawTitle: rawTitleToClean,
      rawArtist: _artistController.text.trim(),
    );

    setState(() {
      _titleController.text = cleaned.title;
      if (cleaned.artist.isNotEmpty &&
          cleaned.artist.toLowerCase() != 'unknown' &&
          cleaned.artist.toLowerCase() != 'unknown artist') {
        _artistController.text = cleaned.artist;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.cyanAccent.withValues(alpha: 0.4)),
        ),
        content: const Text(
          'Tags cleaned from filename clutter',
          style: TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveMetadata() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          content: const Text('Title cannot be empty'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final finalArtist = artist.isEmpty ? 'Unknown Artist' : artist;
      final finalAlbum = album.isEmpty ? null : album;

      // 1. Update Drift database (marks isCustomEdited = true)
      await db.updateSongMetadata(
        songId: widget.song.id,
        title: title,
        artist: finalArtist,
        album: finalAlbum,
      );

      // 2. Refresh active queue and current track in PlayerController
      ref
          .read(playerControllerProvider.notifier)
          .updateTrackMetadata(
            songId: widget.song.id,
            title: title,
            artist: finalArtist,
            album: finalAlbum,
          );

      // 3. If lyrics are currently empty, trigger auto-fetch with new clean tags
      final updatedSong = await db.getSongById(widget.song.id);
      if (updatedSong != null &&
          (updatedSong.lyrics == null || updatedSong.lyrics!.trim().isEmpty)) {
        ref.read(lyricsControllerProvider.notifier).refetchLyrics(updatedSong);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1A2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.cyanAccent.withValues(alpha: 0.4),
              ),
            ),
            content: Text(
              'Updated "$title"',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to save metadata: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    String filename = widget.song.filePath;
    final separatorIndex = filename.lastIndexOf(RegExp(r'[/\\]'));
    if (separatorIndex != -1) {
      filename = filename.substring(separatorIndex + 1);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13111C).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cyanAccent.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.cyanAccent.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: AppColors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'EDIT TRACK TAGS',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // File preview info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    SongArtwork.fromSong(
                      widget.song,
                      size: 46,
                      borderRadius: BorderRadius.circular(10),
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filename,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Duration: ${formatDuration(widget.song.duration)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Auto-Clean Filename button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _autoCleanTags,
                  icon: const Icon(
                    Icons.auto_fix_high_rounded,
                    size: 16,
                    color: AppColors.cyanAccent,
                  ),
                  label: const Text(
                    'Auto-Clean Tags from Filename',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.cyanAccent.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              _EditTextField(
                label: 'Title',
                icon: Icons.music_note_rounded,
                controller: _titleController,
                hintText: 'Enter song title',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 12),

              // Artist Field
              _EditTextField(
                label: 'Artist',
                icon: Icons.person_rounded,
                controller: _artistController,
                hintText: 'Enter artist name',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 12),

              // Album Field
              _EditTextField(
                label: 'Album',
                icon: Icons.album_rounded,
                controller: _albumController,
                hintText: 'Enter album name (optional)',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 20),

              // Action buttons (Cancel / Save)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveMetadata,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyanAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditTextField extends StatelessWidget {
  const _EditTextField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hintText,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: AppColors.cyanAccent.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.cyanAccent,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
