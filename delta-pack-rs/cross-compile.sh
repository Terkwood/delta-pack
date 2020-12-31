#!/bin/bash

cargo build --target=x86_64-unknown-linux-gnu
cargo build --target=x86_64-apple-darwin
cp ./target/x86_64-apple-darwin/debug/libincremental_patch.dylib ../game/.
cp ./target/x86_64-unknown-linux-gnu/debug/libincremental_patch.so ../game/.
