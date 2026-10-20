package com.spideytech.spinora

import android.content.ContentUris
import android.net.Uri
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.spideytech.spinora/media_store"
    private val WIDGET_CHANNEL = "com.spideytech.spinora/widget"
    private var widgetMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "querySongs") {
                try {
                    val songs = queryAudioMediaStore()
                    result.success(songs)
                } catch (e: Exception) {
                    result.error("MEDIA_STORE_ERROR", e.localizedMessage, null)
                }
            } else if (call.method == "getArtwork") {
                val songId = call.argument<Number>("songId")?.toLong()
                val filePath = call.argument<String>("filePath")
                val uriStr = call.argument<String>("uri")
                try {
                    val bytes = getSongArtwork(songId, filePath, uriStr)
                    result.success(bytes)
                } catch (e: Exception) {
                    result.success(null)
                }
            } else if (call.method == "shareFile") {
                val filePath = call.argument<String>("filePath")
                val title = call.argument<String>("title") ?: "Share Spinora Backup"
                try {
                    if (filePath != null) {
                        val file = java.io.File(filePath)
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this@MainActivity,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = "application/octet-stream"
                            putExtra(android.content.Intent.EXTRA_STREAM, uri)
                            putExtra(android.content.Intent.EXTRA_SUBJECT, title)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(android.content.Intent.createChooser(intent, title))
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "File path was null", null)
                    }
                } catch (e: Exception) {
                    try {
                        val file = if (filePath != null) java.io.File(filePath) else null
                        val text = if (file != null && file.exists()) file.readText() else ""
                        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(android.content.Intent.EXTRA_TEXT, text)
                            putExtra(android.content.Intent.EXTRA_SUBJECT, title)
                        }
                        startActivity(android.content.Intent.createChooser(intent, title))
                        result.success(true)
                    } catch (e2: Exception) {
                        result.error("SHARE_ERROR", e2.localizedMessage, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }

        widgetMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    SpinoraAppWidgetProvider.updateAllWidgets(this@MainActivity, title, artist, isPlaying)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
        }

        // Bridge native widget button taps into Flutter PlayerController if running
        SpinoraAppWidgetProvider.onWidgetActionListener = { action ->
            runOnUiThread {
                widgetMethodChannel?.invokeMethod("onWidgetAction", action)
            }
        }
    }

    override fun onDestroy() {
        SpinoraAppWidgetProvider.onWidgetActionListener = null
        widgetMethodChannel = null
        super.onDestroy()
    }

    private fun getSongArtwork(songId: Long?, filePath: String?, uriStr: String?): ByteArray? {
        if (!filePath.isNullOrEmpty()) {
            var retriever: android.media.MediaMetadataRetriever? = null
            try {
                retriever = android.media.MediaMetadataRetriever()
                retriever.setDataSource(filePath)
                val picture = retriever.embeddedPicture
                if (picture != null && picture.isNotEmpty()) {
                    return picture
                }
            } catch (_: Exception) {
            } finally {
                try {
                    retriever?.release()
                } catch (_: Exception) {}
            }
        }

        if (!uriStr.isNullOrEmpty() && uriStr.startsWith("content://")) {
            try {
                contentResolver.openInputStream(Uri.parse(uriStr))?.use { input ->
                    val bytes = input.readBytes()
                    if (bytes.isNotEmpty()) return bytes
                }
            } catch (_: Exception) {}
        }

        if (songId != null && songId >= 0) {
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
                    val bitmap = contentResolver.loadThumbnail(contentUri, android.util.Size(512, 512), null)
                    val stream = java.io.ByteArrayOutputStream()
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, stream)
                    val bytes = stream.toByteArray()
                    if (bytes.isNotEmpty()) return bytes
                } else {
                    val artBaseUri = Uri.parse("content://media/external/audio/albumart")
                    val albumArtUri = ContentUris.withAppendedId(artBaseUri, songId)
                    contentResolver.openInputStream(albumArtUri)?.use { input ->
                        val bytes = input.readBytes()
                        if (bytes.isNotEmpty()) return bytes
                    }
                }
            } catch (_: Exception) {}
        }

        return null
    }

    private fun queryAudioMediaStore(): List<Map<String, Any?>> {
        val songList = mutableListOf<Map<String, Any?>>()
        val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.ALBUM_ID
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        contentResolver.query(uri, projection, selection, null, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)

            val artBaseUri = Uri.parse("content://media/external/audio/albumart")

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val title = cursor.getString(titleCol) ?: "Unknown"
                val artist = cursor.getString(artistCol) ?: "Unknown Artist"
                val album = cursor.getString(albumCol)
                val duration = cursor.getLong(durationCol)
                val data = cursor.getString(dataCol) ?: ""
                val albumId = cursor.getLong(albumIdCol)
                val albumArtUri = if (albumId >= 0) ContentUris.withAppendedId(artBaseUri, albumId).toString() else null

                songList.add(
                    mapOf(
                        "id" to id,
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "duration" to duration.toInt(),
                        "filePath" to data,
                        "albumArtPath" to albumArtUri
                    )
                )
            }
        }
        return songList
    }
}
