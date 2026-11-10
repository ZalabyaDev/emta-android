# Emta for Android

This repo turns the Emta web app (from the ZalabyaDev/Waqt repo) into an Android app.
GitHub builds it in the cloud: Actions tab -> "Build Emta APK" -> Run workflow.
When it finishes, download "emta-apk" from the run page and install it on your phone.

- App ID: com.zalabyadev.emta (never change this once the app is on Google Play)
- To update the app: update index.html in the Waqt repo, then run the workflow again.
- debug.keystore is only for test builds. Google Play uses a separate key.
