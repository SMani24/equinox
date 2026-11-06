# Equinox (`equinox`)

> **Weighted Time Tracking & Work-Rest Equilibrium**  
> *An offline-first, cross-platform weighted balance application for Android, Linux, and Windows.*

---

## 🌓 Core Philosophy: Balance Through Weighting

Traditional time-trackers treat every hour identically: 1 hour of intense deep programming is logged the exact same way as 1 hour of mindless social media scrolling.

**Equinox introduces Weighted Time Tracking**:
1. **Start First, Categorize Later**: When you sit down to do something, tap **Start Timer** immediately. You don't have to decide what folder, project, or category it belongs to until you tap **Stop & Log**.
2. **Coefficients & Point Equilibrium**: Every activity has an assigned multiplier (`coefficient` $C_i$).
   - **Productive Work (+)** earns positive balance points.
   - **Rest & Leisure (-)** costs points.
   - **Neutral / Life (0.0)** tracks sleep, meals, and transit without shifting the work/rest score.
3. **100% Offline-First & Private**: Zero cloud servers, zero logins, zero internet permissions required in the release manifest. Your data resides securely on your device in SQLite.

---

## 📐 Mathematical Model

For any completed time entry $i$ with duration in hours $D_i = \frac{\text{duration\_seconds}_i}{3600}$ and snapshot coefficient $C_i$:

$$\text{Entry Score}_i = D_i \times C_i$$

For a given logical day $d$:
- **Gross Productive Score:**
  $$S_{\text{prod}}(d) = \sum_{i \in d, C_i > 0} D_i \times C_i$$
- **Gross Rest Cost:**
  $$S_{\text{rest}}(d) = \sum_{i \in d, C_i < 0} |D_i \times C_i|$$
- **Net Daily Balance:**
  $$\text{Net}(d) = \sum_{i \in d} D_i \times C_i = S_{\text{prod}}(d) - S_{\text{rest}}(d)$$

### Equilibrium Example
- **1 hour of Deep Work (`+1.0`)** = `+1.00 pts` (earned)
- **30 minutes of Gaming (`-2.0`)** = `0.5 × (-2.0) = -1.00 pts` (spent)
- **Net Balance** = `0.00 pts` (Exact Equilibrium achieved!)

### Historical Coefficient Snapshot Rule
When a session is logged, both the `activity_id` and a `coefficient_snapshot` are recorded. If you adjust an activity's weight from `-2.0` to `-3.0` in the future, your historical records remain intact by default, with an optional toggle to recalculate past entries if desired.

---

## 📱 Feature Overview

### 1. Hero Timer & Crash-Proof Engine
- **Crash-Proof State**: Stored in a single-row SQLite table (`active_timer`). If Android kills the background app, the timer recovers seamlessly upon restart using absolute timestamps (`start_time - accumulated_paused_ms`).
- **Tabular Figures Monospace Dial**: Oversized clock format (`00:00:00`) with ambient breathing glow.
- **Ongoing Notification**: Displays live chronometer status in the notification shade.
- **Top Equilibrium Pill**: Live today's score (`+1.50 pts`) and visual work-to-rest ratio bar.

### 2. Post-Stop Classification & Session Splitting
- **Live Score Previews**: Every activity card previews the exact score before you tap (e.g., *Deep Work (+1.5x) → +1.86 pts* vs *Gaming (-3.0x) → -3.72 pts*).
- **Session Splitting**: Forgot to stop your timer? Split a long session into work and rest segments with a tactile slider and live previews for both halves.
- **Manual Past Entry**: Quickly log forgotten sessions with backdated timestamps.

### 3. Analytics & Multi-Dimensional Heatmaps
- **GitHub-Style Calendar Heatmap**: 60-day visual intensity grid filterable by *Net Score*, *Productive Hours*, or *Rest Hours*, with interactive day drill-down.
- **24-Hour Rhythm Heatmap**: $7 \times 24$ (Day of Week $\times$ Hour of Day) matrix mapping when you work vs. when you rest.
- **Work vs. Rest Bar Chart (`fl_chart`)**: Stacked balance bars showing daily productive earnings, rest costs, and net scores.
- **Activity Donut Breakdown**: Proportional hour and point distribution by activity.

### 4. Activities & Coefficients Manager
- Curated color palette (12 vibrant themes) and 30+ Material symbols.
- Quick preset multipliers (`0.5x`, `1.0x`, `1.5x`, `2.0x`, `3.0x`, `5.0x`) + custom decimal input.
- Real-time plain-English explanation of scoring impact.

### 5. Multi-Device Sync & Data Portability
- **JSON Export / Import**: Schema versioned and UUID-keyed.
- **Smart UUID Merge**: Merge databases across Android and Desktop via Syncthing, local Wi-Fi transfer, or shared drive without primary key collisions.
- **CSV Export**: Full tabular export ready for spreadsheet analysis.
- **Custom Day Rollover Hour**: Set when a day turns over (e.g., `04:00 AM` for night owls).

---

## 🏗 Architecture & Stack

Equinox is organized with a feature-first architecture:

```text
equinox/
├── lib/
│   ├── main.dart                          # App entry point & initialization
│   ├── app.dart                           # Material 3 dark theme & navigation
│   ├── core/
│   │   ├── theme/                         # Deep Obsidian theme, colors, and icons
│   │   ├── utils/                         # ScoreCalculator, DateBoundary, DurationFormatter
│   │   ├── services/                      # NotificationService, BackupService (JSON/CSV)
│   │   └── providers/                     # Database and repository providers
│   ├── data/
│   │   ├── database/                      # Drift SQLite schema, migrations, seed data
│   │   └── repositories/                  # Activity, TimeEntry, and Timer repositories
│   └── features/
│       ├── timer/                         # Hero dial, classify sheet, split dialog
│       ├── analytics/                     # Heatmaps, rhythm grid, bar/donut charts
│       ├── activities/                    # Activity management, coefficient calculator
│       └── settings/                      # Target goals, day rollover, JSON/CSV sync
└── test/
    ├── score_calculator_test.dart         # Unit tests for scoring math & day rollover
    ├── timer_persistence_test.dart        # SQLite crash-proof active timer unit tests
    └── backup_merge_test.dart             # JSON export & smart UUID merge tests
```

### Core Technologies
- **Flutter (Dart 3.x)**: Material 3 dark-first UI.
- **Riverpod**: Reactive, testable state management.
- **Drift (SQLite)**: Strongly-typed persistence with reactive streams.
- **fl_chart**: GPU-accelerated balance and donut charts.
- **flutter_local_notifications**: Ongoing system chronometer notification.

---

## 🧪 Testing & Verification

Equinox includes comprehensive unit and widget tests covering:
- Mathematical scoring precision and gross/net equilibrium.
- Date boundary shifting for day rollover hours.
- Background timer persistence, pausing, and recovery.
- JSON backup export, import, and smart UUID merging.
- Widget smoke tests for navigation and controls.

Run the test suite:
```bash
flutter test
```

Static analysis verification:
```bash
flutter analyze
```

---

## 🚀 Building & Running

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/) (3.13+ / Dart 3.x)
- Android SDK or Linux desktop build tools

### Linux Desktop
```bash
# Install GTK 3 development libraries if not already present:
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev

# Run or build:
flutter run -d linux
flutter build linux
```

### Android
```bash
flutter run -d android
flutter build apk --release
```

---

## 📄 License
MIT License. 100% Free and Open Source.
