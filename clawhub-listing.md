# ClawHub listing copy

For submission to clawhub.ai listing.

---

## Title (max ~60 chars)
**RealBrowser by Ceki — Give your AI agent a human disguise**

## Subtitle (~120 chars)
**Real Chrome from real humans. Defeats Cloudflare, DataDome, BasedFlare. Free for your own. $0.01/min marketplace.**

## Short description (~200 chars)
Plug your AI agent into a real residential Chrome — your own (free) or rented from real human hosts ($0.01/min, USDC). Real IP, real fingerprint, real history. Sites can't tell.

## Long description (markdown allowed)

Anti-bot defeats your AI agent? Cloudflare, DataDome, BasedFlare, Imperva, PerimeterX, Akamai — all of them flag headless browsers, datacenter IPs, and fake fingerprints in milliseconds.

This skill plugs your OpenClaw / Claude Desktop / Cursor / Cline agent into a **real Chrome on a real device**:

- **Real residential ISP IP** (not datacenter)
- **Real canvas/WebGL/font/audio fingerprint** (matches a real device)
- **Real session history and cookies**
- **Real mouse acceleration patterns** (from actual host hardware)
- **Real timezone, real language, real OS**

Sites can't tell your agent apart from a person. Because, mechanically, the request IS coming from a real person's machine.

### Three modes

| Mode | Where | Cost |
|---|---|---|
| **Self** | Your OWN Chrome, after installing the [Ceki extension](https://browser.ceki.me/install) | FREE when host_user == renter_user |
| **Marketplace** | Real Chrome rented from real human hosts worldwide | $0.01/min, USDC |
| **Earn** (opt-in) | Share your idle Chrome → agents rent → you get USDC | 90% to you |

### Install

```bash
clawhub skill install realbrowser
```

### Get API key

1. Sign up at [ceki.me](https://ceki.me) — email only, no KYC
2. Dashboard → API keys → create one
3. Export: `export CEKI_API_KEY="your_key_here"`

### Use

```bash
SID=$(ceki rent --schedule <schedule_id> | jq -r .session_id)
ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/01.png
ceki click $SID 400 300
ceki type $SID "hello"
ceki stop $SID
```

No SaaS. No datacenter proxies. No fingerprint spoofing libraries that break next week. Just real Chrome on real devices, paid by the minute in USDC.

---

## Tags / keywords
`browser`, `automation`, `ai-agent`, `anti-bot`, `residential`, `chrome`, `scraping`, `cloudflare`, `datadome`, `marketplace`, `mcp`, `usdc`, `web3`

## Category
`browser` / `automation` / `marketplace`

## License
MIT

## Author
iWedmak (GitHub)

## Links
- Homepage: https://ceki.me
- Repo: https://github.com/Ceki-me/realbrowser-skill
- Docs: https://ceki.me (TBD `/docs` or `/for-agents`)
- Issues: https://github.com/Ceki-me/realbrowser-skill/issues
- PyPI: https://pypi.org/project/ceki-sdk/

## Permissions to declare (per ClawHub post-ClawHavoc policy)
- `network.outbound`: api.ceki.me, browser.ceki.me, chat.ceki.me
- `process.spawn`: node, python3, ceki
- `filesystem.read`: ~/.ceki/sessions/
- `filesystem.write`: ~/.ceki/sessions/, /tmp/

## Why this skill is safe (for ClawHavoc reviewers)
- Open source (MIT, github.com/Ceki-me/realbrowser-skill)
- No credential transmission — auth via single API key the user generates
- No filesystem writes outside ~/.ceki and /tmp
- Network outbound limited to ceki.me subdomains (declared)
- No process spawn beyond ceki CLI invocation
- Self-mode does NOT transmit user's Chrome data to third parties (only routing through Ceki dispatcher for agent task execution)
