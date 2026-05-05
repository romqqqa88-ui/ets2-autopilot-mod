# Autopilot Mod AI Agent Instructions

## Project scope
- This repository contains an ETS 2 mod project located in `autopilot_mod/`.
- The mod is implemented using Lua scripts, ETS2 definition files, and UI layout files.
- Target runtime is Euro Truck Simulator 2 mod scripting API, not a general Lua application.

## Key files and directories
- `manifest.sii` — ETS2 mod manifest and entrypoint registration.
- `script/init.lua` — main mod initialization file loaded by ETS2.
- `script/autopilot.lua` — core autopilot orchestration.
- `script/speed_controller.lua`, `script/obstacle_detector.lua`, `script/navigation_integration.lua` — main functional subsystems.
- `lua/` — supporting Lua modules used by compatibility tests and internal logic.
- `def/` — mod configuration and GUI definitions for ETS2.
- `ui/autopilot.ui` — in-game interface definition.
- `build_mod.bat`, `build_simple.bat`, `build_zip.bat` — packaging workflows for `.scs`/`.zip` distributions.
- `test_runner.lua` — local compatibility test harness.

## Build / test guidance
- Use `build_mod.bat` to create `.scs` packages; it requires `scs_archiver` available in PATH.
- Use `build_simple.bat` or `build_zip.bat` for ZIP-based packaging alternatives.
- Use `lua test_runner.lua` to run local compatibility checks against required file structure.
- There is no CI configuration in this repository; do not assume automated pipeline support.

## Development conventions
- Preserve ETS2 mod loading contracts: `manifest.sii`, `script/init.lua`, and `def/*.sui` must remain consistent with script paths.
- Keep Lua module dependencies local to the repository; there is no external package manager.
- Prefer small, incremental changes in Lua and ETS2 definition files to avoid breaking mod load or game integration.
- Confirm file-based references before renaming any assets or UI definitions.

## Useful documentation
- `README.md` — feature overview, user commands, setup, and troubleshooting.
- `INSTALL_RU.md` — installation instructions.
- `TROUBLESHOOTING_RU.md` — runtime and packaging troubleshooting.

## Notes for code changes
- The project is a game mod, so focus on in-game behavior, performance, and compatibility with ETS2 script API.
- Do not add unrelated frameworks or external runtime dependencies.
- When fixing or refactoring, check the mod packaging scripts after changes to ensure all required files are included.
