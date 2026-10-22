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
- Albania's starting 2.4M population comes from the supplied dataset. Mission values 2.7M and 2.9M, plus census years 2020/2025/2026, are fictional teaching examples. Do not present them as verified census facts or overwrite the source JSON.

## Existing store and interactions

The store uses 20 Kenney Mini Market GLB assets in `models/`, with `models/Textures/colormap.png`. It has shelves, freezers, a cashier/register, walls, a roof, and collision shapes. Current lighting uses nine ceiling `OmniLight3D` lamps and white ambient fill. The user requested removal of the sun and decorative rectangular light strips; preserve the current lighting direction.

The capsule player has an attached first-person camera. WASD/arrows move, Space jumps, and the mouse looks around. A centered crosshair ray reaches three units and detects both bodies and areas. Aimed items and quest objects receive white outlines; the cashier shows “Click to talk.” Left-click interacts. Clicking empty space hides the popup; Esc releases the mouse, and another click captures it.

Country data and quest dialogue share the top-left popup. Mission progress appears at the top center. Crate names and years are printed flat on readable crate faces, excluding the face toward the sign. Sign labels may still float. Stickers are small clickable cubes that can be carried and placed one at a time.

## Mission requirements

Click the cashier to start mission 1. After completing a mission, another cashier interaction starts the next one. All missions stay inside the store.

| Mission | Required sequence | Completion |
| --- | --- | --- |
| **1. The Mixed-Up Crates — Albania / update anomaly** | In the back-right corner, compare two crates: 2.7M/2025 and 2.4M/2020. Select the older crate **or its sticker**. Carry each red sticker to the Albania sign. Both crates then display 2.7M/2025. Return to the cashier for another simulated census. | The sign and both crates display 2.9M/2026 together. |
| **2. The Last Crate — Algeria / deletion anomaly** | In the back-left corner, sell the only crate by clicking it or its green ALGIERS sticker. Ask the cashier for the capital; the fact has disappeared from the mission's records. Talk again to rewind. Move the restored sticker onto an Algeria sign, then sell the crate again. | The crate disappears while the sign retains Algiers. |
| **3. No Crate Yet — Argentina / insertion anomaly** | Start holding a blue BUENOS AIRES sticker, with no Argentina crate available. Return to the cashier to discover the problem; talk again to create a sign in the front-left corner. Place the sticker there, then ask the cashier to order a crate. | The delivered crate immediately displays Buenos Aires from the country-sign concept. |

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
| `mission_mixed_crates.gd`, `mission_last_crate.gd`, `mission_no_crate.gd` | Individual mission state machines extending `quest_kit.gd`. |

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
