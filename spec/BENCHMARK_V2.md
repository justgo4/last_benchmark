# Benchmark v2 specification

## Purpose

v2 replaces the four-kernel composite with a broad, deterministic suite of common algorithms and data structures. The goal is not to force C to win; the goal is to make every published score explainable, reproducible, and resistant to one pathological workload dominating the ranking.

The original benchmark is retained as historical material. Benchmark v2 is now the primary suite and has a complete validated result for all 23 technologies.

## Workload set

The canonical list lives in [SUITE_V2.json](SUITE_V2.json). It covers:

- Algorithms: integer/bitwise work, JSON escaping, merge sort, binary search, prefix sum, dense matrix multiplication, BFS, Dijkstra, union-find, and Mandelbrot.
- Data structures: dynamic array, linked list, ring queue, open-addressing hash table, binary heap, binary search tree, and trie.

Every implementation must use deterministic generated input and return the exact expected checksum. Different output with similar timing is a failed benchmark.

For cross-language fairness, v2 uses a portable 32-bit `mix32` generator for ordinary algorithm/data-structure inputs, and those input arrays are prepared before timing. This avoids turning unrelated structures into a 64-bit integer-emulation benchmark on JavaScript/TypeScript and similar runtimes. `integer50` remains the deliberate wide-integer workload.

## Runtime protocol

- single-threaded score unless a workload explicitly says otherwise
- fixed deterministic input
- deterministic input generation is outside the timed region; construction is timed only when construction is the data-structure operation under test
- one untimed warm-up
- seven measured rounds
- median workload runtime
- no relaxed floating-point semantics that change results
- architecture-native optimization is allowed
- process-tree RSS is sampled every 2 ms while the workload runs
- both average sampled RSS and peak sampled RSS are recorded
- each non-C workflow measures the C reference on the same runner for the same workloads

## Required metrics

For every technology:

1. runtime
2. compile/build time
3. compiler-generated intermediate bytes
4. final runnable artifact bytes
5. average runtime RSS
6. peak runtime RSS

The raw metrics are always published alongside the composite.

## Runtime aggregation

For each workload, runtime is divided by the C reference measured in the same workflow run. The technology runtime index is the geometric mean of those per-workload ratios. This prevents absolute runner speed from becoming the language score and prevents one very large workload from numerically swamping the rest.

Average-memory comparison is the geometric mean of per-workload average-RSS ratios to the same-run C baseline. Peak-memory comparison uses the maximum observed workload peak divided by the maximum observed same-run C peak.

Compile time and artifact sizes are also stored with their same-run C ratios. JavaScript has no ahead-of-time compile step; its compile time is recorded as zero rather than fabricated.

## Composite score

The user-selected weights are fixed:

| Metric | Weight |
| --- | ---: |
| runtime | 0.500 |
| compile time | 0.150 |
| average runtime memory | 0.150 |
| peak runtime memory | 0.150 |
| intermediate artifact size | 0.025 |
| final artifact size | 0.025 |

Because the six metrics have different units and may contain zero (for example JavaScript compile time or no intermediate artifact), raw values are never added directly.

For the final 23-technology table, each metric first becomes a cohort-relative **0-100 score** using a logarithmic lower-is-better normalization. Zero-valued metrics use `log1p`. The best observed technology receives 100 for that metric and the worst receives 0. The final composite is the weighted arithmetic sum of those six metric scores.

This means the composite is relative to the technologies in this repository; it is not a universal constant. Raw values and per-workload results remain the authoritative evidence.

## Fairness notes

- A checksum match proves output equivalence, not automatically identical allocation behavior. Allocation-heavy data-structure workloads are therefore shown individually as well as in the broad aggregate.
- JVM/JIT/source artifacts may depend on an external runtime. The artifact metric reports the produced benchmark artifact, and README must explicitly disclose that runtime dependencies are not bundled.
- SIMD, arena allocation, PGO, specialized libraries, or algorithm substitution belong in a separate max-performance/idiomatic track. The strict v2 score uses the same algorithmic contract first.
