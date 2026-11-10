from pathlib import Path
import re
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
perms='''    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
'''
if 'android.permission.INTERNET' not in s:
    s=s.replace('<manifest ', '<manifest ', 1)
    pos=s.find('>', s.find('<manifest'))+1
    s=s[:pos]+'\n'+perms+s[pos:]
service='''        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
'''
if 'com.ryanheise.audioservice.AudioService' not in s:
    s=s.replace('</application>', service+'    </application>')
p.write_text(s)
