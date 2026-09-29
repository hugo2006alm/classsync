package app.classsync.classsync

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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

    companion object {
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

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.next_class_widget)
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(SLOTS, "[]") ?: "[]"
            val now = System.currentTimeMillis()
            var next: JSONObject? = null
            try {
                val slots = JSONArray(raw)
                for (index in 0 until slots.length()) {
                    val slot = slots.optJSONObject(index) ?: continue
                    val start = slot.optLong("start", 0)
                    if (start > now && start < now + FOUR_DAYS &&
                        (next == null || start < next.optLong("start"))) {
                        next = slot
                    }
                }
            } catch (_: Exception) {
                // Corrupt optional widget cache is treated as empty.
            }
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
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
