#!/bin/bash

TARGET_CC=x86_64-linux-musl-gcc cargo build --target=x86_64-unknown-linux-musl
cargo build --target=x86_64-apple-darwin
