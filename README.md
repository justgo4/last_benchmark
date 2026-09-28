# last_benchmark

A public cross-language benchmark suite for comparing **execution speed, compilation speed, build artifact size, and memory usage** under a strict same-algorithm protocol.

## Public-data rule

This repository contains only generic benchmark code and deterministic synthetic data. It must never contain personal information, credentials, usernames, database/server configuration, production identifiers, private network information, or production data.

See [PUBLIC_REPO_POLICY.md](PUBLIC_REPO_POLICY.md). Every push and pull request runs a sensitive-data scanner before benchmark code is accepted.

## Languages and technologies

The target set is:

- C
- C++
- Cython
- nanobind
- PyO3
- Rust
- Zig
- Go
- Haskell (GHC)
- Racket
- Chez Scheme
- Gambit Scheme
- Gerbil Scheme
- Common Lisp (SBCL)
- Java
- Scala
- Swift
- Mojo
- TypeScript
- JavaScript (Node.js)
- Nim

The experimental modern Forth discussed separately is intentionally not included yet.

C and C++ use the newest stable GCC for the primary result. A newest-stable Clang/LLVM build may be reported as an additional compiler variant rather than a separate language.

## Same-algorithm suite

Seven workloads cover different compiler/runtime pressure points:

| Workload | Main pressure |
| --- | --- |
| `integer50` | scalar integer/bitwise code generation |
| `stable_partition` | memory traffic, indexed writes, bounds-check elimination |
| `binary_decode` | branch-heavy, bounds-checked binary parsing |
| `text_parse` | byte classification, integer/date-time conversion |
| `json_escape` | string scanning, branching, buffer writes, valid JSON escaping |
| `binary_trees` | allocation, pointer traversal, allocator/GC behavior |
| `mandelbrot` | scalar floating-point code generation and branches |

The C implementation under `benchmarks/core/c` is the semantic reference. A result is rejected unless its checksum matches [spec/EXPECTED.json](spec/EXPECTED.json).

Different algorithms, specialist libraries, unsafe shortcuts, or hand-written SIMD belong in a separate optimized/idiomatic track and never replace the same-algorithm result.

## Metrics

Each implementation reports:

| Metric | Definition |
| --- | --- |
| `compile_seconds` | clean source-to-runnable-artifact build wall time |
| `intermediate_bytes` | designated compiler-generated intermediate artifacts |
| `final_bytes` | runnable artifact size |
| `run_seconds` | median steady-state workload time after warm-up |
| `max_rss_kib` | maximum resident memory of the workload process |

The exact compiler/runtime version, optimization flags, CPU model and OS are recorded with each result. Toolchain installation/download time is excluded from compile time.

JIT/VM technologies are accounted for honestly rather than pretending they emit native ELF binaries; see [spec/BENCHMARK_SPEC.md](spec/BENCHMARK_SPEC.md).

## Optimization

Use the strongest stable optimization mode that preserves benchmark semantics. Native targets may use the runner CPU. Semantic-relaxing modes such as `-ffast-math` are excluded from the same-algorithm ranking.

Toolchains resolve to the newest stable release available at run time. A dated reproducibility snapshot is kept in [spec/TOOLCHAINS.md](spec/TOOLCHAINS.md).

## Status

The benchmark harness, public-safety policy/scanner, expected checksums, and complete seven-workload C reference are implemented. Additional language ports enter the benchmark only after checksum parity is verified.

Run the C reference locally with:

```bash
python scripts/check_public_repo.py
python scripts/measure.py c
```
