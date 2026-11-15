# Independent, seeded adversarial audit of the mission energy model.
# Run: godot --headless --path game --script res://tests/energy_audit_test.gd
# The numerical oracle samples power in time; it does not call model integrators.
# Bounds allow only the stated midpoint integration/discrete-clipping error.
extends SceneTree
const Model=preload("res://scripts/training_mission.gd")
var rng=RandomNumberGenerator.new()
var failures=[]
var checks=0
func check(ok:bool,label:String,detail:Dictionary={}):
 checks+=1
 if not ok:
  failures.append({"check":label,"details":detail})
  print("AUDIT_FAILURE ",JSON.stringify(failures[-1]))
func near(a:float,b:float,tol:float=0.000002)->bool:return absf(a-b)<=tol+maxf(absf(a),absf(b))*0.000000001
func advance_parts(m,seconds:float):
 var left=seconds
 var loops=0
 while left>0:
  var n=minf(left,rng.randf_range(0.00003,3.0))
  m.advance(n)
  left=maxf(0,left-n)
  loops+=1
  if loops>100000:push_error("audit partition limit");quit(2);return
func energy_conservation(s:Dictionary)->float:
 return s.initial_battery_kwh+s.solar_energy_generated_kwh-s.habitat_energy_used_kwh-s.curtailed_energy_kwh+s.unserved_energy_kwh
func compare(a:Dictionary,b:Dictionary,label:String,config:Dictionary):
 for key in ["sim_elapsed_seconds","cleaned_work","dose_ugy","battery_kwh","solar_energy_generated_kwh","habitat_energy_used_kwh","curtailed_energy_kwh","unserved_energy_kwh","projected_battery_at_warning_kwh"]:
  check(near(a[key],b[key]),label+"/"+key,{"a":a[key],"b":b[key],"config":config})
 check(a.status==b.status and a.phase==b.phase,label+"/terminal",{"a":a.status,"b":b.status,"config":config})
func oracle(config:Dictionary,work:float,speed:float)->Dictionary:
 var duration=minf(work*config.section_work_seconds/speed+config.recall_entry_sim_seconds,config.warning_seconds)
 var battery:float=config.initial_battery_kwh
 var generated=0.0
 var used=0.0
 var curtailed=0.0
 var unserved=0.0
 var t=0.0
 # Midpoint numerical oracle, independently sampling physical power over time.
 # Error is bounded by <=2*(max power + load)*0.07/3600 kWh.
 while t<duration:
  var dt=minf(0.07,duration-t)
  var fraction=minf(work,(t+dt*0.5)*speed/config.section_work_seconds)/config.max_sections
  var solar=config.clear_solar_power_kw*(config.minimum_solar_transmission+(1-config.minimum_solar_transmission)*fraction)
  var incoming=solar*dt/3600.0
  var load=config.habitat_load_kw*dt/3600.0
  generated+=incoming;used+=load
  var e=battery+incoming-load
  curtailed+=maxf(0,e-config.battery_capacity_kwh)
  unserved+=maxf(0,-e)
  battery=clampf(e,0,config.battery_capacity_kwh)
  t+=dt
 return {"battery_kwh":battery,"solar_energy_generated_kwh":generated,"habitat_energy_used_kwh":used,"curtailed_energy_kwh":curtailed,"unserved_energy_kwh":unserved}
func _initialize():call_deferred("run")
func run():
 rng.seed=202611152103
 for i in range(120):
  var config=Model.default_settings()
  config.warning_seconds=rng.randf_range(10,3600)
  config.section_work_seconds=rng.randf_range(1,900)
  config.recall_entry_sim_seconds=0.0 if i%5==0 else rng.randf_range(0.01,config.warning_seconds*1.3)
  config.max_sections=rng.randi_range(1,12)
  config.clear_solar_power_kw=rng.randf_range(0,70)
  config.minimum_solar_transmission=0.0 if i%4==0 else rng.randf()
  config.habitat_load_kw=rng.randf_range(0,50)
  config.battery_capacity_kwh=rng.randf_range(0.001,3)
  config.initial_battery_kwh=0.0 if i%3==0 else rng.randf()*config.battery_capacity_kwh
  config.storm_duration_hours=rng.randf_range(0,3)
  config.storm_load_kw=rng.randf_range(0,4)
  config.storm_solar_kw=rng.randf_range(0,4)
  var work=rng.randf()*config.max_sections
  var speed=1.25 if i%2 else 1.0
  var a=Model.new(config);var b=Model.new(config)
  a.set_cleaning_speed(speed);b.set_cleaning_speed(speed)
  var clean_real=work*config.section_work_seconds/speed/config.time_scale
  a.advance(clean_real);advance_parts(b,clean_real)
  a.request_recall();b.request_recall()
  a.advance(config.recall_entry_sim_seconds/config.time_scale+1.0);advance_parts(b,config.recall_entry_sim_seconds/config.time_scale+1.0)
  var sa=a.snapshot();var sb=b.snapshot()
  compare(sa,sb,"partitions/"+str(i),config)
  check(near(sa.battery_kwh,energy_conservation(sa)),"conservation/"+str(i),{"state":sa})
  var p=a.plan_for_work(work,speed)
  check(p.status==sa.status and near(p.battery_kwh,sa.battery_kwh) and near(p.projected_battery_at_warning_kwh,sa.projected_battery_at_warning_kwh) and near(p.dose_ugy,sa.dose_ugy),"planner-actual/"+str(i),{"plan":p,"actual":sa,"config":config})
  if i<35:
   var reference=oracle(config,work,speed)
   var tolerance=2.0*(config.clear_solar_power_kw+config.habitat_load_kw)*0.07/3600.0+0.0000001
   for key in reference:check(near(sa[key],reference[key],tolerance),"numerical-oracle/"+str(i)+"/"+key,{"actual":sa[key],"oracle":reference[key],"tolerance":tolerance,"config":config})
 # Same timestamped commands, with many randomly partitioned frames.
 for i in range(50):
  var a=Model.new();var b=Model.new()
  for command in range(35):
   var seconds=rng.randf_range(0.00001,8)
   a.advance(seconds);advance_parts(b,seconds)
   match rng.randi_range(0,3):
    0:a.stop_cleaning();b.stop_cleaning()
    1:a.start_cleaning();b.start_cleaning()
    2:a.set_cleaning_speed(1.25);b.set_cleaning_speed(1.25)
    3:a.set_cleaning_speed(1.0);b.set_cleaning_speed(1.0)
  a.request_recall();b.request_recall();a.advance(1000);advance_parts(b,1000)
  compare(a.snapshot(),b.snapshot(),"mixed-controls/"+str(i),{})
 regression_edges()
 print("INDEPENDENT_ENERGY_AUDIT ",JSON.stringify({"checks":checks,"failures":failures.size(),"random_plan_cases":120,"independent_numerical_oracles":35,"mixed_control_cases":50,"boundary_regressions":9,"seed":202611152103}))
 quit(1 if failures.size() else 0)

func regression_edges():
 var zero = Model.new({"recall_entry_sim_seconds": 0.0})
 var plan = zero.plan_for_work(3.75)
 zero.advance(300.0)
 check(plan.status == "late" and not plan.on_time, "zero-entry/exact-deadline-plan")
 check(not zero.request_recall() and zero.snapshot().status == "late", "zero-entry/no-terminal-resurrection")
 var instant = Model.new({"recall_entry_sim_seconds": 0.0})
 var minimum = instant.minimum_reserve_plan()
 check(minimum.valid and minimum.on_time and minimum.reserve_met, "zero-entry/minimum-plan-exists")
 instant.advance(minimum.cleaning_active_sim_seconds / 6.0)
 check(instant.request_recall(), "zero-entry/minimum-plan-executable")
 check(instant.snapshot().status == "success", "zero-entry/minimum-plan-actual-success")
 var whole = Model.new()
 var split = Model.new()
 whole.advance(0.01)
 for i in range(10000): split.advance(0.000001)
 check(absf(whole.snapshot().cleaned_work - split.snapshot().cleaned_work) < 1e-12, "microsecond/initial-work-preserved")
 whole = Model.new()
 split = Model.new()
 whole.advance(80.01)
 split.advance(80.0)
 for i in range(10000): split.advance(0.000001)
 check(absf(whole.snapshot().cleaned_work - split.snapshot().cleaned_work) < 1e-10, "microsecond/post-section-work-preserved")
 var ordinary = Model.new()
 ordinary.advance(290.0)
 check(ordinary.request_recall(), "positive-entry/deadline-tie-starts")
 ordinary.advance(10.0)
 check(ordinary.snapshot().status == "success", "positive-entry/deadline-tie-finishes")
