package app.classsync.classsync

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class NextClassWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            REFRESH -> refreshAll(context)
            CYCLE -> {
                val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                val manager = AppWidgetManager.getInstance(context)
                if (id in manager.getAppWidgetIds(ComponentName(context, javaClass))) {
                    update(context, manager, id, advance = true)
                }
            }
        }
    }

    companion object {
        private const val REFRESH = "app.classsync.classsync.WIDGET_REFRESH"
        private const val CYCLE = "app.classsync.classsync.WIDGET_CYCLE"
        const val PREFS = "classsync_next_class_widget"
        const val SLOTS = "slots"
        private const val FOUR_DAYS = 4L * 24 * 60 * 60 * 1000

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, NextClassWidgetProvider::class.java),
            )
            ids.forEach { update(context, manager, it) }
        }

        private fun broadcast(context: Context, action: String, id: Int): PendingIntent {
            val intent = Intent(context, NextClassWidgetProvider::class.java)
                .setAction(action)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            return PendingIntent.getBroadcast(context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int, advance: Boolean = false) {
            val views = RemoteViews(context.packageName, R.layout.next_class_widget)
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(SLOTS, "[]") ?: "[]"
            val now = System.currentTimeMillis()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val available = mutableListOf<JSONObject>()
            try {
                val slots = JSONArray(raw)
                for (index in 0 until slots.length()) {
                    val slot = slots.optJSONObject(index) ?: continue
                    val start = slot.optLong("start", 0)
                    val end = slot.optLong("end", 0)
                    if (end > start && end > now && start < now + FOUR_DAYS) {
                        available.add(slot)
                    }
                }
            } catch (_: org.json.JSONException) {
                // Corrupt optional widget cache is treated as empty.
            }
            available.sortBy { it.optLong("start") }
            val current = available.takeWhile { it.optLong("start") <= now }
            val upcoming = available.getOrNull(current.size)
            val choices = current + listOfNotNull(upcoming)
            val key = "selection_$id"
            val saved = prefs.getString(key, null)
            val selected = choices.indexOfFirst { it.toString() == saved }.coerceAtLeast(0)
            val next = if (advance && choices.isNotEmpty()) {
                choices[(selected + 1) % choices.size].also {
                    prefs.edit().putString(key, it.toString()).apply()
                }
            } else {
                if (saved != null && choices.none { it.toString() == saved }) {
                    prefs.edit().remove(key).apply()
                }
                choices.getOrNull(selected)
            }
            val boundary = (current.map { it.optLong("end") } +
                listOfNotNull(upcoming?.optLong("start"))).minOrNull()
            val refresh = broadcast(context, REFRESH, 0)
            val alarms = context.getSystemService(AlarmManager::class.java)
            if (boundary == null) alarms.cancel(refresh)
            else alarms.set(AlarmManager.RTC, boundary, refresh)

            views.setViewVisibility(R.id.widget_cycle, if (choices.size > 1) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.widget_cycle, broadcast(context, CYCLE, id))
            views.setTextViewText(R.id.widget_label,
                if (next != null && next.optLong("start") <= now) "Current class" else "Next class")
            if (next == null) {
                views.setTextViewText(R.id.widget_subject, "No class in next four days")
                views.setTextViewText(R.id.widget_time, "Open ClassSync to refresh your timetable")
                views.setTextViewText(R.id.widget_details, "")
            } else {
                val start = Date(next.optLong("start"))
                val end = Date(next.optLong("end"))
                val date = SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(start)
                val time = SimpleDateFormat("HH:mm", Locale.getDefault())
                val details = listOfNotNull(
                    next.optString("type").takeIf { it.isNotBlank() },
                    next.optString("class").takeIf { it.isNotBlank() },
                    next.optString("room").takeIf { it.isNotBlank() }?.let { "Room $it" },
                    next.optString("teacher").takeIf { it.isNotBlank() }?.let { "Teacher $it" },
                ).joinToString(" · ")
                views.setTextViewText(R.id.widget_subject, next.optString("subject"))
                views.setTextViewText(R.id.widget_time,
                    "$date · ${time.format(start)}–${time.format(end)}")
                views.setTextViewText(R.id.widget_details, details)
            }
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("classsync://timetable/academic?section=0"),
                context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
