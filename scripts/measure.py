#!/usr/bin/env python3
import argparse
import json
import math
import pathlib
import platform
import re
import shutil
import subprocess
import tempfile
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESULT_RE = re.compile(
    r"^RESULT kernel=(?P<kernel>\S+) units=(?P<units>\d+) rounds=(?P<rounds>\d+) "
    r"seconds=(?P<seconds>[0-9.eE+-]+) rate=(?P<rate>[0-9.eE+-]+) checksum=(?P<checksum>\d+)$"
)
EXPECTED_PATH = ROOT / "spec" / "EXPECTED_V2.json"
LEGACY_EXPECTED_PATH = ROOT / "spec" / "EXPECTED.json"


def load_expected():
    out = {}
    for p in (LEGACY_EXPECTED_PATH, EXPECTED_PATH):
        if p.exists():
            data = json.loads(p.read_text())
            if isinstance(data, dict):
                out.update(data)
    return out


EXPECTED = load_expected()


def run(cmd, capture=True):
    proc = subprocess.run(
        cmd, cwd=ROOT, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=False,
    )
    if proc.returncode != 0:
        if capture:
            print("FAILED COMMAND:", " ".join(map(str, cmd)))
            print("STDOUT:\n" + (proc.stdout or ""))
            print("STDERR:\n" + (proc.stderr or ""))
        raise subprocess.CalledProcessError(
            proc.returncode, cmd, output=proc.stdout, stderr=proc.stderr)
    return proc


def tree_bytes(path):
    if not path.exists():
        return 0
    if path.is_file():
        return path.stat().st_size
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def parse_result_text(stdout, stderr, label):
    result = None
    for line in ((stdout or "") + "\n" + (stderr or "")).splitlines():
        m = RESULT_RE.match(line.strip())
        if m:
            result = m.groupdict()
    if result is None:
        raise RuntimeError(
            f"{label}: no RESULT line\nstdout={stdout}\nstderr={stderr}")
    return result


def proc_children(pid):
    p = pathlib.Path(f"/proc/{pid}/task/{pid}/children")
    try:
        return [int(x) for x in p.read_text().split()]
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return []


def proc_rss_kib(pid):
    p = pathlib.Path(f"/proc/{pid}/status")
    try:
        for line in p.read_text().splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1])
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        pass
    return 0


def process_tree_rss_kib(root_pid):
    total = 0
    seen = set()
    stack = [root_pid]
    while stack:
        pid = stack.pop()
        if pid in seen:
            continue
        seen.add(pid)
        total += proc_rss_kib(pid)
        stack.extend(proc_children(pid))
    return total


def run_monitored(cmd, sample_interval=0.002):
    proc = subprocess.Popen(
        cmd, cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    samples = []
    stop = threading.Event()

    def sampler():
        while not stop.is_set():
            samples.append(process_tree_rss_kib(proc.pid))
            if proc.poll() is not None:
                break
            stop.wait(sample_interval)

    th = threading.Thread(target=sampler, daemon=True)
    th.start()
    stdout, stderr = proc.communicate()
    stop.set()
    th.join(timeout=1.0)
    samples.append(process_tree_rss_kib(proc.pid))
    samples = [x for x in samples if x > 0]
    if proc.returncode != 0:
        print("FAILED COMMAND:", " ".join(map(str, cmd)))
        print("STDOUT:\n" + (stdout or ""))
        print("STDERR:\n" + (stderr or ""))
        raise subprocess.CalledProcessError(
            proc.returncode, cmd, output=stdout, stderr=stderr)
    avg_rss = (sum(samples) / len(samples)) if samples else 0.0
    peak_rss = max(samples) if samples else 0
    return stdout, stderr, avg_rss, peak_rss, len(samples)


def validate_checksum(kernel, checksum, label):
    if kernel not in EXPECTED:
        raise RuntimeError(
            f"{label}: no expected checksum for {kernel}; "
            f"add it to spec/EXPECTED_V2.json before publishing the result")
    expected = int(EXPECTED[kernel])
    if int(checksum) != expected:
        raise RuntimeError(
            f"{label}: checksum mismatch expected={expected} actual={checksum}")


def measure_workload(cmd, kernel, label):
    stdout, stderr, avg_rss, peak_rss, samples = run_monitored(cmd)
    result = parse_result_text(stdout, stderr, label)
    checksum = int(result["checksum"])
    validate_checksum(kernel, checksum, label)
    return {
        "kernel": result["kernel"],
        "units": int(result["units"]),
        "rounds": int(result["rounds"]),
        "run_seconds": float(result["seconds"]),
        "rate": float(result["rate"]),
        "checksum": checksum,
        "avg_rss_kib": avg_rss,
        "max_rss_kib": peak_rss,
        "rss_samples": samples,
    }


def c_compile(cc, out_dir):
    source_v2 = ROOT / "benchmarks" / "v2" / "c" / "main.c"
    source = source_v2 if source_v2.exists() else ROOT / "benchmarks" / "core" / "c" / "main.c"
    obj = out_dir / "main.o"
    binary = out_dir / "bench"
    flags = ["-O3", "-march=native", "-flto", "-DNDEBUG", "-ffp-contract=off"]
    t0 = time.perf_counter()
    run([cc, *flags, "-std=c11", "-c", str(source), "-o", str(obj)])
    run([cc, *flags, str(obj), "-o", str(binary)])
    seconds = time.perf_counter() - t0
    return {
        "source": str(source.relative_to(ROOT)),
        "compiler": run([cc, "--version"]).stdout.splitlines()[0].strip(),
        "optimization": " ".join(flags),
        "compile_seconds": seconds,
        "intermediate_bytes": tree_bytes(obj),
        "final_bytes": tree_bytes(binary),
        "binary": binary,
    }


def measure_c_baseline(kernels):
    cc = shutil.which("gcc") or shutil.which("cc")
    if not cc:
        raise RuntimeError("no system C compiler available for same-run baseline")
    with tempfile.TemporaryDirectory(prefix="bench-c-baseline-") as td_name:
        td = pathlib.Path(td_name)
        info = c_compile(cc, td)
        workloads = [
            measure_workload(
                [str(info["binary"]), kernel],
                kernel, f"c_baseline/{kernel}")
            for kernel in kernels
        ]
        return {
            "compiler": info["compiler"],
            "optimization": info["optimization"],
            "compile_seconds": info["compile_seconds"],
            "intermediate_bytes": info["intermediate_bytes"],
            "final_bytes": info["final_bytes"],
            "workloads": workloads,
        }


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

    compile_seconds = 0.0
    if manifest.get("has_compile_step", True):
        t0 = time.perf_counter()
        run(["bash", str(lang_dir / "build.sh")], capture=False)
        compile_seconds = time.perf_counter() - t0
    else:
        run(["bash", str(lang_dir / "build.sh")], capture=False)

    kernels = tuple(args.kernels or manifest.get("kernels", ()))
    if not kernels:
        raise RuntimeError(f"{args.language}: manifest has no kernels")

    workloads = []
    for kernel in kernels:
        workloads.append(measure_workload(
            ["bash", str(lang_dir / "run.sh"), kernel],
            kernel, f"{args.language}/{kernel}"))

    if args.language == "c":
        c_baseline = {
            "compiler": version,
            "optimization": manifest["optimization"],
            "compile_seconds": compile_seconds,
            "intermediate_bytes": tree_bytes(build_root / "intermediate"),
            "final_bytes": tree_bytes(build_root / "final"),
            "workloads": workloads,
        }
    else:
        c_baseline = measure_c_baseline(kernels)

    result = {
        "schema_version": 2,
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
        "c_baseline": c_baseline,
    }

    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / f"{args.language}.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
