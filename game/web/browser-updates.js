/* Browser installation and updates are separate from the native signed updater. */
(() => {
  "use strict";
  const script = document.currentScript;
  const build = script.dataset.build;
  const version = script.dataset.version;
  const root = new URL(script.dataset.root, document.baseURI);
  const workerURL = new URL(script.dataset.worker, root);
  if (root.origin !== location.origin || workerURL.origin !== location.origin)
    return;
  let registration = null;
  let preparedWorker = null;
  let preparedVersion = "";
  let applying = false;
  let deferred = false;
  let installPrompt = null;
  let checking = false;
  let inspectionGeneration = 0;

  const widget = document.createElement("aside");
  widget.id = "red-veil-web-updates";
  widget.setAttribute("aria-label", "Browser game updates");
  const toggle = document.createElement("button");
  toggle.type = "button";
  toggle.textContent = "Game updates";
  toggle.setAttribute("aria-expanded", "false");
  toggle.setAttribute("aria-controls", "red-veil-web-update-panel");
  const panel = document.createElement("section");
  panel.id = "red-veil-web-update-panel";
  panel.hidden = true;
  const title = document.createElement("h2");
  title.textContent = "Ready for your next adventure?";
  const status = document.createElement("p");
  status.id = "red-veil-web-update-status";
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");
  status.textContent = `Browser edition ${version}. Preparing offline play…`;
  const note = document.createElement("p");
  note.className = "rv-update-note";
  note.textContent =
    "Finish your mission before updating. Restarting ends this game session.";
  const actions = document.createElement("div");
  actions.className = "rv-update-actions";
  function button(text, callback) {
    const item = document.createElement("button");
    item.type = "button";
    item.textContent = text;
    item.addEventListener("click", callback);
    actions.append(item);
    return item;
  }
  const checkButton = button("Check for updates", check);
  const applyButton = button("Update and restart", apply);
  applyButton.hidden = true;
  const installButton = button("Install / home-screen help", install);
  button("Later — keep playing", () => {
    deferred = true;
    panel.hidden = true;
    toggle.setAttribute("aria-expanded", "false");
    toggle.focus();
  });
  panel.append(title, status, note, actions);
  widget.append(toggle, panel);
  document.body.append(widget);
  toggle.addEventListener("click", () => {
    panel.hidden = !panel.hidden;
    toggle.setAttribute("aria-expanded", String(!panel.hidden));
  });
  function open() {
    panel.hidden = false;
    toggle.setAttribute("aria-expanded", "true");
  }
  window.RedVeilWebUpdates = Object.freeze({ open, check });

  function ask(worker, data) {
    return new Promise((resolve, reject) => {
      if (!worker) return reject(new Error("Worker unavailable"));
      const channel = new MessageChannel();
      const timer = setTimeout(() => {
        channel.port1.close();
        reject(new Error("Update did not respond"));
      }, 10000);
      channel.port1.onmessage = (event) => {
        clearTimeout(timer);
        channel.port1.close();
        resolve(event.data);
      };
      worker.postMessage(data, [channel.port2]);
    });
  }

  async function inspect() {
    if (!registration || applying) return;
    const inspection = ++inspectionGeneration;
    const waiting = registration.waiting;
    if (waiting) {
      const info = await ask(waiting, { type: "RV_STATUS" });
      if (inspection !== inspectionGeneration || applying) return;
      if (info.ok && info.complete && info.build_id !== build) {
        preparedWorker = waiting;
        preparedVersion = info.version;
        status.textContent = `Red Veil ${preparedVersion} is ready. The complete game has been saved and checked.`;
        toggle.textContent = "Update ready";
        applyButton.hidden = false;
        if (!deferred) open();
        return;
      }
      if (info.ok && info.complete && info.build_id === build) return;
    }
    if (registration.installing) return;
    const active = registration.active;
    if (active) {
      const info = await ask(active, { type: "RV_STATUS" });
      if (inspection !== inspectionGeneration || applying) return;
      if (info.ok && info.complete) {
        if (info.build_id !== build) {
          preparedWorker = active;
          preparedVersion = info.version;
          status.textContent = `Red Veil ${preparedVersion} is ready. Restart this game when you’re ready.`;
          toggle.textContent = "Update ready";
          applyButton.hidden = false;
          if (!deferred) open();
        } else {
          preparedWorker = null;
          preparedVersion = "";
          applyButton.hidden = true;
          toggle.textContent = "Game updates";
          status.textContent = `Browser edition ${version} is saved for offline play. No newer prepared update was found.`;
        }
      }
    }
  }

  function watch(worker) {
    if (!worker) return;
    status.textContent =
      "Saving the complete game for offline play… You can keep playing.";
    worker.addEventListener("statechange", () => {
      if (worker.state === "installed" || worker.state === "activated")
        inspect().catch(unavailable);
      if (worker.state === "redundant") {
        status.textContent =
          "The new version could not be saved or checked. This game session has not restarted. Reconnect and try again.";
      }
    });
  }

  function unavailable() {
    status.textContent =
      "Updates could not be checked. This game session has not restarted. You can keep playing and try again later.";
  }

  async function check() {
    open();
    if (checking || applying) return;
    if (!registration) {
      status.textContent =
        "Offline installation needs a supported browser and HTTPS. You can still play online.";
      return;
    }
    checking = true;
    checkButton.disabled = true;
    deferred = false;
    status.textContent = "Checking for a new browser edition…";
    try {
      await registration.update();
      await inspect();
    } catch {
      unavailable();
    } finally {
      checking = false;
      checkButton.disabled = false;
    }
  }

  async function apply() {
    if (!preparedWorker || applying) return;
    applying = true;
    applyButton.disabled = true;
    status.textContent = "Preparing to restart this game…";
    try {
      const result = await ask(preparedWorker, {
        type: "RV_APPLY",
        previous: build,
      });
      if (!result.ok) {
        applying = false;
        applyButton.disabled = false;
        status.textContent =
          result.error === "other_windows"
            ? "Close the other Red Veil tabs or app windows, then select Update and restart again. Those games will not be restarted for you."
            : "The complete update is no longer saved. Reconnect and check again. Your current game has not changed.";
        return;
      }
      if (navigator.serviceWorker.controller === preparedWorker)
        location.reload();
      else
        setTimeout(() => {
          if (!applying) return;
          applying = false;
          applyButton.disabled = false;
          status.textContent =
            "The restart did not finish. Keep playing, or close and reopen this game when you’re ready.";
        }, 15000);
      // Otherwise controllerchange below reloads only this consenting window.
    } catch {
      applying = false;
      applyButton.disabled = false;
      unavailable();
    }
  }

  async function install() {
    if (installPrompt) {
      const prompt = installPrompt;
      installPrompt = null;
      await prompt.prompt();
      await prompt.userChoice;
      installButton.textContent = "Install / home-screen help";
    } else {
      status.textContent =
        "On iPhone or iPad, open this page in Safari, choose Share, then Add to Home Screen. In other browsers, look for Install in the browser menu. Offline play is ready only after the full game finishes saving.";
    }
  }

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    installPrompt = event;
    installButton.textContent = "Install on this device";
  });
  window.addEventListener("appinstalled", () => {
    installButton.hidden = true;
  });
  if (matchMedia("(display-mode: standalone)").matches || navigator.standalone)
    installButton.hidden = true;

  if (
    !("serviceWorker" in navigator) ||
    !window.isSecureContext ||
    !crypto.subtle
  ) {
    status.textContent =
      "Offline installation needs a supported browser and HTTPS. You can still play online.";
    return;
  }
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (applying) location.reload();
    else inspect().catch(unavailable);
  });
  navigator.serviceWorker.addEventListener("message", (event) => {
    if (
      !event.source ||
      event.source.scriptURL !== workerURL.href ||
      !event.data
    )
      return;
    if (event.data.type === "RV_PREPARING") {
      status.textContent = `Saving the complete game… ${Math.floor((event.data.saved * 100) / event.data.total)}%. You can keep playing.`;
    } else if (event.data.type === "RV_PREPARE_FAILED") {
      status.textContent =
        "The new version could not be saved or checked. This game session has not restarted. Reconnect and try again.";
    } else if (
      event.data.type === "RV_PREPARED" ||
      event.data.type === "RV_ACTIVE"
    ) {
      inspect().catch(unavailable);
    }
  });
  navigator.serviceWorker
    .register(workerURL.href, { scope: root.pathname, updateViaCache: "none" })
    .then(async (result) => {
      registration = result;
      registration.addEventListener("updatefound", () =>
        watch(registration.installing),
      );
      watch(registration.installing);
      await inspect();
      // Registration already performs its own update check. Never reload a mission here.
    })
    .catch(unavailable);
})();
