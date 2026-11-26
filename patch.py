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

