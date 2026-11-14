# Player experience review — 0.7

KŌMAKU: Shield Protocol now starts with the player **inside mission control**, looking through the window at dunes and stranded Mira. This review covers the current indoor-rescue source candidate. It is an engineering and presentation review, **not a child playtest or evidence of learning outcomes**.

## The first minute

The short briefing gives one initial goal: guide Mira home. The default window view removes the old external habitat, refuge, array and route clutter. The three mission controls are cleaner, save power and guide Mira. Optional learning tools and the outdoor EVA mission remain under **Learn & more**.

Press **3**, or press **Tab** and choose **Guide Mira**. The command starts her return; it does not teleport her or grant immediate shielding. Feedback progresses through returning, airlock cycling, indoor entry and protected. Repeated commands cannot restart her journey. Once Mira is inside, the objective changes to preserving the base reserve through the remaining mission.

**Base** means habitat energy. **Mira suit** and **Mira exposure** belong to the crewmate outside, not the indoor operator. Walking around the room cannot protect Mira or refill her battery. The optional Details drawer identifies simulated time and provides the radio explanation. Controls and Details pause both resource use and Mira's movement; Escape restores play.

## Scientific and interaction boundaries

The existing mission equations remain unchanged. Twelve simulated hours run in approximately four real minutes. Cleaning removes deposited panel dust, not airborne dust. Power saving reduces the modeled optional research rate while exposed; essential life support still consumes energy. The operator mode does not perform array inspection.

Mira receives the shelter factor only after travel, the airlock cycle and indoor entry finish. Travel speed, airlock timing, equipment loads and dose limits are illustrative scenario parameters, not certified engineering. The optional planner explicitly freezes Mira's current protection level; it does not predict her route or airlock completion.

Reaching shelter and completing base recovery are separate milestones. The debrief identifies Mira's entry status and the remaining base energy. A failed mission keeps recovery choices available; opening the guide or calling resume cannot re-enable an ended player. The untimed tour has explicit actions to start a fresh rescue or return to the title screen.

## Verified acceptance checks

- [x] Default Start enters the bounded indoor operator mode; the forward view contains dunes and Mira rather than external infrastructure.
- [x] The title and mission each present three primary choices; immediate controls fit desktop and compact-landscape viewports.
- [x] Suit and exposure labels identify Mira independently of the operator.
- [x] Guide Mira starts visible travel and does not grant instant shielding; cycling remains exposed until indoor entry completes.
- [x] Controls and the planner freeze crew travel and mission resources together.
- [x] Details remains bounded and scrollable; Escape returns to play and restores mouse capture.
- [x] Returning to play releases button focus, so Space cannot retrigger the previous control.
- [x] Successful rescue, no-action failure, terminal-state recovery and tour-to-rescue reset work in the engine.
- [ ] Child comprehension, pacing and independent completion need supervised playtesting.
- [ ] Physical mobile touch ergonomics, controller hardware and device performance need separate validation.

## Verification and images

An independent engine review passed **36 assertions**, including a complete guide-and-save run: Mira protected, 12 simulated hours completed, 8.330 kWh base energy remaining. Taking no actions ended in a controlled exposure-limit abort at approximately 6.142 hours, stopped Mira and displayed the debrief. Further checks covered repeated commands, operator/crew independence, paused travel, terminal guards and resetting practice settings when starting a rescue from the tour. These were accelerated controller checks, not a demonstrated child-played session.

The final native Linux run used Godot 4.6.3, authenticated X11/Xvfb and Mesa software OpenGL. It passed **65 assertions: 58 behavior/geometry checks and seven captures**, at 1280×720 and 844×390. Keyboard and pointer events exercised Start, Tab, Details, cleaner, Guide Mira, Escape, focus release and ordinary pause. Both rendered layouts were inspected. The interface owner's separate suite covers portrait, small-laptop and live-resize behavior.

Current unedited captures: [title](media/0.7-title.png), [mission](media/0.7-mission.png), [paused controls](media/0.7-controls.png) and [Mira after indoor entry](media/0.7-rescue-arrival.png). The arrival capture advances 39 ordinary quarter-second controller steps without waiting in real time, then turns the player's view using a mouse event. No actor position, rescue phase or shielding value was assigned for the image.

The [capture provenance](media/0.7-capture.json) records source fingerprints, renderer, viewport, time advancement and image hashes. Images come directly from the game viewport, with no compositing or color edits. They show this source candidate, not an installed published archive or evidence of hardware performance.
