# OpenMS-TOPP-GUI Development

The Qt GUI layer of OpenMS (OpenMS_GUI, TOPPView, TOPPAS, INIFileEditor, ExecutePipeline,
ImageCreator), built against an installed OpenMS of the same version. See `AGENTS.md`.

- Build folder: `OpenMS-TOPP-GUI-build/`
- Configure: `cmake -S . -B OpenMS-TOPP-GUI-build -G Ninja -DCMAKE_PREFIX_PATH="<OpenMS prefix or SDK>;<Qt prefix>"`
- Build: `cmake --build OpenMS-TOPP-GUI-build -j$(nproc)`
- Test: `ctest --test-dir OpenMS-TOPP-GUI-build --output-on-failure`
- Docs: `cmake --build OpenMS-TOPP-GUI-build --target doc` (needs doxygen; output in `doc/html-gui/`)

## Build Gotchas

- **OpenMS must have the same version** as `CMakeLists.txt` (`find_package(OpenMS ... EXACT)`) and must
  be built without its former GUI: a core whose tool registry lists ExecutePipeline/ImageCreator is refused.
- **CMAKE_PREFIX_PATH**: Use `;` separator with `-D` flag, `:` with env var on Unix.
- **FuzzyDiff and TOPP tools** come from OpenMS (`-DOPENMS_TOPP_BIN_DIR=<OpenMS>/bin`). The SDK has
  none: tests that need them are left out with a configure message, not failed.
- **No display needed**: the tests set `QT_QPA_PLATFORM=offscreen`; do the same when running GUI tools by hand.
- **Running GUI TOPP tools from the build tree** needs `OPENMS_TOOL_REGISTRY_PATH=<build>/share/OpenMS/TOOLS`
  (the OpenMS registry does not list them; TOPPBase refuses unregistered tools).
- A GUI built against a source-built OpenMS reads that OpenMS's source `share/OpenMS` first (compiled-in path).

## Guidelines

- When CI tests fail, always investigate the root cause first before patching reference files or test expectations. Never bulk-replace expected values or regenerate test outputs as a first approach.
- Never dismiss a test failure as "acceptable behavior" or "pre-existing/unrelated" without explicit user confirmation.
- Prefer existing APIs of OpenMS and OpenMS_GUI over new helpers; explore the code before non-trivial changes.
- Changes that need a change in OpenMS (API, tool registry, install layout) need a PR in OpenMS/OpenMS first.
- Keep PR descriptions up to date with the current state of the PR.
- Do not add `CHANGELOG` entries in PRs unless asked; the maintainers update it for a release.
