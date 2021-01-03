# delta pack: incremental updates for Godot games

![downloading and applying updates](https://user-images.githubusercontent.com/38859656/103387434-c9408080-4ad1-11eb-9249-f7d2d14b8abb.gif) 

Don't you wish that your homebrew Godot game could deliver updates to your players?  During our development cycle we found that we regularly had updates representing only a few MB of changes, but our total PCK file was ~700MB.  We want our users to be able to download only the bytes which have changed!

This project takes an outdated PCK file and a small binary diff as inputs. It creates the updated PCK file necessary to run the newest version of a game. It can then load the updated PCK.

The patch system works for any stream of updates. It only works for Mac, Windows and Linux/X11.

We plan to write a simple script to help publish new releases (issue #5). There is a public webserver which can be queried for metadata about new versions ("deltas" containing the URL of the binary diff as well as checksums for the diff and the expected PCK output).

[See the official docs](https://godot-es-docs.readthedocs.io/en/latest/getting_started/workflow/export/exporting_pcks.html) for more information on Godot Engine's support for live-reloading of PCK (game payload) files.

## How to use this demo

First of all, this is a demo. Until we have more time to test it out with a few small game deployments, we can't offer much in the way of support. That said, the strategy seems promising as a stopgap until Godot engine provides an official alternative. 

You must:

- manage the version of your Godot game carefully
- host [delta server](./delta-server), which describes version diffs 
- host the diffs on something like S3, a CDN, or your own webserver

### Godot app

To make this system work, your Godot app needs to have access to a resource at `res://release.tres` as defined in `release.gd`:

```swift 
extends Resource
export var version: String
```

This will be used to query for new versions of your game from the delta (patch metadata) server.  You must use [Semantic Versioning](https://semver.org) formatting, or the delta server will reject your queries.

Make sure to update this resource every time you release a new version of your software, as it will be used to query for updates. 

### delta server 

Todo

### diffs

Todo 

## Community reference

[This question has been explored a bit on the Godot User Forums](https://godotengine.org/qa/23165/can-we-hot-update-gdscript).  Once the project is more mature, we should post there and assess community interest in the project.

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

We have github actions configured so that each tagged release pushes shared libs for all three platforms to the releases page.

### Exported Payload

The payload exported by Godot will must contain a library file specific to your client's gaming environment. For example, if you export as a Linux/X11 app, your deliverable has a `.so` library in addition to the `pck` and the executable:

```text
libincremental_patch.so linux-test.pck          linux-test.x86_64
```

Still in the planning stage: the shared lib appropriate for a given client OS [must be fetched from the github releases page](https://github.com/Terkwood/delta-pack/issues/5) if it doesn't already exist on the machine performing the export step.

## Making a new release

You need to tag a release in order to trigger the dylib-publishing step.

```sh
git tag -a v0.1.0 -m "my release"
git push --tags
```
