#!/bin/bash

# There doesn't seem to be a nice way to cross-compile from
# mac to windows right now, sorry.

cargo build --release --target=x86_64-apple-darwin
# We specify this env var manually, instead of in .cargo/config,
# so that we don't confuse the Github Actions build job for linux
# (which shares our .cargo/config).
# 
# STILL, IT DOESN'T ACTUALLY WORK ... seems to want .cargo/config written

#  ...fail
RUSTFLAGS="-C linker=x86_64-unknown-linux-gnu" cargo build --release --target=x86_64-unknown-linux-gnu
# ....fail
RUSTFLAGS="-C linker=x86_64-linux-gnu-gcc" cargo build --release --target=x86_64-unknown-linux-gnu
mv ./target/x86_64-apple-darwin/release/libdeltapack.dylib ./godot/.
mv ./target/x86_64-unknown-linux-gnu/release/libdeltapack.so ./godot/.
