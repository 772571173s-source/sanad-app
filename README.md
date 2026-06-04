# Sanad

Sanad is a Flutter application for speech therapy and rehabilitation centers. It supports first-run setup, a system owner, multiple centers, center managers, specialists, data entry users, parent accounts, student files, sessions, evaluations, plans, homework, rewards, PDF reports, and database backup.

## First Run

Sanad does not create any default account or default center.

On the first launch, the app shows a setup screen where you create the system owner:

- Owner name
- Email
- Password
- Password confirmation

After creating the owner, sign in with that account. The system owner can then create centers and create a center manager for each center.

## Workflow

1. System owner creates the first center.
2. System owner creates a center manager for that center.
3. Center manager signs in, completes center settings, and creates specialists or data entry users.
4. Data entry users add and update basic student data only.
5. Specialists create evaluations, plans, sessions, homework, and therapy reports.
6. Parents see only their child, homework, notes, rewards, and simplified progress.

## Roles

| Role | Scope |
| --- | --- |
| `sanadOwner` | All centers, center creation, center manager creation, support mode |
| `centerManager` | One center, center settings, staff, students, reports |
| `specialist` | Center students, evaluations, plans, sessions, homework, reports |
| `dataEntry` | Basic student entry only |
| `parent` | Own child only |

## Run On Windows

```powershell
cd "C:\Users\Ali\Documents\Codex\2026-06-01\new-chat-2\outputs\sanad_app"
flutter pub get
flutter analyze
flutter run -d windows
```

## Run On Android

```powershell
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

## Security Notes

- No default users are seeded.
- No default password is stored.
- Passwords are stored as salted hashes.
- Parent passwords are generated during student creation, printed once for handover, and not stored as plain text.
- Role checks run inside the provider layer before write operations.
- Center-scoped data is loaded by `center_id`; parents are restricted to their own `student_id`.

## Production Notes

For a hosted production SaaS version, add server-side authentication, encrypted backup storage, remote sync, and signed report archives.
