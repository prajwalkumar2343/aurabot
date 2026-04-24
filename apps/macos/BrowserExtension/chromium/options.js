const fields = {
  captureEnabled: document.getElementById("captureEnabled"),
  serverURL: document.getElementById("serverURL"),
  apiKey: document.getElementById("apiKey"),
  captureFullPageText: document.getElementById("captureFullPageText"),
  disabledDomains: document.getElementById("disabledDomains")
};
const status = document.getElementById("status");

restore();
document.getElementById("save").addEventListener("click", save);

async function restore() {
  const settings = await chrome.storage.sync.get(DEFAULT_SETTINGS);
  fields.captureEnabled.checked = Boolean(settings.captureEnabled);
  fields.serverURL.value = settings.serverURL || DEFAULT_SETTINGS.serverURL;
  fields.apiKey.value = settings.apiKey || "";
  fields.captureFullPageText.checked = Boolean(settings.captureFullPageText);
  fields.disabledDomains.value = settings.disabledDomains || "";
}

async function save() {
  await chrome.storage.sync.set({
    captureEnabled: fields.captureEnabled.checked,
    serverURL: fields.serverURL.value.trim() || DEFAULT_SETTINGS.serverURL,
    apiKey: fields.apiKey.value.trim(),
    captureFullPageText: fields.captureFullPageText.checked,
    disabledDomains: fields.disabledDomains.value.trim()
  });

  status.textContent = "Saved.";
  setTimeout(() => {
    status.textContent = "";
  }, 1800);
}
