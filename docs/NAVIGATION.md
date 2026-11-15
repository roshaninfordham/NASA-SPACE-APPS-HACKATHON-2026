# Navigation and leaving fullscreen

The journey controller separates two actions: changing the operating system's window mode, and going back within the game. Escape must never become a quit shortcut or a way to lose an attempt without confirmation.

## Player behavior

- **Preflight:** select a cleaning pace without advancing time, fatigue, work, energy or dose. **Enter / START MISSION** begins the run only from preflight. The science constellation is optional.
- **Pace controls:** **1 / SLOWER**, **3 / FASTER** and the stepped slider select 0.25–1.75. They act only when exposed in preflight or active play, never beneath a card or modal. There is no Recall or manual work-hold shortcut.
- **Completion:** at 30 simulated minutes Ren enters automatically. Replay returns to preflight, rather than starting a hidden countdown immediately.
- **Escape in fullscreen:** leave fullscreen, show the pointer and pause an active mission. A second Escape can handle the current dialog or pause screen. Reading or changing window mode should not cost mission time.
- **Escape in a window:** close the top concept/dialog or open the mission pause menu. Each press handles only one layer. A confirmation dialog's Escape means “keep playing.”
- **F11 / Fullscreen button:** toggle fullscreen explicitly. The app starts in a normal window; entering fullscreen is never a prerequisite to play.
- **View:** choose **Science window** (eight live bubbles) or **Focused window**. Both retain the outpost framing and the same mission. View also links to sound/motion/round-length settings and fullscreen. Layout changes preserve every model quantity.
- **Menu:** pauses and provides Resume, View & accessibility, Science, Sound/motion/pace, Restart, Home and Quit. Restart or leaving a started attempt requires confirmation; leaving untouched preflight for Home does not discard a running mission.
- **Settings and Back:** Home offers View and sound settings directly. Settings opened from View returns to View; View returns to the paused menu. Only an explicit Resume continues the mission. Each layout preference is saved locally when storage is available.
- **Radio captions:** pace commands produce a short player line and Ren's reply without microphone input. Captions work with sound disabled; motion and caption timing respect pause and reduced motion.
- **Exit:** is an explicit desktop action. Browser players close the browser tab; the game must not claim it can close an ordinary tab. A native window-close request during an attempt follows the same confirmation path as Exit.
- **Focus loss:** pauses the mission and releases captured input. Returning to the app does not resume the countdown or capture the pointer automatically.

Browser Escape can be reserved by the browser. The controller also observes fullscreen state, so a browser-owned exit does not depend on the game receiving the key. Browser entry requires a real user gesture and can be denied by browser or embedding policy; the visible control should reflect the actual mode.

## Shared window policy

[`navigation_policy.gd`](../game/scripts/navigation_policy.gd) is a small explicit display boundary. It has no `_input` or `_unhandled_input` callback and never quits, changes mission state or consumes an event by itself.

| Method                                  | Responsibility                                                                                               |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `is_fullscreen()`                       | Query normal or exclusive fullscreen.                                                                        |
| `toggle_fullscreen()`                   | Request a supported mode change; remember window geometry before entering.                                   |
| `exit_fullscreen()` / `handle_escape()` | Exit fullscreen and release the pointer; return false while already windowed.                                |
| `handle_key(event)`                     | Dispatch a pressed, non-repeated Escape or F11; other events return false.                                   |
| `poll_external_exit()`                  | Report an externally caused fullscreen exit once and release the pointer. Call before advancing the mission. |
| `remember_windowed_geometry()`          | Record valid windowed dimensions and position; ignore fullscreen/transition dimensions.                      |

`window_mode_requested(fullscreen)` reports an action request, not a guarantee that an operating system or browser granted it. Desktop restoration fits the current monitor's usable rectangle and retains portrait window sizes. It does not impose a desktop minimum on a small screen. The web backend owns canvas geometry; the policy does not resize or reposition a browser window.

Native mode transitions can finish asynchronously. Restoration is repeated after deferral, and a serial number prevents an old restoration from undoing a newer fullscreen request. Temporary geometry signals during transitions cannot replace the saved window with monitor-sized dimensions. Headless/unsupported displays receive no mode changes.

## Controller integration and the existing input trap

The previous game bound Escape to pause/control mode only; it never requested windowed mode. Its Suit Lab, Habitat Field Notes and mission planner also consume Escape in their own `_input` methods. Godot processes input in reverse tree order, so adding a fullscreen check to a parent controller's `_input` is insufficient: a later child can consume the event first.

The main controller therefore owns a lightweight input guard placed as the **last direct child of the root Window**, with `PROCESS_MODE_ALWAYS`. Its callback checks `policy.handle_key(event)` first. On consumed Escape it pauses the active mission, releases input and calls `set_input_as_handled()`. On an unconsumed windowed Escape it routes one contextual back action. When a legacy activity is active, it can yield that unconsumed event to the legacy modal. It must not both close a modal and resume its underlying mission on the same press.

Add the guard deferred if the root is busy adding children. Bind its lifetime to the main scene's `tree_exiting` signal so scene reloads cannot accumulate input guards. Do not use `Window.window_input` as a replacement for this routing: it did not fire for `Viewport.push_input` in the input-traversal probe.

The reusable guard is [`journey_input_guard.gd`](../game/scripts/journey_input_guard.gd). Set its `controller` property before attaching it. It keeps a weak reference and calls `controller.handle_global_input(event)` for each input event. Returning `true` consumes the event; returning `false` or nothing yields to the scene. A controller can also call `set_input_as_handled()` directly. The guard does not independently interpret keys, so there is only one owner of fullscreen, pause, modal and story navigation. A missing or freed controller safely yields input. The controller must still connect its `tree_exiting` signal to the guard's `queue_free()`.

Before updating mission time, call `poll_external_exit()`. If it returns true, pause. Also pause on application/window focus loss. Releasing a key after a modal closes must not trigger another navigation action; key echoes are ignored. Pace shortcuts belong only to exposed preflight or running-mission controls, never to a concept, confirmation, story or result screen. Enter starts only in preflight; closing a dialog cannot also trigger Start. Resume must explicitly restore its intended pointer mode, and a paused legacy activity must remain paused after a lesson closes.

This policy module supplies window behavior; the main controller owns the journey's exact pause, confirmation and back-stack behavior. Source tests of the policy alone do not prove that every player-facing menu has been wired correctly.

## Verification scope

**Final pace-workflow integration evidence is pending until refreshed.** The display policy and guard checks below have their own stable scope. Earlier full-controller evidence is bound to its recorded source hashes and must not be relabeled as proof of the new preflight/automatic-entry flow.

[`navigation_policy_test.gd`](../game/tests/navigation_policy_test.gd) checks normal/exclusive fullscreen, key releases and repeats, untouched startup geometry, portrait restoration, smaller/moved monitors, asynchronous same-frame toggles, external mode exits and unsupported displays. It also sends actual Godot input through a last-root guard and nested consuming modal, confirming dispatch order and one-action ownership. Display operations use an injected deterministic backend in this suite.

Run with:

```sh
godot --headless --path game --script res://tests/navigation_policy_test.gd
godot --headless --path game --script res://tests/journey_input_guard_test.gd
```

The guard suite adds 12 real input-traversal assertions: consumed and yielded Escape, direct consumption, navigation while paused, pointer forwarding, controller replacement, missing/freed receivers and guard cleanup on scene exit. These use Godot's actual `Viewport.push_input()` dispatch, with a competing nested modal, rather than direct calls alone.

Actual OS fullscreen behavior, browser gesture restrictions and complete menu navigation need the separate native/browser integration checks. A headless mock is not evidence of Mac green-button behavior or a physical keyboard test.

The same suite has an opt-in real-window check:

```sh
godot --path game --script res://tests/navigation_policy_test.gd -- --native-window-check
```

It uses a disposable test window and should run with an isolated user-data directory. On Linux X11/Xvfb with Godot 4.6.3 and Mesa llvmpipe, all 19 policy/dispatch assertions and seven actual-display assertions passed: entering/leaving fullscreen, releasing the captured pointer, restoring the prior size and observing an external exit exactly once. This is Linux display-boundary evidence, not Mac green-button, browser Escape or complete player-navigation acceptance.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
