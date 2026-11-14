extends SceneTree
const Learning = preload("res://scripts/learning.gd")
var failures := 0
var path := "user://learning-test-%d.json" % OS.get_process_id()

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var tutor := Learning.new(path)
	tutor.reset()
	check(tutor.lessons.size() == 5 and tutor.recommend(100) == 0, "First practice starts with separate batteries")
	var valid := true
	for lesson in tutor.lessons:
		valid = valid and lesson.questions.size() >= 2 and not lesson.mission_tip.is_empty()
		for question in lesson.questions:
			valid = valid and question.options.size() == 4 and question.answer >= 0 and question.answer < 4 and not question.explanation.is_empty() and not question.hint.is_empty()
	check(valid, "Every concept has alternate prompts, hints, four choices and explanations")
	check(is_equal_approx(Learning.update_estimate(0.2, true), 0.536842105263), "Correct evidence follows the documented Bayesian calculation")
	check(is_equal_approx(Learning.update_estimate(0.2, false), 0.148387096774), "Incorrect evidence follows the documented Bayesian calculation")
	var first := tutor.answer(0, 0, 1, false, 100)
	check(first.correct and first.evidence and first.saved, "Independent correct response is saved")
	check(tutor.recommend(100) == 1 and tutor.question_index(0) == 1, "Next concept and alternate question are recommended")
	var previous: float = tutor.skills.energy.estimate
	var repeated := tutor.answer(0, 0, 1, false, 101)
	check(not repeated.evidence and tutor.skills.energy.estimate == previous, "Repeated same-day answers cannot inflate the estimate")
	var hinted := tutor.answer(0, 1, 2, true, 102)
	check(hinted.correct and not hinted.evidence and tutor.skills.energy.estimate == previous, "Hint-assisted response is practice only")
	check(not tutor.answer(-1, 0, 0, false, 103).accepted and not tutor.answer(0, 99, 0, false, 103).accepted, "Out-of-range answer input rejected")
	var reloaded := Learning.new(path)
	check(is_equal_approx(reloaded.skills.energy.estimate, tutor.skills.energy.estimate), "Local profile reload preserves learning progress")
	check(tutor.mission_recommendation("dose-abort") == 2 and tutor.mission_recommendation("power-abort") == 3, "Mission outcomes recommend relevant help without awarding knowledge")
	tutor.answer(0, 1, 2, false, 200)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	var recovered := Learning.new(path)
	check(recovered.skills.energy.attempts == 1, "Corrupt primary recovers last valid backup")
	check(recovered.reset() and not FileAccess.file_exists(path + ".backup"), "Reset erases primary and recovery copies")
	var fresh := Learning.new(path)
	check(fresh.skills.energy.attempts == 0, "Reset progress stays erased after restart")
	for index in range(fresh.lessons.size()):
		fresh.answer(index, 0, int(fresh.lessons[index].questions[0].answer), false, 100 + index * 10)
	check(fresh.recommend(100 + Learning.DAY) == 0, "Oldest due lesson is recommended after all concepts are practised")
	check(not fresh.answer(0, 0, 1, false, 50).evidence, "Clock moving backwards cannot farm repeated evidence")
	fresh.answer(0, 0, 1, false, 100 + Learning.DAY)
	check(fresh.skills.energy.attempts == 2, "A later-day retrieval can supply new evidence")
	fresh.reset()
	quit(1 if failures else 0)
