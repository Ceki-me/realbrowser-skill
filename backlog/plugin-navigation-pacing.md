# Plugin Backlog: Navigation Pacing Before First Interaction

**Status:** 🆕 Proposed
**Priority:** Medium (gives +5-10% on DataDome/Cloudflare Enterprise)
**Area:** `sw/background.js` — CDP session handling
**Depends on:** None

## Problem

When an agent calls `navigate()` followed immediately by `click()` or `type()`, the plugin processes both commands back-to-back. Even though mouse bezier paths and human typing are already implemented, the **time-to-first-interaction** is unrealistically short.

Anti-bot systems (DataDome, Cloudflare Enterprise, Turnstile) track:
- Time between `Page.navigate` completion and first `Input.dispatchMouseEvent`
- Presence of scroll events between navigation and interaction
- Natural "reading" pauses

Currently: agent sends `ceki navigate ... && sleep 0.5 && ceki click` → plugin fires commands without any interstitial pacing.

## Solution

Add a **navigation pacing phase** before the first user interaction on each fresh page load. This should live as an automatic interceptor in the plugin's command processing, not something every agent has to code.

### Suggested implementation

In `sendCommand()` (line 1166), after the `Page.navigate` and before allowing any `Input.dispatchMouseEvent` or `Input.dispatchKeyEvent` on a newly navigated page:

```js
const PACING = {
  minReadMs: 1500,
  maxReadMs: 4000,
  minScrollDepth: 0.3,
  maxScrollDepth: 0.7,
  scrollJitterMs: { min: 300, max: 1200 },
  preClickPauseMs: { min: 200, max: 600 }
};
```

Phase sequence:
1. **Read pause**: `PACING.minReadMs + random(PACING.maxReadMs - PACING.minReadMs)` — no input at all
2. **Pre-scroll**: evaluate `document.body.scrollHeight`, scroll down to a random fraction (`minScrollDepth`–`maxScrollDepth`) in 1-2 segments
3. **Post-scroll pause**: `PACING.scrollJitterMs.min–max` — mimics "reading what just scrolled"
4. **Scroll back** to the original viewport position (or near the target element)
5. **Pre-click pause**: `PACING.preClickPauseMs.min–max` — mimics hovering/deciding

### Where to hook

The best place is in `handleMouseClick()` (line 1223) and the first `Input.dispatchMouseEvent` after a `Page.navigate` completes. Add a `needsPacing` flag that resets on each `Page.frameNavigated` event (the listener already exists at line 1304).

### Configurability

Add session-level config so `ceki rent --pacing-profile aggressive` can select the pacing intensity:

| Setting | Pause range | Scroll passes |
|---------|------------|---------------|
| `minimal` | 200-800ms | 0 (skip) |
| `normal` (default) | 1500-4000ms | 1-2 |
| `aggressive` | 3000-7000ms | 2-3 |
| `random` | random from all | 0-3 |

### Existing infrastructure

The plugin already has:
- `generateTrajectory()` for bezier mouse (reuse for scroll easing if needed)
- `firstNavigateDone` flag (line 1177) — but it's too basic (only 500-1500ms)
- `handleMouseClick()` intercepts all mouse presses — add pacing check here
- `Page.frameNavigated` event handler — reset pacing flag here

### Effort estimate

- ~50 lines of new JS code
- 1 new config object (pacing profiles)
- No new dependencies
- Changes only in `sw/background.js`

### Acceptance criteria

- [ ] No commands are processed for 1.5-4s after `Page.navigate` completes
- [ ] A pre-scroll phase generates scroll depth before first interaction
- [ ] Behaviour is configurable per session (profile setting)
- [ ] Works with existing `humanize` typing + mouse bezier features
- [ ] Does NOT apply to subsequent navigations (same-tab link clicks), only full page loads
