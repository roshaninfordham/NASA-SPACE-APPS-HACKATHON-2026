import test from "node:test";
import assert from "node:assert/strict";
import {
  createState,
  step,
  telemetry,
  environment,
  runPolicy,
  fixedPolicy,
  adaptivePolicy,
  applyAction,
} from "../src/simulation.js";
import { SCENARIOS, SYSTEM } from "../src/scenarios.js";
test("energy balance conserves kWh without clipping", () => {
  const s = createState();
  const t = telemetry(s);
  const next = step(s);
  assert.ok(
    Math.abs(next.energy - s.energy - t.net * SYSTEM.stepHours) < 1e-10,
  );
});
test("dose accumulates in mSv and shelter reduces exposure without power load", () => {
  const s = { ...createState(), time: 5 };
  const shelter = { ...s, shelter: true };
  assert.equal(telemetry(s).load, telemetry(shelter).load);
  assert.ok(
    Math.abs(step(shelter).dose / step(s).dose - SYSTEM.shelterFactor) < 1e-10,
  );
});
test("cleaning cannot remove atmospheric opacity", () => {
  const s = { ...createState(), time: 6, cleaning: true };
  const next = step(s);
  assert.ok(next.dust < s.dust);
  assert.equal(telemetry(next).tau, environment(next.time, SCENARIOS[0]).tau);
  assert.ok(telemetry(next).transmission < 0.1);
});
test("essential life support cannot be switched off", () => {
  const s = { ...createState(), conserve: true };
  assert.ok(telemetry(s).load >= SYSTEM.essentialKW);
  assert.deepEqual(applyAction(s, "essential"), s);
});
for (const scenario of SCENARIOS) {
  test(`${scenario.id}: adaptive policy is viable, deterministic, and finite`, () => {
    const a = runPolicy(scenario.id, adaptivePolicy);
    assert.equal(a.status, "success");
    assert.deepEqual(a, runPolicy(scenario.id, adaptivePolicy));
    assert.ok(a.dose < SYSTEM.doseLimit);
    assert.ok(a.energy >= SYSTEM.recoveryKWh);
  });
  test(`${scenario.id}: fixed policy fails for calculated energy reasons`, () => {
    const s = runPolicy(scenario.id, fixedPolicy);
    assert.equal(s.status, "power-abort");
    assert.equal(s.energy, 0);
  });
}
test("terminal states do not advance and invalid time steps are rejected", () => {
  const s = { ...createState(), status: "power-abort" };
  assert.equal(step(s), s);
  for (const n of [0, -1, NaN, Infinity, 1])
    assert.throws(() => step(createState(), n), RangeError);
});
test("unsheltered event leads to dose abort", () => {
  const s = runPolicy("first-light", (s) => ({ ...s, conserve: true }));
  assert.equal(s.status, "dose-abort");
});
test("visor cleaning draws only additional suit power, not habitat power", () => {
  const a = createState(),
    b = { ...a, visorCleaning: true };
  assert.equal(telemetry(a).load, telemetry(b).load);
  assert.ok(
    Math.abs(
      step(a).suitEnergy -
        step(b).suitEnergy -
        SYSTEM.visorCleaningKW * SYSTEM.stepHours,
    ) < 1e-10,
  );
  assert.ok(step(b).visorDust < step(a).visorDust);
});
test("shelter command includes travel exposure and continuous suit life support", () => {
  let s = applyAction(createState(), "shelter");
  assert.equal(s.shelter, false);
  assert.equal(s.returning, SYSTEM.returnHours);
  const energy = s.suitEnergy;
  s = step(s);
  assert.ok(s.suitEnergy < energy);
  assert.ok(s.dose > 0);
  for (let i = 0; i < 20; i++) s = step(s);
  assert.equal(s.shelter, true);
  assert.equal(s.eva, false);
  assert.equal(s.returning, 0);
  const indoors = step(s);
  assert.equal(indoors.suitEnergy, s.suitEnergy);
});
test("visibility controls inspection progress and inspection improves solar output", () => {
  const clear = { ...createState(), visorDust: 0 },
    dusty = { ...createState(), visorDust: 0.9 };
  assert.ok(step(clear).inspection > step(dusty).inspection);
  assert.ok(
    telemetry({ ...clear, inspection: 1 }).solar > telemetry(clear).solar,
  );
  assert.equal(step({ ...clear, returning: 0.1 }).inspection, 0);
});
test("suit depletion safely aborts the mission and cannot draw from the habitat battery", () => {
  const s = { ...createState(), suitEnergy: 0.0001 };
  assert.equal(step(s).status, "suit-abort");
  assert.ok(step(s).energy > 0);
});
