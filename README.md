# Disk Performance Monitor for Kubernetes

Writes a file to disk, then reads it, on a set interval and exposes metrics on a `/metrics` endpoint.

## Local run

Prerequisites: Ruby 3.4.7

Install dependencies: `bundle install`.

Start the app: `bundle exec puma`.

## Configuration

The app is configured via ENV variables.

`MEGABYTES_PER_BLOCK` - How many megabytes to write per block (default: 1)
`BLOCKS_PER_ITERATION` - How many blocks to write per iteration (default: 100)
`INTERVAL_IN_SECONDS` - How many seconds to wait per benchmark run (default: 60)

## Example metrics output

```
# HELP disk_read_bytes_per_second Disk read bytes per second
# TYPE disk_read_bytes_per_second gauge
disk_read_bytes_per_second %<read_bytes_per_second>
# HELP disk_write_bytes_per_second Disk write bytes per second
# TYPE disk_write_bytes_per_second gauge
disk_write_bytes_per_second %<write_bytes_per_second>
```

## Kubernetes Deployment

Prerequisites: `prometheus-operator` must be present in the target cluster for the `ServiceMonitor` to work.

See example files under `/deploy` and adjust to your environment.
