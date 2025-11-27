# Disk Performance Monitor for Kubernetes

Writes a file to disk, then reads it, on a set interval and exposes metrics on a `/metrics` endpoint.

## Example output

```
# HELP disk_read_bytes_per_second Disk read bytes per second
# TYPE disk_read_bytes_per_second gauge
disk_read_bytes_per_second %<read_bytes_per_second>
# HELP disk_write_bytes_per_second Disk write bytes per second
# TYPE disk_write_bytes_per_second gauge
disk_write_bytes_per_second %<write_bytes_per_second>
```
