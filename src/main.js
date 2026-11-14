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
import { SCENARIOS, SYSTEM, SCIENCE } from "./scenarios.js";
import { createScene } from "./scene.js";
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
$("#app").innerHTML = `
<header class="topbar"><a class="brand" href="./" aria-label="Red Veil home"><span class="brand-mark">R</span><span>RED VEIL<small>A MARS SURVIVAL MISSION</small></span></a><div class="mission-tag"><span class="live-dot"></span> MARS OPERATIONS <span class="divider">/</span> SOL 018</div><div class="header-actions"><button id="science-open" class="quiet">Field guide <span>↗</span></button><button id="sound" class="icon-button" aria-label="Enable sound" aria-pressed="false">♫</button></div></header>
<main><section class="mission-heading"><div><div class="eyebrow">JUNIOR ASTRONAUT PROGRAM · MISSION 01</div><h1>A small outpost.<br class="mobile-break"> <em>A big responsibility.</em></h1><p>A storm is coming. Keep your crew safe and the lights on.</p></div><button id="brief-open" class="text-button">How to play <span>ⓘ</span></button></section>
<div class="dashboard"><section class="world-card" aria-label="Mission view"><div class="world-top"><div><span class="live-dot"></span> ELYSIUM OUTPOST <small>04° N / 136° E · ILLUSTRATIVE SITE</small></div><span class="view-label">LIVE SIMULATION</span></div><div id="scene"></div><div class="world-title"><span class="eyebrow">AEGIS ENVIRONMENTAL TEST</span><h2 id="phase">Before the storm</h2><p id="phase-detail">Your crew is counting on you.</p></div><div class="scene-label label-shelter">01 <span>SHIELDED REFUGE</span></div><div class="scene-label label-array">02 <span>SOLAR ARRAY</span></div><div class="world-bottom"><span>↔ Drag to explore</span><span id="sky-label">Sky: clear</span><span class="coordinates">12 HRS IN 4 MIN</span></div></section>
<aside class="status-panel"><div class="section-label">OUTPOST STATUS <span id="mission-status">STANDING BY</span></div><article class="metric"><div class="metric-name"><span>▰ &nbsp; Battery reserve</span><span id="energy-label">Healthy</span></div><div class="metric-value"><strong id="energy">8.0</strong><span>/ 12 kWh</span></div><div class="meter"><i id="energy-bar"></i><b title="Recovery reserve: 2.4 kWh"></b></div><div class="metric-foot"><span id="net">— kW net</span><span>Keep some for later</span></div></article><article class="metric"><div class="metric-name"><span>◈ &nbsp; Crew exposure</span><span id="crew-label">In the lab</span></div><div class="metric-value"><strong id="dose">0.00</strong><span>/ 4 mSv</span></div><div class="meter dose-meter"><i id="dose-bar"></i></div><div class="metric-foot"><span>Less is better</span><span>Game limit*</span></div></article><article class="metric compact"><div class="metric-name"><span>☀ &nbsp; Solar power</span><strong id="solar">0.00 kW</strong></div><div class="solar-detail"><span id="dust-label">28% panel dust</span><svg id="sparkline" viewBox="0 0 150 32" aria-label="Solar generation history" role="img"><path d="M0 26H150"/></svg></div></article><div class="crew-strip"><span class="crew-avatar">◉</span><div><strong>Two explorers. One team.</strong><small id="crew-message">Ready for your first command.</small></div></div></aside>
<section class="timeline-card"><div class="timeline-heading"><span class="section-label">YOUR NEXT 12 HOURS</span><span><b id="clock">00:00</b> <span class="muted">/ 12:00</span></span></div><div class="forecast"><div class="dust-track"><span>DUST STORM</span></div><div id="radiation-track"><span>PARTICLE EVENT</span></div><div id="playhead"></div></div><div class="timeline-ticks"><span>NOW</span><span>+3 HRS</span><span>+6 HRS</span><span>+9 HRS</span><span>+12 HRS</span></div><div class="playback"><button id="start" class="primary">Launch mission <span>↗</span></button><div class="speed-controls" aria-label="Simulation speed"><button class="speed active" data-speed="1" aria-pressed="true">1×</button><button class="speed" data-speed="2" aria-pressed="false">2×</button><button class="speed" data-speed="4" aria-pressed="false">4×</button></div><button id="restart" class="quiet">↻ Restart</button></div></section>
<section class="advisor"><div class="advisor-icon">✳</div><div><span class="eyebrow">AEGIS · YOUR MISSION PARTNER</span><h3 id="advice-title">You’re in command.</h3><p id="advice-reason">Launch when you’re ready. I’ll help you spot the trade-offs.</p><button id="apply-advice" class="text-button" hidden>Try this idea →</button></div></section>
</div>
<section class="controls-section"><div class="controls-heading"><h2>Three decisions. <span>Make them count.</span></h2><span>Change your plan as the storm changes.</span></div><div class="controls"><button class="control" id="shelter" aria-pressed="false"><span class="control-icon">⌂</span><span class="control-copy"><strong>Shelter crew</strong><small>Take cover from space particles.</small><span class="control-effect">Less exposure · Lab work pauses</span></span><span class="toggle"><i></i></span><span class="key">1</span></button><button class="control" id="cleaning" aria-pressed="false"><span class="control-icon">✧</span><span class="control-copy"><strong>Clean panels</strong><small>Brush off dust. Catch more sunlight.</small><span class="control-effect">Cleaner panels · Uses 0.9 kW</span></span><span class="toggle"><i></i></span><span class="key">2</span></button><button class="control" id="conserve" aria-pressed="false"><span class="control-icon">ϟ</span><span class="control-copy"><strong>Save power</strong><small>Keep the essentials. Pause the extras.</small><span class="control-effect">More reserve · Slower research</span></span><span class="toggle"><i></i></span><span class="key">3</span></button></div></section>
<section class="eva-card" aria-label="Spacesuit and visor"><div><span class="eyebrow">ASTRONAUT / SUIT</span><strong id="suit-energy">0.90 kWh</strong><small id="suit-status">Outside · Life support always on</small></div><div><span class="eyebrow">VISOR / VISIBILITY</span><strong id="visor-status">85% clear</strong><small>Cleaning uses suit power</small></div><div><span class="eyebrow">ARRAY INSPECTION</span><progress id="inspection" value="0" max="1" aria-label="Solar array inspection progress"></progress><small id="inspection-status">Finish outside to restore full array capacity</small></div><button id="visorCleaning" aria-pressed="false">Clean visor</button></section><footer><span>BUILT FOR CURIOUS EXPLORERS, AGES 7–12</span><span>*An educational model. Mission limits are fictional.</span><button id="missions-open" class="text-button">Choose a mission →</button></footer></main>
<dialog id="brief"><button class="dialog-close" aria-label="Close guide">×</button><span class="eyebrow">WELCOME, MISSION COMMANDER</span><h2>Mars needs a<br><em>good decision-maker.</em></h2><p>One explorer is checking the solar array outside. Their teammate is inside the outpost. A dust storm will block sunlight. A separate burst of space particles will arrive, too.</p><ol class="brief-steps"><li><b>Protect your crew.</b> Send them into the shelter before the particle event.</li><li><b>Use power wisely.</b> Cleaning costs energy. It works best when sunlight reaches the panels.</li><li><b>Watch the spacesuit.</b> Clear the visor to finish the inspection faster. This uses a separate suit battery. Returning to shelter takes time.</li><li><b>Leave a little in the tank.</b> Save enough battery to restart after the storm.</li></ol><p class="note">There’s time to think: pause whenever you like. A mission abort means “let’s try a different plan.”</p><button id="brief-ready" class="primary">I’m ready to explore →</button><small class="dialog-hint">Keyboard: 1 / 2 / 3 / 4 change systems · Space pauses</small></dialog>
<dialog id="science"><button class="dialog-close" aria-label="Close field guide">×</button><span class="eyebrow">THE FIELD GUIDE</span><h2>Real ideas.<br><em>A miniature mission.</em></h2><p>Our mission is fictional. The trade-offs come from physics. Open each idea to explore the maths.</p><details open><summary>Why does the battery change?</summary><p>Sunlight makes electricity. Your outpost uses it. The battery stores what is left.</p><code>ΔE = (Psolar − Pload) × Δt</code><p>Energy is in kWh, power in kW, and time in hours. Life support always gets power until the reserve runs out.</p></details><details><summary>Why can’t cleaning fix a dust storm?</summary><p>Dust on panels and dust in the sky are different problems. Cleaning only removes dust from surfaces.</p><code>Psolar = Prated × exp(−τ / μ) × (1 − dust)</code><p>This simplified direct-light model omits diffuse light, temperature, and spectral effects. It is a teaching approximation, not a solar-system design tool.</p></details><details><summary>What does the shelter do?</summary><p>Installed material reduces exposure to space particles. The shielding itself needs no electricity. In our game, sheltering also pauses lab work.</p><code>ΔD = dose rate × shelter factor × Δt</code><p>The 0.67 mSv/day background reference comes from historical Curiosity RAD surface measurements. The event intensity, 85% shelter reduction, and 4 mSv mission limit are illustrative, not astronaut safety standards.</p><a href="${SCIENCE.reference}" target="_blank" rel="noopener noreferrer">Read the NASA source ↗</a></details><details><summary>What is real, and what did we invent?</summary><p>NASA observations inform the background radiation scale. Dust reduces solar output, and NASA has investigated electrodynamic dust removal. Our habitat, weather timeline, loads, battery, shielding factor, and particle event are game assumptions. Lunar dust-cleaning demonstrations do not establish performance on Mars.</p><p>AEGIS offers transparent rules, not a trained AI. The comparison uses the same scenario for both players. This game is not certified astronaut training or a predictive radiation tool.</p></details><details><summary>How are the suit and visor connected?</summary><p>The suit has its own battery. Life support is automatic while outside, including the journey home. Visor cleaning spends additional suit energy to improve visibility. Better visibility speeds the array inspection, which restores up to 25% of array capacity. Returning early keeps the explorer safe but may leave that work unfinished.</p><p>The suit load, inspection time, and capacity bonus are game assumptions. A visor cleaner does not protect against radiation.</p></details><details><summary>For grown-ups and educators</summary><p>Ask: Why did cleaning help more at one time than another? What changed when you saved power? What would you test next?</p><p>No accounts, ads, analytics, or personal data collection. Best scores stay on this device. Optional mission downloads contain decisions and simulated measurements only.</p><button id="clear-data" class="quiet">Clear saved best score</button></details></dialog>
<dialog id="missions"><button class="dialog-close" aria-label="Close mission selection">×</button><span class="eyebrow">THE NEXT EXPERIMENT</span><h2>Same outpost.<br><em>New decisions.</em></h2><div class="mission-options">${SCENARIOS.map((s, i) => `<button data-mission="${s.id}"><span>0${i + 1}</span><strong>${s.name}<small>${s.subtitle}</small></strong><span>→</span></button>`).join("")}</div><p>Choosing a mission starts a fresh experiment.</p></dialog>
<dialog id="result"><span class="eyebrow">MISSION DEBRIEF</span><h2 id="result-title"></h2><p id="result-subtitle"></p><div id="result-metrics"></div><div id="result-notes"></div><div class="comparison"><h3>What if everything stayed on?</h3><p>A fixed crew-in-shelter, cleaning-on, normal-power strategy faced the same weather. It skipped the exterior inspection.</p><div id="baseline"></div><small>Aborted runs end early. Compare survival time as well as final resources; this is one baseline, not proof of universal superiority.</small></div><div class="result-actions"><button id="again" class="primary">Try another plan ↗</button><button id="export" class="quiet">Download mission log</button></div></dialog>
<div id="announcer" class="sr-only" role="status" aria-live="polite"></div>`;
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
  a.download = `red-veil-${state.scenarioId}.json`;
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
