# Changelog

All notable changes to RealBrowser by Ceki will be documented here.

## v0.1.0 — 2026-06-20

Initial public release.

### Features

- Three modes: **Self** (own Chrome, free when host_user == renter_user), **Marketplace** ($0.01/min in USDC), **Earn** (opt-in, 90% revenue share)
- CLI subcommands: rent, search, snapshot, navigate, click, type, scroll, switch-tab, configure, cdp, wait, chat, profile, upload, request-captcha, sessions, stop
- Python + Node.js SDKs (cli is primary, SDK for callbacks / advanced)
- MCP integration examples for Claude Desktop, Cursor, Cline
- Built-in anti-bot evasion (default ON), defeats Cloudflare, DataDome, BasedFlare, Imperva, PerimeterX, Akamai
- Pre-warm pattern for captcha-protected sites
- Profile export/import (cookies + storage + fingerprint)
- Cookie consent banner handling (CDP fallback)
- Chat with the host (for captcha solving, OTP, confirms)
- Crypto-only payouts: USDC on Base / Tron / Polygon / Solana

### Notes

- Ceki Chrome extension (for Self mode setup): https://browser.ceki.me/install
- Listing on ClawHub: https://clawhub.ai/skills/realbrowser
- Source: https://github.com/Ceki-me/realbrowser-skill
