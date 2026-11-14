import { SCENARIOS, SYSTEM, SCIENCE } from './scenarios.js';
export const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));
export function scenarioById(id) { return SCENARIOS.find(s => s.id === id) ?? SCENARIOS[0]; }
export function environment(time, scenario) {
  const storm = Math.sin(Math.PI * clamp((time - 1) / 10, 0, 1)) ** 2;
  const tau = 0.25 + scenario.peakTau * storm;
  const solarAngle = 0.65 + 0.35 * Math.sin(Math.PI * time / scenario.duration);
  const event = time >= scenario.eventStart && time < scenario.eventEnd;
  return { storm, tau, solarAngle, transmission: Math.exp(-tau / solarAngle), doseRate: SCIENCE.backgroundDosePerDay / 24 + (event ? scenario.eventDose : 0), event };
}
export function createState(id = 'first-light') {
  const scenario = scenarioById(id);
  return { scenarioId: scenario.id, time: 0, energy: scenario.initialEnergy, dose: 0, dust: 0.28, research: 0, shelter: false, cleaning: false, conserve: false, status: 'running', generated: 0, consumed: 0, cleaningEnergy: 0, peakStormCleaning: 0, history: [] };
}
export function telemetry(state) {
  const env = environment(state.time, scenarioById(state.scenarioId));
  const solar = SYSTEM.arrayKW * env.transmission * (1 - state.dust);
  const load = SYSTEM.essentialKW + (state.conserve ? SYSTEM.conserveKW : SYSTEM.normalKW) + (state.cleaning ? SYSTEM.cleaningKW : 0);
  return { ...env, solar, load, net: solar - load, doseRate: env.doseRate * (state.shelter ? SYSTEM.shelterFactor : 1) };
}
export function applyAction(state, action) {
  if (state.status !== 'running' || !['shelter', 'cleaning', 'conserve'].includes(action)) return state;
  return { ...state, [action]: !state[action] };
}
/** Fixed-step integration in hours; pure and independent of renderer or wall clock. */
export function step(state, dt = SYSTEM.stepHours) {
  if (!Number.isFinite(dt) || dt <= 0 || dt > 0.1) throw new RangeError('Step must be > 0 and <= 0.1 hours');
  if (state.status !== 'running') return state;
  const scenario = scenarioById(state.scenarioId);
  dt = Math.min(dt, scenario.duration - state.time);
  const t = telemetry(state);
  const energy = clamp(state.energy + t.net * dt, 0, SYSTEM.capacity);
  const dose = state.dose + t.doseRate * dt;
  const time = Math.min(scenario.duration, state.time + dt);
  const finished = time >= scenario.duration - 1e-8;
  const status = energy <= 0 ? 'power-abort' : dose >= SYSTEM.doseLimit ? 'dose-abort' : finished ? (energy >= SYSTEM.recoveryKWh ? 'success' : 'partial') : 'running';
  return { ...state, time, energy, dose, status,
    dust: clamp(state.dust + (scenario.deposition * (0.3 + t.storm) - (state.cleaning ? SYSTEM.cleaningRate : 0)) * dt, 0, 0.95),
    research: state.research + (!state.shelter ? (state.conserve ? 0.25 : 1) : 0) * dt,
    generated: state.generated + t.solar * dt,
    consumed: state.consumed + t.load * dt,
    cleaningEnergy: state.cleaningEnergy + (state.cleaning ? SYSTEM.cleaningKW * dt : 0),
    peakStormCleaning: state.peakStormCleaning + (state.cleaning && t.transmission < 0.15 ? dt : 0),
  };
}
export function advice(state) {
  const s = scenarioById(state.scenarioId), t = telemetry(state);
  if (!state.shelter && state.time >= s.eventStart - 0.75 && state.time < s.eventEnd) return { action: 'shelter', title: 'Bring the crew to shelter', reason: 'The particle event is near or active. Installed shielding reduces exposure; it needs no continuous power.' };
  if (state.cleaning && t.transmission < 0.15) return { action: 'cleaning', title: 'Pause panel cleaning', reason: 'Airborne dust is blocking sunlight. Cleaner panels cannot clear the sky. Save the cleaning power.' };
  if (!state.conserve && (t.net < -0.5 || state.energy < 5)) return { action: 'conserve', title: 'Protect the power reserve', reason: 'Pause nonessential experiments. Essential life support remains powered in both modes.' };
  if (state.shelter && state.time >= s.eventEnd) return { action: 'shelter', title: 'The particle event has passed', reason: 'Resume work in the main habitat. The dust storm and radiation event are independent hazards.' };
  if (!state.cleaning && t.transmission > 0.28 && state.dust > 0.22 && state.energy > 2) return { action: 'cleaning', title: 'Sunlight is available. Clean now.', reason: 'Removing deposited dust can recover array output while sunlight reaches the surface.' };
  if (state.cleaning && state.dust < 0.04) return { action: 'cleaning', title: 'Panels are clean', reason: 'Switch off cleaning to avoid spending power without additional benefit.' };
  return { action: null, title: 'Watch the forecast', reason: 'Keep one eye on the crew and one on the reserve. You can pause to plan your next move.' };
}
export function runPolicy(id, policy) {
  let state = createState(id);
  for (let n = 0; n < 2000 && state.status === 'running'; n++) {
    state = policy(state);
    state = step(state);
  }
  return state;
}
export const fixedPolicy = s => ({ ...s, shelter: true, cleaning: true, conserve: false });
export function adaptivePolicy(s) { const a = advice(s).action; return a ? applyAction(s, a) : s; }
export function debrief(state) {
  const baseline = runPolicy(state.scenarioId, fixedPolicy);
  const notes = [state.dose < SYSTEM.doseLimit ? 'Crew dose stayed below the fictional mission limit.' : 'Shelter earlier: exposure accumulates over time, even when power reserves are healthy.', state.energy >= SYSTEM.recoveryKWh ? 'You retained the energy required by this scenario for recovery.' : 'Recovery needs a reserve. Try conserving nonessential power before the storm peaks.', state.peakStormCleaning > 0.5 ? 'Cleaning during the darkest sky spent energy without restoring much generation.' : 'You avoided prolonged cleaning during the darkest part of the storm.'];
  return { baseline, notes };
}
