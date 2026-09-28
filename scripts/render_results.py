#!/usr/bin/env python3
import argparse
import csv
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ("integer50", "json_escape", "binary_trees", "mandelbrot")

def load_results(path):
    rows = []
    for p in sorted(path.glob("*.json")):
        try:
            data = json.loads(p.read_text())
        except Exception:
            continue
        if not isinstance(data, dict) or "language" not in data:
            continue
        rows.append(data)
    return rows

def fmt_seconds(v):
    if v is None:
        return "N/A"
    return f"{float(v):.6f}"

def fmt_bytes(v):
    if v is None:
        return "N/A"
    n = int(v)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return str(v)

def workload_map(row):
    return {x["kernel"]: x for x in row.get("workloads", [])}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default=str(ROOT / "results"))
    ap.add_argument("--markdown", default=str(ROOT / "results" / "SUMMARY.md"))
    ap.add_argument("--csv", dest="csv_path", default=str(ROOT / "results" / "SUMMARY.csv"))
    args = ap.parse_args()

    results_dir = pathlib.Path(args.results)
    rows = load_results(results_dir)
    if not rows:
        raise SystemExit("no result JSON files found")

    header = [
        "Technology", "Version", "Compile s", "Intermediate", "Final artifact",
        "Peak RSS KiB", *[f"{k} s" for k in CORE],
    ]
    table = []
    csv_rows = []
    for row in rows:
        wm = workload_map(row)
        rss = max((int(wm[k]["max_rss_kib"]) for k in CORE if k in wm), default=0)
        values = [
            row.get("display_name") or row["language"],
            str(row.get("version", "")).replace("\n", " / "),
            fmt_seconds(row.get("compile_seconds")),
            fmt_bytes(row.get("intermediate_bytes")),
            fmt_bytes(row.get("final_bytes")),
            str(rss),
        ]
        values += [fmt_seconds(wm.get(k, {}).get("seconds")) for k in CORE]
        table.append(values)
        csv_rows.append(values)

    md = []
    md.append("# Benchmark summary")
    md.append("")
    md.append("Generated from validated result JSON files. Lower runtime, compile time, memory, and artifact sizes are better within their respective metrics; no single composite score is implied.")
    md.append("")
    md.append("| " + " | ".join(header) + " |")
    md.append("| " + " | ".join(["---"] * len(header)) + " |")
    for values in table:
        md.append("| " + " | ".join(str(x).replace("|", "\\|") for x in values) + " |")
    md.append("")
    pathlib.Path(args.markdown).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(args.markdown).write_text("\n".join(md) + "\n")

    with open(args.csv_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(csv_rows)

    print(f"wrote {args.markdown} and {args.csv_path} for {len(rows)} technologies")

if __name__ == "__main__":
    main()
