extends SceneTree
const TrainingLog = preload("res://ui/training_log.gd")
var failures := 0
var assertions := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, description: String) -> void:
 assertions += 1
 if not ok:
  failures += 1
  push_error(description)
func frames(count := 6) -> void:
 for i in range(count): await process_frame
func press(button: Button) -> void:
 button.grab_focus()
 await frames(2)
 for down in [true,false]:
  var event := InputEventKey.new()
  event.keycode=KEY_ENTER
  event.physical_keycode=KEY_ENTER
  event.pressed=down
  root.push_input(event)
 await frames(2)
func validate_width(node: Node, viewport_width: int) -> void:
 if node is Control and node.is_visible_in_tree() and (node is Label or node is Button):
  var rect: Rect2 = node.get_global_rect()
  check(rect.position.x >= 23 and rect.end.x <= viewport_width-23,"No horizontal overflow: "+str(node.name)+" at "+str(viewport_width))
  if node is Button: check(rect.size.y >= 48,"Touch target remains at least48px: "+str(node.name))
 for child in node.get_children(): validate_width(child,viewport_width)
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var fixture := {"completed_runs":12,"attempts":12,"reviewed_count":5,"practice_attempts":4,"correct_first_unassisted":2,"counters_cover_all_history":true,"storage_available":true,"suggested_focus":{"id":"speed","title":"Compare two cleaning plans","detail":"Try a gentler pace. Then compare how much dust you clear."},"recent_results":[]}
 for i in range(7): fixture.recent_results.append({"status":["win","pass","lose"][i%3],"clean_fraction":0.867-i*0.08,"battery_kwh":1.58-i*0.1})
 var original := fixture.duplicate(true)
 var margin := MarginContainer.new()
 root.add_child(margin)
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus=true
 margin.add_child(scroll)
 var journal := TrainingLog.new(fixture)
 scroll.add_child(journal)
 await frames()
 check(journal.summary==fixture,"Constructor accepts the detached progress summary")
 fixture.suggested_focus.title="Changed elsewhere"
 check(journal._challenge_title.text=="Compare two cleaning plans","Source mutation does not change the journal's detached snapshot")
 check(journal._stat_values.missions.text=="12" and journal._stat_values.ideas.text=="5 / 8","Mission and explored-idea figures match actual counters")
 check(journal._stat_values.practice.text=="2 / 4","First-try practice includes the answered denominator")
 check(journal._recent.get_child_count()==5,"Only the latest five supplied results appear")
 var clean: Label = journal.find_child("AttemptClean_0",true,false)
 var energy: Label = journal.find_child("AttemptEnergy_0",true,false)
 check(clean.text=="Panel clean  86.7%" and energy.text=="Energy  1.58 kWh","Results retain exact continuous cleaning and correct energy units")
 check("Saved on this device" in journal._storage_note.text,"Persistent storage copy appears only for available storage")
 var events: Array[String]=[]
 journal.play_requested.connect(func():events.append("play"))
 journal.practice_requested.connect(func():events.append("practice"))
 for dimensions in [Vector2i(1280,720),Vector2i(700,720),Vector2i(390,844),Vector2i(320,568),Vector2i(844,390)]:
  root.size=dimensions
  await frames(10)
  validate_width(journal,dimensions.x)
  journal.practice_button.grab_focus()
  await frames()
  check(scroll.get_global_rect().grow(2).encloses(journal.practice_button.get_global_rect()),"Keyboard focus scrolls Explore science into view at "+str(dimensions))
  await press(journal.details_button)
  check(journal._details.visible,"Keyboard can expand the honest journal explanation")
  validate_width(journal,dimensions.x)
  await press(journal.details_button)
  check(not journal._details.visible,"Keyboard can close the explanation")
 await press(journal.play_button)
 await press(journal.practice_button)
 check(events==["play","practice"],"Actions emit navigation intents without mutating progress")
 check(journal.summary==original,"Browsing and keyboard navigation never change the summary")
 var legacy := {"completed_runs":3,"reviewed_count":2,"practice_attempts":0,"correct_first_unassisted":0,"counters_cover_all_history":false,"storage_available":false,"recent_results":[{"status":"success","clean_fraction":null,"battery_kwh":null}]}
 journal.configure(legacy)
 await frames()
 check("recorded" in journal._mission_caption.text and "older version" in journal._history_note.text,"Migrated lower-bound counts do not claim complete history")
 check("This session only" in journal._storage_note.text,"Unavailable storage is not described as saved")
 clean=journal.find_child("AttemptClean_0",true,false)
 energy=journal.find_child("AttemptEnergy_0",true,false)
 check("Not recorded" in clean.text and "Not recorded" in energy.text,"Historical missing measurements are never invented")
 check(journal.find_children("*","ProgressBar",true,false).is_empty(),"Unknown historical cleaning has no fabricated progress bar")
 journal.configure({"completed_runs":NAN,"reviewed_count":99,"practice_attempts":-4,"correct_first_unassisted":8,"recent_results":[null,{},"invalid"]})
 await frames()
 check(journal._stat_values.missions.text=="0" and journal._stat_values.ideas.text=="8 / 8" and journal._stat_values.practice.text=="Not yet","Malformed display inputs are bounded without false practice successes")
 journal.configure({"recent_results":[{"status":"pass","clean_fraction":0.79999,"battery_kwh":0.5}]})
 await frames()
 clean=journal.find_child("AttemptClean_0",true,false)
 check(clean.text=="Panel clean  79.9%","Display rounding cannot claim the80percent goal for a below-goal attempt")
 journal.configure({})
 await frames()
 check(journal._recent.get_child_count()==1 and journal.play_button.text=="Start a mission","New profiles get an honest empty state and useful first action")
 journal.queue_free()
 await frames()
 print("TRAINING LOG ASSERTIONS: ",assertions," FAILURES: ",failures)
 quit(1 if failures else 0)
