#!/bin/bash

cargo build --target=x86_64-unknown-linux-gnu
cargo build --target=x86_64-apple-darwin
mv ./target/x86_64-apple-darwin/debug/libdeltapack.dylib ./godot/.
mv ./target/x86_64-unknown-linux-gnu/debug/libdeltapack.so ./godot/.
