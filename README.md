# st_log

Strata's logging system. One shared import in every resource gives you
colored, structured logging with operational sinks already wired in.

**What you get:**

- Colored, level-tagged console output with auto-capitalized messages and
  a player-tag column that auto-resolves `src → name #netId · stateId`.
- Daily + size-capped file rotation, with optional NDJSON sidecar for log
  pipelines and automatic retention sweep (default 30 days).
- Discord webhook for `warn`/`error` (threshold configurable) — embeds
  carry color, KV as fields, stack traces as a code block.
- Stack traces auto-attached to every `Log.error`, no extra wiring.
- Consecutive-line dedup that collapses spam into `… ×N`, with an idle
  flush so the last line in a burst still appears.
- In-memory ring buffer (2000 entries) for live tail + on-demand export.
- Secret scrubbing: tokens, API keys, mysql passwords, Discord webhook
  tokens etc. are stripped from messages **and** kv values before any
  sink sees them.
- Async batched file writes (50 ms flush thread) — emit is non-blocking
  even under heavy load.
- Boot deferral: non-critical lines hold until `st_bootstrap` flushes,
  keeping the splash screen as the visual centerpiece.

## Install

```lua
server_scripts {
    '@st_log/lib/init.lua',
}
```

After that, `Log.*` is a global in every resource that imports the shim.
The shim only defines functions and forwards them to st_log via exports —
it does no work itself.

## API

```lua
Log.info(domain, message, kv?)        -- general info
Log.warn(domain, message, kv?)        -- warnings (also hits webhook by default)
Log.error(domain, message, kv?)       -- bold; stack trace auto-captured
Log.debug(domain, message, kv?)       -- only when st:debug = 1
Log.sys(domain, message, kv?)         -- system / lifecycle events
Log.chat(domain, message, kv?)
Log.admin(domain, message, kv?)
Log.connect(domain, message, kv?)     -- CONN+
Log.disconnect(domain, message, kv?)  -- CONN-

Log.command(source, name, args)       -- shortcut for command-trace lines
Log.wrap(domain, label, fn)           -- pcall wrapper; preserves fn's return values
```

`kv` is an arbitrary table. The following keys auto-enrich into a player
tag instead of being rendered as kv pairs:

```
src, player, netId, charId, userId, stateId
```

If you only pass `{ src = source }`, `Log` will pull the player's name
via `GetPlayerName` and (when ox_core is started) charId/stateId via
`Ox.GetPlayer`. Everything else falls through to the kv tail.

### Example

```lua
Log.info('apartments', 'apartment assigned', {
    src   = playerId,
    apt   = 12,
    room  = 'Room 101',
})
-- 22:28:40   INFO   [apartments] IcyToad0238 #1 · SK4247 › Apartment assigned  apt=12 room=Room 101
```

```lua
Log.error('db', 'failed to save player', {
    src = playerId,
    err = err,
})
-- 22:28:40   ERROR  [db] IcyToad0238 #1 · SK4247 › Failed to save player  err=connection lost
--         stack traceback:
--             [C]: in function '...'
--             @db/server/save.lua:42: in function 'savePlayer'
--             ...
```

## Convars

| Convar                   | Default | Effect                                            |
|--------------------------|---------|---------------------------------------------------|
| `st:debug`               | `0`     | enable `Log.debug` output                         |
| `st:log:file`            | `1`     | write to `strata-YYYY-MM-DD.log`                  |
| `st:log:json`            | `0`     | also write NDJSON sidecar (`.ndjson`)             |
| `st:log:max_size_mb`     | `10`    | roll log file when it crosses this size           |
| `st:log:retention_days`  | `30`    | delete rolled / dated log files older than this   |
| `st:log:level`           | `info`  | min console level: `debug`/`info`/`warn`/`error`  |
| `st:log:<category>`      | `1`     | per-category mute (e.g. `st:log:chat 0`)          |
| `st:log:webhook`         | `""`    | Discord webhook URL (off when empty)              |
| `st:log:webhook_level`   | `warn`  | min level forwarded to webhook                    |
| `st:log:redact`          | `1`     | scrub secrets (tokens, mysql passwords, etc.)     |

Setting `st:log:retention_days 0` disables retention sweeps entirely.

## Console commands

All console-only (`source == 0`). Run them from txAdmin or the FXServer
console.

| Command            | Action                                          |
|--------------------|-------------------------------------------------|
| `logdebug on/off`  | toggle `Log.debug` output                       |
| `logmute <cat>`    | mute/unmute a category in the console           |
| `loglevel <lvl>`   | set the min console level                       |
| `logtail [n]`      | print the last N entries from the ring buffer   |
| `logexport`        | dump the ring buffer to `strata-export-*.log`   |

## Exports

| Export             | Use                                                |
|--------------------|----------------------------------------------------|
| `emit`             | core API — the `Log.*` shim forwards here          |
| `flushDeferred`    | release the boot-deferred console buffer           |
| `writeLogLine`     | append a raw stripped line directly to the text log|
| `recordEntry`      | append a pre-built entry to the ring buffer        |
| `tail(n)`          | pull the last N ring-buffer entries                |
| `clear`            | wipe the ring buffer                               |
| `export`           | dump the ring buffer to a file, returns its path   |

`emit` is wrapped in `pcall` at the export boundary — a malformed kv or
sink failure can never propagate back to the caller.

## On-disk files

All written into the resource directory.

| File                                       | When                                  |
|--------------------------------------------|---------------------------------------|
| `strata-YYYY-MM-DD.log`                    | live text log (current day)           |
| `strata-YYYY-MM-DD.ndjson`                 | live NDJSON sidecar (if `st:log:json`)|
| `strata-YYYYMMDD-HHMMSS.log/.ndjson`       | rolled file after a size-cap rotation |
| `strata-export-YYYYMMDD-HHMMSS.log`        | one-shot snapshot via `logexport`     |

All matching files older than `st:log:retention_days` are swept on boot
(after 5 s) and every 6 hours thereafter.

## Redaction

When `st:log:redact 1` (default), these patterns are scrubbed from every
message and every kv string value before it touches any sink:

- `mysql://user:password@host` → `mysql://user:***@host`
- `Bearer <token>` → `Bearer ***`
- `sk-...`, `xoxb-...` (OpenAI / Slack key prefixes) → `sk-***`, `xoxb-***`
- `discord.com/api/webhooks/<id>/<token>` → `…/<id>/***`
- `password=`, `token=`, `api_key=`, `Authorization:` followed by a value

Walks tables up to 3 deep; non-strings pass through untouched.

## Webhook payload shape

```json
{
  "embeds": [{
    "title":       "[ERROR] db",
    "description": "Failed to save player\n```\nstack traceback: ...\n```",
    "color":       16734298,
    "timestamp":   "2026-05-17T03:14:15Z",
    "fields": [
      { "name": "err", "value": "`connection lost`", "inline": true }
    ]
  }]
}
```

Queue is throttled at 250 ms per request. Field count capped at 24,
field values at 1024 chars, description at 4000 chars, stack body at
1800 chars (all to stay under Discord's embed limits).

## NDJSON entry shape

```json
{
  "ts":       "22:28:40",
  "level":    "error",
  "resource": "db",
  "message":  "Failed to save player",
  "player":   "IcyToad0238 #1 · SK4247",
  "kv":       { "err": "connection lost" },
  "stack":    "stack traceback:\n..."
}
```

## Layout

```
st_log/
├── fxmanifest.lua
├── lib/
│   └── init.lua          consumer-side shim — defines Log.* globals
└── server/
    ├── main.lua          entry · safe-emit wrapper · exports · retention start
    ├── format.lua        palette · level/weight tables · fmt helpers
    ├── buffer.lua        ring buffer (record / walk / tail / clear)
    ├── file.lua          async batched text + NDJSON writes, rotation
    ├── player.lua        buildTag — src → name #netId · stateId
    ├── dedup.lua         consecutive-line collapse with idle flush
    ├── webhook.lua       throttled Discord queue with embed building
    ├── redact.lua        secret scrubbing for messages + kv values
    ├── retention.lua     periodic sweep of dated/rolled log files
    ├── emit.lua          orchestrator — redact · dedup · sinks
    ├── hooks.lua         playerJoining / Dropped / chat / ox events
    └── commands.lua      logdebug · logmute · loglevel · logtail · logexport
```

Each module is `local M = {}; ...; return M`. Cross-module dependencies
are explicit imports at file top via a tiny `require` shim defined in
`main.lua` (FiveM's Lua sandbox doesn't expose `package`).
