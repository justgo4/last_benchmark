
#!/usr/bin/env python3
import argparse,csv,json,math,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
SUITE=json.loads((ROOT/"spec"/"SUITE_V2.json").read_text())
WORKLOADS=[x["name"] for x in SUITE["workloads"]]
WEIGHTS=SUITE["composite_weights"]
TECHS=["c","cpp","c3","cython","nanobind","pyo3","rust","zig","v","go","haskell","racket","chez","gambit","gerbil","sbcl","java","scala","swift","mojo","typescript","javascript","nim"]
METRICS=["runtime","compile_time","average_memory","peak_memory","intermediate_size","final_size"]

def gm(xs):
    xs=[float(x) for x in xs if x is not None and x>0]
    return math.exp(sum(math.log(x) for x in xs)/len(xs)) if xs else None

def wm(r): return {x["kernel"]:x for x in r.get("workloads",[])}

def load_results(d):
    out={}
    for p in d.glob("*.json"):
        try:r=json.loads(p.read_text())
        except Exception:continue
        if isinstance(r,dict) and r.get("schema_version")==2 and r.get("language") in TECHS:
            out[r["language"]]=r
    return out

def ratio(a,b):
    if a is None or b is None:return None
    if b==0:return 1.0 if a==0 else None
    return float(a)/float(b)

def aggregate(r):
    a,b=wm(r),wm(r["c_baseline"])
    miss=[k for k in WORKLOADS if k not in a or k not in b]
    if miss:raise RuntimeError(r["language"]+" missing "+",".join(miss))
    rr=[ratio(a[k]["run_seconds"],b[k]["run_seconds"]) for k in WORKLOADS]
    ar=[ratio(a[k]["avg_rss_kib"],b[k]["avg_rss_kib"]) for k in WORKLOADS]
    peak=max(float(a[k]["max_rss_kib"]) for k in WORKLOADS)
    cpeak=max(float(b[k]["max_rss_kib"]) for k in WORKLOADS)
    return {
      "language":r["language"],"technology":r.get("display_name",r["language"]),
      "version":str(r.get("version","")).replace("\n"," / "),
      "runtime":gm(rr),
      "compile_time":ratio(r.get("compile_seconds",0.0),r["c_baseline"].get("compile_seconds",0.0)),
      "average_memory":gm(ar),"peak_memory":ratio(peak,cpeak),
      "intermediate_size":ratio(r.get("intermediate_bytes",0),r["c_baseline"].get("intermediate_bytes",0)),
      "final_size":ratio(r.get("final_bytes",0),r["c_baseline"].get("final_bytes",0)),
      "compile_seconds":float(r.get("compile_seconds",0.0)),
      "intermediate_bytes":int(r.get("intermediate_bytes",0)),
      "final_bytes":int(r.get("final_bytes",0)),
      "average_rss_kib":gm([a[k]["avg_rss_kib"] for k in WORKLOADS]),
      "peak_rss_kib":peak,
      "workload_ratios":{k:rr[i] for i,k in enumerate(WORKLOADS)},
      "workload_seconds":{k:float(a[k]["run_seconds"]) for k in WORKLOADS}
    }

def score(rows):
    for key in METRICS:
        vals=[math.log1p(max(0.0,float(r[key]))) for r in rows]
        lo,hi=min(vals),max(vals)
        ss=[100.0 if hi==lo else 100.0*(hi-v)/(hi-lo) for v in vals]
        for r,s in zip(rows,ss):r[key+"_score"]=s
    for r in rows:r["composite_score"]=sum(r[k+"_score"]*float(WEIGHTS[k]) for k in METRICS)
    rows.sort(key=lambda r:(-r["composite_score"],r["technology"].lower()))

def esc(s):
    return str(s).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def fbytes(v):
    x=float(v)
    for u in ["B","KiB","MiB","GiB"]:
        if x<1024 or u=="GiB":return (str(int(x))+" B") if u=="B" else (f"{x:.1f} "+u)
        x/=1024

def bars(rows,key,title,fmt,reverse=False):
    a=sorted(rows,key=lambda r:r[key],reverse=reverse)
    W,L,T,RH=1120,250,60,31
    H=T+RH*len(a)+45
    mx=max(float(r[key]) for r in a) if a else 1
    z=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
       '<style>text{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Arial,sans-serif;fill:#24292f}.t{font-size:22px;font-weight:600}.l{font-size:13px}.v{font-size:12px}</style>',
       '<rect width="100%" height="100%" fill="white"/>',
       f'<text class="t" x="{W/2}" y="30" text-anchor="middle">{esc(title)}</text>']
    for i,r in enumerate(a):
        y=T+i*RH;v=float(r[key]);bw=max(2,(v/mx if mx else 0)*(W-L-140))
        z += [f'<text class="l" x="{L-12}" y="{y+14}" text-anchor="end">{esc(r["technology"])}</text>',
              f'<rect x="{L}" y="{y+2}" width="{bw:.2f}" height="17" fill="#2f81f7" opacity=".78"/>',
              f'<text class="v" x="{L+bw+7:.2f}" y="{y+15}">{esc(fmt(v))}</text>']
    z.append("</svg>");return "".join(z)

def color(v):
    if v<=.75:return "#2da44e"
    if v<=.95:return "#57ab5a"
    if v<=1.05:return "#bf8700"
    if v<=1.5:return "#d29922"
    if v<=2.5:return "#cf6a4c"
    return "#cf222e"

def heatmap(rows):
    a=sorted(rows,key=lambda r:r["runtime"]);cw,ch,L,T=68,27,220,155
    W=L+cw*len(WORKLOADS)+25;H=T+ch*len(a)+45
    z=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
       '<style>text{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Arial,sans-serif;fill:#24292f}.t{font-size:22px;font-weight:600}.l{font-size:12px}.c{font-size:10px;fill:white;font-weight:600}.h{font-size:10px}</style>',
       '<rect width="100%" height="100%" fill="white"/>',
       f'<text class="t" x="{W/2}" y="30" text-anchor="middle">Per-workload runtime ratio vs same-run C</text>']
    for j,k in enumerate(WORKLOADS):
        x=L+j*cw+7;z.append(f'<text class="h" transform="translate({x},{T-8}) rotate(-58)">{esc(k)}</text>')
    for i,r in enumerate(a):
        y=T+i*ch;z.append(f'<text class="l" x="{L-10}" y="{y+18}" text-anchor="end">{esc(r["technology"])}</text>')
        for j,k in enumerate(WORKLOADS):
            v=float(r["workload_ratios"][k]);x=L+j*cw
            z += [f'<rect x="{x}" y="{y}" width="{cw-2}" height="{ch-2}" rx="2" fill="{color(v)}"/>',
                  f'<text class="c" x="{x+(cw-2)/2}" y="{y+17}" text-anchor="middle">{v:.2f}</text>']
    z.append("</svg>");return "".join(z)

def outputs(rows,d):
    docs=ROOT/"docs";docs.mkdir(exist_ok=True)
    charts={
      "v2-composite.svg":bars(rows,"composite_score","Benchmark v2 composite score (higher is better)",lambda x:f"{x:.1f}",True),
      "v2-runtime.svg":bars(rows,"runtime","Runtime index vs same-run C (lower is better)",lambda x:f"{x:.3f}x"),
      "v2-compile.svg":bars(rows,"compile_seconds","Compile / build time",lambda x:f"{x:.3f} s"),
      "v2-average-rss.svg":bars(rows,"average_rss_kib","Average runtime RSS",lambda x:f"{x/1024:.1f} MiB"),
      "v2-peak-rss.svg":bars(rows,"peak_rss_kib","Peak runtime RSS",lambda x:f"{x/1024:.1f} MiB"),
      "v2-intermediate-size.svg":bars(rows,"intermediate_bytes","Intermediate artifact size",fbytes),
      "v2-final-size.svg":bars(rows,"final_bytes","Final artifact size",fbytes),
      "v2-runtime-heatmap.svg":heatmap(rows)}
    for n,s in charts.items():(docs/n).write_text(s)
    (d/"summary_v2.json").write_text(json.dumps({"schema_version":2,"weights":WEIGHTS,"workloads":WORKLOADS,"results":rows},indent=2)+"\n")
    fields=["language","technology","version","composite_score","runtime","compile_time","average_memory","peak_memory","intermediate_size","final_size","compile_seconds","intermediate_bytes","final_bytes","average_rss_kib","peak_rss_kib"]+[k+"_seconds" for k in WORKLOADS]+[k+"_vs_c" for k in WORKLOADS]
    with (d/"summary_v2.csv").open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader()
        for r in rows:
            o={k:r.get(k) for k in fields}
            for k in WORKLOADS:o[k+"_seconds"]=r["workload_seconds"][k];o[k+"_vs_c"]=r["workload_ratios"][k]
            w.writerow(o)

def fr(v):return "N/A" if v is None else f"{v:.3f}x"

def readme_section(rows):
    x=["<!-- BENCHMARK_V2_START -->","## Benchmark v2 results","",
       "The v2 suite benchmarks common algorithms and data structures and records runtime, compile/build time, intermediate and final artifact size, average runtime RSS, and peak runtime RSS.","",
       "### Composite score","",
       "The composite is cohort-relative 0-100; higher is better. Lower-is-better raw metrics are logarithmically normalized before weighting.","",
       "| Metric | Weight |","| --- | ---: |","| Runtime | 50.0% |","| Compile/build time | 15.0% |","| Average runtime memory | 15.0% |","| Peak runtime memory | 15.0% |","| Intermediate artifact size | 2.5% |","| Final artifact size | 2.5% |","",
       "![Benchmark v2 composite score](docs/v2-composite.svg)","",
       "| Technology | Composite | Runtime vs C | Compile vs C | Avg RSS vs C | Peak RSS vs C | Intermediate vs C | Final vs C |",
       "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for r in rows:x.append(f'| {r["technology"]} | {r["composite_score"]:.1f} | {fr(r["runtime"])} | {fr(r["compile_time"])} | {fr(r["average_memory"])} | {fr(r["peak_memory"])} | {fr(r["intermediate_size"])} | {fr(r["final_size"])} |')
    x += ["","### Runtime by workload","","![Benchmark v2 runtime heatmap](docs/v2-runtime-heatmap.svg)","","![Benchmark v2 runtime index](docs/v2-runtime.svg)","",
          "### Build, memory and artifact metrics","","![Benchmark v2 compile time](docs/v2-compile.svg)","","![Benchmark v2 average RSS](docs/v2-average-rss.svg)","","![Benchmark v2 peak RSS](docs/v2-peak-rss.svg)","","![Benchmark v2 intermediate size](docs/v2-intermediate-size.svg)","","![Benchmark v2 final size](docs/v2-final-size.svg)","",
          "Machine-readable results: results/summary_v2.json and results/summary_v2.csv. Methodology: spec/BENCHMARK_V2.md.","",
          "> Artifact-size caveat: VM/JIT and extension-module results may rely on an external runtime that is not bundled into the reported artifact.","","<!-- BENCHMARK_V2_END -->"]
    return "\n".join(x)

def update_readme(rows):
    p=ROOT/"README.md";old=p.read_text();a="<!-- BENCHMARK_V2_START -->";b="<!-- BENCHMARK_V2_END -->";s=readme_section(rows)
    if a in old and b in old:
        i=old.index(a);j=old.index(b,i)+len(b);p.write_text(old[:i]+s+old[j:])
    else:p.write_text(old.rstrip()+"\n\n"+s+"\n")

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--results",default=str(ROOT/"results"));ap.add_argument("--allow-partial",action="store_true");ap.add_argument("--write-readme",action="store_true");args=ap.parse_args()
    d=pathlib.Path(args.results);m=load_results(d);missing=[x for x in TECHS if x not in m]
    if missing and not args.allow_partial:raise SystemExit("v2 results incomplete; missing: "+", ".join(missing))
    if not m:raise SystemExit("no v2 result JSON files found")
    rows=[aggregate(m[x]) for x in TECHS if x in m];score(rows);outputs(rows,d)
    if args.write_readme:
        if missing:raise SystemExit("refusing README update from partial results")
        update_readme(rows)
    print(f"rendered v2 results for {len(rows)} technologies; missing={len(missing)}")
if __name__=="__main__":main()
