package com.spideytech.spinora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

/**
 * Native Android Home Screen App Widget for Spinora Music.
 *
 * Displays currently playing song title, artist, and playback controls (Prev, Play/Pause, Next).
 * Dispatches playback actions to AudioService's MediaButtonReceiver and Flutter MethodChannel.
 */
class SpinoraAppWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.spideytech.spinora.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.spideytech.spinora.ACTION_NEXT"
        const val ACTION_PREV = "com.spideytech.spinora.ACTION_PREV"

        const val PREFS_NAME = "SpinoraWidgetPrefs"
        const val PREF_TITLE = "title"
        const val PREF_ARTIST = "artist"
        const val PREF_IS_PLAYING = "isPlaying"

        var onWidgetActionListener: ((String) -> Unit)? = null

        fun updateAllWidgets(
            context: Context,
            title: String?,
            artist: String?,
            isPlaying: Boolean
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString(PREF_TITLE, title ?: "Spinora Music")
                putString(PREF_ARTIST, artist ?: "Ready to play")
                putBoolean(PREF_IS_PLAYING, isPlaying)
                apply()
            }

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SpinoraAppWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (widgetId in allWidgetIds) {
                updateWidgetView(context, appWidgetManager, widgetId, title, artist, isPlaying)
            }
        }

        fun updateWidgetView(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            title: String?,
            artist: String?,
            isPlaying: Boolean
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_spinora)

            val displayTitle = if (!title.isNullOrBlank()) title else context.getString(R.string.widget_default_title)
            val displayArtist = if (!artist.isNullOrBlank()) artist else context.getString(R.string.widget_default_artist)

            views.setTextViewText(R.id.widget_title, displayTitle)
            views.setTextViewText(R.id.widget_artist, displayArtist)

            val playIcon = if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
            views.setImageViewResource(R.id.widget_btn_play_pause, playIcon)

            // Intent to open app when tapping widget body
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)

            // Play / Pause PendingIntent
            val playPauseIntent = Intent(context, SpinoraAppWidgetProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            val playPausePendingIntent = PendingIntent.getBroadcast(
                context,
                1,
                playPauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_play_pause, playPausePendingIntent)

            // Next PendingIntent
            val nextIntent = Intent(context, SpinoraAppWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context,
                2,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_next, nextPendingIntent)

            // Prev PendingIntent
            val prevIntent = Intent(context, SpinoraAppWidgetProvider::class.java).apply {
                action = ACTION_PREV
            }
            val prevPendingIntent = PendingIntent.getBroadcast(
                context,
                3,
                prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_prev, prevPendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val title = prefs.getString(PREF_TITLE, context.getString(R.string.widget_default_title))
        val artist = prefs.getString(PREF_ARTIST, context.getString(R.string.widget_default_artist))
        val isPlaying = prefs.getBoolean(PREF_IS_PLAYING, false)

        for (widgetId in appWidgetIds) {
            updateWidgetView(context, appWidgetManager, widgetId, title, artist, isPlaying)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        when (action) {
            ACTION_PLAY_PAUSE -> {
                onWidgetActionListener?.invoke("play_pause")
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            }
            ACTION_NEXT -> {
                onWidgetActionListener?.invoke("next")
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            }
            ACTION_PREV -> {
                onWidgetActionListener?.invoke("prev")
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            }
        }
    }

    private fun sendMediaKeyEvent(context: Context, keyCode: Int) {
        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        context.sendBroadcast(downIntent)
        context.sendBroadcast(upIntent)
    }
}
