# Usage

Using the [write-delta](../write-delta) tool, make sure you have some data available:

```sh
# bogus record for the very first version of the PCK
write-delta --data-dir /tmp/delta-data-example -r 0.0.0 -p 0.0.0 --diff-url "https://some/horrible/cloud/bogus.diff" --diff-b2bsum 0 --expected-pck-b2bsum 0

# then we release diffs for each new update...
write-delta --data-dir /tmp/delta-data-example -r 0.1.0 -p 0.0.0 --diff-url "https://some/horrible/cloud/myapp-0.0.0_to_0.1.0.diff" --diff-b2bsum abc --expected-pck-b2bsum bbb
write-delta --data-dir /tmp/delta-data-example -r 0.1.1 -p 0.1.0 --diff-url "https://some/horrible/cloud/myapp-0.1.0_to_0.1.1.diff" --diff-b2bsum ffe010 --expected-pck-b2bsum def012
```

Install this utility with

```sh
cargo install --path .
```

Start the web server with

```sh
delta-server -d /tmp/delta-data-example  # replace this path
```

Then you can query this webserver for recent deltas:

```text
$ curl http://127.0.0.1:45819/deltas\?from_version=\0.0.0  | jq

[
  {
    "id": 2000000,
    "release_version": "0.1.0",
    "previous_version": "0.0.0",
    "diff_url": "https://some/horrible/cloud/myapp-0.0.0_to_0.1.0.diff",
    "diff_b2bsum": "abc",
    "expected_pck_b2bsum": "bbb"
  },
  {
    "id": 4000000,
    "release_version": "0.1.1",
    "previous_version": "0.1.0",
    "diff_url": "https://some/horrible/cloud/myapp-0.1.0_to_0.1.1.diff",
    "diff_b2bsum": "ffe010",
    "expected_pck_b2bsum": "def012"
  }
]
```

## Admin route

There's an admin route exposed on an alternate port. Using this, you can write new records. Configure your firewall resources: you want to make sure that the admin route is not available via public-facing internet.

```sh
curl --header "Content-Type: application/json" \
   --request POST \
   --data '{"release_version": "0.2.0", "previous_version": "0.1.0", "diff_url": "http://localhost:59999/bar/baz.diff", "diff_b2bsum": "0", "expected_pck_b2bsum": "abc"}' \
 http://127.0.0.1:37917
```
