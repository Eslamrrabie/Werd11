"""يعدّل مشروع أندرويد المُولَّد تلقائياً ليدعم التنبيهات المجدولة."""
import pathlib
import re
import sys

app = pathlib.Path('android/app')
DEP = '2.1.4'

g, k = app / 'build.gradle', app / 'build.gradle.kts'
if g.exists():
    s = g.read_text(encoding='utf-8')
    if 'coreLibraryDesugaringEnabled' not in s:
        n = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', s, count=1)
        if n == s:
            sys.exit('compileOptions not found in build.gradle')
        n += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:%s'\n}\n" % DEP
        g.write_text(n, encoding='utf-8')
elif k.exists():
    s = k.read_text(encoding='utf-8')
    if 'isCoreLibraryDesugaringEnabled' not in s:
        n = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', s, count=1)
        if n == s:
            sys.exit('compileOptions not found in build.gradle.kts')
        n += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:%s")\n}\n' % DEP
        k.write_text(n, encoding='utf-8')
else:
    sys.exit('no app gradle file found')

m = app / 'src/main/AndroidManifest.xml'
t = m.read_text(encoding='utf-8')
if 'POST_NOTIFICATIONS' not in t:
    t = t.replace('<application',
                  '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
                  '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
                  '    <application', 1)
if 'ScheduledNotificationReceiver' not in t:
    t = t.replace('</application>', '''    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''', 1)
m.write_text(t, encoding='utf-8')
print('android patched')
