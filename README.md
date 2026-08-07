# Golder Dragon Cage X Executive – Flutter

Flutter version ng **Golder Dragon Cage X Executive** dashboard (convert mula sa React/Vite app).

## Setup

1. **May Flutter SDK na naka-install**  
   - [Install Flutter](https://docs.flutter.dev/get-started/install)

2. **Generate platform folders** (kung wala pa):
   ```bash
   cd flutter_app
   flutter create . --project-name appcage_flutter
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run**
   ```bash
   flutter run
   ```
   Pwede ring: `flutter run -d chrome` (web) o `flutter run -d windows`.

## Structure

- `lib/main.dart` – Entry point
- `lib/screens/` – Real-Time, Daily Settlement, Monthly, Marker, Ranking
- `lib/widgets/` – StatCard, DrawerPanel
- `lib/models/types.dart` – Data models
- `lib/constants/mock_data.dart` – Mock data
- `lib/theme/app_theme.dart` – Dark theme, cyan/emerald/rose accents

## Features

- **Real-Time** – Stat cards (chips, cash, guest balance, junket) + ongoing games table
- **Daily** – Metrics + charts (games & win/loss, trend, commission, expenses) via `fl_chart`
- **Monthly** – Win/loss, commission, expenses, rolling + casino integration progress
- **Marker** – Guest markers, balance/limit, utilization %
- **Ranking** – Guest & agent ranking with wins/losses/rolling
- Sidebar (desktop) at bottom nav (mobile)
- Notification at profile drawer (right-side panel)

Dependencies: `flutter`, `fl_chart`, `intl`.
