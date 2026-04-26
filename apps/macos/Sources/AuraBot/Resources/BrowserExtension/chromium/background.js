importScripts("settings.js");

chrome.runtime.onInstalled.addListener(async () => {
  const existing = await chrome.storage.sync.get(DEFAULT_SETTINGS);
  await chrome.storage.sync.set({ ...DEFAULT_SETTINGS, ...existing });
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type !== "AURABOT_CONTEXT") {
    return false;
  }

  postContext(message.context, sender.tab)
    .then(() => sendResponse({ ok: true }))
    .catch((error) => sendResponse({ ok: false, error: String(error) }));

  return true;
});

chrome.tabs.onActivated.addListener(({ tabId }) => {
  requestTabContext(tabId, "tab_activated");
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete" || changeInfo.url || changeInfo.title) {
    requestTabContext(tabId, "tab_updated");
  }
});

async function requestTabContext(tabId, reason) {
  try {
    await chrome.tabs.sendMessage(tabId, {
      type: "AURABOT_COLLECT_CONTEXT",
      reason
    });
  } catch {
    // The tab may not have a content script, e.g. browser settings pages.
  }
}

async function postContext(rawContext, tab) {
  const settings = await chrome.storage.sync.get(DEFAULT_SETTINGS);
  if (!settings.captureEnabled) {
    return;
  }

  const context = sanitizeContext(rawContext, tab);
  const endpoint = `${String(settings.serverURL || DEFAULT_SETTINGS.serverURL).replace(/\/+$/, "")}/browser/context`;
  const headers = {
    "Content-Type": "application/json"
  };

  if (settings.apiKey) {
    headers.Authorization = `Bearer ${settings.apiKey}`;
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers,
    body: JSON.stringify(context)
  });

  if (!response.ok) {
    throw new Error(`AuraBot context update failed: ${response.status}`);
  }
}

function sanitizeContext(context, tab) {
  const privateWindow = Boolean(tab?.incognito);
  const safeContext = {
    ...context,
    privateWindow,
    timestamp: new Date().toISOString()
  };

  if (privateWindow) {
    delete safeContext.visibleText;
    delete safeContext.selectedText;
    delete safeContext.readableText;
    safeContext.textCaptureMode = "private_window_metadata_only";
  }

  return safeContext;
}
