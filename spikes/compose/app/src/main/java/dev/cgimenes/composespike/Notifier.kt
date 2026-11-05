package dev.cgimenes.composespike

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

private const val CHANNEL_ID = "running"
private const val NOTIFICATION_ID = 100
private const val ACTION_STOP = "dev.cgimenes.composespike.STOP"
private const val ACTION_DISMISSED = "dev.cgimenes.composespike.DISMISSED"
private const val EXTRA_ACCOUNT = "account"
private const val MAX_ACTIONS = 3 // Android limit

/** Single ongoing notification for all running entries. */
object Notifier {
    /** Posts, updates or cancels the notification according to the stored running list. */
    fun sync(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val running = Store.running(ctx)
        if (running.isEmpty()) {
            nm.cancel(NOTIFICATION_ID)
            return
        }
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Running entries", NotificationManager.IMPORTANCE_LOW),
        )

        val open = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val dismissed = PendingIntent.getBroadcast(
            ctx, 1,
            Intent(ctx, NotificationReceiver::class.java).setAction(ACTION_DISMISSED),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = Notification.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentTitle(if (running.size == 1) running[0].account else "${running.size} running")
            .setContentText(running.joinToString { it.account })
            .setOngoing(true)
            .setShowWhen(true)
            .setWhen(running[0].start) // oldest entry
            .setUsesChronometer(true)
            .setContentIntent(open)
            .setDeleteIntent(dismissed)
            .setStyle(
                Notification.InboxStyle().also { style ->
                    running.forEach { style.addLine("${it.account} (since ${stamp(it.start).substring(11, 16)})") }
                },
            )

        running.take(MAX_ACTIONS).forEach { e ->
            val stop = PendingIntent.getBroadcast(
                ctx, e.account.hashCode(),
                Intent(ctx, NotificationReceiver::class.java)
                    .setAction(ACTION_STOP)
                    .putExtra(EXTRA_ACCOUNT, e.account),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            builder.addAction(
                Notification.Action.Builder(null, "Stop ${e.account.substringAfterLast(':')}", stop).build(),
            )
        }

        nm.notify(NOTIFICATION_ID, builder.build())
    }
}

/** Runs even when the app process is dead; no engine or isolate needed. */
class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                when (intent.action) {
                    ACTION_STOP -> Store.stopEntry(app, intent.getStringExtra(EXTRA_ACCOUNT)!!)
                    ACTION_DISMISSED -> Notifier.sync(app) // swiped away: bring it back
                }
            } finally {
                pending.finish()
                Handler(Looper.getMainLooper()).post { MainActivity.onExternalChange?.invoke() }
            }
        }
    }
}
