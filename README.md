# 🚧 delta pack: incremental updates for Godot games 🚧

🏗 _THIS PROJECT IS STILL UNDER CONSTRUCTION!_ 🏗

![Live loading a PCK file](https://user-images.githubusercontent.com/38859656/102728162-25e4b400-42f8-11eb-9265-a3a93e32aab1.gif)

Don't you wish that your homebrew Godot game could deliver updates to your players?  During our development cycle we found that we regularly had updates representing only a few MB of changes, but our total PCK file was ~700MB.  We want our users to be able to download only the bytes which have changed!

This project takes an outdated PCK file and a small binary diff as inputs. It outputs the updated PCK file necessary to run the newest version of a game. It can then load the updated PCK.

Everything is hardcoded right now, but we are in the process of making the patch system work for any stream of updates.  We are also adding a publishing process for new releases, and a simple, public webserver which can be queried for metadata about new versions ("deltas" containing the URL of the binary diff as well as checksums for the diff and the expected PCK output).

[Read the planning ticket](https://github.com/Terkwood/godot-incremental-patch/issues/2).

[See the official docs](https://godot-es-docs.readthedocs.io/en/latest/getting_started/workflow/export/exporting_pcks.html) for more information on Godot Engine's support for live-reloading of PCK (game payload) files.

## How to use this demo

To make this system work, your Godot app needs to have a ProjectSetting called "version" configured:

![how to create project setting manually](https://user-images.githubusercontent.com/38859656/103154864-b859dd00-4768-11eb-83f5-ac181c26c32b.png)


## Using bidiff

We can use `bidiff` to create and apply patches. 

### Creating a patch with bic

Install the barebones command line interface, `bic`, and create a diff:

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

Assume the new file is 688MB, and assume we have 8 cores. Then we can accomplish this patch creation in about 220sec:

```sh
time bic diff target/App-0.1.4.pck target/App-0.1.5-example.pck /tmp/tryagain-bidiff.diff --sort-partitions 7 --scan-chunk-size 28666666 --method zstd
```

This example uses `zstd` compression and results in a diff which is 1.4MB.

It's important to specify a compression method, so that you don't end up with a diff which is the same size as the original. See these [arbitrary compression benchmarks](https://quixdb.github.io/squash-benchmark/#results) if you're interested in how various compression algorithms perform.

You must tune the partition and chunk size parameters to your machine. If you take the defaults, it takes far too long to generate a diff.

### Testing patch application

Just to measure how fast the patch application can be, let's use `bic` to apply a diff. 

```text
$ time bic patch App-0.1.4.pck /tmp/App-0.1.4_to_App-0.1.5-example_ZSTD.diff /tmp/App-reconstituted.pck --method zstd
Using method Zstd
bic patch App-0.1.4.pck /tmp/App-0.1.4_to_App-0.1.5-example_ZSTD.diff    0.87s user 1.41s system 121% cpu 1.885 total 
```

This is good news: regardless of what hardware is used, applying a patch will be considerably faster than generating one.

In the context of a game needing to update its PCK file, we use the `bidiff` lib instrumented through `godot` and `rust`.

## Export Considerations

The creation of the exported payloads becomes more complex than a normal godot app, using this system.  We want to create rust binaries for use in Mac, Windows, and Linux/X11 environments.

### Setting up Cross-Compilation with Mac as Host

You need to run [this script](setup-mac-build.sh) if you want to cross-compile
from Mac to Linux. The SergioBenitez brew config is important.

### Exported Payload

The exported payload will now contain a library file specific to your client's gaming environment. For example, if you export as a Linux/X11 app, your deliverable has a `.so` library in addition to the `pck` and the executable:

```text
libincremental_patch.so linux-test.pck          linux-test.x86_64
```

