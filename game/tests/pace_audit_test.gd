# Independent audit: fixed-seed histories, closed-form fixtures, and numerical oracle.
# Run: godot --headless --path game --script res://tests/pace_audit_test.gd
extends SceneTree
const Model = preload("res://scripts/pace_mission.gd")
const SEED = 202611150804
const SPEEDS = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75]
var rng = RandomNumberGenerator.new()
var checks = 0
var failures = []
func check(ok: bool, label: String, detail: Dictionary = {}):
 checks += 1
 if not ok:
  failures.append({"check": label, "details": detail})
  print("PACE_AUDIT_FAILURE ", JSON.stringify(failures[-1]))
func near(a: float, b: float, tolerance: float = 1e-8) -> bool:
 return absf(a - b) <= tolerance + maxf(absf(a), absf(b)) * 1e-10
func partition(model, seconds: float):
 var left = seconds
 var count = 0
 while left > 0.0:
  var dt = minf(left, rng.randf_range(0.000003, 2.0))
  model.advance(dt)
  left = maxf(0.0, left - dt)
  count += 1
  if count > 100000: push_error("Audit partition limit"); quit(2); return
func _initialize(): call_deferred("run")
func run():
 rng.seed = SEED
 var work = [0.9375, 1.875, 2.8125, 3.75, 3.28125, 2.4609375, 2.1328125]
 var energy = [1.3515625, 1.703125, 2.0546875, 2.40625, 2.40625, 2.27880859375, 2.1689453125]
 var fatigue = [0.0, 0.0, 0.0, 0.0, 0.6, 0.9, 0.9]
 var status = ["lose", "pass", "pass", "win", "win", "pass", "pass"]
 for i in range(7):
  var m = Model.new()
  m.set_cleaning_speed(SPEEDS[i])
  m.advance(300.0)
  var s = m.snapshot()
  check(near(s.cleaned_work, work[i]), "constant/work/" + str(i), {"actual": s.cleaned_work, "expected": work[i]})
  check(near(s.battery_kwh, energy[i]), "constant/energy/" + str(i))
  check(near(s.fatigue, fatigue[i]), "constant/fatigue/" + str(i))
  check(near(s.dose_ugy, 10.9375), "constant/dose/" + str(i))
  check(s.status == status[i] and s.crew_sheltered, "constant/terminal/" + str(i))
  check(not m.set_cleaning_speed(1.0), "constant/terminal-command-rejected/" + str(i))
  m.advance(1000.0)
  check(m.snapshot() == s, "constant/terminal-immutable/" + str(i))
 # Recovery closed form: 10min at1.75 givesF=.6,w=1.53125;
 # 10min at.5 recovers linearly to0, adding.4375sections.
 var recovery = Model.new()
 recovery.set_cleaning_speed(1.75)
 recovery.advance(100.0)
 recovery.set_cleaning_speed(0.5)
 recovery.advance(100.0)
 check(near(recovery.snapshot().fatigue, 0.0), "switch/recovery-floor")
 check(near(recovery.snapshot().cleaned_work, 1.96875), "switch/analytic-work")
 # Uncapped work would be4.0546875. Full work freezes fatigue, not time/dose/energy.
 var capped = Model.new()
 capped.advance(250.0)
 capped.set_cleaning_speed(1.75)
 capped.advance(50.0)
 var cs = capped.snapshot()
 var cap_time = (1.0 - sqrt(0.52)) / 0.06
 check(near(cs.cleaned_work, 4.0), "cap/work")
 check(near(cs.fatigue, 0.06 * cap_time), "cap/fatigue-stops-with-work", {"actual": cs.fatigue, "expected": 0.06 * cap_time})
 check(near(cs.dose_ugy, 10.9375) and near(cs.sim_elapsed_seconds, 1800.0), "cap/fixed-terminal-clock")
 # Exact pass/win thresholds and a distinguishable value just below each.
 for fraction in [0.4, 0.8]:
  for delta in [0.0, -0.000001]:
   var m = Model.new({"base_cleaning_rate_sections_per_minute": (fraction + delta) * 4.0 / 30.0})
   m.advance(300.0)
   var expected = "win" if fraction == 0.8 and delta == 0.0 else ("lose" if fraction == 0.4 and delta < 0.0 else "pass")
   check(m.snapshot().status == expected, "outcome/threshold/" + str(fraction) + "/" + str(delta))
 # Empty storage followed by a net-power sign change: independently integrate
 # max(0, -2 + .1875*t) kW over0..30min, and the negative area separately.
 var empty = Model.new({"initial_battery_kwh": 0.0, "habitat_load_kw": 4.0})
 empty.advance(300.0)
 check(near(empty.snapshot().battery_kwh, 0.5840277777777778), "energy/empty-then-charging")
 check(near(empty.snapshot().unserved_energy_kwh, 0.17777777777777778), "energy/unserved-area")
 var full = Model.new({"battery_capacity_kwh": 0.6})
 full.advance(300.0)
 check(near(full.snapshot().battery_kwh, 0.6), "energy/capacity")
 check(near(full.snapshot().curtailed_energy_kwh, 1.80625), "energy/curtailed-area")
 for comfort in [0.5, 2.0]:
  var m = Model.new()
  m.set_pace(comfort)
  m.advance(300.0 / comfort)
  check(near(m.snapshot().cleaned_work, 3.75) and near(m.snapshot().dose_ugy, 10.9375), "clock/comfort-preserves-simulated-outcome/" + str(comfort))
 var micro = Model.new()
 for i in range(10000): micro.advance(0.000001)
 check(near(micro.snapshot().cleaned_work, 0.000125, 1e-12), "clock/microsecond-work-progress")
 for i in range(80):
  var cfg = Model.default_settings()
  cfg.clear_solar_power_kw = rng.randf_range(0.0, 50.0)
  cfg.habitat_load_kw = rng.randf_range(0.0, 30.0)
  cfg.minimum_solar_transmission = rng.randf()
  cfg.battery_capacity_kwh = rng.randf_range(0.001, 4.0)
  cfg.initial_battery_kwh = 0.0 if i % 3 == 0 else rng.randf() * cfg.battery_capacity_kwh
  var whole = Model.new(cfg)
  var split = Model.new(cfg)
  var commands = []
  var left = 30.0
  for j in range(12):
   var minutes = left if j == 11 else rng.randf_range(0.01, left / float(12 - j))
   var u = SPEEDS[rng.randi_range(0, 6)]
   commands.append({"minutes": minutes, "u": u})
   whole.set_cleaning_speed(u)
   split.set_cleaning_speed(u)
   whole.advance(minutes * 10.0)
   partition(split, minutes * 10.0)
   left = maxf(0.0, left - minutes)
  # A final tiny overrun removes ambiguity from float summation of command lengths.
  whole.advance(0.000001)
  split.advance(0.000001)
  var a = whole.snapshot()
  var b = split.snapshot()
  for key in ["fatigue", "cleaned_work", "battery_kwh", "solar_energy_generated_kwh", "habitat_energy_used_kwh", "curtailed_energy_kwh", "unserved_energy_kwh", "dose_ugy", "cleaning_active_sim_seconds", "fatigue_weighted_work_seconds"]:
   check(near(a[key], b[key]), "partitions/" + str(i) + "/" + key, {"whole": a[key], "split": b[key]})
  check(a.status == b.status and a.status != "running", "partitions/terminal/" + str(i))
  check(near(a.battery_kwh, cfg.initial_battery_kwh + a.solar_energy_generated_kwh - a.habitat_energy_used_kwh - a.curtailed_energy_kwh + a.unserved_energy_kwh), "ledger/conservation/" + str(i))
  var oracle = numerical_oracle(commands, cfg)
  for key in oracle:
   # Oracle steps are0.002sim-min. Error at a clipped fatigue/work boundary
   # is first order in that tiny interval; power integration is midpoint sampled.
   var tolerance = 0.00015 if key == "fatigue" else 0.00002
   check(near(a[key], oracle[key], tolerance), "oracle/" + str(i) + "/" + key, {"actual": a[key], "oracle": oracle[key], "tolerance": tolerance})
 print("INDEPENDENT_PACE_AUDIT ", JSON.stringify({"checks": checks, "failures": failures.size(), "seed": SEED, "constant_pace_fixtures": 7, "random_switching_cases": 80, "independent_numerical_oracles": 80, "oracle_step_sim_minutes": 0.002}))
 quit(0 if failures.is_empty() else 1)

# Independent numerical oracle: midpoint time sampling, no model integration calls.
# All durations here are simulated minutes; the runtime uses simulated seconds.
func numerical_oracle(commands: Array, settings: Dictionary) -> Dictionary:
 var f = 0.0
 var work = 0.0
 var battery = float(settings.initial_battery_kwh)
 var generated = 0.0
 var used = 0.0
 var curtailed = 0.0
 var unserved = 0.0
 var elapsed = 0.0
 for command in commands:
  var left = float(command.minutes)
  var u = float(command.u)
  var slope = 0.08 * maxf(u - 1.0, 0.0) - 0.12 * maxf(1.0 - u, 0.0)
  while left > 0.0:
   var dt = minf(left, 0.002)
   var active_slope = slope if work < 4.0 else 0.0
   var middle_f = clampf(f + active_slope * dt / 2.0, 0.0, 0.9)
   var delta_work = 0.125 * u * (1.0 - middle_f) * dt
   var middle_work = minf(4.0, work + delta_work / 2.0)
   var p = settings.clear_solar_power_kw * (settings.minimum_solar_transmission + (1.0 - settings.minimum_solar_transmission) * middle_work / 4.0)
   var incoming = p * dt / 60.0
   var demand = settings.habitat_load_kw * dt / 60.0
   generated += incoming
   used += demand
   var unclamped = battery + incoming - demand
   curtailed += maxf(0.0, unclamped - settings.battery_capacity_kwh)
   unserved += maxf(0.0, -unclamped)
   battery = clampf(unclamped, 0.0, settings.battery_capacity_kwh)
   work = minf(4.0, work + delta_work)
   f = clampf(f + active_slope * dt, 0.0, 0.9)
   elapsed += dt
   left = maxf(0.0, left - dt)
 return {"fatigue": f, "cleaned_work": work, "battery_kwh": battery, "solar_energy_generated_kwh": generated, "habitat_energy_used_kwh": used, "curtailed_energy_kwh": curtailed, "unserved_energy_kwh": unserved, "dose_ugy": 210.0 / 1440.0 * (elapsed + 1.5 * elapsed * elapsed / 30.0)}
