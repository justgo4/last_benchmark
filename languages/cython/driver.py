import sys, bench
sizes={"integer50":200000000,"json_escape":16000000,"binary_trees":16,"mandelbrot":1600}
k=sys.argv[1]
bench.bench(k, int(sys.argv[2]) if len(sys.argv)>2 else sizes[k])
