from pathlib import Path
# App label customization; flutter create supplies valid Android launcher resources.
manifest=Path('android/app/src/main/AndroidManifest.xml')
text=manifest.read_text()
text=text.replace('android:label="git_credit_tracker"', 'android:label="GIT Credit Tracker"')
text=text.replace('<application', '<application android:allowBackup="false"', 1)
manifest.write_text(text)
# Generate a blue G icon using vector-based Android XML for a reliable launcher icon.
drawable=Path('android/app/src/main/res/drawable')
drawable.mkdir(parents=True,exist_ok=True)
(drawable/'git_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
<item><shape android:shape="rectangle"><solid android:color="#1166D9"/><corners android:radius="16dp"/></shape></item>
<item android:gravity="center"><bitmap android:src="@android:drawable/ic_menu_save" android:gravity="center"/></item>
</layer-list>''')
# Keep the Flutter-generated PNG mipmaps as a platform-safe fallback.
