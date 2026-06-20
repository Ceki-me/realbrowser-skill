# RealBrowser by Ceki

> **Give your AI agent a human disguise.**
>
> Real Chrome from real humans. Defeats Cloudflare, DataDome, BasedFlare, Imperva, PerimeterX, Akamai.

Anti-bot vendors fingerprint your AI agent in milliseconds — Canvas, WebGL, JA3/JA4 TLS, mouse patterns, IP ASN. Headless browsers and datacenter proxies fail every check.

This skill plugs your OpenClaw / Claude Desktop / Cursor / Cline agent into a **real Chrome on a real device**:

- **Self mode** — use your OWN Chrome after installing the [Ceki extension](https://browser.ceki.me/install). **Free** when host_user == renter_user.
- **Marketplace mode** — rent Chrome from a real human host worldwide. **$0.01/min**, settled in USDC.
- **Earn mode** (opt-in) — share your idle Chrome → other agents pay you. **90% revenue share** to you.

No SaaS. No datacenter proxies. No fingerprint spoofing libraries that break next week.

## Install

```bash
clawhub skill install realbrowser
```

Or standalone CLI:

```bash
pip install --upgrade ceki-sdk --break-system-packages
```

## Get API key

1. Sign up at [ceki.me](https://ceki.me) — email only, no KYC
2. Dashboard → API keys → create one
3. Export:

```bash
export CEKI_API_KEY="your_key_here"
```

## Quickstart

```bash
# discover available browsers
ceki search --limit 5

# rent one
SID=$(ceki rent --schedule <schedule_id> | jq -r .session_id)

# drive it
ceki navigate $SID https://example.com
ceki snapshot $SID -o /tmp/01.png
ceki click $SID 400 300
ceki type $SID "hello world"

# stop
ceki stop $SID
```

## See also

- **[SKILL.md](./SKILL.md)** — full reference for AI agents using this skill
- **[examples/](./examples/)** — integration configs for Claude Desktop, Cursor, Cline
- **[ceki.me](https://ceki.me)** — marketplace dashboard, API key management
- **[ceki-sdk on PyPI](https://pypi.org/project/ceki-sdk/)** — Python SDK + CLI

## License

MIT. See [LICENSE](./LICENSE).
