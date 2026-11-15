/* KŌMAKU screen review: static, account-free drawing. Sharing is always explicit. */
(() => {
  "use strict";
  const REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026";
  const ISSUE_BASE = `https://github.com/${REPOSITORY}/issues/new`;
  const LIMIT = {
    marks: 20,
    note: 500,
    comment: 2000,
    reviewer: 80,
    url: 7500,
    json: 100000,
  };
  const SVG_NS = "http://www.w3.org/2000/svg";
  const KIND = {
    rect: "Rectangle",
    ellipse: "Ellipse",
    arrow: "Arrow",
    pin: "Pin",
  };
  const COLORS = { normal: "#ff857c", selected: "#74e7df", ink: "#081319" };
  const $ = (id) => document.getElementById(id);
  const copy = (value) => JSON.parse(JSON.stringify(value));
  const clamp = (value, lo = 0, hi = 1) => Math.max(lo, Math.min(hi, value));
  let manifest = null;
  let screen = null;
  let draft = null;
  let selected = null;
  let tool = "pin";
  let history = [];
  let gesture = null;
  let pending = null;
  let imageReady = false;
  let storageAvailable = true;
  let sharedUnsaved = false;
  let loadSequence = 0;
  let imageSequence = 0;
  let imageObjectURL = null;
  let lastNavigationURL = "";
  let zoomIndex = 0;
  const ZOOM_LEVELS = [1, 1.5, 2, 3, 4];
  const textTransactions = new Set();

  function announce(message) {
    $("status").textContent = message;
  }
  function boundedText(value, max, field) {
    if (typeof value !== "string" || value.length > max)
      throw new Error(`${field} is missing or too long.`);
    return value;
  }
  function matches(value, pattern, field) {
    if (typeof value !== "string" || !pattern.test(value))
      throw new Error(`${field} is invalid.`);
    return value;
  }
  function safeSourceURL(value) {
    try {
      const url = new URL(value);
      if (url.protocol !== "https:" || url.username || url.password || url.hash)
        return false;
      const base = `/${REPOSITORY}/`;
      if (url.hostname === "raw.githubusercontent.com")
        return (
          url.pathname.startsWith(base) &&
          /^[a-f0-9]{40}\//.test(url.pathname.slice(base.length))
        );
      if (url.hostname === "github.com")
        return (
          url.pathname.startsWith(`${base}blob/`) &&
          /^[a-f0-9]{40}\//.test(url.pathname.slice(`${base}blob/`.length))
        );
    } catch (_) {
      /* A source link must be a pinned image in this repository. */
    }
    return false;
  }
  function validateManifest(raw) {
    if (
      !raw ||
      raw.schema !== 1 ||
      raw.repository !== REPOSITORY ||
      !Array.isArray(raw.screens) ||
      !raw.screens.length ||
      raw.screens.length > 100
    )
      throw new Error("This is not a supported KŌMAKU screen manifest.");
    const result = {
      schema: 1,
      version: matches(raw.version, /^[0-9][0-9A-Za-z.+-]{0,60}$/, "Version"),
      sourceCommit: matches(
        raw.sourceCommit,
        /^[a-f0-9]{40}$/,
        "Game source commit",
      ),
      repository: REPOSITORY,
      displayName: boundedText(
        raw.displayName || "KŌMAKU: Dust & Radiation",
        120,
        "Display name",
      ),
      title: boundedText(raw.title || "KŌMAKU", 60, "Game title"),
      subtitle: boundedText(
        raw.subtitle || "DUST & RADIATION",
        100,
        "Game subtitle",
      ),
      preview: raw.preview === true,
      screens: [],
    };
    const ids = new Set();
    for (const entry of raw.screens) {
      if (!entry || typeof entry !== "object")
        throw new Error("A screen entry is invalid.");
      const id = matches(entry.id, /^[a-z0-9][a-z0-9_-]{0,79}$/, "Screen ID");
      if (ids.has(id)) throw new Error("The screen manifest repeats an ID.");
      ids.add(id);
      if (
        !Number.isInteger(entry.width) ||
        !Number.isInteger(entry.height) ||
        entry.width < 1 ||
        entry.height < 1 ||
        entry.width > 8192 ||
        entry.height > 8192
      )
        throw new Error("A screen has unsupported dimensions.");
      const previewSource =
        raw.preview === true &&
        entry.sourcePinned === false &&
        typeof entry.sourceUrl === "string" &&
        entry.sourceUrl.startsWith(
          `https://raw.githubusercontent.com/${REPOSITORY}/main/`,
        );
      if (!safeSourceURL(entry.sourceUrl) && !previewSource)
        throw new Error(
          "A screen source URL is not pinned to this repository.",
        );
      result.screens.push({
        id,
        title: boundedText(entry.title, 120, "Screen title"),
        group: boundedText(entry.group, 80, "Screen group"),
        file: matches(
          entry.file,
          /^screens\/[a-z0-9][a-z0-9._-]{0,120}\.(png|jpe?g|webp)$/i,
          "Screen file",
        ),
        width: entry.width,
        height: entry.height,
        sha256: matches(entry.sha256, /^[a-f0-9]{64}$/, "Image SHA-256"),
        sourceUrl: entry.sourceUrl,
        sourcePinned: !previewSource,
        description: boundedText(
          entry.description || "",
          800,
          "Screen description",
        ),
      });
    }
    return result;
  }
  function validateReview(raw) {
    if (
      !raw ||
      typeof raw !== "object" ||
      Array.isArray(raw) ||
      raw.schema !== 1
    )
      throw new Error("This review uses an unsupported schema.");
    const version = boundedText(raw.version, 64, "Review version");
    const sourceCommit = matches(
      raw.sourceCommit,
      /^[a-f0-9]{40}$/,
      "Review source commit",
    );
    const screenId = matches(
      raw.screenId,
      /^[a-z0-9][a-z0-9_-]{0,79}$/,
      "Review screen ID",
    );
    const target = manifest.screens.find((entry) => entry.id === screenId);
    if (!target)
      throw new Error(
        "This review refers to a screen that is not in this gallery.",
      );
    if (version !== manifest.version || sourceCommit !== manifest.sourceCommit)
      throw new Error(
        "This review belongs to a different game version or source commit. Open its matching gallery; your current draft is unchanged.",
      );
    if (raw.imageSha256 !== target.sha256)
      throw new Error(
        "The screenshot fingerprint does not match this review. Your current draft is unchanged.",
      );
    if (!Array.isArray(raw.marks) || raw.marks.length > LIMIT.marks)
      throw new Error("A review can contain at most 20 marks.");
    const ids = new Set();
    const marks = raw.marks.map((mark) => {
      if (!mark || typeof mark !== "object" || !Object.hasOwn(KIND, mark.type))
        throw new Error("An annotation type is invalid.");
      const id = matches(mark.id, /^[A-Za-z0-9_-]{1,64}$/, "Mark ID");
      if (ids.has(id)) throw new Error("Annotation IDs must be unique.");
      ids.add(id);
      const value = { id, type: mark.type };
      for (const key of ["x1", "y1", "x2", "y2"]) {
        if (
          typeof mark[key] !== "number" ||
          !Number.isFinite(mark[key]) ||
          mark[key] < 0 ||
          mark[key] > 1
        )
          throw new Error(
            "Mark coordinates must be finite numbers between 0 and 1.",
          );
        value[key] = mark[key];
      }
      value.note = boundedText(mark.note, LIMIT.note, "Mark note");
      return value;
    });
    return {
      schema: 1,
      version,
      sourceCommit,
      screenId,
      imageSha256: target.sha256,
      reviewer: boundedText(raw.reviewer, LIMIT.reviewer, "Reviewer name"),
      comment: boundedText(raw.comment, LIMIT.comment, "General comment"),
      marks,
      updatedAt:
        typeof raw.updatedAt === "string" &&
        raw.updatedAt.length <= 40 &&
        Number.isFinite(Date.parse(raw.updatedAt))
          ? raw.updatedAt
          : new Date().toISOString(),
    };
  }
  function emptyDraft(target) {
    return {
      schema: 1,
      version: manifest.version,
      sourceCommit: manifest.sourceCommit,
      screenId: target.id,
      imageSha256: target.sha256,
      reviewer: "",
      comment: "",
      marks: [],
      updatedAt: new Date().toISOString(),
    };
  }
  function storageKey(target = screen) {
    return `komaku.review.v1:${manifest.version}:${manifest.sourceCommit}:${target.id}:${target.sha256}`;
  }
  function readSaved(target) {
    try {
      const raw = localStorage.getItem(storageKey(target));
      if (!raw) return emptyDraft(target);
      if (raw.length > LIMIT.json) throw new Error("Saved draft is too large.");
      const value = validateReview(JSON.parse(raw));
      if (value.screenId !== target.id)
        throw new Error("Saved draft belongs to a different screen.");
      return value;
    } catch (error) {
      if (error instanceof DOMException) storageAvailable = false;
      announce(
        "A saved draft could not be read. It was left untouched; you can continue and export your work.",
      );
      return emptyDraft(target);
    }
  }
  function save() {
    draft.updatedAt = new Date().toISOString();
    sharedUnsaved = false;
    try {
      localStorage.setItem(storageKey(), JSON.stringify(draft));
      storageAvailable = true;
    } catch (_) {
      storageAvailable = false;
    }
    $("save-status").textContent = storageAvailable
      ? "Saved on this device"
      : "This tab only · export to keep a copy";
  }
  function remember() {
    history.push(copy(draft));
    if (history.length > 40) history.shift();
    textTransactions.clear();
  }
  function change(action) {
    if (!draft) return;
    remember();
    action();
    save();
    render();
  }
  function updateText(field, value, transaction) {
    if (!draft) return;
    if (!textTransactions.has(transaction)) {
      history.push(copy(draft));
      if (history.length > 40) history.shift();
      textTransactions.add(transaction);
    }
    if (field === "note") {
      const mark = draft.marks.find((item) => item.id === selected);
      if (!mark) return;
      mark.note = value;
    } else draft[field] = value;
    save();
    renderList();
    updateButtons();
    updateCounters();
  }
  function setTool(value) {
    if (value !== "select" && !Object.hasOwn(KIND, value)) return;
    tool = value;
    gesture = null;
    pending = null;
    for (const button of document.querySelectorAll("[data-tool]"))
      button.setAttribute(
        "aria-pressed",
        String(button.dataset.tool === value),
      );
    $("annotation-layer").dataset.tool = value;
    $("add-center").disabled =
      !imageReady ||
      value === "select" ||
      (draft && draft.marks.length >= LIMIT.marks);
    renderMarks();
  }
  function buildNavigation() {
    $("screen-list").replaceChildren();
    let group = "";
    for (const entry of manifest.screens) {
      if (entry.group !== group) {
        group = entry.group;
        const heading = document.createElement("h2");
        heading.className = "screen-group-label";
        heading.textContent = group;
        $("screen-list").append(heading);
      }
      const button = document.createElement("button");
      button.className = "screen-option";
      button.type = "button";
      button.dataset.screenId = entry.id;
      const thumb = document.createElement("img");
      thumb.src = `./${entry.file}`;
      thumb.alt = "";
      thumb.loading = "lazy";
      thumb.width = 60;
      thumb.height = 40;
      const title = document.createElement("span");
      title.textContent = entry.title;
      button.append(thumb, title);
      button.addEventListener("click", () =>
        switchScreen(entry.id, null, true),
      );
      $("screen-list").append(button);
    }
    $("screen-count").textContent = String(manifest.screens.length);
  }
  function switchScreen(id, incoming = null, updateURL = false) {
    const target = manifest.screens.find((entry) => entry.id === id);
    if (!target) return;
    screen = target;
    zoomIndex = 0;
    $("stage").scrollLeft = 0;
    $("stage").scrollTop = 0;
    draft = incoming || readSaved(target);
    sharedUnsaved = Boolean(incoming);
    selected = null;
    history = [];
    gesture = null;
    pending = null;
    textTransactions.clear();
    imageReady = false;
    $("screen-title").textContent = target.title;
    $("screen-group").textContent = target.group;
    $("screen-description").textContent = target.description;
    $("original-screen").href = target.sourceUrl;
    $("original-screen").hidden = !target.sourcePinned;
    $("image-size").textContent = `${target.width} × ${target.height}`;
    $("screenshot").alt =
      `${target.title} — actual ${manifest.displayName} ${manifest.version} game capture`;
    $("image-loading").textContent = "Loading the captured screen…";
    $("image-loading").hidden = false;
    $("annotation-layer").setAttribute(
      "viewBox",
      `0 0 ${target.width} ${target.height}`,
    );
    for (const button of document.querySelectorAll("[data-screen-id]"))
      button.setAttribute(
        "aria-current",
        String(button.dataset.screenId === target.id),
      );
    $("save-status").textContent = sharedUnsaved
      ? "Shared review · local draft unchanged until you edit"
      : storageAvailable
        ? "Saved on this device"
        : "This tab only · export to keep a copy";
    if (updateURL) {
      try {
        const next = `${location.pathname}${location.search}#screen=${encodeURIComponent(id)}`;
        if (location.href !== new URL(next, location.href).href)
          window.history.pushState(null, "", next);
        lastNavigationURL = location.href;
      } catch (_) {
        /* file URLs may restrict history updates. */
      }
      announce("");
    }
    render();
    loadScreenImage(target);
    if (window.matchMedia("(max-width:700px)").matches)
      $("screen-picker").open = false;
  }
  async function loadScreenImage(target) {
    const sequence = ++imageSequence;
    if (imageObjectURL) {
      URL.revokeObjectURL(imageObjectURL);
      imageObjectURL = null;
    }
    try {
      const response = await fetch(`./${target.file}`, { cache: "no-cache" });
      if (!response.ok)
        throw new Error(`Screenshot returned HTTP ${response.status}.`);
      const bytes = await response.arrayBuffer();
      if (bytes.byteLength > 20000000)
        throw new Error("The screenshot file is unexpectedly large.");
      if (globalThis.crypto?.subtle) {
        const digest = await crypto.subtle.digest("SHA-256", bytes);
        const actual = Array.from(new Uint8Array(digest), (byte) =>
          byte.toString(16).padStart(2, "0"),
        ).join("");
        if (actual !== target.sha256)
          throw new Error(
            "Screenshot fingerprint mismatch. Drawing is disabled because these are not the expected pixels.",
          );
      }
      if (sequence !== imageSequence) return;
      imageObjectURL = URL.createObjectURL(
        new Blob([bytes], {
          type: target.file.toLowerCase().endsWith(".webp")
            ? "image/webp"
            : /\.jpe?g$/i.test(target.file)
              ? "image/jpeg"
              : "image/png",
        }),
      );
      $("screenshot").src = imageObjectURL;
    } catch (error) {
      if (sequence !== imageSequence) return;
      if (location.protocol === "file:") {
        // Browsers commonly block fetch for a local file. Local rendering can
        // still work; its JSON draft remains useful even if PNG export is blocked.
        $("screenshot").src = `./${target.file}`;
        announce(
          "Local-file view: the browser cannot verify image bytes. Use the hosted gallery or a local server for verified screenshots and PNG export.",
        );
      } else {
        imageReady = false;
        $("screenshot").removeAttribute("src");
        $("image-loading").textContent = error.message;
        $("image-loading").hidden = false;
        announce(error.message);
        updateButtons();
      }
    }
  }
  function imageLoaded() {
    if (!screen || !$("screenshot").complete) return;
    const img = $("screenshot");
    if (
      img.naturalWidth !== screen.width ||
      img.naturalHeight !== screen.height
    ) {
      imageReady = false;
      $("image-loading").textContent =
        "This image has unexpected dimensions. Drawing is disabled to keep marks accurate.";
      $("image-loading").hidden = false;
      updateButtons();
      return;
    }
    imageReady = true;
    $("image-loading").hidden = true;
    applyZoom();
    updateButtons();
    renderMarks();
  }
  function applyZoom() {
    if (!screen || !imageReady) return;
    const stage = $("stage"),
      image = $("screenshot"),
      frame = $("image-frame");
    const oldWidth = Math.max(1, frame.getBoundingClientRect().width);
    const oldHeight = Math.max(1, frame.getBoundingClientRect().height);
    const centerX = (stage.scrollLeft + stage.clientWidth / 2) / oldWidth;
    const centerY = (stage.scrollTop + stage.clientHeight / 2) / oldHeight;
    stage.dataset.zoomed = "false";
    frame.style.width = "";
    image.style.width = "";
    image.style.maxWidth = "";
    image.style.maxHeight = "";
    const fit = image.getBoundingClientRect().width;
    if (zoomIndex > 0) {
      stage.dataset.zoomed = "true";
      frame.style.width = `${fit * ZOOM_LEVELS[zoomIndex]}px`;
      image.style.width = "100%";
      image.style.maxWidth = "none";
      image.style.maxHeight = "none";
      stage.scrollLeft = Math.max(
        0,
        centerX * frame.getBoundingClientRect().width - stage.clientWidth / 2,
      );
      stage.scrollTop = Math.max(
        0,
        centerY * frame.getBoundingClientRect().height - stage.clientHeight / 2,
      );
    } else {
      stage.scrollLeft = 0;
      stage.scrollTop = 0;
    }
    $("zoom-status").textContent =
      zoomIndex === 0 ? "Fit" : `${Math.round(ZOOM_LEVELS[zoomIndex] * 100)}%`;
    $("zoom-out").disabled = zoomIndex === 0;
    $("zoom-in").disabled = zoomIndex === ZOOM_LEVELS.length - 1;
    renderMarks();
  }
  function zoomBy(direction) {
    if (!imageReady) return;
    zoomIndex = clamp(zoomIndex + direction, 0, ZOOM_LEVELS.length - 1);
    applyZoom();
  }
  function selectedMark() {
    return draft ? draft.marks.find((mark) => mark.id === selected) : null;
  }
  function render() {
    if (!draft) return;
    $("reviewer-name").value = draft.reviewer;
    $("general-comment").value = draft.comment;
    const mark = selectedMark();
    $("selected-editor").hidden = !mark;
    $("selected-note").value = mark ? mark.note : "";
    $("selected-note-label").textContent = mark
      ? `Mark ${draft.marks.indexOf(mark) + 1} · what should change?`
      : "Mark note";
    $("selected-kind").textContent = mark ? KIND[mark.type] : "";
    renderList();
    renderMarks();
    updateButtons();
    updateCounters();
  }
  function updateCounters() {
    if (!draft) return;
    $("mark-count").textContent =
      `${draft.marks.length} / ${LIMIT.marks} marks`;
    $("note-count").textContent =
      `${selectedMark()?.note.length || 0} / ${LIMIT.note}`;
    $("comment-count").textContent = `${draft.comment.length} / 2,000`;
  }
  function updateButtons() {
    const ready = Boolean(draft);
    for (const id of ["share-review", "export-json"]) $(id).disabled = !ready;
    $("github-review").disabled = !ready || !screen.sourcePinned;
    $("github-review").title = screen?.sourcePinned
      ? "Create a draft issue for manual submission"
      : "Preview capture: commit this screenshot before creating a pinned GitHub review";
    $("export-png").disabled = !ready || !imageReady;
    $("zoom-fit").disabled = !ready || !imageReady;
    $("zoom-out").disabled = !ready || !imageReady || zoomIndex === 0;
    $("zoom-in").disabled =
      !ready || !imageReady || zoomIndex === ZOOM_LEVELS.length - 1;
    $("undo").disabled = !history.length;
    $("delete-mark").disabled = !selectedMark();
    $("clear-review").disabled =
      !ready || (!draft.marks.length && !draft.comment && !draft.reviewer);
    $("add-center").disabled =
      !ready ||
      !imageReady ||
      tool === "select" ||
      draft.marks.length >= LIMIT.marks;
    for (const button of document.querySelectorAll("[data-tool]"))
      button.disabled = !ready || !imageReady;
  }
  function renderList() {
    $("mark-list").replaceChildren();
    if (!draft) return;
    $("empty-marks").hidden = draft.marks.length > 0;
    draft.marks.forEach((mark, index) => {
      const item = document.createElement("li");
      const button = document.createElement("button");
      button.type = "button";
      button.className = "mark-choice";
      button.dataset.markId = mark.id;
      button.setAttribute("aria-pressed", String(mark.id === selected));
      const number = document.createElement("span");
      number.className = "mark-number";
      number.textContent = String(index + 1);
      const label = document.createElement("span");
      label.className = "mark-summary";
      label.textContent = mark.note.trim() || `${KIND[mark.type]} · add a note`;
      button.setAttribute(
        "aria-label",
        `Mark ${index + 1}, ${KIND[mark.type]}: ${mark.note.trim() || "no note yet"}`,
      );
      button.append(number, label);
      button.addEventListener("click", () => {
        selected = mark.id;
        render();
        $("selected-note").focus();
      });
      item.append(button);
      $("mark-list").append(item);
    });
  }
  function svgElement(tag, attrs = {}) {
    const element = document.createElementNS(SVG_NS, tag);
    for (const [key, value] of Object.entries(attrs))
      element.setAttribute(key, String(value));
    return element;
  }
  function markPoints(mark) {
    return {
      x1: mark.x1 * screen.width,
      y1: mark.y1 * screen.height,
      x2: mark.x2 * screen.width,
      y2: mark.y2 * screen.height,
    };
  }
  function renderMarks() {
    const layer = $("annotation-layer");
    layer.replaceChildren();
    if (!screen || !draft) return;
    const ratio =
      screen.width /
      Math.max(1, $("image-frame").getBoundingClientRect().width);
    const radius = 12 * ratio;
    const defs = svgElement("defs");
    for (const name of ["normal", "selected"]) {
      const marker = svgElement("marker", {
        id: `head-${name}`,
        viewBox: "0 0 10 10",
        refX: 9,
        refY: 5,
        markerWidth: 8,
        markerHeight: 8,
        orient: "auto-start-reverse",
      });
      marker.append(
        svgElement("path", { d: "M 0 0 L 10 5 L 0 10 z", fill: COLORS[name] }),
      );
      defs.append(marker);
    }
    layer.append(defs);
    let marks = draft.marks;
    if (pending)
      marks =
        pending.id === selected && gesture?.kind === "move"
          ? marks.map((mark) => (mark.id === pending.id ? pending : mark))
          : [...marks, pending];
    marks.forEach((mark, index) => {
      const active = mark.id === selected || mark === pending;
      const color = active ? COLORS.selected : COLORS.normal;
      const p = markPoints(mark);
      const group = svgElement("g", {
        "data-id": mark.id,
        role: "button",
        tabindex: "0",
        "aria-label": `Mark ${index + 1}, ${KIND[mark.type]}${mark.note ? `: ${mark.note}` : ""}`,
      });
      if (mark === pending) group.dataset.pending = "true";
      const common = {
        stroke: color,
        "stroke-width": active ? 3 : 2.5,
        "vector-effect": "non-scaling-stroke",
        fill: active ? "#74e7df12" : "#ff857c12",
      };
      if (mark.type === "rect")
        group.append(
          svgElement("rect", {
            ...common,
            x: Math.min(p.x1, p.x2),
            y: Math.min(p.y1, p.y2),
            width: Math.abs(p.x2 - p.x1),
            height: Math.abs(p.y2 - p.y1),
            rx: 3 * ratio,
          }),
        );
      if (mark.type === "ellipse")
        group.append(
          svgElement("ellipse", {
            ...common,
            cx: (p.x1 + p.x2) / 2,
            cy: (p.y1 + p.y2) / 2,
            rx: Math.abs(p.x2 - p.x1) / 2,
            ry: Math.abs(p.y2 - p.y1) / 2,
          }),
        );
      if (mark.type === "arrow")
        group.append(
          svgElement("line", {
            ...common,
            fill: "none",
            x1: p.x1,
            y1: p.y1,
            x2: p.x2,
            y2: p.y2,
            "marker-end": `url(#head-${active ? "selected" : "normal"})`,
          }),
        );
      const bx = clamp(
        mark.type === "arrow" || mark.type === "pin"
          ? p.x1
          : Math.min(p.x1, p.x2),
        radius,
        screen.width - radius,
      );
      const by = clamp(
        mark.type === "arrow" || mark.type === "pin"
          ? p.y1
          : Math.min(p.y1, p.y2),
        radius,
        screen.height - radius,
      );
      group.append(
        svgElement("circle", {
          cx: bx,
          cy: by,
          r: radius,
          fill: color,
          stroke: COLORS.ink,
          "stroke-width": 1.5,
          "vector-effect": "non-scaling-stroke",
        }),
      );
      const text = svgElement("text", {
        x: bx,
        y: by,
        "text-anchor": "middle",
        "dominant-baseline": "central",
        "font-family": "system-ui,sans-serif",
        "font-weight": "800",
        "font-size": 12 * ratio,
        fill: COLORS.ink,
        "pointer-events": "none",
      });
      text.textContent = String(index + 1);
      group.append(text);
      group.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          event.stopPropagation();
          selected = mark.id;
          render();
          $("selected-note").focus();
        }
      });
      layer.append(group);
    });
  }
  function point(event) {
    const box = $("annotation-layer").getBoundingClientRect();
    return {
      x: clamp((event.clientX - box.left) / box.width),
      y: clamp((event.clientY - box.top) / box.height),
    };
  }
  function newMark(type, x1, y1, x2 = x1, y2 = y1) {
    const id = globalThis.crypto?.randomUUID
      ? `m-${crypto.randomUUID()}`
      : `m-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    return { id, type, x1, y1, x2, y2, note: "" };
  }
  function appendMark(mark) {
    if (draft.marks.length >= LIMIT.marks) {
      announce(
        "This screen has 20 marks. Delete a mark or start another screen before adding more.",
      );
      return;
    }
    change(() => {
      draft.marks.push(mark);
      selected = mark.id;
    });
    announce(`Mark ${draft.marks.length} added. Add a note in Your feedback.`);
  }
  function addCentered() {
    if (!imageReady || tool === "select") return;
    const mark =
      tool === "pin"
        ? newMark("pin", 0.5, 0.5)
        : newMark(tool, 0.35, 0.35, 0.65, 0.65);
    appendMark(mark);
    $("selected-note").focus();
  }
  function pointerDown(event) {
    if (!imageReady || event.button !== 0 || gesture) return;
    event.preventDefault();
    const pos = point(event);
    const hit = event.target.closest?.("g[data-id]");
    if (tool === "select") {
      selected = hit?.dataset.id || null;
      const mark = selectedMark();
      if (!mark && zoomIndex > 0)
        gesture = {
          kind: "pan",
          clientX: event.clientX,
          clientY: event.clientY,
          left: $("stage").scrollLeft,
          top: $("stage").scrollTop,
          pointer: event.pointerId,
        };
      if (mark)
        gesture = {
          kind: "move",
          start: pos,
          original: copy(mark),
          pointer: event.pointerId,
        };
      render();
    } else if (draft.marks.length >= LIMIT.marks) {
      announce(
        "This screen has 20 marks. Delete a mark before adding another.",
      );
      return;
    } else if (tool === "pin") {
      appendMark(newMark("pin", pos.x, pos.y));
      return;
    } else {
      pending = newMark(tool, pos.x, pos.y);
      gesture = { kind: "draw", start: pos, pointer: event.pointerId };
      renderMarks();
    }
    if (gesture) $("annotation-layer").setPointerCapture(event.pointerId);
  }
  function pointerMove(event) {
    if (!gesture || gesture.pointer !== event.pointerId) return;
    event.preventDefault();
    if (gesture.kind === "pan") {
      $("stage").scrollLeft = gesture.left - (event.clientX - gesture.clientX);
      $("stage").scrollTop = gesture.top - (event.clientY - gesture.clientY);
      return;
    }
    const pos = point(event);
    if (gesture.kind === "draw") {
      pending.x2 = pos.x;
      pending.y2 = pos.y;
    } else {
      const old = gesture.original;
      const dx = clamp(
        pos.x - gesture.start.x,
        -Math.min(old.x1, old.x2),
        1 - Math.max(old.x1, old.x2),
      );
      const dy = clamp(
        pos.y - gesture.start.y,
        -Math.min(old.y1, old.y2),
        1 - Math.max(old.y1, old.y2),
      );
      pending = {
        ...old,
        x1: old.x1 + dx,
        x2: old.x2 + dx,
        y1: old.y1 + dy,
        y2: old.y2 + dy,
      };
    }
    renderMarks();
  }
  function pointerUp(event) {
    if (!gesture || gesture.pointer !== event.pointerId) return;
    const state = gesture;
    const mark = pending;
    gesture = null;
    pending = null;
    if ($("annotation-layer").hasPointerCapture(event.pointerId))
      $("annotation-layer").releasePointerCapture(event.pointerId);
    if (
      mark &&
      state.kind === "draw" &&
      Math.hypot(mark.x2 - mark.x1, mark.y2 - mark.y1) >= 0.006
    )
      appendMark(mark);
    else if (
      mark &&
      state.kind === "move" &&
      Math.abs(mark.x1 - state.original.x1) +
        Math.abs(mark.y1 - state.original.y1) >
        0.0001
    )
      change(() => {
        draft.marks = draft.marks.map((item) =>
          item.id === mark.id ? mark : item,
        );
      });
    else renderMarks();
  }
  function undo() {
    if (!history.length) return;
    draft = history.pop();
    selected = draft.marks.some((mark) => mark.id === selected)
      ? selected
      : null;
    gesture = null;
    pending = null;
    textTransactions.clear();
    save();
    render();
    announce("Last change undone.");
  }
  function deleteSelected() {
    if (!selectedMark()) return;
    change(() => {
      draft.marks = draft.marks.filter((mark) => mark.id !== selected);
      selected = null;
    });
    announce("Mark removed. Undo can bring it back.");
  }
  function clearDraft() {
    if (
      !draft ||
      !window.confirm(
        "Clear all marks and comments on this screen? Other screens stay unchanged. You can Undo this action.",
      )
    )
      return;
    change(() => {
      draft = emptyDraft(screen);
      selected = null;
    });
    announce("This screen’s draft is clear. Undo can restore it.");
  }
  function encodeReview(value) {
    const bytes = new TextEncoder().encode(JSON.stringify(value));
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "");
  }
  function decodeReview(value) {
    if (!/^[A-Za-z0-9_-]+$/.test(value) || value.length > LIMIT.json * 2)
      throw new Error("The shared review link is malformed or too large.");
    const binary = atob(value.replace(/-/g, "+").replace(/_/g, "/"));
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    if (bytes.byteLength > LIMIT.json)
      throw new Error("The shared review is too large.");
    return validateReview(
      JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)),
    );
  }
  function readHash() {
    if (!manifest) return false;
    const params = new URLSearchParams(location.hash.slice(1));
    if (params.has("review")) {
      try {
        const value = decodeReview(params.get("review"));
        switchScreen(value.screenId, value);
        announce("Shared review loaded. Nothing has been sent to GitHub.");
      } catch (error) {
        if (!screen) switchScreen(manifest.screens[0].id);
        announce(`Could not open shared review: ${error.message}`);
      }
      return true;
    }
    if (
      params.has("screen") &&
      manifest.screens.some((entry) => entry.id === params.get("screen"))
    ) {
      switchScreen(params.get("screen"));
      return true;
    }
    return false;
  }
  function reviewJSON() {
    return JSON.stringify(validateReview(draft), null, 2);
  }
  function shareURL() {
    const url = new URL(location.href);
    url.search = "";
    url.hash = `review=${encodeReview(validateReview(draft))}`;
    return url.href;
  }
  function issueBody(includeJSON = true, includeShare = true) {
    const lines = [
      "## Screen review",
      `Game: ${manifest.displayName} · ${manifest.version}`,
      `Screen: ${screen.title} (${screen.id})`,
      `Game source: ${manifest.sourceCommit}`,
      `Screenshot SHA-256: ${screen.sha256}`,
      `Pinned screenshot: ${screen.sourceUrl}`,
      "",
      "Please attach the annotated PNG if useful. This review was composed in the team gallery and submitted manually.",
      "",
    ];
    if (includeJSON && includeShare && /^https?:$/.test(location.protocol))
      lines.push(`Open annotated screen: ${shareURL()}`, "");
    if (includeJSON) lines.push("```json", reviewJSON(), "```");
    else
      lines.push(
        "This review is too large for a prefilled URL. Attach the exported review JSON and annotated PNG here before clicking Submit.",
      );
    return lines.join("\n");
  }
  function githubURL(includeJSON = true, includeShare = true) {
    const url = new URL(ISSUE_BASE);
    url.searchParams.set(
      "title",
      `[Screen review] ${screen.title} · ${manifest.version}`,
    );
    url.searchParams.set("body", issueBody(includeJSON, includeShare));
    return url.href;
  }
  function openTransfer(kind) {
    if (!draft) return;
    const isGitHub = kind === "github";
    let value;
    if (isGitHub) {
      value = githubURL();
      if (value.length > LIMIT.url) value = githubURL(true, false);
    } else value = shareURL();
    const tooLong = value.length > LIMIT.url;
    const localOnly = !isGitHub && !/^https?:$/.test(location.protocol);
    $("transfer-title").textContent = isGitHub
      ? "Send this review to GitHub"
      : "Share your review";
    $("transfer-value-label").textContent =
      tooLong || localOnly
        ? "Manual sharing instructions"
        : isGitHub
          ? "GitHub draft link"
          : "Review link";
    $("transfer-description").textContent = tooLong
      ? "This review is too large for a reliable link. Download the JSON and annotated PNG, then attach them to a GitHub issue or send them to your team."
      : localOnly
        ? "This gallery is open from your computer. Its file link won’t open on someone else’s device. Download the JSON, or use the hosted gallery to create a shareable link."
        : isGitHub
          ? "Open the draft, review its content, sign in to your own GitHub account, and click Submit. No feedback is sent automatically. This repository’s issues are public."
          : "Anyone with this link can view its marks and notes. It contains this screen’s review, not a live collaborative session. Nothing is sent to GitHub.";
    $("transfer-value").value =
      tooLong || localOnly
        ? "1. Download this screen’s review JSON.\n2. Save the annotated PNG if helpful.\n3. Share both files with your team, or attach them to the GitHub draft before submitting."
        : value;
    $("copy-transfer").hidden = tooLong || localOnly;
    $("copy-transfer").textContent = isGitHub ? "Copy draft link" : "Copy link";
    const open = $("open-github");
    open.hidden = !isGitHub;
    if (isGitHub) open.href = tooLong ? githubURL(false) : value;
    else open.removeAttribute("href");
    $("transfer-status").textContent = "";
    $("transfer-dialog").showModal();
    if (!tooLong && !localOnly) {
      $("transfer-value").focus();
      $("transfer-value").select();
    }
  }
  async function copyTransfer() {
    const field = $("transfer-value");
    field.focus();
    field.select();
    try {
      if (!navigator.clipboard?.writeText)
        throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(field.value);
      $("transfer-status").textContent = "Link copied.";
    } catch (_) {
      $("transfer-status").textContent =
        "The link is selected. Press Ctrl+C or Cmd+C, or use your device’s Copy action.";
    }
  }
  function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
  }
  function exportJSON() {
    if (!draft) return;
    downloadBlob(
      new Blob([reviewJSON() + "\n"], { type: "application/json" }),
      `komaku-review-${manifest.version}-${screen.id}.json`,
    );
    announce(
      "Review JSON downloaded. It includes the pinned screen identity, marks, and comments.",
    );
  }
  async function importJSON(file) {
    if (!file) return;
    try {
      if (file.size > LIMIT.json)
        throw new Error("This file is too large for a screen review.");
      const value = validateReview(JSON.parse(await file.text()));
      const existing =
        value.screenId === screen?.id
          ? draft
          : readSaved(
              manifest.screens.find((entry) => entry.id === value.screenId),
            );
      if (
        existing &&
        (existing.marks.length || existing.comment || existing.reviewer) &&
        !window.confirm(
          "Replace this screen’s draft with the imported review? Export the current draft first if you need both.",
        )
      ) {
        announce("Import cancelled. Your draft is unchanged.");
        return;
      }
      switchScreen(value.screenId, value, true);
      save();
      render();
      announce("Review imported. Nothing has been sent to GitHub.");
    } catch (error) {
      announce(
        `Could not import review: ${error.message} Your current draft is unchanged.`,
      );
    } finally {
      $("import-json").value = "";
    }
  }
  function wrappedLines(context, text, width) {
    const lines = [];
    for (const paragraph of text.split("\n")) {
      let line = "";
      for (const word of paragraph.split(/\s+/)) {
        if (!word) continue;
        if (
          context.measureText((line ? line + " " : "") + word).width <= width
        ) {
          line += (line ? " " : "") + word;
          continue;
        }
        if (line) {
          lines.push(line);
          line = "";
        }
        for (const character of word) {
          if (line && context.measureText(line + character).width > width) {
            lines.push(line);
            line = "";
          }
          line += character;
        }
      }
      lines.push(line);
    }
    return lines;
  }
  function canvasMark(context, mark, index, offsetY, width, height) {
    const x1 = mark.x1 * width,
      y1 = mark.y1 * height + offsetY,
      x2 = mark.x2 * width,
      y2 = mark.y2 * height + offsetY;
    const radius = Math.max(11, width / 95);
    context.strokeStyle = COLORS.normal;
    context.fillStyle = "rgba(255,133,124,0.09)";
    context.lineWidth = Math.max(2, width / 500);
    context.lineJoin = "round";
    context.beginPath();
    if (mark.type === "rect")
      context.rect(
        Math.min(x1, x2),
        Math.min(y1, y2),
        Math.abs(x2 - x1),
        Math.abs(y2 - y1),
      );
    if (mark.type === "ellipse")
      context.ellipse(
        (x1 + x2) / 2,
        (y1 + y2) / 2,
        Math.abs(x2 - x1) / 2,
        Math.abs(y2 - y1) / 2,
        0,
        0,
        Math.PI * 2,
      );
    if (mark.type === "arrow") {
      context.moveTo(x1, y1);
      context.lineTo(x2, y2);
    }
    context.fill();
    context.stroke();
    if (mark.type === "arrow") {
      const angle = Math.atan2(y2 - y1, x2 - x1),
        length = radius * 1.5;
      context.fillStyle = COLORS.normal;
      context.beginPath();
      context.moveTo(x2, y2);
      context.lineTo(
        x2 - length * Math.cos(angle - 0.45),
        y2 - length * Math.sin(angle - 0.45),
      );
      context.lineTo(
        x2 - length * Math.cos(angle + 0.45),
        y2 - length * Math.sin(angle + 0.45),
      );
      context.closePath();
      context.fill();
    }
    const bx = clamp(
      mark.type === "arrow" || mark.type === "pin" ? x1 : Math.min(x1, x2),
      radius,
      width - radius,
    );
    const by = clamp(
      mark.type === "arrow" || mark.type === "pin" ? y1 : Math.min(y1, y2),
      offsetY + radius,
      offsetY + height - radius,
    );
    context.fillStyle = COLORS.normal;
    context.beginPath();
    context.arc(bx, by, radius, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = COLORS.ink;
    context.font = `bold ${Math.round(radius)}px system-ui,sans-serif`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(String(index + 1), bx, by);
    context.textAlign = "left";
    context.textBaseline = "alphabetic";
  }
  async function exportPNG() {
    if (!draft || !imageReady) return;
    try {
      const exportDraft = validateReview(draft);
      const width = screen.width,
        height = screen.height;
      const padding = Math.max(16, Math.round(width / 60));
      const fontSize = Math.max(13, Math.round(width / 80));
      const lineHeight = Math.round(fontSize * 1.55);
      const canvas = document.createElement("canvas");
      canvas.width = width;
      const context = canvas.getContext("2d");
      if (!context)
        throw new Error("Canvas export is unavailable in this browser.");
      context.font = `${fontSize}px system-ui,sans-serif`;
      const legend = [];
      if (exportDraft.reviewer)
        legend.push(
          ...wrappedLines(
            context,
            `Reviewer: ${exportDraft.reviewer}`,
            width - padding * 2,
          ),
          "",
        );
      exportDraft.marks.forEach((mark, index) =>
        legend.push(
          ...wrappedLines(
            context,
            `${index + 1}. ${KIND[mark.type]} — ${mark.note || "No note added."}`,
            width - padding * 2,
          ),
          "",
        ),
      );
      if (exportDraft.comment)
        legend.push(
          ...wrappedLines(
            context,
            `General comment: ${exportDraft.comment}`,
            width - padding * 2,
          ),
          "",
        );
      legend.push(
        ...wrappedLines(
          context,
          `${manifest.displayName} ${manifest.version} · ${screen.id} · source ${manifest.sourceCommit.slice(0, 12)}`,
          width - padding * 2,
        ),
      );
      const header = padding * 2 + lineHeight * 2;
      canvas.height =
        header + height + padding * 2 + legend.length * lineHeight;
      if (canvas.width * canvas.height > 32000000 || canvas.height > 16000)
        throw new Error(
          "This export is too large for a reliable image. Export JSON instead.",
        );
      context.fillStyle = COLORS.ink;
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.fillStyle = "#f3f5f3";
      context.font = `bold ${fontSize}px system-ui,sans-serif`;
      context.fillText(
        `${manifest.title} · Screen review`,
        padding,
        padding + lineHeight,
      );
      context.font = `${fontSize}px system-ui,sans-serif`;
      context.fillStyle = "#a8bac2";
      context.fillText(
        screen.title,
        padding,
        padding + lineHeight * 2,
        width - padding * 2,
      );
      context.drawImage($("screenshot"), 0, header, width, height);
      exportDraft.marks.forEach((mark, index) =>
        canvasMark(context, mark, index, header, width, height),
      );
      context.font = `${fontSize}px system-ui,sans-serif`;
      context.fillStyle = "#f3f5f3";
      legend.forEach((line, index) =>
        context.fillText(
          line,
          padding,
          header + height + padding + (index + 1) * lineHeight,
        ),
      );
      const blob = await new Promise((resolve, reject) =>
        canvas.toBlob(
          (value) =>
            value
              ? resolve(value)
              : reject(new Error("The browser could not encode this image.")),
          "image/png",
        ),
      );
      downloadBlob(blob, `komaku-review-${manifest.version}-${screen.id}.png`);
      announce(
        "Annotated PNG downloaded, including numbered marks and their notes.",
      );
    } catch (error) {
      announce(
        `PNG export unavailable: ${error.message} The JSON export keeps all your feedback.`,
      );
    }
  }
  async function start(rawManifest = null) {
    const sequence = ++loadSequence;
    $("app").setAttribute("aria-busy", "true");
    $("load-error").hidden = true;
    try {
      let raw = rawManifest;
      if (!raw) {
        const response = await fetch("./screens.json", { cache: "no-cache" });
        if (!response.ok)
          throw new Error(`The screen list returned HTTP ${response.status}.`);
        const text = await response.text();
        if (text.length > 250000)
          throw new Error("The screen manifest is unexpectedly large.");
        raw = JSON.parse(text);
      }
      if (sequence !== loadSequence) return;
      manifest = validateManifest(raw);
      $("app").hidden = false;
      $("version").textContent = manifest.version;
      $("wordmark").textContent = manifest.title;
      $("wordmark").title = manifest.displayName;
      document.title = `${manifest.displayName} · Team screen review`;
      buildNavigation();
      if (!readHash()) {
        switchScreen(manifest.screens[0].id);
        try {
          window.history.replaceState(
            null,
            "",
            `${location.pathname}${location.search}#screen=${encodeURIComponent(screen.id)}`,
          );
        } catch (_) {
          /* Local file history can be restricted. */
        }
      }
      lastNavigationURL = location.href;
      setTool("pin");
      $("app").setAttribute("aria-busy", "false");
    } catch (error) {
      if (sequence !== loadSequence) return;
      $("app").hidden = true;
      $("load-error").hidden = false;
      $("version").textContent = "Gallery unavailable";
      $("load-error-message").textContent =
        `${error.message} Open the hosted gallery, or serve the downloaded gallery folder locally. If your browser blocks a local screens.json file, choose it below.`;
    }
  }

  $("screenshot").addEventListener("load", imageLoaded);
  $("screenshot").addEventListener("error", () => {
    imageReady = false;
    $("image-loading").textContent =
      "This screenshot could not be loaded. Your notes are still available.";
    $("image-loading").hidden = false;
    updateButtons();
  });
  for (const button of document.querySelectorAll("[data-tool]"))
    button.addEventListener("click", () => setTool(button.dataset.tool));
  $("annotation-layer").addEventListener("pointerdown", pointerDown);
  $("annotation-layer").addEventListener("pointermove", pointerMove);
  $("annotation-layer").addEventListener("pointerup", pointerUp);
  $("annotation-layer").addEventListener("pointercancel", () => {
    gesture = null;
    pending = null;
    renderMarks();
  });
  $("stage").addEventListener("keydown", (event) => {
    if (event.target === $("stage") && event.key === "Enter") {
      event.preventDefault();
      addCentered();
    }
  });
  $("zoom-in").addEventListener("click", () => zoomBy(1));
  $("zoom-out").addEventListener("click", () => zoomBy(-1));
  $("zoom-fit").addEventListener("click", () => {
    zoomIndex = 0;
    applyZoom();
  });
  window.addEventListener("resize", () => {
    if (imageReady) applyZoom();
  });
  $("add-center").addEventListener("click", addCentered);
  $("undo").addEventListener("click", undo);
  $("delete-mark").addEventListener("click", deleteSelected);
  $("clear-review").addEventListener("click", clearDraft);
  $("reviewer-name").addEventListener("input", (event) =>
    updateText(
      "reviewer",
      event.target.value.slice(0, LIMIT.reviewer),
      "reviewer",
    ),
  );
  $("general-comment").addEventListener("input", (event) =>
    updateText(
      "comment",
      event.target.value.slice(0, LIMIT.comment),
      "comment",
    ),
  );
  $("selected-note").addEventListener("input", (event) =>
    updateText(
      "note",
      event.target.value.slice(0, LIMIT.note),
      `note:${selected}`,
    ),
  );
  for (const id of ["reviewer-name", "general-comment", "selected-note"])
    $(id).addEventListener("blur", () => textTransactions.clear());
  $("share-review").addEventListener("click", () => openTransfer("share"));
  $("github-review").addEventListener("click", () => openTransfer("github"));
  $("close-transfer").addEventListener("click", () =>
    $("transfer-dialog").close(),
  );
  $("copy-transfer").addEventListener("click", copyTransfer);
  $("download-transfer").addEventListener("click", exportJSON);
  $("export-json").addEventListener("click", exportJSON);
  $("export-png").addEventListener("click", exportPNG);
  $("import-json").addEventListener("change", (event) =>
    importJSON(event.target.files[0]),
  );
  $("retry-load").addEventListener("click", () => start());
  $("manifest-file").addEventListener("change", async (event) => {
    const file = event.target.files[0];
    if (!file) return;
    try {
      if (file.size > 250000) throw new Error("Manifest too large.");
      await start(JSON.parse(await file.text()));
    } catch (error) {
      $("load-error-message").textContent = error.message;
    }
  });
  function handleNavigation() {
    if (!manifest || location.href === lastNavigationURL) return;
    lastNavigationURL = location.href;
    if (!readHash()) switchScreen(manifest.screens[0].id);
  }
  window.addEventListener("hashchange", handleNavigation);
  window.addEventListener("popstate", handleNavigation);
  document.addEventListener("keydown", (event) => {
    if (
      !draft ||
      $("transfer-dialog").open ||
      event.target.closest("input,textarea,[contenteditable=true]")
    )
      return;
    if (event.key === "Escape") {
      gesture = null;
      pending = null;
      selected = null;
      render();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "z") {
      event.preventDefault();
      undo();
      return;
    }
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    if (event.key === "Delete" || event.key === "Backspace") {
      if (selectedMark()) {
        event.preventDefault();
        deleteSelected();
      }
      return;
    }
    const shortcut = {
      v: "select",
      b: "rect",
      e: "ellipse",
      a: "arrow",
      p: "pin",
    }[event.key.toLowerCase()];
    if (shortcut) {
      event.preventDefault();
      setTool(shortcut);
    }
  });
  if (globalThis.ResizeObserver)
    new ResizeObserver(renderMarks).observe($("image-frame"));
  else window.addEventListener("resize", renderMarks);
  start();
})();
