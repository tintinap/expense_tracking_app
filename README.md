# DailySpend

A production-ready expense tracking mobile application built with Flutter.

## Tech Stack

- Flutter (latest)
- Provider (state management)
- Hive (local database)
- fl_chart (charts)
- pluto_grid (spreadsheet view)
- excel (XLSX export)
- Material 3 (Green/Teal theme)

## Setup

1. Ensure Flutter is installed: `flutter doctor`
2. If platform folders are incomplete, run: `flutter create .` (adds/updates android/, ios/ without overwriting lib/)
3. Get dependencies: `flutter pub get`
4. The Hive adapter for Expense is pre-generated in `lib/data/models/expense.g.dart`. To regenerate: `dart run build_runner build`
5. Run the app: `flutter run`

## Features

- **Dashboard**: Filter by Weekly/Fortnightly/Monthly/Yearly, pie chart by category, transaction list
- **Spreadsheet**: Pivot-style view with categories as rows, time periods as columns, frozen category column
- **Settings**: Theme (System/Light/Dark), Export to Excel (Raw Data + Matrix sheets), Share
