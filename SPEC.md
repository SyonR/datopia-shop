# Datopia Shop — continuation spec

Condensed from the development conversation; updated against local source and the supplied transcript on October 24, 2026. Continue the existing prototype. This handoff update inspected source only; it did not run Godot, test a headset, export, or deploy.

## Current priorities — start here

The latest user report supersedes the old instruction to start by verifying mission 3:

1. **Broom inaccessible in VR.** Diagnose this first. `vr.gd` listens only to the right controller's `button_pressed`, expecting `grip_click` to toggle and `trigger_click` to interact/swing. `broom.gd` connects that grip signal to `toggle()` and mounts the broom on the left controller. The inventory button is a desktop `CanvasLayer` control. These are inspected implementation details, not proof that Quest sends those inputs or that the broom is usable. Inspect the input path before choosing a fix; preserve desktop controls and the rule that an equipped broom consumes interaction clicks. Diagnostic added 2026-10-24 (untested): `vr.gd` `DEBUG_BUTTONS = true` shows the last button name pressed on each hand plus `broom out: true/false` on the left-hand HUD. Next: user squeezes the right grip in VR and reports what it shows. Turn it off for release.
2. **Pause menu (moved into Godot 2026-10-24, untested).** `ui/menu.gd` is a `CanvasLayer` (layer 10, `PROCESS_MODE_ALWAYS`): Tab/Esc toggle it; it sets `get_tree().paused`, which also pauses the music. Resume, Fullscreen, Restart (`reload_current_scene`), Quit, a Music volume slider, and a controls panel. In a browser, Esc frees the pointer lock without the key reaching the game, so the menu also opens when the mouse goes from captured to free; a 300 ms guard stops that same Esc from closing it again. On the website, `ShopGame.tsx` no longer has a DOM menu: it exposes `window.shopGame = {quit, toggleFullscreen}` (the page owns the fullscreen shell) and calls the game's `window.shopOpenMenu()` when the browser leaves fullscreen. Quit is hidden in a standalone web build. Not visible in VR (CanvasLayer). The Broom slot can no longer be mouse-clicked mid-game because freeing the mouse now pauses; B still works. Website lint/typecheck pass.
3. **Mission signs (redesigned 2026-10-24, untested).** User chose: no pole, floating, glowing. `quest_kit.gd::make_sign()` now builds a board with light-cyan emission, a pulsing additive halo box, `CPUParticles3D` sparkles, and a sine bob (tweens owned by the sign body). Tunables: `SIGN_GLOW`, `SIGN_BOB`, `SIGN_BOB_TIME`. No `OmniLight3D` was added (Compatibility renderer per-object light limit). Stickers still parent to the board, so they bob with it. Needs a desktop and VR look.

Work through one obstacle at a time. Keep this file current after meaningful changes so future agents need only this spec and the relevant source, not the full chat history.

## Goal and design decisions

Build a small first-person Godot grocery-store game using real country data, playable on desktop and in the Meta Quest browser through WebXR and the Datopia website. Players explore five country items and learn about update, deletion, and insertion anomalies through short cashier quests involving crates, shelf products, movable stickers, and country signs.

The user rejected the text-heavy table/cell-clicking puzzle and approved physical interactions inside the 3D store. Preserve that direction: small scenes, readable labels, concrete actions, and one immediate objective. The separate 2D “Critter Courier” proposal, its robot deliveries, and its formal 1NF–3NF curriculum were not adopted.

The three current missions demonstrate anomaly types and the benefit of storing country facts independently of crates. They are not a one-to-one demonstration of 1NF, 2NF, and 3NF.

The intended shelf metaphor is “shelf = table, product = row”; missions 2 and 3 already use it. Deferred ideas include moving mission 1 onto the shelf and an animal-like player model. These are not the current task. The customer and its animations already exist. There is no conveyor mission; references to one came from a generic feature prompt and were corrected.

## Working with the user

- The user has ADHD and feels overwhelmed. Keep replies under 120 words unless more detail is requested.
- Address only the current obstacle; give a brief explanation and exactly one action or one question, then wait. Do not bundle the backlog into one response.
- Inspect relevant files; ask for unavailable code instead of guessing.
- Before unfamiliar actions, briefly explain what they do and the expected result.
- When teaching, use small examples from this project; invite predictions or small fill-ins without requiring unknown syntax.
- When confused, use a smaller concrete example instead of a longer explanation. When the user answers correctly, briefly explain why and move forward. After a meaningful milestone, show what now works and the next small goal.
- Avoid exaggerated praise. Do not supply a complete solution unless explicitly requested; implement changes when the user asks you to build them.

## Project and data

- Project: `/home/syonr/datopia-shop`; open `project.godot`, run `main.tscn` with F5.
- Configuration targets Godot 4.6, GDScript, GL Compatibility, and Jolt Physics.
- This directory now has its own Git repository. The website has a separate repository at `/home/syonr/datopia/Datopia-VR-Project`; inspect each repository's status and remote independently.
- `data/countries.enriched.json` contains 118 countries. The first five display items are Albania, Algeria, Argentina, Armenia, and Australia.
- Item popups display `name`, `facts.capital`, `facts.region`, `facts.population_millions`, and entries in `facts.metrics` using their labels, values, and units.
- Missions currently select countries by JSON array index: Albania 0, Algeria 1, Argentina 2. Preserve that mapping unless deliberately replacing it with stable IDs.
- Mission 1 uses made-up crate prices ($5.00 → $6.00 → $7.00), not dataset values. It was switched from population on 2026-10-22 because populations legitimately differ by year, so two crates with different years were not a real anomaly. A price has one current value, and both crates are labeled CURRENT PRICE so the contradiction is explicit. Do not overwrite the source JSON.

## Existing store and interactions

The store uses 20 Kenney Mini Market GLB assets in `models/`, with `models/Textures/colormap.png`. It has shelves, freezers, a cashier/register, walls, a roof, and collision shapes. Current lighting uses nine ceiling `OmniLight3D` lamps and white ambient fill. The user requested removal of the sun and decorative rectangular light strips; preserve the current lighting direction.

The capsule player has an attached first-person camera. WASD/arrows move, Space jumps, and the mouse looks around. A centered crosshair ray reaches three units and detects both bodies and areas. Aimed items and quest objects receive white outlines; the cashier shows “Click to talk.” Left-click interacts. Clicking empty space hides the popup; Tab/Esc open the pause menu (which frees the mouse), and a click captures it again.

Country data, shelf records and quest dialogue share a bottom-center dialogue box (`dialogue.gd`): name tab, optional portrait (`ui/cashier.png` for lines starting "Cashier: "), and text that grows upward. Since 2026-10-24, lines reveal word by word (`words_per_second` 12, `comma_pause` 0.15 s, `sentence_pause` 0.35 s; `@export` vars in `ui/dialogue.gd`) using `visible_characters` with `VC_CHARS_AFTER_SHAPING`, so the box takes its final size at once. Country fact popups (`show_popup`) appear instantly (`say(..., animate = false)`). While a line is typing, a click / VR trigger on empty space or on the cashier (group `finishes_dialogue`) only finishes it, so cashier lines can't be skipped unread; clicks on any other object go through normally (`player._click`, after the broom check). The first version swallowed every click while typing, which made the customer seem to ignore the milk right after a long shelf-record line (user report 2026-10-24; fixed and checked headlessly). The VR hand HUD shows `dialogue.shown_text()`. Cashier and Customer lines "speak" through `ui/voice.gd`: one blip per word, from five vowel blips synthesized into `AudioStreamWAV`s at startup (original, no files, single reused player), pitch from the word's first vowel plus random variation; Customer is pitched 1.35×, narration is silent. Voice stops on finish, replace, or hide, and pauses with the menu. Mission progress appears at the top center. Crate headings and values are printed flat on readable crate faces, excluding the face toward the sign. Sign labels may still float. Stickers are small clickable cubes that can be carried and placed one at a time.

## Rats and broom (optional fun)

Separate from the missions. A rat spawns every 8–15 s at one of six open floor points (at least 3 m from the player), up to 5 at once; an unhit rat leaves after 30 s. Rats run short straight hops, each checked with a ray against store collision and the food shelf, and stay inside ±13.5 m. Press B (or click the bottom-right "Broom (B)" slot with the mouse free, or VR grip) to equip the broom; the slot gets a yellow border. While equipped, left click / VR trigger swings (0.3 s; 0.45 s between swing starts) instead of interacting. During the contact part of the swing, rats whose nearest end is within 1.4 m horizontally, within 50° of where you face, with no wall in between, flatten (visual squashed, collision off) and vanish after 1 s. Rats are 0.7 m long and stand on the floor tiles' top (y = 0.075; the physics floor is at 0). The smack plays from 0.92 s into `sounds/smack.mp3` (the file has ~0.9 s of lead-in) and is cut after 0.5 s. A "Rats swatted: N" label sits just above the Broom slot (`broom.gd` `swatted`/`counter`, added 2026-10-24, untested) and is repeated on the VR hand HUD. It counts for the whole session and isn't reset by the dev mission jumps. Tunables are `@export` vars at the top of each script. Rat textures are import-capped at 256 px (32 px for the flat roughness map) for the web build.

## Mission requirements

Click the cashier to start mission 1. After completing a mission, another cashier interaction starts the next one. All missions stay inside the store.

| Mission | Required sequence | Completion |
| --- | --- | --- |
| **1. The Mixed-Up Crates — Albania / update anomaly** | In the back-right corner, two crates both headed CURRENT PRICE show $6.00 and $5.00. Select the $5.00 crate **or its sticker**. Carry each red sticker to the Albania sign. Both crates then read $6.00 from the sign. Return to the cashier for another price change. | The sign and both crates display $7.00 together. |
| **2. The Last Item — Algeria / deletion anomaly** | A customer (Kenney mini-character `character-female-b`) walks in through the front door and waits in front of the food shelf. Algeria's shelf product (Milk) carries a green ALGIERS tag, the only copy of the capital. Pick up the product (or click its tag) and hand it to the customer; she nods and walks out carrying it. Ask the cashier for the capital; it's gone. Talk again to rewind: the product returns to the shelf and the customer walks in again. Move the tag onto the Algeria sign beside the shelf, then hand over the product. | The customer leaves with the product while the sign retains Algiers. |
| **3. Nothing to Stick It On — Argentina / insertion anomaly** | Start holding a blue BUENOS AIRES sticker; capitals go on product tags, but the shelf has no Argentina product (shelf origins skip JSON index 2). Clicking a product while holding the sticker names its country. Return to the cashier to discover the problem; talk again to create an Argentina sign at the right end of the food shelf. Place the sticker there, then ask the cashier to order a product. | Argentina honey appears in an empty shelf spot with a BUENOS AIRES tag and a record that reads the capital from the sign. |

Wrong selections should leave the mission solvable. Preserve the crate/sticker click equivalence during anomaly selection and selling. Picking up a sticker disables its collision so it cannot block aiming at its destination.

`quest.gd` currently has `DEV_MODE = true`: physical keys 1/2/3 rebuild the missions and start the selected one fresh. Skipped earlier missions count as complete for progress. Restarting must clean up old objects, including a sticker parented to the camera. Disable these shortcuts for release.

The progress label must count down “Missions left: 3 of 3” → “2 of 3” → “1 of 3” → “All missions complete!” The bar fills by one third per completed mission and reflects dev jumps.

## Code map

Scripts were grouped into folders on 2026-10-24 (paths in `preload`/`extends`/`.tscn` updated to match). `main.tscn`, `main.gd`, and `store.tscn` stay at the root.

| File | Responsibility |
| --- | --- |
| `main.tscn`, `main.gd` | Assemble the game, load country data, spawn five items, connect signals, display popups and mission progress. |
| `store.tscn` | Store models, lighting, roof, and static collision. |
| `player/player.tscn`, `player/player.gd` | Movement, jumping, mouse capture/look, ray selection, hover highlighting. |
| `player/vr.gd` | WebXR rig: Enter VR button, controller laser, thumbstick move/snap turn, hand HUD. |
| `interact/item.tscn`, `interact/item.gd` | Country display item, outline, selected-country signal. |
| `interact/cashier.gd` | Hover hint and `talked_to` signal. |
| `interact/clickable.gd` | Shared clickable box geometry, collision, outline, and `clicked` signal. |
| `missions/quest.gd` | Mission creation, sequence, cashier routing, and dev jumps. |
| `missions/quest_kit.gd` | Shared crate/sign/sticker creation, carrying, placement, selling/delivery animations, and labels. |
| `missions/mission_mixed_crates.gd`, `missions/mission_last_item.gd`, `missions/mission_no_item.gd` | Individual mission state machines extending `quest_kit.gd`. Missions get `shelf` and implement `cleanup()` for dev jumps. |
| `missions/shelf.gd` | Food shelf: 6 product rows on 8 spots, pick up/put back, `find_item`, `give_held`, `restock`, `add_item`, `remove`, optional per-row `note`, and `busy_handler` for clicks while holding a sticker. |
| `npc/customer.gd` | Clickable animated shopper: `walk(from, points)`, `take(body)`, `thank_and_walk(points)`, `react(yes)`. |
| `ui/dialogue.gd`, `ui/*.png` | Bottom dialogue box; cashier and customer portraits rendered from their models. |
| `sounds/music.gd` | Looping `background-music.mp3` from game start and `mission-complete.mp3` on each mission's `complete()` (via `quest.gd` `mission_completed`; dev jumps don't trigger it). Music volume (0–1, default 0.5) is saved in `user://settings.cfg`. |
| `ui/menu.gd` | Pause menu (see Current priorities). Music and Voice volume sliders. |
| `ui/voice.gd` | Gibberish dialogue voice; `@export` `enabled`, `base_db` (-10), `pitch_variation`, `blip_length`. Volume setting via `music.gd` `set_voice_volume` (saved as `audio/voice_volume`). |
| `rats/rat.gd`, `rats/rat_spawner.gd`, `rats/broom.gd` | Optional rat smacking (not part of the missions): rats scurry on physics layer 4 (block nothing); B / the Broom slot / VR grip toggles the broom; while it's out, clicks and VR trigger swing instead of interacting. |

Missions expose `started`, `done`, `complete()` / `completed`, `held`, `setup(country)`, `start()`, `on_cashier()`, and `say(text)`. Interactable objects implement `set_highlight(bool)` and `select()`.

## Continuation and verification

**Running tests here:** Godot isn't installed in WSL, but the Windows build works through interop: `"/mnt/c/Users/syonr/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path "$(wslpath -w .)" -s res://zz_test_x.gd` (run `--import` first after adding assets). On 2026-10-24 a temporary headless test (since deleted) passed 24 checks: word reveal, punctuation pauses, click-to-finish then click-to-dismiss, replace/hide stopping the voice, silent narration, instant popups, voice volume, mission-complete jingle, typing pausing with the menu. Exiting while the MP3 music plays prints an `AudioStreamPlaybackMP3` "leaked at exit" warning (it happens even without looping; it's only at shutdown). The audio itself, the browser build, and VR were not tested.

The user previously confirmed desktop loading/play and the website embed. The supplied transcript reports passing headless mission/progress checks, later shelf/customer/mission 3 and rat/broom regression checks, rendered screenshots, and exported-pack startup checks. Those are historical reports, not tests rerun for this handoff; the temporary `zz_test_*.gd` scripts may no longer be available. Initial simulated XR start/end checks do not validate physical controllers. The latest user report establishes that the VR broom remains unusable and the menu is uncertain.

**Start with the VR broom report above.** Use the following checks as relevant regression coverage, not a request to repeat every test before addressing the current obstacle:

1. Run the project and check movement, collision, item popups, and cashier interaction.
2. Complete all three missions in order; check each success condition and each progress transition.
3. Test both crate and sticker selection in mission 1. Confirm incorrect selections remain recoverable.
4. Test keys 1/2/3, including jumps while carrying a sticker or while a crate is selling. Check for duplicate objects, stale highlights, and freed-object errors.
5. Check label readability and HUD overlap at the actual game-window size. Report separately what was inspected, executed, and still requires user playtesting.

The current “reads sign” behavior is scripted: mission code updates labels and values together. There is no general shared country-record/reference model yet. If gameplay expands to editable facts, implement actual shared data ownership before claiming updates propagate through references.

## Web export and deployment context

- `export_presets.cfg` exists: Web preset, `data/*.json` included, threads off, desktop and mobile texture compression on. Target: `../datopia/Datopia-VR-Project/public/shop/index.html`. Historical exports used Godot 4.6.1. Keep threads off to avoid introducing cross-origin isolation requirements into the Cesium website.
- The Next.js `/shop` route already exists and embeds `/shop/index.html` through `components/ShopGame.tsx` (launch card + fullscreen shell; the menu is in Godot), with `allow="xr-spatial-tracking; fullscreen; autoplay"`. No game backend was added. Read the website's own `AGENTS.md` before changing it.
- Historical access: `https://datopia.discovery.cs.vt.edu/shop` loaded on the campus network/eduroam; off-campus access had returned 403. Current availability and deployed build were not checked for this handoff.
- Exporting updates local website files. A game-repo push alone does not update the website export or deployment. Current flow (from the website's `k8s/README.md`, read 2026-10-24): export the Web build into `public/shop`; commit the website repo (`k8s/build.sh` refuses to build with uncommitted tracked changes); `export NEXT_PUBLIC_CESIUM_ION_TOKEN=...`, `docker login container.cs.vt.edu`, `./k8s/build.sh` (builds and pushes an image tagged with the current commit); then `./k8s/deploy.sh` (deploys that tag to `datopia-namespace1`; `IMAGE_TAG=abc1234` picks another). Roll back with `kubectl rollout undo deploy/datopia-deployment`. Re-read that README before deploying.
- The transcript's last export reported a roughly 2.0 MB `.pck`; the engine `.wasm` is additional, previously about 35.7 MB. Those are historical sizes, not a current measurement or a total-download claim.
- `quest.gd` still has `DEV_MODE = true`; disable the shortcuts for a release. A custom collision detector was never supplied or integrated; the current game uses Godot collision.
