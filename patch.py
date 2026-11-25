import os
m='android/app/src/main/AndroidManifest.xml'; s=open(m,encoding='utf-8').read()
perms=''.join(f'<uses-permission android:name="android.permission.{p}"/>' for p in ['POST_NOTIFICATIONS','SCHEDULE_EXACT_ALARM','USE_EXACT_ALARM','RECEIVE_BOOT_COMPLETED','VIBRATE'])
rec='<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/><receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"><intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/><action android:name="android.intent.action.MY_PACKAGE_REPLACED"/><action android:name="android.intent.action.QUICKBOOT_POWERON"/><action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/></intent-filter></receiver>'
s=s.replace('<application',perms+'<application',1).replace('</application>',rec+'</application>',1)
open(m,'w',encoding='utf-8').write(s)
for g in ['android/app/build.gradle.kts','android/app/build.gradle']:
    if os.path.exists(g):
        t=open(g,encoding='utf-8').read(); k=g.endswith('.kts')
        t=t.replace('compileOptions {','compileOptions {\n        '+('isCoreLibraryDesugaringEnabled = true' if k else 'coreLibraryDesugaringEnabled true'),1)
        t+=('\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' if k else "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n")
        open(g,'w',encoding='utf-8').write(t)

# ---- home-screen widget ----
pkg = 'com.ahmed.schedule.schedule_app'
kd = 'android/app/src/main/kotlin/' + pkg.replace('.', '/')
os.makedirs(kd, exist_ok=True)
open(kd + '/ScheduleWidget.kt', 'w', encoding='utf-8').write("""package %s
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScheduleWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val now = System.currentTimeMillis()
        val f = SimpleDateFormat("h:mm a", Locale("ar"))
        var cur = "لا توجد مهمة الآن"
        var nxt = "—"
        var found = false
        (widgetData.getString("w_blocks", "") ?: "").lines().forEach { l ->
            val p = l.split("|")
            if (p.size >= 3) {
                val s = p[0].toLong()
                val e = p[1].toLong()
                if (s <= now && now < e) { cur = p[2] + " — حتى " + f.format(Date(e)) }
                else if (s > now && !found) { nxt = p[2] + " — " + f.format(Date(s)); found = true }
            }
        }
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget)
            v.setTextViewText(R.id.w_cur, cur)
            v.setTextViewText(R.id.w_next, "التالي: " + nxt)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
""" % pkg)
for d in ['android/app/src/main/res/layout', 'android/app/src/main/res/xml']:
    os.makedirs(d, exist_ok=True)
open('android/app/src/main/res/layout/widget.xml', 'w', encoding='utf-8').write("""<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:padding="14dp" android:background="#17352B" android:layoutDirection="rtl">
    <TextView android:id="@+id/w_cur" android:layout_width="match_parent" android:layout_height="wrap_content" android:textColor="#FFFFFF" android:textSize="16sp" android:textStyle="bold"/>
    <TextView android:id="@+id/w_next" android:layout_width="match_parent" android:layout_height="wrap_content" android:textColor="#B8D8C8" android:textSize="12sp" android:layout_marginTop="4dp"/>
</LinearLayout>
""")
open('android/app/src/main/res/xml/widget_info.xml', 'w', encoding='utf-8').write("""<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android" android:minWidth="250dp" android:minHeight="60dp" android:updatePeriodMillis="1800000" android:initialLayout="@layout/widget" android:resizeMode="horizontal|vertical" android:widgetCategory="home_screen"/>
""")
m = 'android/app/src/main/AndroidManifest.xml'
t = open(m, encoding='utf-8').read()
w = '<receiver android:name="%s.ScheduleWidget" android:exported="true"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter><meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_info"/></receiver>' % pkg
open(m, 'w', encoding='utf-8').write(t.replace('</application>', w + '</application>', 1))
