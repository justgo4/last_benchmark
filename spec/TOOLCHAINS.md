# Toolchain policy and verified snapshot

CI resolves the newest **stable** release at run time and records the exact version. Beta, RC, nightly and development snapshots are excluded.

This table is a reproducibility snapshot verified on 2026-09-30; it is documentation, not a permanent pin.

| Technology | Verified stable snapshot |
| --- | --- |
| C / C++ (GCC) | GCC 16.2 |
| C / C++ (Clang variant) | LLVM/Clang 22.1.8 |
| C3 | 0.8.4 |
| CPython host for extension benchmarks | CPython 3.14.7 |
| Cython | 3.3.0 |
| nanobind | 3.0.1 |
| PyO3 | 0.29.2 |
| Rust | 1.98.1 |
| Zig | 0.16.0 |
| V | 0.5.2 (7647ce1) |
| Go | 1.27.1 |
| Haskell | GHC 9.14.1 |
| Racket | 9.3 |
| Chez Scheme | 10.4.1 |
| Gambit Scheme | 4.9.8 source version |
| Gerbil Scheme | 0.18.2 |
| Common Lisp | SBCL 2.6.9 |
| Java | JDK 27 |
| Scala | 3.9.0 LTS |
| Swift | 6.4 |
| Mojo | 1.1.0 |
| TypeScript | 7.0 |
| JavaScript | Node.js 26.10.0 Current |
| Nim | 2.2.12 |

For C and C++, GCC is the primary same-algorithm result; Clang/LLVM is an additional compiler variant.

For JavaScript, "latest stable" means the latest Current release rather than the older LTS line. Extension benchmarks record the CPython host separately.
