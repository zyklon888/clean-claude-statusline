#!/usr/bin/env pwsh
# Claude Code status line. Reads session JSON on stdin, prints a single line:
#   <dir>  <branch*>  <model>  ctx <pct>%
# Designed for Windows PowerShell 5.1 (no node required).

$ErrorActionPreference = 'SilentlyContinue'

# --- read session JSON from stdin ---
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$parts = @()

# 1) directory (workspace.current_dir, fallback cwd), ~-abbreviated, forward slashes
$dir = $null
if ($j.workspace -and $j.workspace.current_dir) { $dir = $j.workspace.current_dir }
elseif ($j.cwd) { $dir = $j.cwd }
if ($dir) {
    $dirN  = ($dir -replace '\\','/')
    $homeN = ($HOME -replace '\\','/')
    if ($homeN -and $dirN.ToLower().StartsWith($homeN.ToLower())) {
        $dirN = '~' + $dirN.Substring($homeN.Length)
    }
    $parts += $dirN
}

# 2) git branch + dirty marker (only if inside a repo)
if ($dir) {
    $branch = (& git -C "$dir" symbolic-ref --short HEAD 2>$null)
    if (-not $branch) { $branch = (& git -C "$dir" rev-parse --short HEAD 2>$null) }
    if ($branch) {
        $status = (& git -C "$dir" status --porcelain 2>$null)
        if ($status) { $branch = "$branch*" }
        $parts += $branch
    }
}

# 3) model display name
if ($j.model -and $j.model.display_name) { $parts += $j.model.display_name }

# 4) context window usage: percentage + tokens-in-window (omit cleanly when not yet available)
function Format-Tokens([double]$n) {
    if ($n -ge 1000000) { return ("{0:0.0}M" -f ($n / 1000000)) }
    if ($n -ge 1000)    { return ("{0:0.0}k" -f ($n / 1000)) }
    return ([int]$n).ToString()
}
if ($j.context_window) {
    $cw = $j.context_window
    $pct = $cw.used_percentage
    $tok = $cw.total_input_tokens
    $seg = $null
    if ($null -ne $pct) { $seg = ("ctx {0}%" -f [int]$pct) }
    if ($null -ne $tok -and [double]$tok -gt 0) {
        $tokStr = "$(Format-Tokens([double]$tok)) tok"
        if ($seg) { $seg = "$seg ($tokStr)" } else { $seg = $tokStr }
    }
    if ($seg) { $parts += $seg }
}

# 5) rate limits: 5h (hourly) and 7d (weekly) usage % + time-to-reset.
#    Reads .rate_limits.{five_hour,seven_day} that Claude Code pipes on stdin;
#    each segment is omitted cleanly when the data isn't present.
function Format-Reset($resetVal) {
    if ($null -eq $resetVal -or "$resetVal" -eq '') { return $null }
    $resetTime = $null
    $num = 0.0
    if ([double]::TryParse("$resetVal", [ref]$num) -and $num -gt 0) {
        if ($num -gt 1e11) { $num = $num / 1000 }   # epoch ms -> s
        try { $resetTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$num).LocalDateTime } catch { return $null }
    } else {
        try { $resetTime = [datetime]::Parse("$resetVal") } catch { return $null }
    }
    $rem  = [int][Math]::Max(0, ($resetTime - (Get-Date)).TotalSeconds)
    $days = [int]($rem / 86400)
    $hrs  = [int](($rem % 86400) / 3600)
    $mins = [int](($rem % 3600) / 60)
    if     ($days -gt 0) { return ("{0}d {1}h" -f $days, $hrs) }
    elseif ($hrs  -gt 0) { return ("{0}h {1}m" -f $hrs, $mins) }
    else                 { return ("{0}m" -f $mins) }
}
function Get-LimitSegment($label, $node) {
    if (-not $node) { return $null }
    $pct = $node.used_percentage
    if ($null -eq $pct) { return $null }
    $seg = ("{0} {1}%" -f $label, [int]$pct)
    $reset = Format-Reset $node.resets_at
    if ($reset) { $seg = "$seg ($reset)" }
    return $seg
}
if ($j.rate_limits) {
    $s5 = Get-LimitSegment '5h' $j.rate_limits.five_hour
    if ($s5) { $parts += $s5 }
    $s7 = Get-LimitSegment '7d' $j.rate_limits.seven_day
    if ($s7) { $parts += $s7 }
}

[Console]::Out.Write(($parts -join '  '))
