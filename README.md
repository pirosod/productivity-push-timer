# Productivity Push Timer

A small Godot 4.6 productivity timer that logs sessions, tracks daily totals (days start at 3:00 AM Adelaide time), and shows a weekly chart with goal bands.

## Features

- Push button to start/stop productivity sessions (white idle / black active UI)
- Daily session log with running totals
- 7-day productivity chart with clickable day labels
- Idle reminders with sound and popup (20-minute interval)
- Snooze for idle alerts
- JSON persistence in `Productivity data/` (daily archives in `Productivity data/Archive/`)

## Requirements

- [Godot 4.6.1](https://godotengine.org/) (or compatible 4.6.x)

## Run

1. Open the project in Godot (`project.godot`)
2. Press Play, or open `scenes/main.tscn` and run the scene

## Data

- Live log: `Productivity data/productivity.json`
- Daily archives: `Productivity data/Archive/`

User productivity data is not committed to git (see `.gitignore`).

## Test shortcut

Press **P** while the app is focused to trigger the idle alert sound and popup.

## Git and GitHub

- Repo: `main` branch, commits use version titles (e.g. `v0.1 First implementation`).
- After GitHub CLI login, create/push with:

```powershell
cd "z:\IonStudios\Godot\Productivity push timer"
gh auth login -h github.com -p https -w
gh repo create productivity-push-timer --public --source=. --remote=origin --push
```

Replace `productivity-push-timer` if you use a different repo name on GitHub.
