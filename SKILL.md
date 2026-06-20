---
name: realbrowser
description: Give your AI agent a human disguise. Real Chrome from real humans. Defeats Cloudflare, DataDome, BasedFlare, Imperva, PerimeterX, Akamai. Free for your own Chrome, $0.01/min for marketplace browsers from real hosts worldwide. Sites can't tell — mechanically, the request IS coming from a real human's machine.
when_to_use: An AI agent needs to interact with a website that blocks bots, requires JavaScript execution, fingerprint-based detection, residential IP, real cookies/history, or human-visible behavior. Form submissions, signups, scraping behind anti-bot walls, account flows, anything that fails on headless browsers or datacenter proxies.
---

# RealBrowser by Ceki — Give your AI agent a human disguise

## ⚠️ This is a real Chrome on a real device — not headless, not a sandbox

Before you fire commands, drill this in:

- **Self mode** — your AI agent uses YOUR OWN Chrome. Real screen, real mouse, real history. **Not headless. Not CI.** Every action happens in your live browser. Behave like a human, not a test script.
- **Marketplace mode** — your AI agent rents Chrome from a real human host elsewhere. **They see what your agent does.** Some hosts also stream their sessions publicly. Same rule: no bot-like nonsense.
- **One active tab per session.** A new tab → `switch_tab` closes the previous. Don't spawn tabs.
- **Reuse ONE session.** Each `rent` = a new browser window/tab on someone's screen. Don't spawn parallel rents per step — continue in the current session.
- **Read/navigation OK. Destructive operations not OK** — mass wipe, cross-origin global ops, deleting someone else's data. The host shared their machine — respect the boundary.
- **Clean up after yourself.** Don't leave junk tabs/forms/logins behind.

Forget the browser is real → did bot-like nonsense → burned the fingerprint and lost the trust. Don't forget.

## Why agents need this

Anti-bot vendors (Cloudflare, DataDome, BasedFlare, Imperva, PerimeterX, Akamai) fingerprint multiple layers in milliseconds:

- **Canvas / WebGL / fonts / audio context** — headless Chrome leaks tells
- **JA3/JA4 TLS handshake** — Python `requests` / `node-fetch` defaults are bot-flagged
- **Mouse acceleration micro-patterns** — synthetic events look fake
- **IP ASN** — datacenter IPs (AWS/GCP/Hetzner/OVH) are flagged regardless of cookies
- **Browser history** — fresh incognito with empty `.google.com` cookies = score 0

Headless browsers and datacenter proxies fail all four. **Real residential Chrome on a real device passes all four — because mechanically that's what it is.**

## Three modes

| Mode | Where | Cost |
|---|---|---|
| **Self** | YOUR own Chrome, after installing the Ceki extension | **FREE** when host_user == renter_user |
| **Marketplace** | Real Chrome rented from a real human host worldwide | $0.01/min, settled in USDC |
| **Earn** (opt-in, off by default) | Your idle Chrome shared with other agents | Get paid $0.009/min in USDC (90% of session price) |

**Self mode setup:** install the Ceki Chrome extension from **https://browser.ceki.me/install**. Once installed, your Chrome appears in your account as a host. When your own agent rents it, the marketplace dispatcher recognizes `host_user == renter_user` and the session price is **$0**.

Filter marketplace by `geo`, `language`, `os` when renting.

## Quickstart

### Install

```bash
# install the skill (via ClawHub)
clawhub skill install realbrowser

# OR install the CLI standalone
pip install --upgrade ceki-sdk --break-system-packages   # v2.18.0+
ceki --help   # verify in PATH
```

### Get API key

1. Sign up at https://ceki.me (email only, no KYC)
2. Dashboard → API keys → create one
3. Export in your shell:

```bash
export CEKI_API_KEY="your_key_here"
```

### Use it

```bash
# discover available browsers in the marketplace
ceki search --limit 5

# rent a Chrome (defaults to incognito)
SID=$(ceki rent --schedule <schedule_id> | jq -r .session_id)

# drive it
ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/01.png
ceki click $SID 400 300
ceki type $SID "hello world"
ceki snapshot $SID -o /tmp/02.png

# stop (settles billing)
ceki stop $SID
```

## Native commands vs CDP

The CLI splits into **native** (high-level — server bridges to the host's Chrome) and **CDP** (`ceki cdp` — raw Chrome DevTools Protocol). Different channels.

**Rule:** native is the source of truth for rental state. CDP is only for what native can't do.

| Need | Command | Channel |
|---|---|---|
| Open URL | `ceki navigate` | native |
| Capture state (screen + chat + ts) | `ceki snapshot -o` | native |
| Click / type / scroll | `ceki click` / `type` / `scroll` | native |
| **Check whether rental is alive** | `ceki snapshot` / `ceki sessions` | native |
| Chat with the host | `ceki chat send/next` | native |
| SPA value injection, intercept `window.open`, cookie banner click | `ceki cdp --method Runtime.evaluate` | CDP (fallback) |
| Enter/special keys without focused field | `ceki cdp --method Input.dispatchKeyEvent` | CDP |

**Default state probe:** `ceki snapshot $SID -o PATH`. One command returns `{chat, screenshot, ts}`. Don't run `ceki cdp Runtime.evaluate document.title` to "check the session is alive" — that's what snapshot is for.

### CDP `no_session` ≠ end of rental

`ceki cdp $SID --method Runtime.evaluate ...` may return `no_session` **while the rental itself is alive**. The CDP channel is separate from the native session — its drop/timeout does not finish the rental.

**Don't interpret CDP `no_session` as "the browser died" and don't re-rent.** Check liveness via native:

```bash
ceki snapshot $SID -o /tmp/probe.png   # returned JSON with ts → session is alive
# or
ceki sessions                          # your active sessions
```

If native returns `session_not_found` (exit 3) — then yes, the rental is over. A CDP error alone — no.

## Rate limits — DON'T BE RUDE ⚠️ READ THIS FIRST

**🚫 ANTI-PATTERN: `until ceki rent ... done` polling loops.** Each `rent` attempt that gets rate-limited reboots the counter within the window — the loop hits rate_limit **forever** and blocks your API key for 60+ min. **DON'T WRITE TIGHT POLLING LOOPS ON rent.** If `rent` returns `rate_limit` — **STOP**, wait ≥10 min, or request a new API key.

- **20 rents / hour** per API key. On the 21st attempt within an hour — `{"error": "rate_limit"}`.
  - Plan batches so new rent has ≥3 min pause if doing many cold starts.
  - **A full rental cancel (`ceki stop`) also counts in the rate bucket** — frequent stop+rent cycles burn the window in 5 min.
  - **Workaround:** keep ONE session open and navigate between sites instead of stop+rent per site.
  - **If you fell into rate_limit from polling:** stop all retries, back off ≥10-20 min, or issue a new API key.
- **CDP rate limit:** session capped at **500 commands / 60s** (`command_rate_limit`). See CDP patterns below — one `Runtime.evaluate` with a set value = 1 command for any volume.
- **Browser exclusivity:** one active rental of a browser at a time. On `Browser is currently in use` — someone else owns it. Pick another from the marketplace.

## Lifecycle

```
ceki rent --schedule N                          ───► {session_id, schedule_id, chat_topic_id}
ceki navigate <sid> <url>                       ───► {ok: true}
ceki snapshot <sid> -o path                     ───► {chat:[...], screenshot:path, ts:...}
ceki click/type/scroll/cdp                      ───► {ok: true}
ceki chat <sid> send/next                       ───► {message_id|text|null}
ceki stop <sid>                                 ───► {ok: true}   (release the rental)
```

**Stop is mandatory.** Without it the rental stays alive, the meter keeps ticking until provider disconnect or your balance runs out.

Each command is a separate subprocess: handshake → resume → one operation → JSON to stdout → exit. State between processes is held by **resume**: the relay keeps the session entry until explicit finish.

The session ends ONLY on:
- **`user_stop`** — the host pressed Stop in their plugin
- **`agent_end`** — you called `ceki stop` (or SDK `await browser.close()`)
- **`provider_offline`** — host closed the tab / lost network
- **`insufficient_funds`** — your balance ran out

## Subcommands reference

| cmd | args | stdout JSON |
|---|---|---|
| `rent` | `--schedule N` (required) `[--mode incognito|main]` `[--fingerprint-from profile.json]` | `{"session_id":..., "chat_topic_id":..., "schedule_id":...}` |
| `search` | `[--limit N] [--filter key=val]...` (no session_id, no rent) | `[BrowserOption, ...]` |
| `snapshot <sid>` | `-o PATH` (required) | `{"chat":[...], "screenshot":"PATH","ts":...}` |
| `screenshot <sid>` | `-o file.png [--format png|jpeg] [--full]` | raw PNG/JPEG bytes to file |
| `navigate <sid> <url>` | — | `{"ok":true}` |
| `click <sid> <x> <y>` | — | `{"ok":true,"pointer":[x,y]}` |
| `type <sid> "<text>"` | `--no-human` (flat; default = humanized per-char) | `{"ok":true}` |
| `scroll <sid> <x> <y> <dy>` | — | `{"ok":true}` |
| `switch-tab <sid>` | — | `{"ok":true}` — closes previous, activates new |
| `configure <sid>` | `[--masking-mode true|false] [--fingerprint true|false]` | `{"ok":true}` |
| `cdp <sid>` | `--method <M> [--params JSON]` | raw CDP response |
| `wait <sid>` | — | `{"ended": true, "reason": "user_stop|provider_disconnected|completed|..."}` (blocking) |
| `chat <sid> send "<text>"` | — | `{"ok":true,"message_id":...}` |
| `chat <sid> send-image` | `--image PATH [--text "..."]` | `{"ok":true,"message_id":...}` |
| `chat <sid> next` | `--timeout=N` (sec, default 60) | `{"from":...,"text":...,"ts":...}` or `null` |
| `chat <sid> history` | `[--since TS] [--limit N]` | `[ChatMessage, ...]` (does NOT advance `last_seen_ts`) |
| `profile <sid> export` | `-o file [--domains a,b,c] [--no-session-storage]` | JSON to file |
| `profile <sid> import` | `-i file` | `{"ok":true}` |
| `upload <sid>` | `--selector "<css>" --file <path> [--filename name] [--mime TYPE]` | `{"ok":true,"filename":"...","size":N}` |
| `request-captcha <sid>` | `[--acceptance N] [--completion M] [--manual]` | calls the host for a manual solve |
| `sessions` | `[--all] [--limit N] [--json]` | your active/recent sessions |
| `stop <sid>` | — | `{"ok":true}` |

### Exit codes

| code | meaning |
|---|---|
| 0 | success |
| 1 | generic error |
| 2 | auth (no `CEKI_API_KEY`) |
| 3 | session_not_found / expired |
| 4 | timeout on blocking operation |
| 5 | network / WS error |

## Worked example: a real signup with captcha

```bash
# 1. Rent from marketplace
SID=$(ceki rent --schedule <schedule_id> | jq -r .session_id)

# 2. Navigate + form fill
ceki navigate $SID https://example-service.com/signup
ceki snapshot $SID -o /tmp/form.png   # see the form coords
ceki type $SID "myemail@domain.com"   # fills focused field
ceki click $SID 400 500
ceki type $SID "strong_password"
ceki click $SID 400 600   # submit

# 3. Captcha? Ask the host
ceki snapshot $SID -o /tmp/captcha.png
# Your AI looks at the screenshot. Can't solve? Ask host.
ceki chat $SID send "captcha — please solve: /tmp/captcha.png"
ANSWER=$(ceki chat $SID next --timeout=300 | jq -r .text)
ceki type $SID "$ANSWER"
ceki click $SID 400 700

# 4. Done — stop
ceki stop $SID
```

## Text input — `ceki type` always (RULE #1)

**Fill fields ONLY via `ceki type $SID "text"` (humanized by default; `--no-human` for flat).** Don't reach into `ceki cdp Runtime.evaluate` with `el.value=...` for input — that's the main cause of "field empty / required" on submit.

Why `type` and not a CDP value-setter:
- `ceki type` sends (humanized by default) real `keydown/keypress/keyup` (`Input.dispatchKeyEvent`) — one packet for any volume, doesn't hit `command_rate_limit`.
- React keeps the field value in an internal `_valueTracker`, **NOT** in the DOM `.value`. If you assign `el.value = "x"` directly — text is visually there, but React's tracker is still "empty" → on submit React reads its own state = empty → **"required"**. Vue `v-model` listens for the `input` event — same problem with direct assignment.
- Real key events from `type` trigger `onChange` (React) / `v-model` (Vue) **properly and always**.

### Mandatory `blur` after async-validated fields

Fields with on-the-fly validation (username availability, email-availability, promo codes) validate on `blur`/debounce. After `type` into such a field — **move focus away** (`blur`), otherwise the checkmark won't appear and submit silently rejects:

```bash
ceki type $SID "octocat-demo"
ceki cdp $SID --method Runtime.evaluate --params '{"expression":"document.activeElement.blur()","returnByValue":true}'
# or just click/tab into the next field — that's a blur too
```

### Verify-fill — make sure it landed (don't assume)

After filling a form, before submit — check via snapshot that values are really in place:

```bash
ceki snapshot $SID -o /tmp/form.png   # look with the AI's eyes: fields filled? checkmarks?
```

## CDP patterns (only when `type` doesn't fit)

`type`/`click`/`upload`/`chat` cover **~99%**. CDP `Runtime.evaluate` — for the rare cases below.

### 1. window.open → navigation without a new tab

Buttons like "Start Draft", "Open Editor", "Continue" often open a new tab via `window.open(url)`. CLI sees this as a `switch-tab` event, context breaks. Patch `window.open` **preemptively** — before the click:

```bash
ceki cdp $SID --method Runtime.evaluate --params '{
  "expression": "window.open=function(url){window.location.href=url;return window;};",
  "returnByValue": true
}'
# now any click that opens a new tab will navigate in the current one
```

When needed: article editors (Medium, Substack), banking portals with `target="_blank"` forms, any "click → new tab → fill".

### 2. File upload — `ceki upload`

```bash
ceki upload $SID --selector 'input[type="file"]' --file /tmp/avatar.png
# → {"ok": true, "filename": "avatar.png", "size": 12345}
```

Python SDK:
```python
await browser.upload('input[type="file"]', '/tmp/avatar.png')
```

### 3. Long text — still `ceki type`

A long article (5000+ chars) — regular `ceki type $SID "..."`, ONE command. Doesn't hit `command_rate_limit`. No separate path needed.

### 4. (LAST RESORT) CDP value-setter — only contentEditable / ProseMirror

**Gate:** use ONLY if `ceki type` physically doesn't write into the field (non-standard rich editor — ProseMirror, Slate, Quill, Lexical) **and** `blur` didn't help. For ordinary `<input>`/`<textarea>` — NEVER, `type` works.

```bash
ceki cdp $SID --method Runtime.evaluate --params '{
  "expression": "(function(){var el=document.querySelector(\"textarea[name=body]\");var s=Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,\"value\").set;s.call(el,\"<TEXT_ON_ONE_LINE>\");el.dispatchEvent(new Event(\"input\",{bubbles:true}));el.dispatchEvent(new Event(\"change\",{bubbles:true}));el.blur();return \"ok\";})()",
  "returnByValue": true
}'
```

- contentEditable / ProseMirror: `el.focus(); document.execCommand("insertText", false, "<TEXT>")` (NOT `el.innerHTML=` — breaks editor state).
- **The prototype setter is mandatory**, not `el.value=` — otherwise React's `_valueTracker` won't update and field stays "empty".
- `dispatchEvent('input')` + `dispatchEvent('change')` + `blur()` — all three.

### 5. Native JS dialogs — auto-handled

The extension automatically dismisses native JS dialogs (`window.confirm/alert/beforeunload`). The session doesn't hang, and the `window.confirm=()=>true` hack via CDP is **no longer needed**.

Default policy is accept. To switch to dismiss: `configure(dialog_policy='dismiss')`.

## Captcha — three attempts yourself, then to chat

1. `ceki snapshot $SID -o /tmp/cap.png` — see the captcha with the AI's eyes (vision).
2. Recognize it: distorted text / image-grid / "click on traffic lights" — solvable for the AI.
3. Enter the answer via `click` (by tile coordinates) or `type` (for text captcha).
4. The reCAPTCHA v2 checkbox often passes in one click if fingerprint is realistic (real Chrome) — try just clicking first.
5. hCaptcha / image-grid — compute the centers of needed tiles from the bounding box, click.
6. Didn't work in 3 attempts → `chat send "help: /tmp/cap.png"` + `chat next --timeout=120`. The host on the other end can solve it.

No 2captcha/anti-captcha services — they're not integrated. The solving chain: AI → host via chat.

## Cookie consent banner — reject or minimum

GDPR/CCPA banners on nearly all EU/UK sites. **Resolve BEFORE the main flow** and **BEFORE** `profile.export()`, so that you:
- don't save tracking cookies into the profile
- don't leave an overlay over the content (some sites don't return content until resolved)
- keep behavior deterministic across rents

### Priority of actions (descending)

1. **Reject all** / Decline / Refuse — direct button
2. **Customize / Settings / Manage preferences** → uncheck everything except necessary → Save
3. **Necessary only** / Strictly necessary — if separate button
4. **Accept all** — last resort. Before `profile.export()` explicitly filter tracking domains via `--domains <whitelist>`.

### Universal CDP fallback

```bash
ceki cdp $SID --method Runtime.evaluate --params '{
  "expression": "(()=>{const wants=[\"reject all\",\"decline\",\"refuse\",\"necessary only\",\"strictly necessary\"];const els=[...document.querySelectorAll(\"button,a,[role=button]\")];for(const t of wants){const b=els.find(e=>(e.textContent||\"\").trim().toLowerCase().includes(t));if(b){b.click();return t}}return null})()",
  "returnByValue": true
}'
```

Returns the text of the matched button or `null`.

### Known CMPs

| CMP | Reject selector |
|---|---|
| OneTrust | `#onetrust-reject-all-handler` |
| Cookiebot | `#CybotCookiebotDialogBodyButtonDecline` |
| Quantcast Choice | `.qc-cmp2-summary-buttons` → "Do not consent" |
| Custom | `button:has-text("Reject")`, `[aria-label*="reject" i]` |

### What NOT to do

- **Don't click "Accept all" automatically** — spoils profile cookies (tracking pixels, ad attribution).
- **Don't ignore the banner when it blocks via overlay** — some sites hide content behind the modal.
- **Don't run `profile.export()` before resolving the banner**.

## Pre-warm for captcha-protected sites

A fresh incognito = `.google.com` has no cookies → reCAPTCHA Enterprise sees "new device, no history" → starting score ≈ 0.0–0.3 → image-challenge → fail. Before signup/login on sites with reCAPTCHA / hCaptcha / Cloudflare Turnstile (Medium, Twitter/X, LinkedIn, Discord, Reddit on new machine, Quora) — **warm up the session**.

### Sequence (≈30-60s)

```bash
ceki navigate $SID https://www.youtube.com
sleep 7
ceki navigate $SID https://www.google.com
sleep 2
# focus search bar — click by coords (Google search field usually top-center)
ceki click $SID 640 280
ceki type $SID "ai news 2026"
# Enter via CDP keyboard event
ceki cdp $SID --method Input.dispatchKeyEvent --params '{"type":"keyDown","key":"Enter"}'
ceki cdp $SID --method Input.dispatchKeyEvent --params '{"type":"keyUp","key":"Enter"}'
sleep 5
sleep 10
ceki navigate $SID https://target-site.com/signup
```

In the same session, `NID/SOCS/__Secure-1PSID` for `.google.com` accumulate. On loading the target page reCAPTCHA sees the cookie history → starting score higher → checkbox captcha or silent v3 instead of image-challenge.

### Limitations

- **Does NOT substitute for residential IP**. If ASN isn't residential (VPN, AWS, Hetzner, OVH) — pre-warm may not pull score into green zone. Additive booster (one of 3-4 factors), not a silver bullet. With Ceki's real-Chrome residential hosts, this is already covered.
- Doesn't work across different sessions — each incognito is fresh.
- Warming adds ~30-60s to total signup time + a few cents billing.

### Anti-pattern

**Do NOT inject cookies from a pool** across sessions. reCAPTCHA Enterprise validates the triplet `(cookie, IP, fingerprint hash)` — a cookie from one device on another → "stolen cookie" marker → score drops even lower than with no cookie.

## Chat with the host

Each rental has a chat between your agent and the host. Use it to:
- ask the host to solve a captcha manually (after your 3 attempts)
- ask about session state ("did 2FA arrive?", "is the page loading for you?")
- warn about a long operation
- get a confirm before commit/payment

### CLI

```bash
# send
ceki chat $SID send "Can you tell me the 6-digit OTP from your phone?"

# wait for reply up to 120s
ANSWER=$(ceki chat $SID next --timeout=120 | jq -r .text)
[ "$ANSWER" = "null" ] && echo "no answer" && exit 1
echo "got: $ANSWER"
```

### Don't

- **Don't spam** — every message is seen by a real person; the plugin makes a sound. One question = one message, not three.
- **Don't forward secrets** to chat — the host gets the message.
- **Don't use chat as a log** — for debugging there's local logging.

## Python SDK (for long-running / advanced)

```python
import asyncio
from pathlib import Path
from ceki_sdk import connect, ConnectOptions

TOKEN = "your_api_key_here"

async def main():
    opts = ConnectOptions(
        relay_url="wss://browser.ceki.me/ws/agent",
        api_url="https://api.ceki.me",
        chat_url="https://chat.ceki.me/api/chat",
    )
    client = await connect(TOKEN, opts)

    options = await client.search({})       # list[ScheduleOption]
    if not options:
        print("No browsers online")
        await client.close()
        return

    browser = await client.rent(options[0].schedule_id, human="natural")
    try:
        await browser.navigate("https://example.com")
        await browser.click(120, 240)
        await browser.type("hello")

        png = await browser.screenshot(format="png")
        Path("/tmp/shot.png").write_bytes(png)

        snap = await browser.snapshot()
    finally:
        await browser.close()
        await client.close()

asyncio.run(main())
```

### Anti-detect — what's on by default

Built-in anti-bot evasion is **ON by default** for every rental. It defeats Cloudflare, DataDome, BasedFlare, Imperva, PerimeterX, Akamai across most flows. No configuration needed — just `rent` and go.

Two knobs you can touch:

| Knob | Default | Control |
|---|---|---|
| Humanizer (pauses + natural typing rhythm) | ON | `client.rent(human="natural"|"careful"|None)` |
| Masking mode | ON | `client.rent(masking_mode=False)` or `await browser.configure(masking_mode=False)` |

The rest runs automatically on the extension side. Don't override it unless you understand the implications.

JS/TS SDK doesn't have `human=` / `configure(masking_mode)` / `resume()` (Python only). Anti-bot evasion is active for js-sdk too.

## Saving and restoring a session

Each rental = a fresh browser tab. But cookies + localStorage + sessionStorage + fingerprint can be dumped to JSON and loaded into the next rental — saves login, captchas, anti-fraud triggers.

Since SDK v2.7.0 the profile includes the **fingerprint** of the current session.

### Saving (export)

```bash
ceki profile $SID export -o /tmp/reddit.json --domains .reddit.com,reddit.com --no-session-storage
```

### Restoring — two-step pattern

**Order is strict:** fingerprint via `rent()` (BEFORE session starts), cookies/storage via `import` (AFTER navigating to origin).

```bash
SID=$(ceki rent --schedule N --fingerprint-from /tmp/reddit.json | jq -r .session_id)
ceki navigate $SID "https://reddit.com"
ceki profile $SID import -i /tmp/reddit.json
```

### When NOT to use

- Smoke-check / one-shot — fresh incognito is more honest
- Cookies are stale — even valid JSON won't help

## Quickstart (Node / TypeScript)

```ts
import { Browser } from 'ceki';

const br = new Browser({
  token: process.env.CEKI_API_KEY!,
  relayUrl: 'wss://browser.ceki.me/ws/agent',
  apiUrl: 'https://api.ceki.me',
});
await br.connect();

const options = await br.search({});
if (options.length === 0) { console.log('no browsers'); await br.close(); process.exit(0); }

const session = await br.rent(options[0].scheduleId);
try {
  await session.send({ method: 'Page.navigate', params: { url: 'https://example.com' } });
} finally {
  await session.close();
  await br.close();
}
```

## Constraints (important)

- **NEVER create a session manually via `curl POST /api/sessions` and connect to `ws_url` by hand.** Use `ceki rent` — it handles handshake + agent-WS + attach + state. Mixing curl-create with CLI-drive does not work.
- **Don't hardcode schedule_id** — discover via `/api/browsers/search` every time.
- **The CLI is the primary interface.** Python SDK — only when you need callbacks (on_message / on_user_event), profile, raw CDP, send_image.
- **One tab per session.** A new navigation = a new event; `switch_tab` closes the previous.
- **Server stateless.** Server doesn't keep cookies/storage between rentals. Want persistence — `browser.profile.export()`.
- **Stop is mandatory** (`ceki stop $SID` or SDK `await browser.close()` in `finally`). Without explicit stop, session lives until host disconnects or your balance runs out.
- **Billing is real.** Marketplace rentals: $0.01/min, settled per minute in USDC. Self mode (your own Chrome): free, rate-limited.

## Readiness check

```bash
# 1. CLI installed?
ceki --help | head -1

# 2. Env var?
echo "$CEKI_API_KEY" | head -c 4   # should start with ag_

# 3. Token valid?
curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/auth/introspect | jq '.tokenable_id, .name'

# 4. Browsers online?
curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/browsers/search | jq '.meta.total, .data[].schedule_id'

# 5. Full round-trip (billing will tick ~$0.02)
SCHED=$(curl -s -H "Authorization: Bearer $CEKI_API_KEY" \
  https://api.ceki.me/api/browsers/search | jq -r '.data[0].schedule_id')
SID=$(ceki rent --schedule $SCHED | jq -r .session_id)
ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/ready.png | jq .ts
ceki stop $SID
```

## When NOT to use

- Pure HTTP API calls — use a regular fetch tool, no browser needed
- Cached static content — use existing scrapers
- Tests on `example.com` / `httpbin` — use headless Chrome locally
- Mass parallel scraping (>10 sessions concurrent) — contact us for volume tier

## Privacy + safety

- **No personal data leaves your machine** in self mode except task results
- **Cookies/credentials NEVER transmitted** to other parties
- **Marketplace mode:** the host sees what your agent does on their screen. Don't enter your own private creds in marketplace sessions.
- **Earn mode (opt-in):** your Chrome is sandboxed per session — agents that rent you can't access your other tabs, saved passwords, or local files.

## Get an API key

Sign up at [ceki.me](https://ceki.me) — email only, no KYC. Get an API key from the dashboard. Set as `CEKI_API_KEY` env var.

## Related

- [ceki-sdk on PyPI](https://pypi.org/project/ceki-sdk/) — version history and full reference
- [ceki.me/docs](https://ceki.me) — REST API + WebSocket protocol details
- Issue tracker: [github.com/Ceki-me/realbrowser-skill/issues](https://github.com/Ceki-me/realbrowser-skill/issues)
