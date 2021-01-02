#!/bin/bash

cargo build --release --target=x86_64-unknown-linux-gnu
cargo build --release --target=x86_64-apple-darwin
mv ./target/x86_64-apple-darwin/release/libdeltapack.dylib ./godot/.
mv ./target/x86_64-unknown-linux-gnu/release/libdeltapack.so ./godot/.
