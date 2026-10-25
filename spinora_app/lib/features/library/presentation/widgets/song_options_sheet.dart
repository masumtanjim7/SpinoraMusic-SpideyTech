import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../player/application/player_controller.dart';
import 'edit_song_dialog.dart';
import 'song_artwork.dart';

/// Shows the glassmorphic song options sheet with options to "Play Next",
/// "Add to Playlist", and "Toggle Favorite".
void showSongOptionsSheet({required BuildContext context, required Song song}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _SongOptionsSheet(song: song, parentContext: context),
  );
}

class _SongOptionsSheet extends ConsumerWidget {
  const _SongOptionsSheet({required this.song, required this.parentContext});

  final Song song;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : const Color(0xFF13111C).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag pill handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Song Header Info
            Row(
              children: [
                SongArtwork.fromSong(
                  song,
                  size: 52,
                  borderRadius: BorderRadius.circular(12),
                  iconSize: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          color: isLight
                              ? const Color(0xFF0F111A)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${song.artist}${song.album != null ? ' • ${song.album}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: isLight
                              ? const Color(0xFF5C6275)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Divider(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.08),
              height: 1,
            ),
            const SizedBox(height: 8),

            // Option 1: Play Next
            _SheetActionTile(
              icon: Icons.playlist_play_rounded,
              iconColor: AppColors.cyanAccent,
              title: 'Play Next',
              subtitle: 'Add as the next track in the current queue',
              isLight: isLight,
              onTap: () {
                Navigator.of(context).pop();
                ref.read(playerControllerProvider.notifier).playSongNext(song);
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: isLight
                          ? Colors.white
                          : const Color(0xFF1E1A2E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.cyanAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      content: Text(
                        'Playing next: "${song.title}"',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF0F111A)
                              : Colors.white,
                        ),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // Option 2: Add to Playlist
            _SheetActionTile(
              icon: Icons.playlist_add_rounded,
              iconColor: AppColors.purpleAccent,
              title: 'Add to Playlist',
              subtitle: 'Select or create a custom playlist',
              isLight: isLight,
              onTap: () {
                Navigator.of(context).pop();
                if (parentContext.mounted) {
                  showAddToPlaylistSheet(context: parentContext, song: song);
                }
              },
            ),

            // Option 3: Toggle Favorite
            _SheetActionTile(
              icon: song.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: Colors.pinkAccent,
              title: song.isFavorite
                  ? 'Remove from Favorites'
                  : 'Add to Favorites',
              subtitle: song.isFavorite
                  ? 'Remove from your starred tracks'
                  : 'Save to your favorites collection',
              isLight: isLight,
              onTap: () async {
                Navigator.of(context).pop();
                final db = ref.read(appDatabaseProvider);
                await (db.update(db.songs)..where((s) => s.id.equals(song.id)))
                    .write(SongsCompanion(isFavorite: Value(!song.isFavorite)));
              },
            ),

            // Option 4: Edit Tags
            _SheetActionTile(
              icon: Icons.edit_note_rounded,
              iconColor: AppColors.cyanAccent,
              title: 'Edit Tags',
              subtitle: 'Clean up song title, artist, or album',
              isLight: isLight,
              onTap: () {
                Navigator.of(context).pop();
                if (parentContext.mounted) {
                  showEditSongDialog(context: parentContext, song: song);
                }
              },
            ),

            // Option 5: Hide from Library
            _SheetActionTile(
              icon: Icons.visibility_off_rounded,
              iconColor: Colors.amberAccent,
              title: 'Hide from Library',
              subtitle: 'Hide ringtone, voice note or unwanted clip',
              isLight: isLight,
              onTap: () async {
                Navigator.of(context).pop();
                final db = ref.read(appDatabaseProvider);
                await db.setSongHidden(songId: song.id, isHidden: true);
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: isLight
                          ? Colors.white
                          : const Color(0xFF1E1A2E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.amberAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      content: Text(
                        'Hidden "${song.title}" from library',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF0F111A)
                              : Colors.white,
                        ),
                      ),
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: AppColors.cyanAccent,
                        onPressed: () async {
                          await db.setSongHidden(
                            songId: song.id,
                            isHidden: false,
                          );
                        },
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLight = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLight ? const Color(0xFF0F111A) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isLight
                ? const Color(0xFF5C6275)
                : Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Displays the "Add to Playlist" sheet where the user can pick a playlist
/// or create a new one.
void showAddToPlaylistSheet({
  required BuildContext context,
  required Song song,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _AddToPlaylistModal(song: song, parentContext: context),
  );
}

class _AddToPlaylistModal extends ConsumerWidget {
  const _AddToPlaylistModal({required this.song, required this.parentContext});

  final Song song;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(allPlaylistsStreamProvider);
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : const Color(0xFF13111C).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add to Playlist',
                  style: tt.titleMedium?.copyWith(
                    color: isLight ? const Color(0xFF0F111A) : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (parentContext.mounted) {
                      showCreatePlaylistDialog(
                        context: parentContext,
                        ref: ref,
                        songIdToInsert: song.id,
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Playlist'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Flexible(
              child: playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.queue_music_rounded,
                              size: 44,
                              color: isLight
                                  ? const Color(0xFF8E95A8)
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Playlists Found',
                              style: tt.titleSmall?.copyWith(
                                color: isLight
                                    ? const Color(0xFF0F111A)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap "+ New Playlist" to create your first playlist.',
                              style: tt.bodySmall?.copyWith(
                                color: isLight
                                    ? const Color(0xFF5C6275)
                                    : Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    separatorBuilder: (context, index) => Divider(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.purpleGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF0F111A)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: isLight ? Colors.black38 : Colors.white38,
                          size: 14,
                        ),
                        onTap: () async {
                          final db = ref.read(appDatabaseProvider);
                          await db.addSongToPlaylist(
                            playlistId: playlist.id,
                            songId: song.id,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          if (parentContext.mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF1E1A2E),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: AppColors.cyanAccent.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                content: Text(
                                  'Added "${song.title}" to ${playlist.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: AppColors.purpleAccent,
                    ),
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.redAccent),
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

/// Standalone dialog widget that owns its [TextEditingController] in [State]
/// and safely disposes it in [dispose] only after the dialog route has finished unmounting.
class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF181528),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.purpleAccent.withValues(alpha: 0.4)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.purpleAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_to_photos_rounded,
              color: AppColors.cyanAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'New Playlist',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        cursorColor: AppColors.cyanAccent,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Enter playlist title...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cyanAccent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purpleAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Displays a glassmorphic dialog to create a new custom playlist.
Future<int?> showCreatePlaylistDialog({
  required BuildContext context,
  required WidgetRef ref,
  int? songIdToInsert,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => const CreatePlaylistDialog(),
  );

  if (name == null || name.isEmpty) return null;

  final db = ref.read(appDatabaseProvider);
  final newId = await db.createPlaylist(name);

  if (songIdToInsert != null) {
    await db.addSongToPlaylist(playlistId: newId, songId: songIdToInsert);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created playlist "$name"'),
        backgroundColor: const Color(0xFF181528),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  return newId;
}
