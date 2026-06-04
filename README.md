# Sanad MVP

Sanad is a Flutter MVP for speech therapy and rehabilitation centers. It supports a SaaS owner account, multiple centers, center admins, specialists, parent accounts, student files, speech sessions, articulation evaluations, home exercises, rewards, PDF reports, and database backup.

## Requirements

- Flutter SDK
- Windows Developer Mode enabled for desktop plugins
- Android Studio / Android SDK for Android builds

## Run On Windows

```powershell
cd "C:\Users\Ali\Documents\Codex\2026-06-01\new-chat-2\outputs\sanad_app"
flutter pub get
flutter run -d windows
```

## Run On Android

```powershell
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

## Demo Accounts

These accounts are for local testing only. The app forces password change after first login.

| Role | Email | Password |
| --- | --- | --- |
| SaaS Owner | `owner@sanad.local` | `123456` |
| Center Admin | `admin@sanad.local` | `123456` |
| Specialist | `specialist@sanad.local` | `123456` |

Parent accounts are created automatically when adding a student. The password is shown in the printable credentials sheet and is stored as a hash for login.

## Main Features

- Architecture: `models`, `services`, `repositories`, `providers`, `screens`, `widgets`.
- SQLite using `sqflite_common_ffi` on desktop and `sqflite` on mobile.
- Migrations with versioned schema upgrades.
- Password hashing with salted SHA-256 hashes.
- Real role checks before write operations.
- SaaS owner role for center management and support mode.
- Center settings: name, logo, address, phone, manager.
- Staff and manager account management.
- Student management with soft delete.
- Formal student profile and visit/session history.
- Speech sessions linked to training plans.
- Articulation evaluation with Arabic letters, position, error type, severity, and recommendations.
- PDF reports: session, monthly, quarterly, final.
- Parent area with homework, parent notes, audio upload path, stars, and rewards.
- Backup export/import for the local database.

## Notes

- This is an MVP, not the final production security model.
- For production, replace local password auth with a server-backed identity system, audit logs, encrypted backups, and signed report storage.
- Run `flutter analyze` before packaging for release.
