# Benchmark specification

## Goal

Compare language/compiler/runtime implementations on the same x86-64 Linux environment with identical algorithms and deterministic synthetic data.

The primary ranking is the **same-algorithm track**. An idiomatic/optimized implementation may exist separately, but it must never replace the same-algorithm result.

## Technologies

C, C++, Cython, nanobind, PyO3, Rust, Zig, Go, Haskell (GHC), Racket, Chez Scheme, Gambit Scheme, Gerbil Scheme, Common Lisp (SBCL), Java, Scala, Swift, Mojo, TypeScript, JavaScript (Node.js), and Nim.

The experimental modern Forth discussed separately is intentionally excluded.

## Core workloads

1. **integer32** — branch-light wrapping 32-bit xorshift/checksum loop. The 32-bit state keeps the same machine-integer semantics across native languages, JVM languages, Scheme/Lisp implementations, and JavaScript/TypeScript without requiring BigInt.
2. **stable_partition** — stable counting partition of 16-bit lane IDs.
3. **binary_decode** — bounds-checked parsing of deterministic binary records with little-endian fixed-width integers, length-encoded integers and bitmaps.
4. **text_parse** — checked signed integer plus fixed datetime/microsecond parsing.
5. **json_escape** — serialize deterministic byte/string data into valid JSON string form with escaping.
6. **binary_trees** — allocate, traverse and release/collect deterministic trees.
7. **mandelbrot** — scalar floating-point Mandelbrot kernel with fixed iteration rules.

All implementations must produce the same checksum or validation value before their timing is accepted.

## Default protocol

- single-threaded main ranking
- deterministic generated input
- input generation outside timed region
- one untimed warm-up
- seven measured rounds
- median measured runtime
- no hand-written SIMD in only one implementation
- no algorithm substitution in the same-algorithm track
- no relaxed floating-point semantics that change benchmark results
- native code may target the actual runner CPU

## Required metrics

For every language/technology:

- `compile_seconds`: clean build wall-clock time; toolchain/dependency installation excluded
- `intermediate_bytes`: total size of designated compiler-generated intermediate artifacts
- `final_bytes`: total size of the runnable artifact
- `run_seconds`: median steady-state workload time after warm-up
- `max_rss_kib`: maximum resident set size of the workload process
- compiler/runtime version, CPU model, OS and optimization flags

### Artifact interpretation

Artifact categories differ by execution model and are reported honestly:

- native AOT: object/generated-code files are intermediate; executable/shared module is final
- JVM: class files are intermediate; packaged runnable JAR/class set is final
- TypeScript: emitted JavaScript is intermediate and part of the runnable artifact
- JavaScript: no source-level AOT compile step; compile time/intermediate size are N/A, source is the runnable artifact, JIT cost belongs to runtime
- Racket/Lisp/Scheme: compiled bytecode/native object/image is classified according to the implementation
- Cython/nanobind/PyO3: generated source/object files are intermediate; extension module plus minimal driver are the final runnable artifact

## Optimization policy

Use the strongest stable, generally applicable performance mode that preserves benchmark semantics.

Examples:

- C/C++: `-O3 -march=native -flto -DNDEBUG`
- Rust/PyO3: release, opt-level 3, target-cpu=native, LTO, one codegen unit where appropriate
- Zig: `ReleaseFast` targeting the runner CPU
- Haskell: GHC `-O2 -march=native` plus safe whole-program options where supported
- Swift: `-O -whole-module-optimization`
- Nim: release + speed optimization + native CPU/LTO through the generated C toolchain
- SBCL: speed 3, safety 0, debug 0 inside benchmark functions
- JVM/JavaScript: warm up before measured rounds so JIT startup is not confused with steady-state kernel time

Semantic-relaxing switches such as `-ffast-math` are not allowed in the same-algorithm track.

## Toolchain policy

Each CI run installs the latest stable release available at run time, never beta/RC/nightly, and prints the resolved version. Toolchain installation is outside `compile_seconds`.
