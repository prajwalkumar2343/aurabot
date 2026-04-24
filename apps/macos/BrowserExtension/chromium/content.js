const CONTEXT_SCHEMA_VERSION = 1;
const DEDUPE_WINDOW_MS = 1500;
const MAX_VISIBLE_TEXT = 8 * 1024;
const MAX_SELECTED_TEXT = 2 * 1024;
const MAX_READABLE_TEXT = 64 * 1024;
const SKIPPED_TAGS = new Set([
  "SCRIPT",
  "STYLE",
  "NOSCRIPT",
  "TEMPLATE",
  "SVG",
  "CANVAS",
  "IFRAME",
  "INPUT",
  "TEXTAREA",
  "SELECT",
  "OPTION"
]);
const SENSITIVE_HOST_PATTERNS = [
  /(^|\.)1password\.com$/i,
  /(^|\.)lastpass\.com$/i,
  /(^|\.)bitwarden\.com$/i,
  /(^|\.)paypal\.com$/i,
  /(^|\.)stripe\.com$/i,
  /(^|\.)plaid\.com$/i,
  /(^|\.)accounts\.google\.com$/i,
  /(^|\.)login\.microsoftonline\.com$/i
];
const SENSITIVE_HOST_KEYWORDS = [
  /bank/i,
  /broker/i,
  /medical/i,
  /health/i
];

let scheduledCapture = null;
let lastVisibleText = "";
let lastSentFingerprint = "";
let lastSentAt = 0;

scheduleCapture("initial_load", 250);

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "AURABOT_COLLECT_CONTEXT") {
    scheduleCapture(message.reason || "requested", 100);
  }
});

window.addEventListener("scroll", () => scheduleCapture("scroll", 700), { passive: true });
document.addEventListener("visibilitychange", () => {
  if (!document.hidden) {
    scheduleCapture("visibility_change", 200);
  }
});
document.addEventListener("selectionchange", () => scheduleCapture("selection_change", 500));
document.addEventListener("play", () => scheduleCapture("media_play", 100), true);
document.addEventListener("pause", () => scheduleCapture("media_pause", 100), true);

function scheduleCapture(reason, delayMs) {
  clearTimeout(scheduledCapture);
  scheduledCapture = setTimeout(() => {
    collectAndSend(reason).catch(() => {});
  }, delayMs);
}

async function collectAndSend(reason) {
  const settings = await getSettings();
  if (!settings.captureEnabled || isDisabledDomain(settings.disabledDomains)) {
    return;
  }

  const sensitive = isSensitivePage();
  const selectedText = sensitive ? "" : cleanText(String(getSelection()?.toString() || ""), MAX_SELECTED_TEXT);
  const selectedTextHash = selectedText ? await sha256Hex(selectedText) : "";
  const visibleText = sensitive ? "" : collectVisibleText(MAX_VISIBLE_TEXT);
  const readableText = !sensitive && settings.captureFullPageText
    ? collectReadableText(MAX_READABLE_TEXT)
    : "";

  const visibleTextHash = visibleText ? await sha256Hex(visibleText) : undefined;
  const readableTextHash = readableText ? await sha256Hex(readableText) : undefined;
  const noveltyScore = visibleText ? calculateNovelty(lastVisibleText, visibleText) : undefined;
  const viewportSignature = await sha256Hex([
    location.origin,
    location.pathname,
    scrollBucket(),
    visibleTextHash || ""
  ].join("|"));
  lastVisibleText = visibleText || lastVisibleText;

  const { browser, bundleIdentifier } = await inferBrowser();
  const media = detectMedia();
  const context = {
    schemaVersion: CONTEXT_SCHEMA_VERSION,
    captureID: crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    browser,
    bundleIdentifier,
    url: location.href,
    title: document.title || "",
    activity: media.isMedia ? "media" : reason === "scroll" ? "scrolling" : "browsing",
    pageID: normalizedPageID(),
    mediaID: media.mediaID,
    mediaIsPlaying: media.isPlaying,
    scrollPercent: scrollPercent(),
    viewportSignature,
    noveltyScore,
    visibleText: visibleText || undefined,
    selectedText: selectedText || undefined,
    readableText: readableText || undefined,
    visibleTextHash,
    readableTextHash,
    textCaptureMode: sensitive
      ? "sensitive_metadata_only"
      : readableText
        ? "full_readable_text"
        : visibleText
          ? "visible_viewport"
          : "metadata_only",
    timestamp: new Date().toISOString()
  };

  if (isDuplicateContext(context, selectedTextHash)) {
    return;
  }

  chrome.runtime.sendMessage({ type: "AURABOT_CONTEXT", context });
}

function getSettings() {
  return chrome.storage.sync.get(DEFAULT_SETTINGS);
}

function isDisabledDomain(disabledDomains) {
  const host = location.hostname.toLowerCase();
  return String(disabledDomains || "")
    .split(/[\n,]/)
    .map((domain) => domain.trim().toLowerCase())
    .filter(Boolean)
    .some((domain) => host === domain || host.endsWith(`.${domain}`));
}

function isSensitivePage() {
  const host = location.hostname.toLowerCase();
  if (document.querySelector('input[type="password"]')) {
    return true;
  }
  return SENSITIVE_HOST_PATTERNS.some((pattern) => pattern.test(host)) ||
    SENSITIVE_HOST_KEYWORDS.some((pattern) => pattern.test(host));
}

function collectVisibleText(maxLength) {
  const pieces = [];
  let length = 0;
  const walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      if (!isReadableTextNode(node) || !isNodeInViewport(node)) {
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    }
  });

  while (walker.nextNode() && length < maxLength) {
    const text = normalizeWhitespace(walker.currentNode.nodeValue || "");
    if (!text) {
      continue;
    }
    pieces.push(text);
    length += text.length + 1;
  }

  return cleanText(pieces.join(" "), maxLength);
}

function collectReadableText(maxLength) {
  const pieces = [];
  let length = 0;
  const walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      if (!isReadableTextNode(node) || !isVisibleElement(node.parentElement)) {
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    }
  });

  while (walker.nextNode() && length < maxLength) {
    const text = normalizeWhitespace(walker.currentNode.nodeValue || "");
    if (!text) {
      continue;
    }
    pieces.push(text);
    length += text.length + 1;
  }

  return cleanText(pieces.join(" "), maxLength);
}

function isReadableTextNode(node) {
  const parent = node.parentElement;
  if (!parent || SKIPPED_TAGS.has(parent.tagName)) {
    return false;
  }
  if (parent.closest("script,style,noscript,template,svg,canvas,iframe,input,textarea,select")) {
    return false;
  }
  return normalizeWhitespace(node.nodeValue || "").length > 0;
}

function isVisibleElement(element) {
  if (!element) {
    return false;
  }
  const style = getComputedStyle(element);
  return style.display !== "none" && style.visibility !== "hidden" && Number(style.opacity || "1") > 0;
}

function isNodeInViewport(node) {
  if (!isVisibleElement(node.parentElement)) {
    return false;
  }

  const range = document.createRange();
  range.selectNodeContents(node);
  const rects = Array.from(range.getClientRects());
  range.detach();

  return rects.some((rect) => (
    rect.width > 0 &&
    rect.height > 0 &&
    rect.bottom >= 0 &&
    rect.right >= 0 &&
    rect.top <= window.innerHeight &&
    rect.left <= window.innerWidth
  ));
}

function normalizeWhitespace(value) {
  return String(value).replace(/\s+/g, " ").trim();
}

function cleanText(value, maxLength) {
  const normalized = normalizeWhitespace(value);
  return normalized.length > maxLength ? normalized.slice(0, maxLength) : normalized;
}

function scrollPercent() {
  const scrollable = Math.max(
    document.documentElement.scrollHeight,
    document.body?.scrollHeight || 0
  ) - window.innerHeight;
  if (scrollable <= 0) {
    return 0;
  }
  return Math.max(0, Math.min(100, Math.round((window.scrollY / scrollable) * 1000) / 10));
}

function scrollBucket() {
  return Math.round(scrollPercent() / 5) * 5;
}

function normalizedPageID() {
  return `${location.hostname.toLowerCase()}${location.pathname || "/"}`;
}

function isDuplicateContext(context, selectedTextHash) {
  const fingerprint = [
    context.url || "",
    context.title || "",
    context.activity || "",
    context.mediaID || "",
    context.mediaIsPlaying ? "1" : "0",
    String(scrollBucket()),
    context.viewportSignature || "",
    context.visibleTextHash || "",
    context.readableTextHash || "",
    selectedTextHash,
    context.textCaptureMode || ""
  ].join("|");

  const now = Date.now();
  if (fingerprint === lastSentFingerprint && now - lastSentAt < DEDUPE_WINDOW_MS) {
    return true;
  }

  lastSentFingerprint = fingerprint;
  lastSentAt = now;
  return false;
}

function detectMedia() {
  const url = new URL(location.href);
  let mediaID;
  if (url.hostname.includes("youtube.com")) {
    mediaID = url.searchParams.get("v") || url.pathname.split("/").filter(Boolean).pop();
  } else if (url.hostname === "youtu.be") {
    mediaID = url.pathname.split("/").filter(Boolean).pop();
  }

  const mediaElements = Array.from(document.querySelectorAll("video,audio"));
  const playing = mediaElements.find((element) => !element.paused && !element.ended);
  const mediaElement = playing || mediaElements[0];
  return {
    isMedia: Boolean(mediaID || mediaElement),
    isPlaying: Boolean(playing),
    mediaID: mediaID || mediaElement?.currentSrc || undefined
  };
}

async function inferBrowser() {
  const ua = navigator.userAgent;
  if (/Edg\//.test(ua)) {
    return { browser: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac" };
  }
  if (navigator.brave && await navigator.brave.isBrave()) {
    return { browser: "Brave Browser", bundleIdentifier: "com.brave.Browser" };
  }
  return { browser: "Google Chrome", bundleIdentifier: "com.google.Chrome" };
}

function calculateNovelty(previous, current) {
  if (!previous || previous === current) {
    return previous ? 0 : 1;
  }
  const previousTokens = tokenSet(previous);
  const currentTokens = tokenSet(current);
  if (!previousTokens.size || !currentTokens.size) {
    return 1;
  }

  let intersection = 0;
  for (const token of currentTokens) {
    if (previousTokens.has(token)) {
      intersection += 1;
    }
  }
  const union = new Set([...previousTokens, ...currentTokens]).size;
  return Math.max(0, Math.min(1, Math.round((1 - intersection / union) * 100) / 100));
}

function tokenSet(value) {
  return new Set(
    value
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((token) => token.length > 3)
  );
}

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
