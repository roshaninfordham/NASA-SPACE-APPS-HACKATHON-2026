import brand from "../game/data/brand.json";
import "./style.css";
import {
  createState,
  step,
  telemetry,
  applyAction,
  advice,
  debrief,
  scenarioById,
} from "./simulation.js";
import { SYSTEM } from "./scenarios.js";
import { createScene } from "./scene.js";
import { missionMarkup } from "./view.js";
document.title = brand.display_name;
const $ = (s) => document.querySelector(s);
let state = createState(),
  started = false,
  paused = false,
  speed = 1,
  accumulator = 0,
  sound = false,
  audio,
  samples = [],
  actions = [],
  lastAdvice = "";
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
let best = 0;
try {
  best = Number(localStorage.getItem("red-veil-best")) || 0;
} catch {}
$("#app").innerHTML = missionMarkup();
const scene = createScene($("#scene"));
function openDialog(id) {
  $(id).showModal();
}
for (const d of document.querySelectorAll("dialog"))
  d.querySelector(".dialog-close")?.addEventListener("click", () => d.close());
$("#brief-open").onclick = () => openDialog("#brief");
$("#science-open").onclick = () => openDialog("#science");
$("#missions-open").onclick = () => openDialog("#missions");
$("#brief-ready").onclick = () => $("#brief").close();
function beep() {
  if (!sound) return;
  try {
    audio ??= new AudioContext();
    audio.resume();
    const o = audio.createOscillator(),
      g = audio.createGain();
    o.type = "sine";
    o.frequency.setValueAtTime(520, audio.currentTime);
    o.frequency.exponentialRampToValueAtTime(780, audio.currentTime + 0.08);
    g.gain.setValueAtTime(0.035, audio.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + 0.12);
    o.connect(g).connect(audio.destination);
    o.start();
    o.stop(audio.currentTime + 0.12);
  } catch {}
}
$("#sound").onclick = () => {
  sound = !sound;
  $("#sound").setAttribute("aria-pressed", sound);
  $("#sound").setAttribute(
    "aria-label",
    sound ? "Disable sound" : "Enable sound",
  );
  beep();
};
function act(action) {
  if (state.status !== "running") return;
  state = applyAction(state, action);
  actions.push({ time: state.time, action, value: state[action] });
  beep();
  render();
}
for (const action of ["shelter", "cleaning", "conserve", "visorCleaning"])
  $("#" + action).onclick = () => act(action);
$("#apply-advice").onclick = () => {
  const a = advice(state);
  if (a.action) act(a.action);
};
function play() {
  if (state.status !== "running") return;
  if (!started) {
    started = true;
    paused = false;
  } else paused = !paused;
  beep();
  render();
}
$("#start").onclick = play;
function reset(id = state.scenarioId) {
  state = createState(id);
  started = false;
  paused = false;
  accumulator = 0;
  samples = [];
  actions = [];
  lastAdvice = "";
  $("#result").close();
  render();
}
$("#restart").onclick = () => {
  paused = true;
  render();
  openDialog("#missions");
};
$("#again").onclick = () => reset();
for (const b of document.querySelectorAll("[data-mission]"))
  b.onclick = () => {
    reset(b.dataset.mission);
    $("#missions").close();
  };
for (const b of document.querySelectorAll("[data-speed]"))
  b.onclick = () => {
    speed = Number(b.dataset.speed);
    for (const s of document.querySelectorAll("[data-speed]")) {
      s.classList.toggle("active", s === b);
      s.setAttribute("aria-pressed", s === b);
    }
  };
window.addEventListener("keydown", (e) => {
  if (
    document.querySelector("dialog[open]") ||
    /INPUT|TEXTAREA|SELECT|BUTTON|A|SUMMARY/.test(e.target.tagName) ||
    e.ctrlKey ||
    e.metaKey ||
    e.altKey
  )
    return;
  if (e.code === "Space") {
    e.preventDefault();
    play();
  }
  const action = {
    1: "shelter",
    2: "cleaning",
    3: "conserve",
    4: "visorCleaning",
  }[e.key];
  if (action) act(action);
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden && started) {
    paused = true;
    accumulator = 0;
    render();
  }
});
$("#clear-data").onclick = () => {
  try {
    localStorage.removeItem("red-veil-best");
    best = 0;
    $("#clear-data").textContent = "Saved score cleared";
  } catch {
    $("#clear-data").textContent = "Storage unavailable";
  }
};
function fmtHour(t) {
  const mins = Math.floor(t * 60 + 1e-6);
  return `${Math.floor(mins / 60)
    .toString()
    .padStart(2, "0")}:${(mins % 60).toString().padStart(2, "0")}`;
}
function finish() {
  const d = debrief(state);
  const success = state.status === "success",
    partial = state.status === "partial";
  $("#result-title").textContent = success
    ? "You found a way through."
    : partial
      ? "Safe crew. A little more reserve?"
      : "Every explorer learns.";
  $("#result-subtitle").textContent = success
    ? "Your crew is protected and the outpost can recover. What would you try differently next time?"
    : state.status === "dose-abort"
      ? "Mission paused for crew safety. Try moving into shelter before the particle event."
      : state.status === "suit-abort"
        ? "The suit battery ran low. Return to shelter sooner; visor cleaning also uses suit power."
        : state.status === "power-abort"
          ? "The battery ran out. Try saving power and cleaning when the sky is brighter."
          : "The crew made it through. Save more energy for recovery on your next mission.";
  $("#result-metrics").innerHTML =
    `<div><strong>${state.energy.toFixed(1)}<small> kWh</small></strong><span>Battery left</span></div><div><strong>${state.dose.toFixed(2)}<small> mSv</small></strong><span>Crew exposure</span></div><div><strong>${state.research.toFixed(1)}<small> hrs</small></strong><span>Lab work</span></div>`;
  $("#result-notes").replaceChildren(
    ...d.notes.map((n) => {
      const p = document.createElement("p");
      p.textContent = "→ " + n;
      return p;
    }),
  );
  $("#baseline").innerHTML =
    `<span>YOUR RUN <b>${fmtHour(state.time)} hrs · ${state.status}</b></span><span>FIXED STRATEGY <b>${fmtHour(d.baseline.time)} hrs · ${d.baseline.status}</b></span>`;
  if (success) {
    best = Math.max(best, state.energy);
    try {
      localStorage.setItem("red-veil-best", String(best));
    } catch {}
  }
  openDialog("#result");
  beep();
}
$("#export").onclick = () => {
  const blob = new Blob(
    [
      JSON.stringify(
        {
          version: 1,
          model: "red-veil-0.2",
          scenario: scenarioById(state.scenarioId),
          parameters: SYSTEM,
          actions,
          samples,
          result: state,
          baseline: debrief(state).baseline,
        },
        null,
        2,
      ),
    ],
    { type: "application/json" },
  );
  const url = URL.createObjectURL(blob),
    a = document.createElement("a");
  a.href = url;
  a.download = `${brand.package_slug}-${state.scenarioId}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};
function render() {
  const t = telemetry(state),
    s = scenarioById(state.scenarioId);
  $("#suit-energy").textContent =
    `${state.suitEnergy.toFixed(2)} / ${SYSTEM.suitCapacity.toFixed(2)} kWh`;
  $("#suit-status").textContent =
    state.returning > 0
      ? `Returning · ${Math.ceil(state.returning * 60)} min to shelter`
      : state.eva
        ? "Outside · Life support always on"
        : "Inside · Suit power preserved";
  $("#visor-status").textContent =
    `${Math.round((1 - state.visorDust) * 100)}% clear`;
  $("#inspection").value = state.inspection;
  $("#inspection-status").textContent =
    state.inspection >= 1
      ? "Complete · Full array capacity restored"
      : `${Math.round(state.inspection * 100)}% checked · Work needs a clear visor`;
  $("#shelter").querySelector("strong").textContent =
    state.returning > 0
      ? "Returning to shelter"
      : state.shelter
        ? "Crew sheltered"
        : "Shelter crew";
  $("#energy").textContent = state.energy.toFixed(1);
  $("#dose").textContent = state.dose.toFixed(2);
  $("#energy-bar").style.width = `${(state.energy / SYSTEM.capacity) * 100}%`;
  $("#dose-bar").style.width =
    `${Math.min(100, (state.dose / SYSTEM.doseLimit) * 100)}%`;
  $("#energy-label").textContent =
    state.energy < 2.4
      ? "Reserve low"
      : state.energy < 5
        ? "Watch reserve"
        : "Healthy";
  $("#energy-label").classList.toggle("warning", state.energy < 5);
  $("#net").textContent = `${t.net >= 0 ? "+" : ""}${t.net.toFixed(2)} kW net`;
  $("#solar").textContent = `${t.solar.toFixed(2)} kW`;
  $("#dust-label").textContent = `${Math.round(state.dust * 100)}% panel dust`;
  $("#crew-label").textContent =
    state.returning > 0
      ? "Returning"
      : state.shelter
        ? "In shelter"
        : state.eva
          ? "Outside"
          : "In the lab";
  $("#crew-message").textContent =
    state.returning > 0
      ? "Coming home. Life support stays on."
      : state.eva
        ? "One outside. One in the habitat."
        : state.shelter
          ? "Safe in the shielded refuge."
          : state.conserve
            ? "Essentials on. Experiments slowed."
            : "Working in the main habitat.";
  $("#clock").textContent = fmtHour(state.time);
  $("#playhead").style.left = `${(state.time / s.duration) * 100}%`;
  $("#radiation-track").style.left = `${(s.eventStart / s.duration) * 100}%`;
  $("#radiation-track").style.width =
    `${((s.eventEnd - s.eventStart) / s.duration) * 100}%`;
  $("#sky-label").textContent =
    t.transmission < 0.15
      ? "Sky: thick dust"
      : t.storm > 0.3
        ? "Sky: hazy"
        : "Sky: clearing";
  $("#phase").textContent = t.event
    ? "Time to take cover"
    : state.time > 8
      ? "Find the light again"
      : t.storm > 0.4
        ? "Weather the storm"
        : "Before the storm";
  $("#phase-detail").textContent = t.event
    ? "Space particles are arriving. The refuge is ready."
    : t.storm > 0.4
      ? "The sky is dim. Every watt matters."
      : "Your crew is counting on you.";
  $("#mission-status").textContent = !started
    ? "STANDING BY"
    : state.status !== "running"
      ? "MISSION ENDED"
      : paused
        ? "PAUSED"
        : "MISSION ACTIVE";
  $("#start").textContent = !started
    ? "Launch mission ↗"
    : paused
      ? "Resume mission ▶"
      : "Pause mission Ⅱ";
  $("#start").disabled = state.status !== "running";
  for (const a of ["shelter", "cleaning", "conserve", "visorCleaning"]) {
    $("#" + a).setAttribute("aria-pressed", state[a]);
    $("#" + a).disabled = state.status !== "running";
  }
  $("#visorCleaning").disabled =
    !state.eva || state.returning > 0 || state.status !== "running";
  $("#shelter").disabled = state.returning > 0 || state.status !== "running";
  if (started) {
    const a = advice(state);
    $("#advice-title").textContent = a.title;
    $("#advice-reason").textContent = a.reason;
    $("#apply-advice").hidden = !a.action || state.status !== "running";
    if (a.title !== lastAdvice) {
      $("#announcer").textContent = a.title;
      lastAdvice = a.title;
    }
  } else {
    $("#advice-title").textContent = "You’re in command.";
    $("#advice-reason").textContent =
      "Launch when you’re ready. I’ll help you spot the trade-offs.";
    $("#apply-advice").hidden = true;
  }
  if (samples.length) {
    const pts = samples
      .slice(-60)
      .map(
        (s, i, arr) =>
          `${(i / Math.max(1, arr.length - 1)) * 150},${30 - (s.solar / 4.8) * 28}`,
      )
      .join(" ");
    $("#sparkline").innerHTML = `<polyline points="${pts}"/>`;
  } else $("#sparkline").innerHTML = '<path d="M0 26H150"/>';
}
let last = performance.now(),
  lastDraw = 0,
  lastUI = 0;
function loop(now) {
  const dt = Math.min((now - last) / 1000, 0.25);
  last = now;
  if (!document.hidden) {
    if (
      started &&
      !paused &&
      state.status === "running" &&
      !document.querySelector("dialog[open]")
    ) {
      accumulator += dt * SYSTEM.hoursPerSecond * speed;
      while (accumulator >= SYSTEM.stepHours && state.status === "running") {
        state = step(state);
        accumulator -= SYSTEM.stepHours;
        if (!samples.length || state.time - samples.at(-1).time >= 0.1)
          samples.push({
            time: state.time,
            energy: state.energy,
            dose: state.dose,
            solar: telemetry(state).solar,
          });
      }
      if (state.status !== "running") {
        render();
        finish();
      }
    }
    if (now - lastDraw > 1000 / 30) {
      scene.update(state, telemetry(state), reducedMotion);
      lastDraw = now;
    }
    if (now - lastUI > 200) {
      render();
      lastUI = now;
    }
  }
  requestAnimationFrame(loop);
}
render();
requestAnimationFrame(loop);
openDialog("#brief");
if ("serviceWorker" in navigator && import.meta.env.PROD)
  navigator.serviceWorker
    .register(`${import.meta.env.BASE_URL}sw.js`)
    .catch(() => {});
