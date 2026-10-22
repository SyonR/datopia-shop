# Datopia Shop — continuation spec

Condensed from the development conversation and checked against local source on October 22, 2026. Continue the existing prototype. Source inspection for this handoff did not include running Godot.

## Goal and design decisions

Build a small, installable, first-person Godot grocery-store game using real country data. Players explore five country items and learn about update, deletion, and insertion anomalies through short cashier quests involving crates, movable stickers, and country signs.

The user rejected the text-heavy table/cell-clicking puzzle and approved physical interactions inside the 3D store. Preserve that direction: small scenes, readable labels, concrete actions, and one immediate objective. The separate 2D “Critter Courier” proposal, its robot deliveries, and its formal 1NF–3NF curriculum were not adopted.

The three current missions demonstrate anomaly types and the benefit of storing country facts independently of crates. They are not a one-to-one demonstration of 1NF, 2NF, and 3NF.

## Working with the user

- Keep ordinary replies under 120 words unless more detail is requested.
- Address the current obstacle; end with exactly one action or one question, then wait.
- Inspect relevant files; ask for unavailable code instead of guessing.
- Before unfamiliar actions, briefly explain what they do and the expected result.
- When teaching, use small examples from this project; invite predictions or small fill-ins without requiring unknown syntax.
- When confused, simplify the example. After progress, briefly explain why it worked and identify the next small goal.
- Avoid exaggerated praise. Do not supply a complete solution unless explicitly requested; implement changes when the user asks you to build them.

## Project and data

- Project: `/home/syonr/datopia-shop`; open `project.godot`, run `main.tscn` with F5.
- Configuration targets Godot 4.6, GDScript, GL Compatibility, and Jolt Physics.
- This directory currently has no Git repository. The earlier Git remote discussion concerned the separate `/home/syonr/datopia/Datopia-VR-Project` web project; do not assume its remote belongs here.
- `data/countries.enriched.json` contains 118 countries. The first five display items are Albania, Algeria, Argentina, Armenia, and Australia.
- Item popups display `name`, `facts.capital`, `facts.region`, `facts.population_millions`, and entries in `facts.metrics` using their labels, values, and units.
- Missions currently select countries by JSON array index: Albania 0, Algeria 1, Argentina 2. Preserve that mapping unless deliberately replacing it with stable IDs.
- Mission 1 uses made-up crate prices ($5.00 → $6.00 → $7.00), not dataset values. It was switched from population on 2026-10-22 because populations legitimately differ by year, so two crates with different years were not a real anomaly. A price has one current value, and both crates are labeled CURRENT PRICE so the contradiction is explicit. Do not overwrite the source JSON.

## Existing store and interactions

The store uses 20 Kenney Mini Market GLB assets in `models/`, with `models/Textures/colormap.png`. It has shelves, freezers, a cashier/register, walls, a roof, and collision shapes. Current lighting uses nine ceiling `OmniLight3D` lamps and white ambient fill. The user requested removal of the sun and decorative rectangular light strips; preserve the current lighting direction.

The capsule player has an attached first-person camera. WASD/arrows move, Space jumps, and the mouse looks around. A centered crosshair ray reaches three units and detects both bodies and areas. Aimed items and quest objects receive white outlines; the cashier shows “Click to talk.” Left-click interacts. Clicking empty space hides the popup; Esc releases the mouse, and another click captures it.

Country data, shelf records and quest dialogue share a bottom-center dialogue box (`dialogue.gd`): name tab, optional portrait (`ui/cashier.png` for lines starting "Cashier: "), and text that grows upward. Mission progress appears at the top center. Crate headings and values are printed flat on readable crate faces, excluding the face toward the sign. Sign labels may still float. Stickers are small clickable cubes that can be carried and placed one at a time.

## Rats and broom (optional fun)

Separate from the missions. A rat spawns every 8–15 s at one of six open floor points (at least 3 m from the player), up to 5 at once; an unhit rat leaves after 30 s. Rats run short straight hops, each checked with a ray against store collision and the food shelf, and stay inside ±13.5 m. Press B (or click the bottom-right "Broom (B)" slot with the mouse free, or VR grip) to equip the broom; the slot gets a yellow border. While equipped, left click / VR trigger swings (0.3 s; 0.45 s between swing starts) instead of interacting. During the contact part of the swing, rats whose nearest end is within 1.4 m horizontally, within 50° of where you face, with no wall in between, flatten (visual squashed, collision off) and vanish after 1 s. Rats are 0.7 m long and stand on the floor tiles' top (y = 0.075; the physics floor is at 0). The smack plays from 0.92 s into `sounds/smack.mp3` (the file has ~0.9 s of lead-in) and is cut after 0.5 s. Tunables are `@export` vars at the top of each script. Rat textures are import-capped at 256 px (32 px for the flat roughness map) for the web build.

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

| File | Responsibility |
| --- | --- |
| `main.tscn`, `main.gd` | Assemble the game, load country data, spawn five items, connect signals, display popups and mission progress. |
| `store.tscn` | Store models, lighting, roof, and static collision. |
| `player.tscn`, `player.gd` | Movement, jumping, mouse capture/look, ray selection, hover highlighting. |
| `item.tscn`, `item.gd` | Country display item, outline, selected-country signal. |
| `cashier.gd` | Hover hint and `talked_to` signal. |
| `clickable.gd` | Shared clickable box geometry, collision, outline, and `clicked` signal. |
| `quest.gd` | Mission creation, sequence, cashier routing, and dev jumps. |
| `quest_kit.gd` | Shared crate/sign/sticker creation, carrying, placement, selling/delivery animations, and labels. |
| `mission_mixed_crates.gd`, `mission_last_item.gd`, `mission_no_item.gd` | Individual mission state machines extending `quest_kit.gd`. Missions get `shelf` and implement `cleanup()` for dev jumps. |
| `shelf.gd` | Food shelf: 6 product rows on 8 spots, pick up/put back, `find_item`, `give_held`, `restock`, `add_item`, `remove`, optional per-row `note`, and `busy_handler` for clicks while holding a sticker. |
| `customer.gd` | Clickable animated shopper: `walk(from, points)`, `take(body)`, `thank_and_walk(points)`, `react(yes)`. |
| `dialogue.gd`, `ui/*.png` | Bottom dialogue box; cashier and customer portraits rendered from their models. |
| `vr.gd` | WebXR rig: Enter VR button, controller laser, thumbstick move/snap turn, hand HUD. |
| `rat.gd`, `rat_spawner.gd`, `broom.gd` | Optional rat smacking (not part of the missions): rats scurry on physics layer 4 (block nothing); B / the Broom slot / VR grip toggles the broom; while it's out, clicks and VR trigger swing instead of interacting. |

Missions expose `started`, `done`, `held`, `setup(country)`, `start()`, `on_cashier()`, and `say(text)`. Interactable objects implement `set_highlight(bool)` and `select()`.

## Continuation and verification

The user confirmed movement/aim interaction, improved crate labels, and progression into mission 2. Mission 3, dev shortcuts, and the newest progress bar exist in source but have no subsequent playtest confirmation in the supplied conversation.

**Start by verifying mission 3 and progress, then fix observed problems in small steps.**

1. Run the project and check movement, collision, item popups, and cashier interaction.
2. Complete all three missions in order; check each success condition and each progress transition.
3. Test both crate and sticker selection in mission 1. Confirm incorrect selections remain recoverable.
4. Test keys 1/2/3, including jumps while carrying a sticker or while a crate is selling. Check for duplicate objects, stale highlights, and freed-object errors.
5. Check label readability and HUD overlap at the actual game-window size. Report separately what was inspected, executed, and still requires user playtesting.

The current “reads sign” behavior is scripted: mission code updates labels and values together. There is no general shared country-record/reference model yet. If gameplay expands to editable facts, implement actual shared data ownership before claiming updates propagate through references.

Export remains unfinished: no `export_presets.cfg` exists, no target platform is agreed, and no build size is measured. The earlier 50–100 MB estimate was guidance, not a requirement. Once gameplay is verified, confirm the platform, configure export with the country JSON included, disable dev mode, and test the packaged build. A custom collision detector was mentioned early but was never supplied or integrated; the current game uses Godot collision.
