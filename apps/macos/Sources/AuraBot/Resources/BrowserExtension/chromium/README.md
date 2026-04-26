# AuraBot Browser Context Extension

This is the Chromium Manifest V3 browser context sender for the AuraBot macOS app.

## What It Sends

- Active URL and title
- Browser name and bundle identifier
- Activity: browsing, scrolling, or media
- Scroll percentage
- Viewport signature
- Visible viewport text, capped at 8 KB
- Selected text, capped at 2 KB
- `visibleTextHash`
- Optional readable page text, capped at 64 KB
- `readableTextHash`

Full readable page text is disabled by default. The extension skips page text capture on sensitive hostnames, pages with password fields, and private/incognito tabs.

## Local Setup

1. Open `chrome://extensions`.
2. Enable Developer mode.
3. Load this directory as an unpacked extension.
4. Open the extension options page.
5. Set the local server URL, usually `http://127.0.0.1:7345`.
6. Paste the AuraBot browser extension API key from the macOS app settings.
7. Enable "Capture full readable page text" only if raw page text should be sent transiently to the app.

The macOS app receives the payload at `POST /browser/context`. Raw readable page text is accepted by the app-side context object, but memory persistence should store hashes and a short summary/excerpt instead of the full body.
