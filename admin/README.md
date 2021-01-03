# Background on bidiff

Old notes with some background on manual usage of `bidiff` and `bic`.

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
