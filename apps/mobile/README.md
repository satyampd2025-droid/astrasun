# Atulyaa Mill phone app

Flutter app for floor staff: owner, sales, gate, lab, loading, drivers. Talks to ERPNext (with our `astrasun` app) over its REST API.

What it does today (Phase 1):
- Log in with the ERPNext user ID and password.
- Home screen shows "what to do now" for the user's mill role (see `lib/home/role_tasks.dart`).
- Hindi and English on every screen, switch with one tap; the choice is saved to the user's ERPNext profile.
- Voice input box (`lib/widgets/voice_text_field.dart`) for remarks and reasons, in Hindi or English.

Screens behind the buttons arrive phase by phase; until then they open a "coming soon" page.

## Run
```bash
flutter pub get
flutter test
flutter run                         # on an Android phone, enter the server address on the login screen
flutter build apk --release         # installable APK
flutter build web --base-href /assets/mobile-demo/   # browser preview served by ERPNext
```
Fonts (Noto Sans, Noto Sans Devanagari) are bundled under `fonts/` with their OFL licence.
