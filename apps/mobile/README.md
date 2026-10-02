# Atulyaa Mill phone app

Flutter app for floor staff: owner, sales, gate, lab, loading, drivers. Talks to ERPNext (with our `astrasun` app) over its REST API.

What it does today (Phase 1):
- Log in with the ERPNext user ID and password.
- Home screen shows "what to do now" for the user's mill role (see `lib/home/role_tasks.dart`).
- Hindi and English on every screen, switch with one tap; the choice is saved to the user's ERPNext profile.
- Voice input box (`lib/widgets/voice_text_field.dart`) for remarks and reasons, in Hindi or English.

Screens behind the buttons arrive phase by phase; until then they open a "coming soon" page.
**Try demo** on the login screen opens the app as any role with sample data and no server.

## Preview APK
Every push that touches `apps/mobile` builds an APK (`.github/workflows/android-preview.yml`) and puts it at
https://github.com/satyampd2025-droid/astrasun/releases/download/app-preview/atulyaa-mill.apk
Set the repository variable `MILL_SERVER_URL` once the mill server exists; until then the APK offers only the demo.

## Run
```bash
flutter pub get
flutter test
flutter run                         # developer build: asks for the server address
flutter build apk --release         # installable APK
flutter build web --base-href /assets/mobile-demo/   # browser preview served by ERPNext
```
Release builds for staff carry the mill server address, so nobody types it:
```bash
flutter build apk --release --dart-define=SERVER_URL=https://<mill-server>
```
Fonts (Noto Sans, Noto Sans Devanagari) are bundled under `fonts/` with their OFL licence.
