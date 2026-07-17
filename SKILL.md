---
name: real-browser-ceki
description: Drive real Chrome sessions via `ceki` CLI/SDK. Pre-flight: sessions → my-browsers → search. Type with `--natural`, probe with `snapshot`, distinguish insufficient_funds vs busy. Generic marketplace + env-driven self mode.
when_to_use: An agent needs a real Chrome session — CAPTCHA/2FA bypass, anti-bot site scraping, authenticated publishing, form fills that require a real fingerprint/cookies/residential IP.
---

# real-browser-ceki — real Chrome for AI agents

> **Use responsibly.** This skill drives someone's real browser. Before using it on any site, confirm you have authorization.

## ⚠️ THIS IS A LIVE BROWSER OF A REAL PERSON — NOT HEADLESS, NOT A SANDBOX

- **Real person, real Chrome.** Their screen, mouse, IP, fingerprint, cookies, open tabs. Not headless. Not CI. Not a test sandbox.
- **Behave like a human.** No burst-clicks, tight loops, or parallel operations.
- **No synthetic smokes.** `example.com`, `httpbin` — FORBIDDEN. Only the real target task.
- **One active tab per session.** New tab → `switch_tab` closes the previous one.
- **Reuse ONE session.** Each new `session(mode=incognito)` opens a new incognito window on the person's screen.
- **Clean up after yourself.** Don't leave junk tabs/forms/logins behind.

---

## Pre-flight — run before EVERY rent

Do NOT jump straight to `ceki rent`. Walk through these steps in order.

### 1. Check active sessions — resume, don't re-rent

If you already have an active session — **resume it**, don't start a new one.

```bash
ceki sessions
# If you see an active entry → ceki rent --resume <session_id>
# If none → proceed to step 2
```

> A relay session lives forever (`RELAY_RESUME_GRACE_MS=-1`) until you call `ceki stop`. Returning after a pause? Your session is still there — `ceki sessions` finds it, `ceki rent --resume` reconnects. No need to re-rent from scratch.

### 2. Check your own browsers

```bash
ceki my-browsers
# → list of your browser_id with online/offline status
# If at least one is online → proceed to rent
# If all are busy (in use) → do NOT jump to public search
```

### 3. Public search — only if explicitly authorized

If `my-browsers` is empty or all busy, **do not run `ceki search` without explicit permission** — this is a public marketplace that rents other people's browsers for money.

When authorized:

```bash
ceki search
# → list of available browsers with geo, price, rating
# Pick one, then rent by its schedule_id
```

### 4. Install CLI (one-time)

```bash
pip install --upgrade ceki-sdk --break-system-packages   # >=2.18.0
ceki --help
```

### 5. Verify auth

```bash
curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/auth/introspect | jq '.tokenable_id, .name'
```

---

## Modes

This skill works in **two modes**, controlled by how you configure it:

| Mode | When to use | How |
|------|-------------|-----|
| **Self** | You own the browser schedules (pre-arranged). Env-driven: `CEKI_RENT_SCHEDULES` + `CEKI_TOKEN` | Set env vars, then `ceki rent --schedule <id>` |
| **Marketplace** | No pre-arranged schedules; rent public Chrome sessions from other providers. Pay per minute. | `CEKI_RENT_SCHEDULES` empty → leaves `ceki search` as fallback |

---

## SDK installation

```bash
pip install --upgrade ceki-sdk --break-system-packages   # >=2.18.0
ceki --help
```

TypeScript: `npm install @ceki/sdk` (or `npm install -g @ceki/sdk`).

## Authentication

### Self mode (env-driven)

Set these env vars (e.g. in `.claude/settings.json`):

```json
{
  "env": {
    "CEKI_TOKEN": "ag_xxxxxxxxxxxx",
    "CEKI_API_KEY": "ag_xxxxxxxxxxxx",
    "CEKI_RENT_SCHEDULES": "12345,67890"
  }
}
```

| Env var | Purpose | Default |
|---------|---------|---------|
| `CEKI_RENT_SCHEDULES` | Comma-separated schedule_ids, priority order | empty → fallback to `ceki search` |
| `CEKI_RENT_MODE` | `main` or `incognito` | `main` |
| `CEKI_TOKEN` / `CEKI_API_KEY` | Sanctum token (`ag_*`) | — |
| `CEKI_API_URL` | API base URL | `https://api.ceki.me` |
| `CEKI_RELAY_URL` | WebSocket relay | `wss://browser.ceki.me/ws/agent` |
| `CEKI_CHAT_URL` | Chat service | `https://chat.ceki.me/api/chat` |

### Marketplace (generic)

1. Register at ceki.me
2. Create a Sanctum token: dashboard → Profile → API Keys
3. Pass as `token=<sanctum_token>` to the SDK

---

## Quickstarts

### Python

```python
import asyncio
from ceki_sdk import Browser

async def main():
    async with Browser(token="YOUR_TOKEN") as br:
        async with await br.session(mode="incognito", domain_hints=["example.com"]) as s:
            await s.navigate("https://example.com")
            title = await s.query("h1")
            print(title.text)

asyncio.run(main())
```

### TypeScript

```ts
import { Browser } from '@ceki/sdk';

const br = new Browser({ token: 'YOUR_TOKEN' });
await br.connect();
const s = await br.openSession({ mode: 'incognito', domainHints: ['example.com'] });
await s.navigate('https://example.com');
const title = await s.query('h1');
console.log(title.elements[0]?.textContent);
await s.close();
await br.close();
```

### CLI — rental loop (env-driven)

```bash
MODE="${CEKI_RENT_MODE:-main}"

# Determine browsers: from env or public search
if [ -z "${CEKI_RENT_SCHEDULES// /}" ]; then
  mapfile -t SCHEDS < <(ceki search --limit 20 | jq -r '.[].schedule_id // empty')
else
  IFS=',' read -ra SCHEDS <<< "$CEKI_RENT_SCHEDULES"
fi

[ ${#SCHEDS[@]} -eq 0 ] && { echo "no available browsers"; exit 0; }

# Iterate in priority order. Stop on insufficient_funds — it's not "busy".
SID=""; NO_FUNDS=0
for s in "${SCHEDS[@]}"; do
  s="${s// /}"; [ -z "$s" ] && continue
  OUT=$(ceki rent --schedule "$s" --mode "$MODE" 2>&1)
  SID=$(printf '%s' "$OUT" | jq -r '.session_id // empty')
  [ -n "$SID" ] && { echo "rented $s → $SID"; break; }
  printf '%s' "$OUT" | grep -qiE "insufficient" && { NO_FUNDS=1; break; }
done

[ "$NO_FUNDS" = 1 ] && { echo "insufficient funds — top up wallet, do NOT retry"; exit 0; }
[ -z "$SID" ] && { echo "all browsers busy — report, do NOT loop"; exit 0; }

# Now drive the session
ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/state.png

# ... do the work ...

ceki stop $SID
```

---

## Text input — ALWAYS `ceki type --natural`

**Rule: fill every field via `ceki type <sid> "text" --natural`.** This is the only reliable path.

### Why `type` and not a CDP value-setter

- `ceki type --natural` sends real `keydown/keypress/keyup` events (`Input.dispatchKeyEvent`). React's `_valueTracker` fires, Vue's `v-model` catches the `input` event — the field genuinely fills.
- A CDP value-setter (`Runtime.evaluate el.value = "x"`) puts text on screen but **does NOT trigger framework state**. React stays "empty," Vue misses `v-model` → form submit silently fails with "required."
- `--natural` adds pauses between keystrokes — human-like timing, less anti-bot suspicion.

### When you MUST blur after type

Fields with async validation (username availability, promo codes) validate on `blur`/debounce. After `type`:

```bash
ceki type $SID "username" --natural
ceki cdp $SID --method Runtime.evaluate \
  --params '{"expression":"document.activeElement.blur()","returnByValue":true}'
```

### CDP value-setter — LAST RESORT only

Only for non-standard rich editors (ProseMirror, Slate, Quill, Lexical) where `type` physically can't write.

```bash
cdp $SID --method Runtime.evaluate --params '{
  "expression": "(function(){var el=document.querySelector(\"textarea[name=body]\");var s=Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,\"value\").set;s.call(el,\"<TEXT>\");el.dispatchEvent(new Event(\"input\",{bubbles:true}));el.dispatchEvent(new Event(\"change\",{bubbles:true}));el.blur();return \"ok\";})()",
  "returnByValue": true
}'
```

Gate: use ONLY if `ceki type` + `blur` didn't work. For ordinary `<input>`/`<textarea>` — NEVER, `type` works there.

---

## Native vs CDP — knowing which is which prevents lost work

The CLI splits operations into **native** (high-level — the relay bridges to the provider) and **CDP** (`ceki cdp` — raw Chrome DevTools Protocol over the same session). These are **different channels**.

| Channel | Commands | Session health indicator |
|---------|----------|------------------------|
| **Native** | `rent`, `navigate`, `snapshot`, `click`, `type`, `sessions`, `my-browsers`, `stop` | ✅ Source of truth |
| **CDP** | `ceki cdp --method Runtime.evaluate ...` | ⚠️ Independent channel — its drop is NOT the session dying |

### CDP `no_session` ≠ rental ended

`ceki cdp $SID --method Runtime.evaluate ...` can return `no_session` **while the rental itself is alive**. The CDP channel is separate from the native session — its timeout/drop does NOT finish the rental.

**Don't interpret CDP `no_session` as "the browser died."** Check liveness via native commands:

```bash
ceki snapshot $SID -o /tmp/probe.png   # returns JSON with ts → session is alive
ceki my-browsers                       # shows your active rental
ceki sessions                          # your active sessions
```

If native also returns `session_not_found` (exit 3) — yes, the rental is over. A CDP error alone — no.

---

## CLI reference

### Subcommands

| cmd | args | stdout JSON |
|-----|------|-------------|
| `rent` | `--schedule N [--mode incognito\|main] [--fingerprint-from f.json]` | `{"session_id", "chat_topic_id", "schedule_id"}` |
| `search` | `[--limit N] [--filter k=v]` | `[BrowserOption, ...]` |
| `sessions` | `[--all]` | list of active sessions |
| `my-browsers` | — | schedules with Renter pivot |
| `snapshot <sid>` | `-o PATH` | `{"chat", "screenshot": "PATH", "ts"}` |
| `screenshot <sid>` | `-o PATH [--full]` | raw PNG/JPEG |
| `navigate <sid> <url>` | — | `{"ok": true}` |
| `click <sid> <x> <y>` | — | `{"ok": true}` |
| `type <sid> "<text>"` | `--natural` | `{"ok": true}` |
| `scroll <sid> <x> <y> <dy>` | — | `{"ok": true}` |
| `switch-tab <sid>` | — | closes previous, activates new |
| `configure <sid>` | `[--masking-mode true\|false]` | `{"ok": true}` |
| `cdp <sid>` | `--method M [--params JSON]` | raw CDP response |
| `wait <sid>` | — | blocking: `{"ended": true, "reason": "..."}` |
| `chat <sid> send "<text>"` | — | `{"message_id": ...}` |
| `chat <sid> send-image` | `--image PATH` | `{"ok": true}` |
| `chat <sid> next` | `--timeout=N (sec)` | next message or `null` |
| `chat <sid> history` | `[--since TS] [--limit N]` | `[ChatMessage, ...]` |
| `profile <sid> export` | `-o PATH` | JSON with cookies+storage+fingerprint |
| `profile <sid> import` | `-i PATH` | `{"ok": true}` |
| `upload <sid>` | `--selector CSS --file PATH` | `{"ok": true}` |
| `request-captcha <sid>` | `[--manual]` | calls provider for manual solve |
| `stop <sid>` | — | `{"ok": true}` |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Generic error |
| 2 | Auth (no `CEKI_API_KEY`) |
| 3 | Session not found / expired |
| 4 | Timeout |
| 5 | Network / WS error |

Errors go to stderr as JSON: `{"error":"...","code":"..."}`.

### Lifecycle

```
rent ──► {session_id} ──► navigate/snapshot/click/type/... ──► stop
```

Each command is a separate subprocess. State between commands is held by **resume**: the relay keeps the session entry until explicit finish. After `RELAY_RESUME_GRACE_MS=-1` the agent disconnect does NOT finish the session.

Session ends ONLY on: `user_stop` (provider pressed Stop), `agent_end` (you called `ceki stop`), `provider_offline` (browser lost network), `insufficient_funds` (balance ran out).

**Stop is mandatory.** Without it the meter keeps ticking.

---

## Chat with the host

Each rental has a chat topic. Use it to ask for 2FA codes, captcha solves, or confirm before commit/payment.

```bash
# Send a message
ceki chat $SID send "Can you tell me the 6-digit code from your phone?"

# Wait for reply (up to 120s)
ANSWER=$(ceki chat $SID next --timeout=120 | jq -r .text)
[ "$ANSWER" = "null" ] && echo "no answer in time"
```

### `chat history` vs `chat next` — two different operations

| Command | Does | Idempotent? |
|---------|------|-------------|
| `chat history` | Returns all past messages (optionally `--since TS` or `--limit N`). Does NOT mark anything as read. | ✅ Yes — call it repeatedly, same result |
| `chat next` | Returns the FIRST unread message, then advances `last_seen_ts`. If nothing unread, opens a WS subscription and waits up to `--timeout` seconds. | ❌ No — each call consumes the next message |

**Pattern:** use `history` for catching up after a resume (no side effects). Use `next` for blocking wait on a new reply.

---

## Rate limits — DON'T BE RUDE

Real-world incidents: agents hitting rate limits, then retrying in loops, making it worse. Follow these rules.

### Rent rate limit: 20/hour per token

- **20 `ceki rent` calls per hour** per account. On the 21st → `rate_limit` error.
- The counter resets on the UTC hour. Non-sliding window.
- Each `ceki stop` + `ceki rent` cycle counts as 2 attempts. Plan long sessions instead of stop+rent per site.

### Rate limit recovery — do NOT retry in loops

A tight polling loop on rent is the fastest way to block your token for 60+ minutes.

```bash
# When rent returns rate_limit:
# 1. STOP all retries immediately
# 2. Wait ≥10 minutes, or switch to a different token
# 3. Check remaining limit:
curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/browsers?limit=1 | jq '.meta'
```

**Never write `until ceki rent ... done` loops.** Each rate-limited attempt resets the monitoring window. A loop that hits rate_limit once will keep hitting it — the window only expands.

### Other limits

- **CDP:** 500 commands / 60s per session (`command_rate_limit`). `ceki type --natural` sends all keystrokes as ONE packet (plugin/413) — doesn't hit this limit.
- **Browser exclusivity:** one active rental per browser_id at a time. `"Browser is currently in use"` means someone else has it — don't retry, pick another or wait.

---

## Error handling — read stderr, check exit code

### Distinguish real errors from "not available"

| Symptom | stderr / exit code | Meaning |
|---------|-------------------|---------|
| `rate_limit` | `{"error":"rate_limit"}` | Token blocked for the hour window. Stop retries. |
| `insufficient_funds` | exit 1, stderr includes `insufficient` | Balance at zero — top up the wallet. Not "busy", iterating other schedules won't help. |
| `Browser is currently in use` | `{"error":"busy"}` | That specific browser is rented by someone else. Try the next schedule_id. |
| `no_providers` | exit 1 | All matching providers offline. Report, do NOT loop. |
| `session_not_found` | exit 3 | Session expired or was stopped. Can't resume — start fresh. |
| CDP `no_session` | stderr `no_session` | **CDP channel only.** Check native (`ceki snapshot`) — session likely alive. |

---

## Important patterns

### Session persistence — export/import profiles

Each rental is a fresh incognito tab. To preserve login state across rents, export cookies + fingerprint:

```bash
ceki profile $SID export -o /tmp/profile.json
# Next rental:
SID=$(ceki rent --schedule $N --fingerprint-from /tmp/profile.json | jq -r .session_id)
ceki navigate $SID "https://site.com"
ceki profile import $SID -i /tmp/profile.json
```

### Pre-warm reCAPTCHA-heavy sites

A fresh incognito has no Google cookies → reCAPTCHA score ~0.0–0.3 → image challenge. Warm up:

```bash
ceki navigate $SID https://www.youtube.com; sleep 7
ceki navigate $SID https://www.google.com; sleep 2
ceki click $SID 640 280
ceki type $SID "ai news 2026" --natural
# press Enter via CDP
ceki cdp $SID --method Input.dispatchKeyEvent --params '{"type":"keyDown","key":"Enter"}'
sleep 10
ceki navigate $SID https://target-site.com
```

This builds Google cookie history → higher starting score → checkbox captcha or silent v3 instead of image grid.

---

## Environments — dev vs prod

| | Dev (ittribe) | Prod (default) |
|---|---|---|
| `CEKI_API_URL` | `https://clawapi.ittribe.org` | omit → `api.ceki.me` |
| `CEKI_RELAY_URL` | `wss://browser.ittribe.org/ws/agent` | omit → `browser.ceki.me` |
| `CEKI_CHAT_URL` | `https://chat.ittribe.org/api/chat` | omit → `chat.ceki.me` |

---

## Session modes

| Mode | Description |
|------|-------------|
| `incognito` | Clean browser, no user cookies. Best for anonymous scraping. |
| `main` / `persona` | Real user cookies and profile of the host. Password fields protected. |

---

## Detailed reference

- `reference/methods.md` — full JSON-RPC method reference
- `reference/pricing.md` — pricing details
- `examples/` — Python and TypeScript examples
