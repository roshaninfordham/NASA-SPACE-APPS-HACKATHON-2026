extends SceneTree
var failures := 0
func check(ok: bool, message: String):
    if not ok:
        push_error(message)
        failures += 1
    else: print("PASS: ", message)
func frames(count: int = 8):
    for index in range(count): await process_frame
func activate(button: Button):
    button.grab_focus()
    await frames(2)
    var key := InputEventKey.new()
    key.keycode = KEY_ENTER
    key.physical_keycode = KEY_ENTER
    key.pressed = true
    root.push_input(key)
    key = InputEventKey.new()
    key.keycode = KEY_ENTER
    key.physical_keycode = KEY_ENTER
    key.pressed = false
    root.push_input(key)
    await frames()
func within(node: Control) -> bool:
    return Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(node.get_global_rect())
func dialog_checks(game, label: String):
    var shell: Control = game.finish_panel.get_node("DialogShell")
    check(within(shell), label + " dialog fits viewport")
    var scroll: ScrollContainer = shell.find_child("BodyScroll", true, false)
    check(scroll.size.y > 40, label + " body remains scrollable")
    for button in shell.find_children("*", "Button", true, false):
        check(within(button), label + " action visible: " + button.text)
        var physical_height: float = button.size.y * root.size.x / root.get_visible_rect().size.x
        check(physical_height >= 44, label + " action is at least 44 physical pixels")
func _initialize(): call_deferred("run")
func run():
    for viewport_size in [Vector2i(1280,720), Vector2i(960,540), Vector2i(390,844), Vector2i(844,390)]:
        root.size = viewport_size
        var game = load("res://legacy_mission.tscn").instantiate()
        root.add_child(game)
        current_scene = game
        await frames()
        game.learning = load("res://scripts/learning.gd").new("user://dialog-test-%d.json" % OS.get_process_id())
        game.show_guide()
        await frames()
        dialog_checks(game, "Guide " + str(viewport_size))
        var guide = game.finish_panel
        await activate(guide.find_child("Primary", true, false))
        check(not is_instance_valid(guide), "Guide back keyboard action closes dialog")
        game.begin_eva()
        game.toggle_pause()
        await frames()
        dialog_checks(game, "Pause " + str(viewport_size))
        await activate(game.finish_panel.find_child("Primary", true, false))
        check(not game.paused and game.player.enabled, "Pause keyboard action resumes actual game")
        game.touch_controls.show()
        await frames()
        var radio_panel: Control = game.radio.get_parent().get_parent()
        check(not radio_panel.is_visible_in_tree(), "Detailed radio stays in optional tray " + str(viewport_size))
        for control in game.touch_controls.get_children():
            if control is Button:
                check(within(control), "Touch action remains in viewport: " + control.text)
                check(not control.get_global_rect().intersects(game.interface_root._action_row.get_global_rect()), "Physical tools do not obscure primary mission controls: " + control.text)
        game.mission.status = "partial"
        game.finish()
        await frames()
        dialog_checks(game, "Debrief " + str(viewport_size))
        var debrief = game.finish_panel
        await activate(debrief.find_child("Secondary", true, false))
        check(is_instance_valid(game.academy), "Debrief practice keyboard action opens real academy")
        game.academy.close()
        await frames()
        await activate(debrief.find_child("Primary", true, false))
        check(not is_instance_valid(game) and current_scene != null, "Debrief retry keyboard action reloads scene")
        current_scene.queue_free()
        await frames()
    print("DIALOG CONTRACT FAILURES: ", failures)
    quit(1 if failures else 0)
