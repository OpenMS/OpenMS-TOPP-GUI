# OpenMS-TOPP-GUI Agent Notes

This file provides context and instructions for coding agents working on OpenMS-TOPP-GUI, the Qt GUI layer
of OpenMS. It follows the [AGENTS.md](https://agents.md) standard.

## What this repository is

- The OpenMS_GUI library (`src/openms_gui`, namespace `OpenMS`, headers `OpenMS/VISUAL/...`) and the GUI
  tools built on it: **TOPPView**, **TOPPAS**, **INIFileEditor** (GUI applications) and **ExecutePipeline**,
  **ImageCreator** (TOPP tools that need Qt; registered in `share/OpenMS/TOOLS/OpenMS-GUI.tsv`).
- It is built against an **installed OpenMS of the same version** (`find_package(OpenMS <version> EXACT CONFIG
  COMPONENTS CLI)` in `cmake/find_openms.cmake`): the OpenMS SDK or an OpenMS built from source and installed.
  OpenMS itself is Qt-free; its library, TOPP tools and pyOpenMS are developed in
  [OpenMS/OpenMS](https://github.com/OpenMS/OpenMS).
- The GUI layer is installed **into the OpenMS prefix** (same `bin/`, `lib/`, `share/OpenMS`): libOpenMS resolves
  the shared data, the tool registry and sibling TOPP executables relative to the executable.
- The layout mirrors OpenMS (`src/openms_gui`, `src/tests`, `doc`, `cmake`) and the moved files kept their history,
  so commits can be cherry-picked between the repositories.

## Critical Constraints

**NEVER do these things:**
- Change the OpenMS core from here: a change of OpenMS API, tool registry or install layout needs a PR in
  OpenMS/OpenMS first (and a GUI release can only use what the OpenMS release of the same version has).
- Install or package anything the OpenMS core ships (its libraries, TOPP tools, share data, MSVC runtime).
- Commit secrets, credentials, or `.env` files
- Add `using namespace` or `using std::...` in header files
- Skip tests when making code changes

**Before opening a pull request, always build the changes locally and run the relevant tests.**

## Quick Commands

```bash
# Configure against an installed OpenMS (or the SDK) and Qt
cmake -S . -B ../OpenMS-TOPP-GUI-build -G Ninja -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_PREFIX_PATH="<OpenMS prefix>;<Qt prefix>" \
      -DOPENMS_TOPP_BIN_DIR="<OpenMS installation with TOPP tools>/bin"   # for FuzzyDiff and pipeline tests

# Build everything (includes tests)
cmake --build ../OpenMS-TOPP-GUI-build -j$(nproc)

# Run tests with verbose output (no display needed: the tests set QT_QPA_PLATFORM=offscreen)
ctest --test-dir ../OpenMS-TOPP-GUI-build -R TOPPView -V

# Documentation (doxygen): ../OpenMS-TOPP-GUI-build/doc/html-gui/index.html
cmake --build ../OpenMS-TOPP-GUI-build --target doc
```

## Repository Layout

```
OpenMS-TOPP-GUI/
├── src/
│   ├── openms_gui/                 # OpenMS_GUI library and the GUI tools
│   │   ├── include/OpenMS/VISUAL/  # Headers (.h)
│   │   ├── source/VISUAL/          # Implementation (.cpp), .ui files, ICONS/ (resources.qrc), STYLE/ (style sheet, style.qrc)
│   │   │   └── APPLICATIONS/GUITOOLS/  # main() of TOPPView, TOPPAS, INIFileEditor, ExecutePipeline,
│   │   │                               # ImageCreator (+ their doxygen tool pages, icons, mac bundle data)
│   │   └── includes.cmake          # source and header lists
│   ├── testframework/              # vendored copy of the OpenMS test framework (not installed)
│   └── tests/
│       ├── class_tests/openms_gui/ # GUI class tests (Qt TestLib)
│       ├── topp/                   # tests of ExecutePipeline / ImageCreator
│       ├── toppas/                 # TOPPAS pipeline tests (ExecutePipeline)
│       └── external/               # installed-consumer test
├── share/OpenMS/                   # DESKTOP (Linux desktop files)
├── doc/                            # doxygen (GUI tool pages, TOPPAS tutorial), documenters, code examples
├── cmake/                          # build, install and packaging (trimmed copies of OpenMS cmake/)
└── tools/                          # CI scripts, update_version_numbers.sh
```

## Build and Install

- **CMake minimum**: 3.24; **C++ standard**: C++23 (as OpenMS). Out-of-tree builds.
- The version in `CMakeLists.txt` (`OPENMS_GUI_VERSION`) must equal the version of the OpenMS it is built against;
  `tools/update_version_numbers.sh` bumps it.
- An OpenMS whose installation already contains a GUI (an OpenMS built with the former `WITH_GUI=ON`, whose
  `OpenMS.tsv` lists ExecutePipeline/ImageCreator) is refused at configure time: both registries would name the
  same tools.
- Variables of the OpenMS build system keep their names (`OPENMS_PACKAGE_VERSION*`, `OPENMS_HOST_DIRECTORY`,
  `INSTALL_*_DIR`), so moved code works unchanged. Install dirs equal those of OpenMS.
- When adding or removing a header or source of the library, update `src/openms_gui/includes.cmake`.
- Public headers are a `FILE_SET HEADERS` of `OpenMS_GUI`; Qt is a PUBLIC dependency
  (`ALLOWED_PUBLIC_INCLUDES` in `src/openms_gui/CMakeLists.txt`).
- Export set `OpenMSGUITargets`, CMake package `OpenMSGUI` (`cmake/OpenMSGUIConfig.cmake.in`), install components
  `library_gui`, `OpenMS_GUI_headers`, `cmake_gui`, `GUIApplications`, `Dependencies`, `doc_gui`.
- A new TOPP tool that needs Qt goes into `GUI_TOPP_TOOLS` in `src/openms_gui/CMakeLists.txt` (declared with
  `openms_topp_tool()`, which writes it into `OpenMS-GUI.tsv`).

**Required dependencies:** OpenMS (same version, core + CLI layer), Qt 6.1+ (Core, Gui, Widgets, Svg,
OpenGLWidgets; PrintSupport on macOS; WebEngineWidgets optional).

### Qt6
- If Qt6 is not found: `-DCMAKE_PREFIX_PATH='<path_to_Qt6_lib_parent>'`
- WebEngineWidgets optional; without it (or with `-DNO_WEBENGINE_WIDGETS=ON`) the JavaScript views of TOPPView are
  disabled (configure warning only).
- Headless runs: `QT_QPA_PLATFORM=offscreen` (or `minimal`). The tests and the documenters set it themselves.
- macOS: remove older Qt versions if they interfere; Qt6 needs `PrintSupport` for the platform plugin.

### Platforms
- **Windows**: Visual Studio environment only (no MSYS/MinGW), 64-bit, short build paths; never mix
  Release/Debug libraries. The installers are add-ons to the OpenMS installer of the same version.
- **macOS**: Apple Clang (Xcode 16+). TOPPView, TOPPAS and INIFileEditor are app bundles; code signing and
  notarization like OpenMS.
- **Linux**: distribution Qt; the packages (`openms-gui`) depend on the `openms` package and ship no Qt.

## Testing

- GUI class tests: `src/tests/class_tests/openms_gui/source/` (Qt TestLib), listed in
  `src/tests/class_tests/openms_gui/CMakeLists.txt`.
- Tests of ExecutePipeline/ImageCreator: `src/tests/topp/`; TOPPAS pipelines: `src/tests/toppas/`.
- `FuzzyDiff` and the TOPP tools the pipelines run come from OpenMS (`OPENMS_TOPP_BIN_DIR`). The SDK has no TOPP
  tools and no examples: tests that need them are left out with a configure message. Do not "fix" that by
  vendoring tools or data.
- Running a GUI TOPP tool from the build tree by hand needs
  `OPENMS_TOOL_REGISTRY_PATH=<build>/share/OpenMS/TOOLS` (TOPPBase refuses unregistered tools).
- Run with `ctest`, use `-R` for a subset, `-V/-VV` for verbosity, `-C` for multi-config generators.

## Coding Conventions

The conventions of OpenMS apply (https://openms.readthedocs.io/en/latest/manual/develop.html):
- 2 spaces, no tabs, Unix line endings; braces on their own lines, always braces; `.clang-format` in the root.
- Classes PascalCase, methods lowerCamel, variables snake_case, private/protected members end with `_`.
- `OPENMS_GUI_DLLAPI` on all exported non-template classes/functions of the GUI library.
- No `using namespace` in headers; OpenMS uses `std::string`; convert to/from `QString` at the Qt boundary
  (`toQString()`, `fromQString()` in OpenMS_GUI).
- Doxygen: `/** */` with `@` tags, `@brief` required; GUI classes go into the groups of
  `doc/doxygen/public/Modules.doxygen` (`Visual`, `PlotWidgets`, `TOPPView_elements`, `TOPPAS_elements`, `Dialogs`).
  A class with parameters (DefaultParamHandler) gets `@htmlinclude OpenMS_<class>.parameters` and an entry in
  `doc/doxygen/parameters/GUIParamDocumenter.cpp`.
- Each file starts with the license header:
  ```cpp
  // Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
  // SPDX-License-Identifier: BSD-3-Clause
  //
  // --------------------------------------------------------------------------
  // $Maintainer: Your Name $
  // $Authors: Original Author, Your Name $
  // --------------------------------------------------------------------------
  ```
  (CMake files: the same with `#`.)
- Comments: simple, useful, plain English.

## Documentation

- Tool pages are the `@page TOPP_<tool>` blocks in `src/openms_gui/source/VISUAL/APPLICATIONS/GUITOOLS/<tool>.cpp`;
  `GUI.doxygen` (main page) lists them. The TOPPAS tutorial is `doc/doxygen/public/TOPPAS.doxygen`.
- The `doc` target runs `GUIParamDocumenter` and `GUIToolDocumenter` (they start the GUI tools offscreen) and then
  doxygen. `@ref TOPP_<core tool>` links need the tag file of the OpenMS documentation (`OPENMS_DOXYGEN_TAGFILE`);
  without it doxygen warns about them, which is expected.
- Installed into `share/doc/html-gui`; online at
  `https://archive.openms.de/openms/Documentation/<release/<version>|nightly/latest>/html-gui/`. TOPPView/TOPPAS
  open these pages with F1 (`GUIHelpers::openURL`).
- User documentation (TOPPView tutorials etc.) is the OpenMS ReadTheDocs manual, maintained in OpenMS/OpenMS.

## Contribution Workflow and Commit Messages

- Gitflow; use forks and open PRs against `develop`.
- Commit format: `[TAG1,TAG2] short summary` (<=120 chars, <=80 preferred), blank line, longer description, and
  `Fixes #N`/`Closes #N` when applicable. Tags: NOP, DOC, COMMENT, API, INTERNAL, FEATURE, FIX, TEST, FORMAT,
  PARAM, IO, LOG, GUI, RESOURCE, BUILD.
- Refer to issues of OpenMS as `OpenMS/OpenMS#N`.
- PR checklist: update `AUTHORS`, run/extend tests, link the OpenMS PR a change depends on.
- Minimize pushes on open PRs (CI is heavy).

## Common Gotchas

1. **Version mismatch**: OpenMS of another version is not accepted (`EXACT`); build against the matching
   release or the nightly SDK of `develop`.
2. **Data path of a source-built OpenMS**: libOpenMS looks in its compiled-in paths first, so a GUI linked
   against an OpenMS build tree reads that tree's `share/OpenMS`.
3. **GUI tests need a display**: they set `QT_QPA_PLATFORM=offscreen`; set it yourself when running tools by hand.
4. **Template methods with 2+ args in OpenMS-style tests**: wrap in parentheses for `START_SECTION`.
5. **Windows**: keep build paths short; the OpenMS and Qt DLLs must be on `PATH` to run tools from the build tree.

## Key Documentation

- `README.md` - overview, build, test, package
- `CONTRIBUTING.md` - contribution guidelines
- [OpenMS user manual](https://openms.readthedocs.io/en/latest)
- [OpenMS API reference](https://archive.openms.de/openms/Documentation/release/latest/html/index.html)
- [GUI documentation](https://archive.openms.de/openms/Documentation/release/latest/html-gui/index.html)
- [OpenMS developer FAQ](https://archive.openms.de/openms/Documentation/release/latest/html/developer_faq.html)
