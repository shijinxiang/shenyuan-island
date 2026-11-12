# Godot 4 Weather & Atmosphere Toolkit

A source-included 3D weather system for Godot 4.2 and newer.

Version `1.0.1` is a packaging and documentation maintenance release. The Version 1 runtime API and weather content are unchanged from `1.0.0`.

## What's included

- Resource-based `WeatherProfile` definitions.
- `WeatherController3D` with smooth transitions and a runtime API.
- Low, Medium, and High particle-allocation tiers.
- Priority-based `WeatherZone3D` requests.
- Camera-following rain and snow.
- Mist plus configurable dust, ash, and pollen particles.
- Shared gust-aware wind sampling.
- Optional player/vehicle effect anchoring for fixed and elevated cameras.
- Optional flat-ground rain ripples and splash droplets.
- Wind-driven precipitation.
- Automatic and manual multi-flash lightning.
- Delayed thunder events for project-supplied audio.
- Optional Forward+ volumetric fog, with Compatibility-renderer fallbacks.
- 12 ready-to-use weather profiles.
- A drop-in `WeatherSystem3D` scene containing the runtime components.
- Interactive demo scene with preset browsing, transitions, controls, and diagnostics.
- Source code and documentation.

## Included presets

- Clear Calm
- Breezy Day
- Light Drizzle
- Steady Rain
- Heavy Rain
- Thunderstorm
- Morning Mist
- Dense Fog
- Gentle Snow
- Heavy Snow
- Blizzard
- Dust Storm

## Installation

No editor plugin needs to be enabled.

1. Extract the ZIP.
2. Copy `addons/weather_atmosphere/` into your Godot project's `addons/` directory.
3. Open the project in Godot and allow the editor to finish its first filesystem scan.
4. Add `res://addons/weather_atmosphere/weather_system_3d.tscn` to your scene.
5. Assign a weather profile or control the system through `WeatherController3D`.

See `docs/QUICK_START.md` for the complete setup walkthrough.

## Try the demo

This download is also a standalone Godot demo project.

Open `project.godot` in Godot 4.2 or newer and run the project. The demo lets you browse presets and inspect transition, wind, quality, and allocation behavior.

## Project structure

```text
addons/weather_atmosphere/   Runtime toolkit, presets, components, zones, and debug helper
demo/                        Interactive showcase project
docs/                        Quick start, API, integration, compatibility, and troubleshooting
CHANGELOG.md                 Release history
LICENSE.txt                  License terms
AI_DISCLOSURE.txt            AI-assisted production disclosure
VERSION.txt                  Package version
SHA256SUMS.txt               SHA-256 checksums for package files
project.godot                Standalone demo project
```

## Documentation

- `docs/QUICK_START.md` - installation and first setup
- `docs/API.md` - public runtime API and code examples
- `docs/INTEGRATION_AND_MIGRATION.md` - integration, updating, and removal
- `docs/COMPATIBILITY_AND_PERFORMANCE.md` - tested versions, renderers, and performance notes
- `docs/TROUBLESHOOTING.md` - common integration and rendering issues

## Compatibility

The toolkit targets Godot 4.2+.

The Version 1 release was validated during development across Godot 4.2.2 through 4.7.1. Forward+/Vulkan-specific features such as volumetric fog remain optional; the default demo project uses the Compatibility renderer.

See `docs/COMPATIBILITY_AND_PERFORMANCE.md` for the detailed validation notes and caveats.

## License

You may use and modify the toolkit in personal and commercial end products under the included license. Attribution is appreciated but not required.

Do not redistribute the toolkit, modified toolkit source, or substantially equivalent extracted files as a standalone asset, library, template, or competing product.

See `LICENSE.txt` for the full terms.

## AI-assisted production disclosure

Generative AI and AI-assisted coding tools were used during production. The package was assembled, reviewed, tested, documented, and prepared as an engine-ready toolkit.

See `AI_DISCLOSURE.txt` for details.

## Updating

When updating from an earlier release, replace the complete `addons/weather_atmosphere/` folder rather than mixing files from different versions.

Version `1.0.1` does not change the Version 1 runtime API.
