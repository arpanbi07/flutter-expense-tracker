# Pennywise — Flutter Expense Tracker upgrade

## Included files
- `main.dart`: colorful dashboard, activity, insights, budget page, add/edit expense form.
- `db_helper.dart`: keeps the existing `transactions` schema, adds update support, and migrates the SQLite database to version 2 with a separate settings table for the monthly budget. Existing transaction rows are retained.
- `transaction_model.dart`: compatible five-field model with a `copyWith` helper.

## Setup
1. Back up your project before replacing files.
2. Replace the three matching files in `lib/` with these versions.
3. In your existing `pubspec.yaml`, ensure these dependencies are present (keep any other dependencies your app uses):

```yaml
dependencies:
  flutter:
    sdk: flutter
  intl: ^0.19.0
  path: ^1.9.0
  sqflite: ^2.3.3+1
```

4. Run:

```bash
flutter pub get
flutter analyze
flutter run
```

Use versions compatible with your installed Flutter SDK if pub resolves newer versions. `sqflite` is for supported mobile/desktop platforms; the current `kIsWeb` in-memory fallback lets the app run on web without SQLite but does not persist data after a reload. For native platforms, the database upgrades from version 1 to 2 by creating a separate `app_settings` table; it does not recreate or delete the existing transactions table.

## Notes / limitations
- Existing transaction fields and the date format `dd MMM yyyy` are retained.
- The monthly budget is saved on native platforms. The web fallback is session-only memory storage, matching the original project's preview approach.
- “Undo” restores a deleted expense as a new row, so its database ID may change.
- Weekly chart groups expenses from the current date and previous six calendar days; category breakdowns use the current month.
- This is a local expense tracker, not a bank-connected or financial-advice app.
