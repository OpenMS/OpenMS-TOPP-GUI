# OpenMS-TOPP-GUI

[![License (3-Clause BSD)](https://img.shields.io/badge/license-BSD%203--Clause-blue.svg?style=flat-square)](https://opensource.org/licenses/BSD-3-Clause)
[![Documentation](https://img.shields.io/static/v1?style=flat-square&message=Doxygen&color=2C4AA8&logo=ReadTheDocs&logoColor=FFFFFF&label=GUI%20docs)](https://archive.openms.de/openms/Documentation/release/latest/html-gui/index.html)
[![User manual](https://img.shields.io/static/v1?style=flat-square&message=ReadTheDocs&color=8CA1AF&logo=ReadTheDocs&logoColor=FFFFFF&label=User%20manual)](https://openms.readthedocs.io/en/latest/index.html)

The graphical tools of [OpenMS](https://github.com/OpenMS/OpenMS), the open-source software for
LC-MS data management and analysis:

- **TOPPView**: viewer and analysis tool for MS and LC-MS data (spectra, chromatograms, ion mobility,
  peak maps, features, identifications).
- **TOPPAS**: assistant for designing and running workflows of TOPP tools.
- **INIFileEditor**: editor for the parameter (INI) files of TOPP tools.
- **ExecutePipeline**: runs TOPPAS workflows on the command line.
- **ImageCreator**: writes an LC-MS map as an image.
- **OpenMS_GUI**: the Qt library behind these tools (plot widgets, dialogs, TOPPView/TOPPAS
  components), usable in applications of your own.

## Relation to OpenMS

OpenMS itself (the library, the TOPP command line tools, pyOpenMS) has no Qt dependency. This
repository is the layer on top of it:

- **Same version.** A release of OpenMS-TOPP-GUI is built against the OpenMS release of the same
  version (`find_package(OpenMS <version> EXACT)`), and nightly builds against OpenMS `develop`.
  The version in `CMakeLists.txt` is bumped together with OpenMS.
- **Layered installation.** The GUI layer is installed *into the OpenMS installation* (same `bin/`,
  `lib/`, `share/OpenMS`): the GUI tools find the shared data, the TOPP tool registry and the TOPP
  tools next to them there. Its tool registry `share/OpenMS/TOOLS/OpenMS-GUI.tsv` adds
  ExecutePipeline and ImageCreator to the TOPP tools of OpenMS.
- **CMake package.** The library is installed as the CMake package `OpenMSGUI`
  (`find_package(OpenMSGUI)`, target `OpenMS::OpenMS_GUI`). With the GUI layer installed into the
  OpenMS prefix, `find_package(OpenMS COMPONENTS GUI)` finds it as well.

The paths of this repository mirror those of OpenMS (`src/openms_gui`, `src/tests`, `doc`, `cmake`),
and the history of the moved files was kept, so changes can be cherry-picked between the two.

## Installation for users

1. Install OpenMS first, from the [OpenMS installers](https://openms.readthedocs.io/en/latest/about/installation.html)
   or the [archive](https://archive.openms.de/openms/OpenMSInstaller/).
2. Then install the GUI installer of the **same version** from the
   [archive](https://archive.openms.de/openms/OpenMSInstaller/) (`OpenMS-GUI-<version>-...`):
   - **Windows**: `OpenMS-GUI-<version>-Win64.exe` installs into the OpenMS installation folder and
     adds the start menu entries and file associations. Uninstalling OpenMS removes it as well.
   - **macOS**: `OpenMS-GUI-<version>-macOS-<Silicon|Intel>.pkg` installs TOPPView, TOPPAS and
     INIFileEditor into the OpenMS folder in `/Applications`.
   - **Linux**: the `openms-gui` package (`.deb` / `.rpm`) depends on the `openms` package of the
     same version.

Tool documentation: [GUI documentation](https://archive.openms.de/openms/Documentation/release/latest/html-gui/index.html),
TOPPView user guide and tutorials: [openms.readthedocs.io](https://openms.readthedocs.io/en/latest/index.html).

## Building

Requirements:

- An installed OpenMS of the same version with the core and CLI layers (`OpenMS::OpenMS`,
  `OpenMS::OpenMS_CLI`): the OpenMS SDK of the release or nightly, or OpenMS built from source and
  installed. OpenMS must be built **without** its former GUI (OpenMS 3.6 and older nightlies built with
  `WITH_GUI=ON` are refused at configure time).
- Qt 6.1 or newer: Core, Gui, Widgets, Svg, OpenGLWidgets (macOS also PrintSupport); WebEngineWidgets
  optional (JavaScript views of TOPPView; `-DNO_WEBENGINE_WIDGETS=ON` builds without it).
- Boost 1.81 or newer (headers), CMake 3.24 or newer, a C++23 compiler (as for OpenMS).
- Optional: doxygen for the documentation.

```bash
cmake -S OpenMS-TOPP-GUI -B OpenMS-TOPP-GUI-build -G Ninja \
      -DCMAKE_PREFIX_PATH="<OpenMS prefix or SDK>;<Qt prefix>"
cmake --build OpenMS-TOPP-GUI-build -j$(nproc)
```

On Linux, the distribution's Qt works (Ubuntu: `qt6-base-dev libqt6svg6-dev libqt6opengl6-dev`, see
`tools/ci/deps-ubuntu.sh`).

Important CMake options:

| Option | Default | Meaning |
|---|---|---|
| `ENABLE_CLASS_TESTING`, `ENABLE_TOPP_TESTING`, `ENABLE_PIPELINE_TESTING` | `ON` | class tests of the GUI library, tests of the GUI TOPP tools, TOPPAS pipeline tests |
| `OPENMS_TOPP_BIN_DIR` | `bin/` of the found OpenMS | where `FuzzyDiff` and the TOPP tools of OpenMS are; tests that need them are left out when they are missing (the SDK has no TOPP tools) |
| `HAS_XSERVER` | `ON` | `OFF` leaves out the tests that open windows |
| `NO_WEBENGINE_WIDGETS` | `OFF` | build without Qt WebEngine |
| `ENABLE_DOCS` | `ON` | documentation targets (`doc`), if doxygen is found |
| `OPENMS_DOXYGEN_TAGFILE` | found `share/doc/OpenMS.tag` | tag file of the OpenMS documentation (`<file>=<url>`), for links to TOPP tools and OpenMS classes |
| `ENABLE_TUTORIALS` | `ON` | GUI code examples (`Tutorials_build`) |
| `PACKAGE_TYPE` | `none` | `deb`, `rpm`, `pkg`, `dmg` or `nsis` to build an installer with the target `dist` |
| `OPENMS_CORE_VERSION_FULLSTRING` | | full version string of the OpenMS core, for the package names when the OpenMS CMake package does not provide it |

## Testing

```bash
ctest --test-dir OpenMS-TOPP-GUI-build --output-on-failure
```

The tests set `QT_QPA_PLATFORM=offscreen` themselves, so no display is needed. The tests of
ExecutePipeline and ImageCreator compare against reference files with `FuzzyDiff` and the pipeline
tests run TOPP tools, both from `OPENMS_TOPP_BIN_DIR`: point it to the `bin/` of an OpenMS
installation with TOPP tools when building against the SDK. The pipeline tests also use the example
workflows in `share/OpenMS/examples/TOPPAS` of that installation.

## Documentation

```bash
cmake --build OpenMS-TOPP-GUI-build --target doc
```

runs the GUI documenters (they start the GUI tools, offscreen) and doxygen, and writes
`OpenMS-TOPP-GUI-build/doc/html-gui/index.html`: the pages of the GUI tools, the TOPPAS tutorial and
the classes of the GUI library. It is installed into `share/doc/html-gui` (component `doc_gui`), next to
`share/doc/html` of OpenMS. TOPPView and TOPPAS open it from there with F1 and fall back to the online
copy at `https://archive.openms.de/openms/Documentation/<release/version|nightly/latest>/html-gui/`.

## Packaging

```bash
cmake -S OpenMS-TOPP-GUI -B build-package -DPACKAGE_TYPE=deb -DCMAKE_PREFIX_PATH="..."
cmake --build build-package --target dist
```

The packages are add-ons to the OpenMS packages of the same version, named like them with
`OpenMS-GUI-` in place of `OpenMS-` (e.g. `OpenMS-GUI-<version>-Win64.exe`). They contain the GUI
library, the GUI tools, their shared data and the Qt libraries (except on Linux, which uses the
distribution's Qt), never anything OpenMS ships.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Pull requests go against `develop`. Issues of the GUI tools can
be reported here or in the [OpenMS issue tracker](https://github.com/OpenMS/OpenMS/issues).

## Citing

Please cite OpenMS, see [CITATION.cff](CITATION.cff):

Pfeuffer, J., Bielow, C., Wein, S. et al. OpenMS 3 enables reproducible analysis of large-scale mass
spectrometry data. *Nat Methods* 21, 365–367 (2024). https://doi.org/10.1038/s41592-024-02197-7

## License

BSD 3-Clause, see [LICENSE](LICENSE). The installers contain Qt, which is licensed under the LGPL 3.0
(see `share/OpenMS/THIRD-PARTY-NOTICES-GUI.txt` of an installation).
