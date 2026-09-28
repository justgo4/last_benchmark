#!/usr/bin/env python3
import argparse
import json
import pathlib
import platform
import re
import shutil
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESULT_RE = re.compile(
    r"^RESULT kernel=(?P<kernel>\S+) units=(?P<units>\d+) rounds=(?P<rounds>\d+) "
    r"seconds=(?P<seconds>[0-9.]+) rate=(?P<rate>[0-9.]+) checksum=(?P<checksum>\d+)$"
)
KERNELS = (
    "integer50", "stable_partition", "binary_decode", "text_parse",
    "json_escape", "binary_trees", "mandelbrot",
)
EXPECTED = json.loads((ROOT / "spec" / "EXPECTED.json").read_text())

def run(cmd, capture=True):
    return subprocess.run(
        cmd, cwd=ROOT, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=True,
    )

def tree_bytes(path):
    if not path.exists():
        return 0
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())

def cpu_model():
    p = pathlib.Path("/proc/cpuinfo")
    if p.exists():
        for line in p.read_text(errors="replace").splitlines():
            if line.lower().startswith("model name") and ":" in line:
                return line.split(":", 1)[1].strip()
    return platform.processor() or "unknown"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("language")
    ap.add_argument("--kernel", action="append", dest="kernels")
    args = ap.parse_args()

    lang_dir = ROOT / "languages" / args.language
    manifest = json.loads((lang_dir / "manifest.json").read_text())
    version = run(["bash", str(lang_dir / "version.sh")]).stdout.strip()

    build_root = ROOT / "build" / args.language
    if build_root.exists():
        shutil.rmtree(build_root)

    compile_seconds = None
    if manifest.get("has_compile_step", True):
        t0 = time.perf_counter()
        run(["bash", str(lang_dir / "build.sh")], capture=False)
        compile_seconds = time.perf_counter() - t0
    else:
        run(["bash", str(lang_dir / "build.sh")], capture=False)

    workloads = []
    for kernel in tuple(args.kernels or KERNELS):
        with tempfile.NamedTemporaryFile(prefix="bench-rss-", delete=False) as tmp:
            rss_path = pathlib.Path(tmp.name)
        try:
            proc = run([
                "/usr/bin/time", "-f", "%M", "-o", str(rss_path),
                "bash", str(lang_dir / "run.sh"), kernel,
            ])
            result = None
            for line in proc.stdout.splitlines():
                m = RESULT_RE.match(line.strip())
                if m:
                    result = m.groupdict()
            if result is None:
                raise RuntimeError(
                    f"{args.language}/{kernel}: no RESULT line\n"
                    f"stdout={proc.stdout}\nstderr={proc.stderr}")
            checksum = int(result["checksum"])
            expected = int(EXPECTED[kernel])
            if checksum != expected:
                raise RuntimeError(
                    f"{args.language}/{kernel}: checksum mismatch "
                    f"expected={expected} actual={checksum}")
            workloads.append({
                "kernel": result["kernel"],
                "units": int(result["units"]),
                "rounds": int(result["rounds"]),
                "run_seconds": float(result["seconds"]),
                "rate": float(result["rate"]),
                "checksum": checksum,
                "max_rss_kib": int(rss_path.read_text().strip()),
            })
        finally:
            rss_path.unlink(missing_ok=True)

    result = {
        "language": args.language,
        "display_name": manifest["display_name"],
        "version": version,
        "optimization": manifest["optimization"],
        "compile_seconds": compile_seconds,
        "intermediate_bytes": tree_bytes(build_root / "intermediate"),
        "final_bytes": tree_bytes(build_root / "final"),
        "cpu": cpu_model(),
        "os": platform.platform(),
        "workloads": workloads,
    }

    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / f"{args.language}.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))

if __name__ == "__main__":
    main()
