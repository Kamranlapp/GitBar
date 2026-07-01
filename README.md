# ProjectBar retest check new

ProjectBar is a tiny macOS menu bar app for running project commands without opening Terminal.

## Build

```bash
cd /Users/kam/Documents/Codex/2026-06-30/i-w/outputs/ProjectBar
chmod +x build_app.sh
./build_app.sh
```

The build script creates:

```text
/Users/kam/Documents/Codex/2026-06-30/i-w/outputs/ProjectBar/ProjectBar.app
```

## Behavior

- Clicking the menu bar icon opens both columns at once.
- The left column lists projects, sorted by most recently used.
- The most recently used project is selected by default.
- The right column runs actions for the selected project.
- Commands run in the background through `/bin/zsh -lc`.
- Terminal is not opened or controlled visually.

## Actions

- `Status`: `git status --short --branch`
- `Pull`: `git pull --ff-only`
- `Push`: `git push`
- `Start LH`: runs the configured dev command, default `npm run dev`
- `Stop LH`: terminates the started dev process
- `Open Git`: opens the configured repository URL
- `Open LH`: opens the configured localhost URL, default `http://localhost:3000`
