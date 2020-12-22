# delta pack: automated, incremental updates for Godot (WIP)

![Live loading a PCK file](https://user-images.githubusercontent.com/38859656/102728162-25e4b400-42f8-11eb-9265-a3a93e32aab1.gif)

So far we are only demonstrating the live loading of a PCK file. A more complete example of incremental patching will hopefully be delivered soon.

[Read the planning ticket](https://github.com/Terkwood/godot-incremental-patch/issues/2).

[See the official docs](https://godot-es-docs.readthedocs.io/en/latest/getting_started/workflow/export/exporting_pcks.html) for more information on Godot Engine's support for live-reloading of PCK (game payload) files.

## Setting up Cross-Compilation with Mac as Host

You need to run [this script](setup-mac-build.sh) if you want to cross-compile
from Mac to Linux. The SergioBenitez brew config is important.

## Exported Payload

For example, if you export as a Linux/X11 app, your deliverables will look like this:

```text
libincremental_patch.so linux-test.pck          linux-test.x86_64
```

## Tinkering with bidiff

Install the barebones command line interface and create a diff:

```sh
git clone git@github.com:divvun/bidiff.git
cd bidiff/crates/bic
cargo install --path .
```

Some reccs from the [bidiff README](https://github.com/divvun/bidiff#what-makes-bidiff-different):
```text
partitions = (num_cores - 1) (this leaves a core for bookkeeping and compression)
chunk size = newer_size / (num_cores * k), where k is between 2 and 4;
```

Assume the new file is 688MB, and assume we have 4 cores.  Then we can accomplish this patch creation in about 160sec:

```sh
time bic diff target/App-0.1.4.pck target/App-0.1.5-example.pck /tmp/tryagain-bidiff.diff --sort-partitions 3 --scan-chunk-size 57000000 --method zstd
```

This example uses `zstd` compression and results in a diff which is 1.4MB.  It's important to specify a compression method, so that you don't end up with a diff which is the same size as the original.  See these [arbitrary compression benchmarks](https://quixdb.github.io/squash-benchmark/#results) if you're interested in how various compression algorithms perform.

The partitions and chunk size parameters are important.  You absolutely must tune these to your machine, or you'll be waiting for years for the algorithm to complete!
