# Core same-algorithm workloads

This directory contains generic, dependency-free workloads for cross-language comparison. All input is deterministic and synthetic.

The seven workloads are `integer50`, `stable_partition`, `binary_decode`, `text_parse`, `json_escape`, `binary_trees`, and `mandelbrot`. Every language must preserve the algorithms and default sizes in `spec/BENCHMARK_SPEC.md` and match `spec/EXPECTED.json` before a timing is accepted.

No workload depends on a database, network service, production schema, production row, server, account, or private configuration.
