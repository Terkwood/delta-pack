# Usage

Install this app in your local userspace.

```sh
cargo install --path .
```

Then:

```sh
write-delta --data-dir /tmp/metadata-tmp -r 0.1.0 -p 0.0.0 --diff-url "https://some/horrible/cloud/myapp-0.0.0_to_0.1.0.diff" --diff-b2bsum abc --expected-pck-b2bsum def
```
