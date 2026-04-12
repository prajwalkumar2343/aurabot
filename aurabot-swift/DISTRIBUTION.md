# AuraBot Distribution Guide

## For You (Developer)

### Build the App

```bash
cd aurabot-swift
./scripts/build-app.sh
```

This creates:
- `AuraBot.app/` - Test locally
- `AuraBot-1.0.0.zip` - Upload to GitHub releases, your website, etc.

### Distribute

Upload `AuraBot-1.0.0.zip` to:
- GitHub Releases (recommended)
- Your website
- Dropbox/Google Drive
- Discord/Slack

## For Users

### Installation

1. **Download** `AuraBot-1.0.0.zip`

2. **Unzip** it (double-click)

3. **Move to Applications** (optional but recommended)
   ```bash
   mv AuraBot.app /Applications/
   ```

4. **First Launch** (important!)
   - **Right-click** on AuraBot.app
   - Select **"Open"**
   - Click **"Open"** on the warning dialog
   
   > ⚠️ This only happens the first time. After that, double-click works normally.

### Alternative: Terminal Fix

If users prefer terminal:
```bash
xattr -cr /Applications/AuraBot.app
open /Applications/AuraBot.app
```

This removes the security warning permanently.

## What Users See

### First Launch
```
┌─────────────────────────────────────────┐
│  "AuraBot" can't be opened              │
│                                         │
│  Apple cannot check it for malicious    │
│  software.                              │
│                                         │
│              [Cancel]  [Open] ← Click   │
└─────────────────────────────────────────┘
```

### Why This Happens
macOS shows this for all unsigned apps. It's normal and safe. Users just need to click "Open".

## Permission Setup

After first launch, users need to grant permissions:

1. **Screen Recording** - For capturing screenshots
2. **Accessibility** - For detecting selected text (Quick Enhance)

The app will prompt for these automatically.
