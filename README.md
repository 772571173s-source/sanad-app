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
3. Center manager signs in, completes center settings, and creates specialists, data entry users, or program entry users.
4. Data entry users add and update basic student data only.
5. Specialists create evaluations, plans, sessions, homework, and therapy reports.
6. Parents see only their child, homework, notes, rewards, and simplified progress.

## Parent Accounts

When a student is created, Sanad creates a parent account automatically:

- Email: `<parent-phone>@sanad.com`
- Temporary password: the parent phone number
- The password is stored as a hash only.
- Temporary credentials are shown once after creating the student, with copy and print actions.
- The parent is forced to change the temporary password on first login.
- Reusing the same parent phone/email for another student is blocked.

## Sessions

Sessions support a live therapy workflow:

- Pre-session context: latest evaluation, latest session, active plan goals, and a smart suggestion.
- Program engine selection: program, skill, and activity cards can be selected inside the session.
- Speech sessions: target letter, word position, training bank, attempts, correct/partial/wrong scoring, and error type.
- Sensory integration activities: structured performance scoring such as cannot perform, performs with help, or performs well.
- Sign-language sessions: choose signs from the sign library and score performance.
- Autosave stores a draft every 30 seconds during a running session.
- Homework can be sent directly from the session content.

## Program Engine

Sanad now includes a center-scoped therapy program engine:

```text
Program
  Sections
  Skills
  Activities
  Evaluation
  Homework
```

Center managers and program entry users can create and maintain therapy programs. Specialists can use these programs during sessions. The first built-in program templates are speech therapy and sensory integration, created only when the center chooses to create them.

## Sign Language

The sign library supports categories, image/video upload, levels, favorites, search, and safe media preview. It appears only when the selected student has a hearing/sign-language program or a sign-language plan.

## Metrics

The dashboard includes center-level analytics:

- Student count
- Session count
- Evaluation count
- Improvement rate
- Hardest letter
- Most used sign
- Completed homework count

## Roles

| Role | Scope |
| --- | --- |
| `sanadOwner` | All centers, center creation, center manager creation, support mode |
| `centerManager` | One center, center settings, staff, students, reports |
| `specialist` | Center students, evaluations, plans, sessions, homework, reports |
| `dataEntry` | Basic student entry only |
| `programEntry` | Center therapy programs, sections, skills, and activities |
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
- Audit logs record key create/update/delete/report/session operations.
- A notification structure is prepared for homework and report events.

## Production Notes

For a hosted production SaaS version, add server-side authentication, encrypted backup storage, remote sync, and signed report archives.
