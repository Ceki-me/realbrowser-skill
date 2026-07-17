---
name: realbrowser
description: Lets your AI agent drive a real Chrome session (yours or a marketplace participant's) for tasks where headless or scripted requests are not enough — your own QA flows, accessibility audits of sites you control, synthetic monitoring, support-dashboard automation, and data collection on sites whose Terms of Service and robots.txt permit it.
when_to_use: An AI agent has a task on a site WHERE YOU HAVE EXPLICIT AUTHORIZATION to operate (your own web app, your own dashboard, a public dataset with permissive Terms of Service, an accessibility audit you're responsible for) and the task requires a real Chrome with JS execution, full layout, and a residential network path because a headless browser or HTTP client would miss something important about the experience.
---

# RealBrowser by Ceki — real Chrome sessions for AI agents

> **Use responsibly.** This skill drives a real Chrome browser. Before using it on any site, confirm you have authorization (your own site, your own account, permissive Terms of Service, explicit consent of the site owner). The skill does not enable anything you wouldn't be allowed to do manually.

## What this skill does

It lets your agent open a Chrome session, navigate, click, type, scroll, take screenshots, and read the page — through one of three paths:

1. **Self mode** — your own Chrome on your own machine, via the [Ceki extension](https://browser.ceki.me/install). Free for sessions where the host and the renter are the same user.
2. **Marketplace** — a Chrome session contributed by another user who opted in to host. Settled per minute in USDC.
3. **Earn (opt-in)** — your own Chrome contributed to the marketplace so other users' agents can rent it. Off by default.

The skill is a thin client to the `ceki-sdk` CLI and Python SDK. It does not bundle credentials, does not perform any network operation other than CLI invocations you make explicitly, and does not transmit any data outside the API endpoints documented below.

## Appropriate use cases

- **QA / E2E testing of your own web apps** — drive a real browser through user flows on a staging or production site you own
- **Accessibility audits** — sites you are responsible for
- **Synthetic monitoring** — heartbeat your own services as a real user would experience them
- **Customer support automation** — actions in your own dashboards, on behalf of your own users with their consent
- **Personal research / data collection** — on sites whose Terms of Service and `robots.txt` permit it
- **Public-data extraction** — public-record sites, open APIs presented as HTML, news, etc., respecting `robots.txt`

## NOT appropriate use cases

- Sites you do not own and whose Terms of Service do not permit automated access
- Account creation on services other than your own
- Filling forms with data that isn't yours or that isn't accurate
- Circumventing access controls, login walls, age gates, or paywalls
- Anything that violates local law where you, the host, or the target site operates
- Banking, payments under another identity, KYC flows for someone else

If you're not sure whether your use case is appropriate, default to: **don't use this skill, ask the site owner**.

## Privacy and consent

- **Marketplace mode shares your task with a real human host.** The host can see (and may record/stream) what your agent does in their browser. Do not enter your personal credentials, payment data, or private content into marketplace-mode sessions. Use Self mode for anything sensitive.
- **Earn mode shares your Chrome with someone else's agent.** They cannot see your other tabs or your saved passwords (the session is sandboxed in a fresh Chrome profile), but they can see what their own session is doing on your machine. Toggle off if you don't want this.
- **Screenshots and chat are visible** to the host (marketplace mode) and to you (host of an earn-mode session). Don't rely on the skill for confidential workflows.
- **Cookies and storage** are not retained on the server between rentals (the server is stateless). If you need persistence, use the local `profile export` / `profile import` flow to manage it yourself.

## Quickstart

### Install

```bash
clawhub skill install realbrowser
```

Or install the CLI standalone:

```bash
pip install --upgrade ceki-sdk --break-system-packages   # v2.18.0+
ceki --help
```

### Sign up for an API key

1. Go to https://ceki.me and create an account (email only, no KYC for individual hosts and renters)
2. Open your dashboard → API keys → create one
3. Export it in your shell, **only when you're about to use the CLI**:

```bash
export CEKI_API_KEY="your_key_here"
```

The skill does NOT transmit your API key during installation. Token verification is a separate, opt-in step you run manually after the skill is installed.

### Use

```bash
# discover marketplace browsers (does not rent anything; no charges)
ceki search --limit 5

# rent a Chrome (incurs marketplace charges if you're not host_user == renter_user)
SID=$(ceki rent --schedule <schedule_id> | jq -r .session_id)

# drive
ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/01.png
ceki click $SID 400 300
ceki type $SID "hello world"

# stop (releases the rental and settles)
ceki stop $SID
```

## Modes

| Mode | Where | Cost | Visibility |
|---|---|---|---|
| **Self** | Your own Chrome (after installing the [Ceki extension](https://browser.ceki.me/install)) | Free when host_user == renter_user | Only you |
| **Marketplace** | Chrome contributed by another opted-in user | $0.01/min, USDC | The host can see your session |
| **Earn** (opt-in, off) | Your idle Chrome contributed back to the marketplace | You receive 90% of session price | Other agents you allow can rent your Chrome |

## Native commands vs CDP

The CLI splits into **native** (high-level — server bridges to the host's Chrome) and **CDP** (`ceki cdp` — raw Chrome DevTools Protocol). Different channels.

| Need | Command | Channel |
|---|---|---|
| Open URL | `ceki navigate` | native |
| Capture state (screen + chat + ts) | `ceki snapshot -o` | native |
| Click / type / scroll | `ceki click` / `type` / `scroll` | native |
| Check whether rental is alive | `ceki snapshot` / `ceki sessions` | native |
| Chat with the host | `ceki chat send/next` | native |

**Default state probe:** `ceki snapshot $SID -o PATH`. One command returns `{chat, screenshot, ts}`.

### CDP `no_session` ≠ end of rental

`ceki cdp $SID --method Runtime.evaluate ...` may return `no_session` while the rental itself is alive. Check liveness via native commands (`ceki snapshot`, `ceki sessions`).

## Rate limits

- **20 rents / hour** per API key. Plan batches accordingly.
- **A full rental cancel (`ceki stop`) also counts in the rate bucket.** Keep one session open and navigate between sites instead of stop+rent per site.
- **CDP rate limit:** session capped at 500 commands / 60s.
- **Browser exclusivity:** one active rental of a browser at a time.

## Lifecycle

```
ceki rent --schedule N       ───►  {session_id, schedule_id, chat_topic_id}
ceki navigate <sid> <url>    ───►  {ok: true}
ceki snapshot <sid> -o path  ───►  {chat:[...], screenshot:path, ts:...}
ceki click/type/scroll/cdp   ───►  {ok: true}
ceki chat <sid> send/next    ───►  {message_id|text|null}
ceki stop <sid>              ───►  {ok: true}
```

**Always stop.** Without `ceki stop`, the rental keeps the meter running until the host disconnects or your balance runs out.

## Subcommand reference

| cmd | args | result |
|---|---|---|
| `rent` | `--schedule N` (required) `[--mode incognito|main]` `[--fingerprint-from profile.json]` | `{session_id, chat_topic_id, schedule_id}` |
| `search` | `[--limit N] [--filter key=val]...` | `[BrowserOption, ...]` |
| `snapshot <sid>` | `-o PATH` | `{chat, screenshot, ts}` |
| `screenshot <sid>` | `-o file.png [--format png|jpeg] [--full]` | raw image to file |
| `navigate <sid> <url>` | — | `{ok:true}` |
| `click <sid> <x> <y>` | — | `{ok:true,pointer:[x,y]}` |
| `type <sid> "<text>"` | `[--no-human]` (skip humanizer) | `{ok:true}` |
| `scroll <sid> <x> <y> <dy>` | — | `{ok:true}` |
| `switch-tab <sid>` | — | `{ok:true}` |
| `chat <sid> send/next/history` | various | message or batch |
| `cdp <sid>` | `--method <M> [--params JSON]` | raw CDP response |
| `wait <sid>` | — | blocking until session ends |
| `profile <sid> export/import` | various | profile JSON (your machine) |
| `upload <sid>` | `--selector ... --file ...` | `{ok, filename, size}` |
| `sessions` | — | your active sessions |
| `stop <sid>` | — | `{ok:true}` |

## Worked example: drive your own app for a synthetic monitoring check

```bash
# 1. Rent (or use Self mode if you're hosting your own Chrome)
SID=$(ceki rent --schedule <your_schedule_id> | jq -r .session_id)

# 2. Run through your own user flow
ceki navigate $SID https://my-app.example.com/login
ceki type $SID "test@my-app.example.com"
ceki click $SID 400 500
ceki type $SID "my-test-password"
ceki click $SID 400 600

# 3. Verify the post-login state
ceki snapshot $SID -o /tmp/after-login.png

# 4. Done
ceki stop $SID
```

## Text input — `ceki type` always

**Fill fields ONLY via `ceki type $SID "text"`.** Don't reach into `ceki cdp Runtime.evaluate` with `el.value=...` for input — that's the main cause of "field empty / required" on submit (React/Vue value trackers).

After filling async-validated fields (username availability, email-availability), move focus away (`blur`) so validation fires:

```bash
ceki type $SID "octocat-demo"
ceki cdp $SID --method Runtime.evaluate --params '{"expression":"document.activeElement.blur()"}'
```

## File upload

```bash
ceki upload $SID --selector 'input[type="file"]' --file /tmp/avatar.png
```

## window.open patch (when buttons open new tabs)

Some web apps open new tabs via `window.open(url)`. The CLI sees this as a tab switch, which can break the sequence. Preemptively redirect window.open before the click:

```bash
ceki cdp $SID --method Runtime.evaluate --params '{
  "expression": "window.open=function(url){window.location.href=url;return window;};"
}'
```

## Cookie consent banners

**Always honor the site's consent preferences.** When a banner appears, reject non-essential cookies, or click the appropriate "necessary only" / "reject all" option. Do not click "accept all" by default.

```bash
ceki cdp $SID --method Runtime.evaluate --params '{
  "expression": "(()=>{const wants=[\"reject all\",\"decline\",\"necessary only\",\"strictly necessary\"];const els=[...document.querySelectorAll(\"button,a,[role=button]\")];for(const t of wants){const b=els.find(e=>(e.textContent||\"\").trim().toLowerCase().includes(t));if(b){b.click();return t}}return null})()"
}'
```

## Saving and restoring a session

The server does not retain cookies or storage between rentals (stateless by design — privacy / data minimization). You can export them to a local file at the end of a session and import on the next one — but only do this for sites you have authorization to use, and only for accounts that are yours.

```bash
SID=$(ceki rent --schedule N --fingerprint-from /tmp/my-app.json | jq -r .session_id)
ceki navigate $SID "https://my-app.example.com"
ceki profile $SID import -i /tmp/my-app.json
```

## Python SDK (for advanced flows)

```python
import asyncio
import os
from pathlib import Path
from ceki_sdk import connect, ConnectOptions

async def main():
    token = os.environ.get("CEKI_API_KEY")
    if not token:
        raise SystemExit("Set CEKI_API_KEY")

    opts = ConnectOptions(
        relay_url="wss://browser.ceki.me/ws/agent",
        api_url="https://api.ceki.me",
        chat_url="https://chat.ceki.me/api/chat",
    )
    client = await connect(token, opts)
    options = await client.search({})
    if not options:
        await client.close()
        return
    browser = await client.rent(options[0].schedule_id)
    try:
        await browser.navigate("https://my-app.example.com")
        png = await browser.screenshot(format="png")
        Path("/tmp/shot.png").write_bytes(png)
    finally:
        await browser.close()
        await client.close()

asyncio.run(main())
```

## Constraints

- **Never create a session manually via raw `curl POST /api/sessions` + WS connect.** Use `ceki rent`.
- **Don't hardcode schedule_id.** Discover via `/api/browsers/search` each time.
- **Server is stateless** between rentals. Use `profile export` / `import` for persistence — and only for your own accounts.
- **Stop is mandatory.** Without `ceki stop`, the rental keeps the meter running.
- **Billing is real** in marketplace mode: $0.01/min, settled in USDC per minute.

## 🧠 Behavioral Profiles

> The browser already handles mouse bezier paths, human typing cadence, and fingerprint emulation automatically. This layer is about **pacing** — the rhythm of interaction that makes a session look like a specific type of person.

Choose a profile that fits your task's target. Each profile encodes reading speed, scroll habits, typing rhythm, active hours, and hesitation patterns. Profiles live in the `profiles/` directory next to this SKILL.md.

### Profile index

| Profile | Gender | Age | Vibe | Best for |
|---------|--------|-----|------|----------|
| `teen-girls-12-15` | female | 12-15 | Fast social scroll, TikTok reflexes | Gen-Z social platforms |
| `teen-boys-16-19` | male | 16-19 | Impulsive clicks, fast typing, gaming late nights | Gaming, esports, Discord |
| `college-female-18-24` | female | 18-24 | Mixed social + academic, moderate pace | University portals, social mix |
| `college-male-18-24` | male | 18-24 | Night owl, targeted browsing, tech-aware | Coursework, tech research |
| `urban-professional-female-25-34` | female | 25-34 | Professional speed, measured scroll, careful typing | Corporate sites, LinkedIn |
| `urban-professional-male-25-34` | male | 25-34 | Direct, purpose-driven, moderate pace | SaaS dashboards, news, finance |
| `tech-worker-25-40` | any | 25-40 | Fast, efficient, minimal scroll, high WPM | GitHub, docs, dev tools |
| `creative-professional-25-40` | any | 25-40 | Meandering, visual browsing, erratic pauses | Dribbble, Behance, portfolios |
| `parent-30-45` | any | 30-45 | Interrupted browsing, efficient, early hours | E-commerce, family services |
| `executive-35-55` | any | 35-55 | Brief, fast bursts, minimal scroll, early-start | Bloomberg, dashboards, email |
| `middle-aged-female-35-50` | female | 35-50 | Thorough reading, careful typing, social | Facebook, recipe sites, health |
| `middle-aged-male-35-50` | male | 35-50 | Linear scroll, functional typing, news | News sites, sports, finance |
| `senior-female-50plus` | female | 50+ | Very slow, reads all text, one-finger typing | Health portals, email, community |
| `senior-male-50plus` | male | 50+ | Very slow, deliberate clicks, cautious | Banking, Medicare, news |
| `gamer-16-30` | any | 16-30 | Fastest clicks, erratic mouse, late nights | Steam, Twitch, gaming wikis |
| `social-media-power-user-16-30` | any | 16-30 | Infinite scroll, constant likes, fast reaction | TikTok, Instagram, X/Twitter |
| `rural-user-all-ages` | any | 15-80 | Daytime, moderate-slow, limited keyboard familiarity | General browsing, local news |
| `freelancer-20-40` | any | 20-40 | Irregular schedule, mixed fast/slow, task-switching | Upwork, client portals, email |
| `student-highschool-14-18` | any | 14-18 | Skim-heavy, after-school hours, trackpad native | Google Classroom, social, homework |
| `night-shift-worker-22-60` | any | 22-60 | Inverted hours, slower at night, higher backspace | Late-night browsing, Amazon |

#### Domain-specific profiles

Built from scraping patterns of existing open-source parsers for each platform. These encode **site-specific interaction strategies** — lazy-load triggers, modal waits, button selectors, and required scroll patterns.

| Profile | Extracted from | Key pattern |
|---------|---------------|-------------|
| `domain-instagram` | ScrapeClaw, instascrape, drawrowfly | Infinite scroll 200-400px/pass, 2-4s pause (image consumption), modal open 1-2s |
| `domain-twitter` | proxidize/x-scraper, ScrapeClaw, hermes-agent | Fast timeline scroll, 1-3s per tweet cluster, 'Show more' expand + 1-2s wait |
| `domain-linkedin` | joeyism/linkedin_scraper v3, ManiMozaffar | **Must scroll full profile** — sections lazy-load! 2-4s pause per section |
| `domain-tiktok` | ScrapeClaw, drawrowfly, scrapfly.io | Vertical full-viewport swipe (700px), 3-8s 'watching' pause between videos |
| `domain-youtube` | ScrapeClaw, scrapfly.io | Scroll 700px past player to trigger **comment lazy-load** (2-3s render wait) |
| `domain-facebook` | ScrapeClaw facebook-scraper | Slow feed scroll 3-8s per post cluster, modal photo load 1-2s |
| `domain-amazon` | Generic e-com scrapers, Scrapfly | Scroll past fold for **description lazy-load** (800px), targeted not aimless |
| `domain-reddit` | Public Playwright automations | Feed skim + comment chain expand, 1-2s load per collapsed thread |

Each file includes `platform_specific.selectors_css`, `platform_specific.sequence_hint`, and `login` timing. Read the file before starting a session on that site.

### ⚠️ Critical Rule — Pick One, Stick to It

Anti-bot systems fingerprint your **behavioural signature** across the session. Switching between profiles mid-session (e.g. teen scroll speed then senior pauses) creates an impossible pattern that flags immediately.

**→ Choose ONE profile before `ceki rent` and follow its pacing for the entire session.**

```bash
# DURING SESSION SETUP — pick one that fits the target, then NEVER CHANGE
cat profiles/domain-linkedin.json        # read it to internalise pace
cat profiles/urban-professional-male-25-34.json  # your persona for this session

# Then pace your session accordingly — the CLI is the instrument:
ceki navigate $SID <url>
sleep {post_navigate_pause}       # from profile

ceki scroll $SID 0 0 {depth}     # first scroll pass — shallow
sleep {pause_between_passes}
ceki scroll $SID 0 0 {depth*2}   # deeper
sleep {pause_between_passes}

ceki click $SID X Y              # first action after "reading"
ceki type $SID "text"            # humanizer ON by default
sleep {inter_action_pause}
ceki click $SID X2 Y2            # next interaction
```

### Key profile parameters explained

```
typing.wpm            → character cadence (lower = more human pauses)
typing.think_prob     → probability of mid-typing hesitation
typing.backspace_freq → how often user corrects themselves

scroll.passes         → how many scroll segments before interacting
scroll.speed_px_per_ms → how fast the scroll feels

navigation.post_navigate_pause_ms → "reading" time before first action
                                     (highest impact on DataDome/CF)

mouse.speed           → base speed of bezier mouse movement
mouse.curvature       → how curved the path is (higher = more erratic)
mouse.jitter          → variance in per-step delay (higher = shakier cursor)
```

### Lazy-load trigger

When a page has lazy-loaded images or infinite scroll sections, the browser's built-in `ceki click` won't trigger them because the element is outside the viewport. Always pre-scroll:

```bash
# STEP 1 — gradual scroll to bottom
ceki scroll $SID 0 0 $(ceki cdp $SID --method Runtime.evaluate \
  --params '{"expression":"document.body.scrollHeight"}' | jq '.result.value * 0.3 | floor')
sleep 600

ceki scroll $SID 0 0 $(ceki cdp $SID --method Runtime.evaluate \
  --params '{"expression":"document.body.scrollHeight * 0.6 | floor()"}' | jq '.result.value')
sleep 400

ceki scroll $SID 0 0 $(ceki cdp $SID --method Runtime.evaluate \
  --params '{"expression":"document.body.scrollHeight * 0.9 | floor()"}' | jq '.result.value')
sleep 500

# STEP 2 — scroll back to target and interact
ceki scroll $SID target_x target_y 0
sleep 300
ceki click $SID target_x target_y
```

Each scroll step triggers IntersectionObserver → lazy images load → analytics scroll-depth events fire.

### Why this matters

Anti-bot systems (DataDome, Cloudflare Enterprise) build behavioural profiles per session:
- **Time-to-first-interaction** — a human doesn't click 100ms after navigation
- **Scroll pattern** — humans scroll in bursts with pauses, not one smooth motion
- **Typing cadence** — constant 900ms between keys is a bot signature
- **Inter-action timing** — same gap between every click → flag

Picking a coherent profile and following its pacing is worth **5-10% pass rate** on aggressive anti-bot targets, on top of what the browser's built-in stealth already provides.

## Readiness check

```bash
ceki --help | head -1
echo "$CEKI_API_KEY" | head -c 4   # should start with ag_
# Manually verify token (one-off, when you're ready):
curl -s -H "Authorization: Bearer $CEKI_API_KEY" https://api.ceki.me/api/auth/introspect | jq '.tokenable_id, .name'
# Discover available browsers
curl -s -H "Authorization: Bearer $CEKI_API_KEY" https://api.ceki.me/api/browsers/search | jq '.meta.total'
```

## When NOT to use

- Sites you don't own and whose Terms of Service prohibit automated access
- Tests on `example.com` / `httpbin` — use a headless Chrome locally
- Pure HTTP API calls — use a regular fetch tool, no browser needed
- Cached static content — use existing scrapers
- Anything you wouldn't be allowed to do manually

## Privacy + data handling

- **No personal data is transmitted to Ceki** beyond the API key (Bearer auth) and the task payload you explicitly send via the SDK
- **Cookies, credentials, browsing history** are not transmitted to the server — they live inside the rented Chrome session and are discarded when the session ends
- **In marketplace mode**, the host of the Chrome can see whatever your session is doing on their screen. Treat the host as a third party. Do not use marketplace sessions for confidential work.
- **In earn mode**, the renter of your Chrome can see whatever their session is doing in your browser, but not your other tabs, saved passwords, or local files (the session runs in a clean Chrome profile)

## License

MIT. See `LICENSE`.

## Links

- [Homepage](https://ceki.me)
- [ClawHub listing](https://clawhub.ai/skills/realbrowser)
- [Source code (GitHub)](https://github.com/Ceki-me/realbrowser-skill)
- [Source code (Codeberg mirror)](https://codeberg.org/cekibrowser/realbrowser-skill)
- [ceki-sdk on PyPI](https://pypi.org/project/ceki-sdk/)
- [Ceki Chrome extension (for Self mode)](https://browser.ceki.me/install)
- [Issue tracker](https://github.com/Ceki-me/realbrowser-skill/issues)
