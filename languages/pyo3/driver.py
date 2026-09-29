import bench_ext,sys
sizes={"integer50":200000000,"json_escape":16000000,"binary_trees":16,"mandelbrot":1600}
k=sys.argv[1]
size=int(sys.argv[2]) if len(sys.argv)>2 else sizes[k]
k,u,s,rate,c=bench_ext.run(k,size)
print(f"RESULT kernel={k} units={u} rounds=7 seconds={s:.9f} rate={rate:.6f} checksum={c}")
