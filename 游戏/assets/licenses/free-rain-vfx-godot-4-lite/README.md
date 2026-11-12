# NIMBLUX Lite - Free 3D Rain for Godot 4

<!-- vfxpack:rate -->
If this free pack saved you time, a quick rating on itch helps other Godot devs find it:
https://gennai.itch.io/free-rain-vfx-godot-4/rate
<!-- /vfxpack:rate -->

Free version of NIMBLUX. It contains the 3D rain from the full pack, with the same look:

- `NimbluxRain3D` - rain around the camera, drizzle to downpour with one value (`amount`),
  ripples and splash crowns on the ground. Drops stay anchored in the world when the camera moves.
- One preset: `presets/3d/rain_steady.tscn` (medium rain)
- A demo scene with an amount slider

Godot 4.4 or newer. Tested on 4.4.1 and 4.7.2 with Forward+, Mobile and Compatibility.
Released under the MIT License (see LICENSE.txt). Version 1.0.4.

## What the Full version adds

Weather VFX for Godot 4 (https://gennai.itch.io/weather-vfx-godot-4) is the full pack this
rain comes from. It adds:

- `NimbluxShelter3D`: no rain, ripples or splashes under roofs, in tunnels or indoors
- 3D snow: drifting flakes, wind-driven blizzard streaks, sleet and ash
- Wind shared by rain, snow and fog, with gusts and changing direction; wind lines,
  tumbling leaves or cherry petals, dust motes
- Fog (ground fog, drifting fog banks, height fog), sandstorm, cloud shadows,
  storm lightning and lens raindrops
- A weather controller: `weather.transition_to(thunderstorm, 10.0)` blends whole weather
  states, with 12 weather profiles
- 2D rain, snow, fog and wind for side view and top-down, with a pixel-art mode
- 32 presets, 3D and 2D showcase scenes, a weather playground and a benchmark scene

The full pack's page has a browser demo. To upgrade, copy its `addons/nimblux_fx/` over
this one; scenes that use the Lite rain keep their saved values.

## What Lite doesn't do

Each of these is in the full version, Weather VFX for Godot 4
(https://gennai.itch.io/weather-vfx-godot-4):

- **Rain falls under roofs and inside buildings.** Lite has no way to stop it there.
  The full version has `NimbluxShelter3D`: put a box under a roof or around a room and no
  rain, ripples or splashes are drawn inside it.
- **No snow.** The full version has snow, blizzard streaks and sleet.
- **No weather changes.** The full version has a weather controller:
  `weather.transition_to(thunderstorm, 10.0)` blends rain, wind, fog, darkness and lightning,
  with 12 weather profiles.
- **The rain falls straight down and the wind never changes.** In the full version rain, snow
  and fog follow a shared wind with gusts and changing direction, and your own shaders can
  read it.
- **No distant rain layer.** The full version adds faint far-away streaks for depth.
- **No fog, wind lines and leaves, sandstorm, cloud shadows, storm lightning or lens raindrops.**
- **No 2D.** The full version has 2D rain, snow, fog and wind for side view and top-down,
  with a pixel-art mode.

To upgrade, copy the full version's `addons/nimblux_fx/` over this one. Scenes that use the
Lite rain keep their saved values.

## Install

Copy `project/addons/nimblux_fx/` into your project. The node appears in the Add Node dialog
(search "Nimblux"). Open `project/` in Godot to run the demo (slider or Up / Down: amount,
T: light).

## Quick start

Drop `addons/nimblux_fx/presets/3d/rain_steady.tscn` into your scene. It follows the active
camera by itself. From code:

```gdscript
var rain := NimbluxRain3D.new()
add_child(rain)
rain.set_amount_smooth(1.0, 5.0)   # drizzle to downpour over 5 seconds
```

Common properties: `amount` (0..1), `time_scale`, `fade_time`, `play()` / `stop()`,
`area_size`, `follow_camera`, `follow_target`, `random_seed`, `preview_in_editor`.
Rain: `max_drops`, `fall_speed`, `drop_length`, `drop_width`, `color`, `emission`,
`ground_height`, `ground_from_raycast`, `ripples`, `splashes`, `splash_radius`.

Drops are computed in the vertex shader from a static mesh, so the CPU cost does not grow
with the drop count. 9000 drops is the default; use fewer on Web and mobile.

## Support

If something breaks or you have a question, leave a comment on its itch page and I will answer.

## Changelog

- 1.0.6 - Demo only (the rain is unchanged): the demo set is lit with glowing street lamps and the figures and props are new.
- 1.0.5 - Demo only (the rain is unchanged): no real shadows in the demo (soft blob shadows instead), so the browser demo starts sooner.
- 1.0.4 - Demo only (the rain is unchanged): the demo is a small studio set instead of the
  village - two figures, a parasol and street lamps on a dark floor that turns glossy in the rain.
- 1.0.3 - README only (nothing else changed): a short Rating section with the itch page link.
- 1.0.2 - Fix: on Godot 4.4.x with Forward+ or Mobile the rain streaks were not drawn (only
  the ground ripples were). Helper functions in `shaders/nimblux_common.gdshaderinc` had
  parameters with the same names as shader uniforms (`size`, `seed`); Godot 4.4's Forward+/Mobile
  shader compiler read the uniform instead. The parameters are renamed; nothing else changed.
  To update, copy the new `addons/nimblux_fx` over the old one.
- 1.0.1 - README: "What the Full version adds" section, corrected link to the full version.
  Demo: a small "Full version" button in the bottom-right corner that opens the full
  version's page in your browser. The rain addon is unchanged apart from that link in a
  doc comment.
- 1.0 - First release.
