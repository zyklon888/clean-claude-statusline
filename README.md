# clean-claude-statusline

A clean, simple [Claude Code](https://claude.com/claude-code) status line for **Windows / PowerShell** — no Node.js required.

It reads the session JSON that Claude Code pipes on stdin and prints a single, tidy line:

```
~/ProjectsGIT/myapp  main*  Opus 4.8  ctx 42% (84.0k tok)  5h 18% (3h 12m)  7d 64% (2d 4h)
```

Each segment is shown only when its data is available, so the line stays uncluttered.

## What it shows

| Segment | Example | Meaning |
| --- | --- | --- |
| Directory | `~/ProjectsGIT/myapp` | Current workspace dir, `~`-abbreviated, forward slashes |
| Git branch | `main*` | Current branch (or short commit); `*` means uncommitted changes |
| Model | `Opus 4.8` | Active model display name |
| Context | `ctx 42% (84.0k tok)` | Context-window usage and tokens in the window |
| 5-hour limit | `5h 18% (3h 12m)` | Rolling 5-hour usage % and time until reset |
| 7-day limit | `7d 64% (2d 4h)` | Weekly usage % and time until reset |

## Requirements

- Windows with **PowerShell 5.1+** (built in)
- [Claude Code](https://claude.com/claude-code)
- `git` on your `PATH` (optional — only needed for the branch segment)

## Installation

### Quick install

Download the script straight into your `.claude` folder (PowerShell):

```powershell
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://raw.githubusercontent.com/zyklon888/clean-claude-statusline/main/statusline-command.ps1" `
  -OutFile "$HOME\.claude\statusline-command.ps1"
```

Then add the `statusLine` block from step 2 below to your `settings.json` and restart Claude Code.

### Manual install

1. **Download** `statusline-command.ps1` from this repo and save it somewhere stable, e.g.:

   ```
   C:\Users\<you>\.claude\statusline-command.ps1
   ```

2. **Configure Claude Code** by adding a `statusLine` block to your `~/.claude/settings.json`
   (`C:\Users\<you>\.claude\settings.json`). Point the `-File` path at wherever you saved the script:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/<you>/.claude/statusline-command.ps1"
     }
   }
   ```

3. **Restart Claude Code** (or start a new session). The status line appears at the bottom.

> **Note:** `-ExecutionPolicy Bypass` applies only to this one invocation; it does not change your machine's PowerShell execution policy.

## How it works

Claude Code pipes a JSON object describing the current session to the status line command on
stdin. The script parses it with `ConvertFrom-Json` and assembles the output from these fields:

- `workspace.current_dir` / `cwd` — directory
- `model.display_name` — model name
- `context_window.used_percentage` / `total_input_tokens` — context usage
- `rate_limits.five_hour` / `rate_limits.seven_day` — usage limits and reset times

Git info is read by shelling out to `git` in the workspace directory. If any field is missing,
that segment is simply omitted.

## Customizing

The script is a single, commented PowerShell file. To change the order or drop a segment, edit
the corresponding numbered block in `statusline-command.ps1` and adjust what gets appended to the
`$parts` array. Segments are joined with two spaces at the end.

## License

[MIT](LICENSE)
