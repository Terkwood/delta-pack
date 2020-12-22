# godot incremental patching (WIP)

![Live loading a PCK file](https://user-images.githubusercontent.com/38859656/102728162-25e4b400-42f8-11eb-9265-a3a93e32aab1.gif)

So far we are only demonstrating the live loading of a PCK file. A more complete example of incremental patching will hopefully be delivered soon.

[Read the planning ticket](https://github.com/Terkwood/godot-incremental-patch/issues/2).

[See the official docs](https://godot-es-docs.readthedocs.io/en/latest/getting_started/workflow/export/exporting_pcks.html) for more information on Godot Engine's support for live-reloading of PCK (game payload) files.

## Setting up Cross-Compilation with Mac as Host

You need to run [this script](setup-mac-build.sh) if you want to cross-compile
from Mac to Linux. The SergioBenitez brew config is important.
