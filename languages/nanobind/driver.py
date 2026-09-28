import bench_ext,sys
k,u,s,rate,c=bench_ext.run(sys.argv[1])
print(f"RESULT kernel={k} units={u} rounds=7 seconds={s:.9f} rate={rate:.6f} checksum={c}")
