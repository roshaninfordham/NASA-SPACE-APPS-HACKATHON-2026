import { SCENARIOS, SYSTEM, SCIENCE } from "./scenarios.js";
export const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));
export function scenarioById(id) {
  return SCENARIOS.find((s) => s.id === id) ?? SCENARIOS[0];
}
export function environment(time, scenario) {
  const storm = Math.sin(Math.PI * clamp((time - 1) / 10, 0, 1)) ** 2;
  const tau = 0.25 + scenario.peakTau * storm;
  const solarAngle =
    0.65 + 0.35 * Math.sin((Math.PI * time) / scenario.duration);
  const event = time >= scenario.eventStart && time < scenario.eventEnd;
  return {
    storm,
    tau,
    solarAngle,
    transmission: Math.exp(-tau / solarAngle),
    doseRate:
      SCIENCE.backgroundDosePerDay / 24 + (event ? scenario.eventDose : 0),
    event,
  };
}
export function createState(id = "first-light") {
  const scenario = scenarioById(id);
  return {
    scenarioId: scenario.id,
    time: 0,
    energy: scenario.initialEnergy,
    dose: 0,
    dust: 0.28,
    research: 0,
    suitEnergy: SYSTEM.suitCapacity,
    visorDust: 0.25,
    visorCleaning: false,
    eva: true,
    returning: 0,
    inspection: 0,
    shelter: false,
    cleaning: false,
    conserve: false,
    status: "running",
    generated: 0,
    consumed: 0,
    cleaningEnergy: 0,
    peakStormCleaning: 0,
  };
}
export function telemetry(state) {
  const env = environment(state.time, scenarioById(state.scenarioId));
  const solar =
    SYSTEM.arrayKW *
    (0.75 + 0.25 * state.inspection) *
    env.transmission *
    (1 - state.dust);
  const load =
    SYSTEM.essentialKW +
    (state.conserve ? SYSTEM.conserveKW : SYSTEM.normalKW) +
    (state.cleaning ? SYSTEM.cleaningKW : 0);
  return {
    ...env,
    solar,
    load,
    net: solar - load,
    doseRate: env.doseRate * (state.shelter ? SYSTEM.shelterFactor : 1),
  };
}
export function applyAction(state, action) {
  if (
    state.status !== "running" ||
    !["shelter", "cleaning", "conserve", "visorCleaning", "eva"].includes(
      action,
    )
  )
    return state;
  if (action === "shelter" && state.returning > 0) return state;
  if (action === "shelter" && state.eva)
    return { ...state, returning: SYSTEM.returnHours, visorCleaning: false };
  if (action === "visorCleaning" && (!state.eva || state.returning > 0))
    return state;
  if (action === "eva") {
    if (state.eva || state.returning > 0 || state.shelter) return state;
    return { ...state, eva: true };
  }
  return { ...state, [action]: !state[action] };
}
/** Fixed-step integration in hours; pure and independent of renderer or wall clock. */
export function step(state, dt = SYSTEM.stepHours) {
  if (!Number.isFinite(dt) || dt <= 0 || dt > 0.1)
    throw new RangeError("Step must be > 0 and <= 0.1 hours");
  if (state.status !== "running") return state;
  const scenario = scenarioById(state.scenarioId);
  dt = Math.min(dt, scenario.duration - state.time);
  const t = telemetry(state);
  const energy = clamp(state.energy + t.net * dt, 0, SYSTEM.capacity);
  const dose = state.dose + t.doseRate * dt;
  const time = Math.min(scenario.duration, state.time + dt);
  const finished = time >= scenario.duration - 1e-8;
  const returning = Math.max(0, state.returning - dt);
  const arrived = state.returning > 0 && returning <= 1e-8;
  const suitEnergy = Math.max(
    0,
    state.suitEnergy -
      (state.eva
        ? SYSTEM.suitLifeSupportKW +
          (state.visorCleaning ? SYSTEM.visorCleaningKW : 0)
        : 0) *
        dt,
  );
  const visorDust = clamp(
    state.visorDust +
      (state.eva
        ? 0.03 +
          t.storm * 0.12 -
          (state.visorCleaning ? SYSTEM.visorCleaningRate : 0)
        : 0) *
        dt,
    0,
    0.95,
  );
  const inspection = clamp(
    state.inspection +
      (state.eva && !state.returning
        ? ((1 - state.visorDust) * dt) / SYSTEM.inspectionHours
        : 0),
    0,
    1,
  );
  const status =
    suitEnergy <= 0 && state.eva
      ? "suit-abort"
      : energy <= 0
        ? "power-abort"
        : dose >= SYSTEM.doseLimit
          ? "dose-abort"
          : finished
            ? energy >= SYSTEM.recoveryKWh
              ? "success"
              : "partial"
            : "running";
  return {
    ...state,
    time,
    energy,
    dose,
    status,
    suitEnergy,
    visorDust,
    inspection,
    returning,
    eva: arrived ? false : state.eva,
    shelter: arrived ? true : state.shelter,
    dust: clamp(
      state.dust +
        (scenario.deposition * (0.3 + t.storm) -
          (state.cleaning ? SYSTEM.cleaningRate : 0)) *
          dt,
      0,
      0.95,
    ),
    research:
      state.research + (!state.shelter ? (state.conserve ? 0.25 : 1) : 0) * dt,
    generated: state.generated + t.solar * dt,
    consumed: state.consumed + t.load * dt,
    cleaningEnergy:
      state.cleaningEnergy + (state.cleaning ? SYSTEM.cleaningKW * dt : 0),
    peakStormCleaning:
      state.peakStormCleaning +
      (state.cleaning && t.transmission < 0.15 ? dt : 0),
  };
}
export function advice(state) {
  const s = scenarioById(state.scenarioId),
    t = telemetry(state);
  if (state.returning > 0)
    return {
      action: null,
      title: "Crew returning to shelter",
      reason:
        "Walking back takes nine simulated minutes. Suit life support stays on during the journey.",
    };
  if (
    !state.shelter &&
    state.time >= s.eventStart - 0.75 &&
    state.time < s.eventEnd
  )
    return {
      action: "shelter",
      title: "Bring the crew to shelter",
      reason:
        "The particle event is near or active. Installed shielding reduces exposure; it needs no continuous power.",
    };
  if (state.eva && state.suitEnergy < 0.15)
    return {
      action: "shelter",
      title: "Time to come inside",
      reason:
        "Your suit has its own battery. Keep enough power for the journey home.",
    };
  if (state.eva && state.visorDust > 0.25 && !state.visorCleaning)
    return {
      action: "visorCleaning",
      title: "Clear your view",
      reason:
        "Dust on the visor slows the panel inspection. Visor cleaning uses the suit battery, not the habitat battery.",
    };
  if (state.visorCleaning && state.visorDust < 0.04)
    return {
      action: "visorCleaning",
      title: "Your visor is clear",
      reason:
        "Switch the cleaner off to save suit energy. A clear visor does not stop radiation.",
    };
  if (state.cleaning && t.transmission < 0.15)
    return {
      action: "cleaning",
      title: "Pause panel cleaning",
      reason:
        "Airborne dust is blocking sunlight. Cleaner panels cannot clear the sky. Save the cleaning power.",
    };
  if (!state.conserve && (t.net < -0.5 || state.energy < 5))
    return {
      action: "conserve",
      title: "Protect the power reserve",
      reason:
        "Pause nonessential experiments. Essential life support remains powered in both modes.",
    };
  if (state.shelter && state.time >= s.eventEnd)
    return {
      action: "shelter",
      title: "The particle event has passed",
      reason:
        "Resume work in the main habitat. The dust storm and radiation event are independent hazards.",
    };
  if (
    !state.cleaning &&
    t.transmission > 0.28 &&
    state.dust > 0.22 &&
    state.energy > 2
  )
    return {
      action: "cleaning",
      title: "Sunlight is available. Clean now.",
      reason:
        "Removing deposited dust can recover array output while sunlight reaches the surface.",
    };
  if (state.cleaning && state.dust < 0.04)
    return {
      action: "cleaning",
      title: "Panels are clean",
      reason:
        "Switch off cleaning to avoid spending power without additional benefit.",
    };
  return {
    action: null,
    title: "Watch the forecast",
    reason:
      "Keep one eye on the crew and one on the reserve. You can pause to plan your next move.",
  };
}
export function runPolicy(id, policy) {
  let state = createState(id);
  for (let n = 0; n < 2000 && state.status === "running"; n++) {
    state = policy(state);
    state = step(state);
  }
  return state;
}
export const fixedPolicy = (s) => ({
  ...s,
  shelter: true,
  eva: false,
  returning: 0,
  cleaning: true,
  conserve: false,
});
export function adaptivePolicy(s) {
  const a = advice(s).action;
  return a ? applyAction(s, a) : s;
}
export function debrief(state) {
  const baseline = runPolicy(state.scenarioId, fixedPolicy);
  const notes = [
    state.dose < SYSTEM.doseLimit
      ? "Crew dose stayed below the fictional mission limit."
      : "Shelter earlier: exposure accumulates over time, even when power reserves are healthy.",
    state.energy >= SYSTEM.recoveryKWh
      ? "You retained the energy required by this scenario for recovery."
      : "Recovery needs a reserve. Try conserving nonessential power before the storm peaks.",
    state.peakStormCleaning > 0.5
      ? "Cleaning during the darkest sky spent energy without restoring much generation."
      : "You avoided prolonged cleaning during the darkest part of the storm.",
  ];
  return { baseline, notes };
}
