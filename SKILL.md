---
name: real-browser-ceki
description: Drive real Chrome sessions (yours or marketplace) via `ceki` CLI/SDK. env-driven for Konstantin's agents (CEKI_RENT_SCHEDULES, CEKI_TOKEN) — sessions → my-browsers → search pre-flight. Generic marketplace for everyone else.
when_to_use: An agent needs a real Chrome session — CAPTCHA/2FA bypass, anti-bot site scraping, authenticated publishing, form fills that require a real fingerprint/cookies/residential IP.
---

# real-browser-ceki — real Chrome, one skill for all modes

> **Use responsibly.** This skill drives someone's real browser. Before using it on any site, confirm you have authorization.

## ⚠️ THIS IS A LIVE BROWSER OF A REAL PERSON — NOT HEADLESS, NOT A SANDBOX

- This is a **real Chrome of a live person**: their screen, mouse, IP, fingerprint, cookies, open tabs. **Not headless. Not CI. Not a test sandbox.**
- **Behave like a human, not a test script.** No burst-clicks, tight loops, or parallel operations.
- **No synthetic smokes.** `example.com`, `httpbin` — FORBIDDEN. Only the real target task.
- **One active tab per session.** New tab → `switch_tab` closes the previous one.
- **Reuse ONE session.** Each new `session(mode=incognito)` = a new incognito window.
- **Clean up after yourself.** Don't leave junk tabs/forms/logins behind.

## Modes

This skill works in **two modes**, controlled by env vars:

| Mode | What | Set by |
|------|------|--------|
| **Self** (Konstantin's browsers) | Your own pre-arranged schedules. Env-driven: `CEKI_RENT_SCHEDULES` + `CEKI_TOKEN`. Pre-flight: sessions → my-browsers → search. | `CEKI_RENT_SCHEDULES` is set |
| **Marketplace** | Public Chrome sessions from other providers. Pay per minute. | `CEKI_RENT_SCHEDULES` is empty → falls back to `ceki search` |

## SDK installation

```bash
pip install --upgrade ceki-sdk --break-system-packages   # >=2.18.0
ceki --help   # check PATH
```

TypeScript: `npm install @ceki/sdk` (or `npm install -g @ceki/sdk` for the CLI binary).

## Authentication

### For Konstantin's agents (Self mode)

Token comes from `CEKI_TOKEN` env var — set in `.claude/settings.json` per agent:

```json
{
  "env": {
    "CEKI_TOKEN": "ag_xxxxxxxxxxxx",
    "CEKI_API_KEY": "ag_xxxxxxxxxxxx",
    "CEKI_RENT_SCHEDULES": "11722,10930"
  }
}
```

Verify:
```bash
curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/auth/introspect | jq '.tokenable_id, .name'
```

### For marketplace users

1. Register at ceki.me
2. Create a Sanctum token: dashboard → Profile → API Keys
3. Pass to SDK as `token=<sanctum_token>`

---

## Pre-flight — ВЫПОЛНЯЙ ПЕРЕД КАЖДОЙ АРЕНДОЙ

Не лезь сразу в `ceki rent`. Проходи шаги по порядку.

### 1. Проверь свои активные сессии

Если уже есть активная сессия — **resume**, а не rent новый.

```bash
ceki sessions
# Если есть active → resume через ceki rent --resume <session_id>
# Если нет → иди дальше
```

> Сессия на relay живёт вечно (`RELAY_RESUME_GRACE_MS=-1`), пока не сделаешь `ceki stop`.

### 2. Проверь свои браузеры

```bash
ceki my-browsers
# → список твоих browser_id со статусом online/offline
# Если все online → можно rent
# Если все заняты (in use) → не дёргай search без спроса
```

### 3. Поиск чужих браузеров — ТОЛЬКО если владелец разрешил

Если `my-browsers` пуст или все заняты, **не лезь в `ceki search` без явного разрешения** — это публичный поиск, берёт браузеры других людей за деньги.

Когда разрешил:
```bash
ceki search
# → список доступных браузеров с geo, ценой, рейтингом
# Выбери подходящий, потом rent по schedule_id
```

### 4. Install CLI (one time)

```bash
pip install --upgrade ceki-sdk --break-system-packages
ceki --help
```

### 5. Проверь env vars

```bash
# CEKI_API_KEY обязан быть
curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/auth/introspect | jq '.tokenable_id, .name'
```

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

### CLI (Konstantin's env-driven)

```bash
# Env already set — rent first available from CEKI_RENT_SCHEDULES
SCHED=$(echo "$CEKI_RENT_SCHEDULES" | cut -d, -f1)
SID=$(ceki rent --schedule "$SCHED" --mode main | jq -r .session_id)

ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/01.png

# Cleanup
ceki stop $SID
```

---

## Browser config — from ENV, not hardcoded

| Env var | What | Default |
|---------|------|---------|
| `CEKI_RENT_SCHEDULES` | Comma-separated schedule_ids, priority order | If empty → `ceki search` |
| `CEKI_RENT_MODE` | Rental mode: `main` or `incognito` | `main` |
| `CEKI_TOKEN` / `CEKI_API_KEY` | Auth token | — |
| `CEKI_API_URL` | API endpoint | `https://api.ceki.me` |
| `CEKI_RELAY_URL` | WebSocket relay | `wss://browser.ceki.me/ws/agent` |
| `CEKI_CHAT_URL` | Chat API | `https://chat.ceki.me/api/chat` |

Rental — iterate in priority order, no retry loop:
```bash
MODE="${CEKI_RENT_MODE:-main}"

if [ -z "${CEKI_RENT_SCHEDULES// /}" ]; then
  echo "CEKI_RENT_SCHEDULES not set → ceki search"
  mapfile -t SCHEDS < <(ceki search --limit 20 | jq -r '.[].schedule_id // empty')
else
  IFS=',' read -ra SCHEDS <<< "$CEKI_RENT_SCHEDULES"
fi

[ ${#SCHEDS[@]} -eq 0 ] && { echo "no available browsers"; exit 0; }

SID=""
for s in "${SCHEDS[@]}"; do
  s="${s// /}"; [ -z "$s" ] && continue
  OUT=$(ceki rent --schedule "$s" --mode "$MODE" 2>&1)
  SID=$(printf '%s' "$OUT" | jq -r '.session_id // empty')
  [ -n "$SID" ] && { echo "rented $s → $SID"; break; }
  printf '%s' "$OUT" | grep -qiE "insufficient" && { echo "insufficient funds"; break; }
done
```

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
| `chat <sid> next` | `--timeout=N` | next message or `null` |
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

### Lifecycle

```
rent ──► {session_id} ──► navigate/snapshot/click/type/... ──► stop
```

Session ends ONLY on: `user_stop` (provider), `agent_end` (`ceki stop`), `provider_offline`, `insufficient_funds`.

**Stop is mandatory.** Without it the meter keeps ticking.

---

## Rate limits — DON'T BE RUDE

- **20 rents / hour** per agent. On 21st → `rate_limit`. Plan with ≥3 min pauses.
- **CDP:** 500 commands / 60s per session.
- **Browser exclusivity:** one active rental per browser_id at a time.
- **Don't poll in tight loops** — if `rent` returns `rate_limit`, STOP for ≥10 min.

---

## Chat with the host

Each rental has a chat. Use it to ask for 2FA, captcha solve, or confirm before commit/payment.

```bash
ceki chat $SID send "Can you tell me the OTP?"
ANSWER=$(ceki chat $SID next --timeout=120 | jq -r .text)
[ "$ANSWER" = "null" ] && echo "no answer"
```

---

## Detailed reference

- `reference/methods.md` — full JSON-RPC method reference
- `reference/pricing.md` — pricing details
- `examples/` — Python and TypeScript examples

## Session modes

| Mode | Description |
|------|-------------|
| `incognito` | Clean browser, no user cookies. Best for anonymous scraping. |
| `main` / `persona` | Real user cookies and profile (Konstantin's profile). Password fields masked. |

## Environments — dev vs prod

Dev (ittribe): set `CEKI_API_URL=https://clawapi.ittribe.org`, `CEKI_RELAY_URL=wss://browser.ittribe.org/ws/agent`, `CEKI_CHAT_URL=https://chat.ittribe.org/api/chat`.

Prod (default): omit all URLs — defaults to `*.ceki.me`.
