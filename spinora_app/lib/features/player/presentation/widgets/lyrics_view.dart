import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/glass_card.dart';
import '../../application/player_controller.dart';
import '../../domain/lrc_parser.dart';

// ---------------------------------------------------------------------------
// Live Glassmorphic Lyrics Card Widget
// ---------------------------------------------------------------------------

/// Displays a sleek dark glassmorphic lyrics card with auto-scrolling
/// synced lines, glowing active line typography, and tap-to-seek.
class LiveLyricsCard extends ConsumerStatefulWidget {
  const LiveLyricsCard({
    super.key,
    required this.track,
    required this.width,
    required this.height,
    required this.onClose,
  });

  final Track track;
  final double width;
  final double height;
  final VoidCallback onClose;

  @override
  ConsumerState<LiveLyricsCard> createState() => _LiveLyricsCardState();
}

class _LiveLyricsCardState extends ConsumerState<LiveLyricsCard> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollDebounce;

  static const double _lineEstimatedHeight = 44.0;

  @override
  void dispose() {
    _scrollController.dispose();
    _userScrollDebounce?.cancel();
    super.dispose();
  }

  void _scrollToIndex(int index, int totalLines) {
    if (_userIsScrolling || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = widget.height;
    final targetOffset = (index * _lineEstimatedHeight - (viewportHeight / 2) + (_lineEstimatedHeight / 2))
        .clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserScrollStart() {
    _userIsScrolling = true;
    _userScrollDebounce?.cancel();
    _userScrollDebounce = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _userIsScrolling = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(trackLyricsProvider(widget.track));
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withValues(
              alpha: playerState.isPlaying ? 0.25 : 0.10,
            ),
            blurRadius: 36,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GlassCard(
        width: widget.width,
        height: widget.height,
        borderRadius: BorderRadius.circular(32),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            // Header Bar: Lyrics Tag, Synced Badge, and Actions (Edit, Close)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyanAccent.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.lyrics_rounded,
                    size: 15,
                    color: AppColors.cyanAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LYRICS',
                  style: tt.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),

                // Synced / Plain format badge
                lyricsAsync.when(
                  data: (lyrics) {
                    if (lyrics.isEmpty) return const SizedBox.shrink();
                    final isSynced = lyrics.isSynced;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSynced
                            ? AppColors.cyanAccent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSynced
                              ? AppColors.cyanAccent.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        isSynced ? 'SYNCED' : 'PLAIN',
                        style: TextStyle(
                          color: isSynced ? AppColors.cyanAccent : Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),

                const Spacer(),

                // Edit / Paste Lyrics Button
                IconButton(
                  onPressed: () => _openEditDialog(context),
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                  tooltip: 'Edit / Paste Lyrics',
                  visualDensity: VisualDensity.compact,
                ),

                // Return to Artwork Card Button
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.photo_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Show Artwork',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 6),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 6),

            // Lyrics Body View
            Expanded(
              child: lyricsAsync.when(
                data: (lyrics) {
                  if (lyrics.isEmpty) {
                    return _NoLyricsPlaceholder(
                      onPastePressed: () => _openEditDialog(context),
                    );
                  }

                  final activeIndex = lyrics.isSynced
                      ? lyrics.activeIndexForPosition(playerState.position)
                      : -1;

                  // Trigger auto-scroll smoothly on active line advance
                  if (lyrics.isSynced &&
                      activeIndex != _lastActiveIndex &&
                      activeIndex >= 0) {
                    _lastActiveIndex = activeIndex;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToIndex(activeIndex, lyrics.lines.length);
                    });
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is UserScrollNotification) {
                        _onUserScrollStart();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      itemCount: lyrics.lines.length,
                      itemBuilder: (context, index) {
                        final line = lyrics.lines[index];
                        final isActive = index == activeIndex;

                        return InkWell(
                          onTap: line.isSynced
                              ? () => ref
                                  .read(playerControllerProvider.notifier)
                                  .seek(line.timestamp)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 6,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.cyanAccent.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isActive
                                          ? AppColors.cyanAccent
                                          : (lyrics.isSynced
                                              ? Colors.white.withValues(alpha: 0.45)
                                              : Colors.white.withValues(alpha: 0.85)),
                                      fontSize: isActive ? 17 : 14.5,
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      letterSpacing: isActive ? 0.2 : 0.0,
                                      height: 1.4,
                                      shadows: isActive
                                          ? [
                                              Shadow(
                                                color: AppColors.cyanAccent
                                                    .withValues(alpha: 0.7),
                                                blurRadius: 14,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                                if (line.isSynced && isActive) ...[
                                  Text(
                                    formatDuration(line.timestamp.inMilliseconds),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.cyanAccent
                                          .withValues(alpha: 0.8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.cyanAccent,
                      value: 0.75,
                    ),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load lyrics: $error',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditDialog(BuildContext context) async {
    final songId = widget.track.id.startsWith('local_')
        ? int.tryParse(widget.track.id.replaceFirst('local_', ''))
        : null;

    if (songId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lyrics editing is only supported for local library tracks.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final song = await db.getSongById(songId);

    if (context.mounted) {
      showEditLyricsDialog(
        context: context,
        songId: songId,
        songTitle: widget.track.title,
        initialLyrics: song?.lyrics,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Empty / No Lyrics Placeholder
// ---------------------------------------------------------------------------

class _NoLyricsPlaceholder extends StatelessWidget {
  const _NoLyricsPlaceholder({
    required this.onPastePressed,
  });

  final VoidCallback onPastePressed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 46,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No Lyrics Available',
              style: tt.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add synced (.lrc) or plain text lyrics to sing along with this track.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onPastePressed,
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 16,
              ),
              label: const Text(
                'Paste Lyrics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.cyanAccent.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Safe Edit & Paste Lyrics Dialog
// ---------------------------------------------------------------------------

/// Helper function to open the safe [EditLyricsDialog].
Future<void> showEditLyricsDialog({
  required BuildContext context,
  required int songId,
  required String songTitle,
  String? initialLyrics,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (dialogContext) => EditLyricsDialog(
      songId: songId,
      songTitle: songTitle,
      initialLyrics: initialLyrics,
    ),
  );
}

/// Fully lifecycle-safe [StatefulWidget] dialog for pasting or editing lyrics.
/// Disposes [TextEditingController] strictly in [dispose()] to prevent any inline
/// pop animation crashes.
class EditLyricsDialog extends ConsumerStatefulWidget {
  const EditLyricsDialog({
    super.key,
    required this.songId,
    required this.songTitle,
    this.initialLyrics,
  });

  final int songId;
  final String songTitle;
  final String? initialLyrics;

  @override
  ConsumerState<EditLyricsDialog> createState() => _EditLyricsDialogState();
}

class _EditLyricsDialogState extends ConsumerState<EditLyricsDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLyrics ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveLyrics() async {
    setState(() => _isSaving = true);
    final text = _controller.text.trim();
    final db = ref.read(appDatabaseProvider);

    await db.updateSongLyrics(
      widget.songId,
      text.isEmpty ? null : text,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.isEmpty ? 'Lyrics removed' : 'Lyrics saved successfully',
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: AppColors.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyanAccent.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: AppColors.cyanAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Lyrics',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.songTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste timestamped .lrc lines or plain text below:',
                style: tt.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                maxLines: 10,
                minLines: 5,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: '[00:12.50]First line of lyrics\n[00:16.80]Second line of lyrics',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
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
          ),
        ),
      ),
      actions: [
        if (widget.initialLyrics != null && widget.initialLyrics!.isNotEmpty) ...[
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    _controller.clear();
                    await _saveLyrics();
                  },
            child: const Text(
              'Clear',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveLyrics,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
