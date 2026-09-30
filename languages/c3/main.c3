module bench;
import std;

fn double elapsed(Clock c) => c.mark().to_sec();

fn double median(double[] a)
{
	for (usz i = 1; i < a.len; i++)
	{
		double x = a[i];
		usz j = i;
		while (j > 0 && a[j - 1] > x)
		{
			a[j] = a[j - 1];
			j--;
		}
		a[j] = x;
	}
	return a[a.len / 2];
}

fn void emit(String k, ulong units, double sec, double rate, ulong checksum)
{
	io::printfn("RESULT kernel=%s units=%d rounds=7 seconds=%.9f rate=%.6f checksum=%d", k, units, sec, rate, checksum);
}

fn uint mix32(uint x)
{
	x += 0x9e3779b9;
	x ^= x >> 16;
	x *= 0x85ebca6b;
	x ^= x >> 13;
	x *= 0xc2b2ae35;
	return x ^ (x >> 16);
}

fn uint hash32(uint x)
{
	x ^= x >> 16;
	x *= 0x7feb352d;
	x ^= x >> 15;
	x *= 0x846ca68b;
	return x ^ (x >> 16);
}

fn uint ck32(uint[] a)
{
	uint h = 2166136261;
	foreach (x : a) { h = (h ^ x) * 16777619; }
	return h;
}

fn uint ck_i32(int[] a)
{
	uint h = 2166136261;
	foreach (x : a) { h = (h ^ (uint)x) * 16777619; }
	return h;
}

fn uint ck64(ulong[] a)
{
	uint h = 2166136261;
	foreach (x : a)
	{
		h = (h ^ (uint)x) * 16777619;
		h = (h ^ (uint)(x >> 32)) * 16777619;
	}
	return h;
}

fn ulong integer50(ulong n) @noinline
{
	const ulong MASK = ((ulong)1 << 50) - 1;
	ulong x = (ulong)88172645463325252 & MASK;
	ulong s = 0;
	for (ulong i = 0; i < n; i++)
	{
		x ^= x >> 7;
		x ^= (x << 8) & MASK;
		x ^= x >> 9;
		x &= MASK;
		s = (s + (x ^ (x >> 17))) & MASK;
	}
	return s;
}

fn void bench_integer()
{
	const ulong N = 200_000_000;
	(void)integer50(N / 20 + 1);
	double[] times = mem::alloc_array(double, 7);
	defer free(times);
	ulong c = 0;
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now();
		c = integer50(N);
		times[r] = elapsed(st);
	}
	double m = median(times);
	emit("integer50", N, m, (double)N / m / 1e6, c);
}

fn sz json_escape(char[] input, char[] out)
{
	const String HEX = "0123456789abcdef";
	sz j = 0;
	out[j++] = 34;
	foreach (c : input)
	{
		switch (c)
		{
			case 34: out[j++] = 92; out[j++] = 34;
			case 92: out[j++] = 92; out[j++] = 92;
			case 8: out[j++] = 92; out[j++] = 98;
			case 12: out[j++] = 92; out[j++] = 102;
			case 10: out[j++] = 92; out[j++] = 110;
			case 13: out[j++] = 92; out[j++] = 114;
			case 9: out[j++] = 92; out[j++] = 116;
			default:
				if (c < 32)
				{
					out[j++] = 92; out[j++] = 117; out[j++] = 48; out[j++] = 48;
					out[j++] = HEX[c >> 4]; out[j++] = HEX[c & 15];
				}
				else out[j++] = c;
		}
	}
	out[j++] = 34;
	return j;
}

fn void bench_json()
{
	const sz N = 16_000_000;
	char[23] pat = {97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47};
	char[] input = mem::alloc_array(char, N);
	char[] out = mem::alloc_array(char, N * 6 + 2);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(out); free(input); }
	for (sz i = 0; i < N; i++) input[i] = pat[i % 23];
	sz on = json_escape(input, out);
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now();
		on = json_escape(input, out);
		times[r] = elapsed(st);
	}
	ulong c = (ulong)on;
	for (sz i = 0; i < on; i++) c += out[i];
	double m = median(times);
	emit("json_escape", N, m, (double)N / m / 1e9, c);
}

fn void merge_sort(uint[] a, uint[] tmp)
{
	sz n = a.len;
	uint[] src = a;
	uint[] dst = tmp;
	bool flip = false;
	for (sz w = 1; w < n;)
	{
		for (sz lo = 0; lo < n; lo += 2 * w)
		{
			sz mid = min(lo + w, n);
			sz hi = min(lo + 2 * w, n);
			sz i = lo; sz j = mid; sz k = lo;
			while (i < mid && j < hi)
			{
				if (src[i] <= src[j]) dst[k++] = src[i++];
				else dst[k++] = src[j++];
			}
			while (i < mid) dst[k++] = src[i++];
			while (j < hi) dst[k++] = src[j++];
		}
		uint[] z = src; src = dst; dst = z; flip = !flip;
		if (w > n / 2) break;
		w *= 2;
	}
	if (flip) for (sz i = 0; i < n; i++) a[i] = src[i];
}

fn void bench_merge()
{
	const sz N = 1_000_000;
	uint[] base = mem::alloc_array(uint, N);
	uint[] a = mem::alloc_array(uint, N);
	uint[] tmp = mem::alloc_array(uint, N);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(tmp); free(a); free(base); }
	for (sz i = 0; i < N; i++) base[i] = mix32((uint)i);
	for (int r = 0; r < 7; r++)
	{
		for (sz i = 0; i < N; i++) a[i] = base[i];
		Clock st = clock::now();
		merge_sort(a, tmp);
		times[r] = elapsed(st);
	}
	double m = median(times);
	emit("merge_sort", N, m, (double)N / m / 1e6, ck32(a));
}

fn int lower_search(uint[] a, uint x)
{
	sz l = 0; sz h = a.len;
	while (l < h)
	{
		sz m = l + (h - l) / 2;
		if (a[m] < x) l = m + 1; else h = m;
	}
	return l < a.len && a[l] == x ? (int)l : -1;
}

fn void bench_bs()
{
	const sz N = 1_000_000;
	const sz NQ = N * 4;
	uint[] a = mem::alloc_array(uint, N);
	uint[] q = mem::alloc_array(uint, NQ);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(q); free(a); }
	for (sz i = 0; i < N; i++) a[i] = (uint)(i * 2);
	for (sz i = 0; i < NQ; i++) q[i] = mix32((uint)i) % (uint)(2 * N);
	ulong c = 0;
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now(); c = 0;
		foreach (x : q)
		{
			int p = lower_search(a, x);
			if (p >= 0) c += (ulong)p + 1;
		}
		times[r] = elapsed(st);
	}
	double m = median(times);
	emit("binary_search", NQ, m, (double)NQ / m / 1e6, c);
}

fn void bench_prefix()
{
	const sz N = 8_000_000;
	uint[] input = mem::alloc_array(uint, N);
	ulong[] out = mem::alloc_array(ulong, N);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(out); free(input); }
	for (sz i = 0; i < N; i++) input[i] = mix32((uint)i) & 1023;
	ulong c = 0;
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now(); c = 0;
		for (int p = 0; p < 16; p++)
		{
			ulong s = (ulong)p;
			for (sz i = 0; i < N; i++) { s += input[i]; out[i] = s; }
			c ^= s;
		}
		times[r] = elapsed(st);
	}
	c ^= ck64(out);
	double m = median(times);
	emit("prefix_sum", N * 16, m, (double)(N * 16) / m / 1e6, c);
}

fn void bench_matrix()
{
	const sz N = 320;
	const sz NN = N * N;
	uint[] a = mem::alloc_array(uint, NN);
	uint[] b = mem::alloc_array(uint, NN);
	ulong[] out = mem::alloc_array(ulong, NN);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(out); free(b); free(a); }
	for (sz i = 0; i < NN; i++) { a[i] = mix32((uint)i) & 15; b[i] = mix32((uint)(i + NN)) & 15; }
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now();
		for (sz i = 0; i < N; i++) for (sz j = 0; j < N; j++)
		{
			ulong s = 0;
			for (sz k = 0; k < N; k++) s += (ulong)a[i * N + k] * b[k * N + j];
			out[i * N + j] = s;
		}
		times[r] = elapsed(st);
	}
	double m = median(times);
	emit("matrix_mul", N, m, (double)(N * N * N) / m / 1e6, ck64(out));
}

fn void fill_graph(uint[] a, uint[] w, sz n, bool weighted)
{
	const int D = 4;
	for (sz i = 0; i < n; i++) for (int e = 0; e < D; e++)
	{
		sz p = i * D + e;
		uint v;
		if (e == 0) v = (uint)((i + 1) % n);
		else if (e == 1) v = (uint)((i + n - 1) % n);
		else v = mix32((uint)p) % (uint)n;
		a[p] = v;
		if (weighted) w[p] = 1 + (mix32(0xabc00000 + (uint)p) & 15);
	}
}

fn void bench_bfs()
{
	const sz N = 200_000;
	const int D = 4; const int PASSES = 16;
	uint[] a = mem::alloc_array(uint, N * D);
	uint[] dummy = mem::alloc_array(uint, N * D);
	int[] dist = mem::alloc_array(int, N);
	uint[] q = mem::alloc_array(uint, N);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(q); free(dist); free(dummy); free(a); }
	fill_graph(a, dummy, N, false);
	uint seen = 0;
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now();
		for (int pass = 0; pass < PASSES; pass++)
		{
			for (sz i = 0; i < N; i++) dist[i] = -1;
			dist[0] = 0; q[0] = 0;
			sz h = 0; sz t = 1;
			while (h < t)
			{
				uint u = q[h++];
				int nd = dist[u] + 1;
				for (int e = 0; e < D; e++)
				{
					uint v = a[(sz)u * D + e];
					if (dist[v] < 0) { dist[v] = nd; q[t++] = v; }
				}
			}
			seen ^= (uint)t + (uint)pass;
		}
		times[r] = elapsed(st);
	}
	double m = median(times);
	emit("bfs", N * PASSES, m, (double)(N * D * PASSES) / m / 1e6, (ulong)(ck_i32(dist) ^ seen));
}

struct HeapItem { ulong d; uint v; }

fn void hp_push(HeapItem[] h, sz* size, HeapItem x)
{
	sz i = (*size)++;
	while (i > 0)
	{
		sz p = (i - 1) / 2;
		if (h[p].d <= x.d) break;
		h[i] = h[p]; i = p;
	}
	h[i] = x;
}

fn HeapItem hp_pop(HeapItem[] h, sz* size)
{
	HeapItem out = h[0];
	HeapItem x = h[--*size];
	sz i = 0;
	while (true)
	{
		sz l = i * 2 + 1;
		if (l >= *size) break;
		sz r = l + 1;
		sz c = r < *size && h[r].d < h[l].d ? r : l;
		if (h[c].d >= x.d) break;
		h[i] = h[c]; i = c;
	}
	if (*size) h[i] = x;
	return out;
}

fn void bench_dijkstra()
{
	const sz N = 100_000;
	const int D = 4;
	uint[] a = mem::alloc_array(uint, N * D);
	uint[] w = mem::alloc_array(uint, N * D);
	ulong[] dist = mem::alloc_array(ulong, N);
	HeapItem[] heap = mem::alloc_array(HeapItem, N * D * 4);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(heap); free(dist); free(w); free(a); }
	fill_graph(a, w, N, true);
	uint c = 0;
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now();
		for (sz i = 0; i < N; i++) dist[i] = (ulong)-1 / 4;
		sz size = 0; dist[0] = 0;
		hp_push(heap, &size, {0,0});
		while (size)
		{
			HeapItem x = hp_pop(heap, &size);
			if (x.d != dist[x.v]) continue;
			for (int e = 0; e < D; e++)
			{
				sz p = (sz)x.v * D + e;
				uint v = a[p];
				ulong nd = x.d + w[p];
				if (nd < dist[v]) { dist[v] = nd; hp_push(heap, &size, {nd,v}); }
			}
		}
		c = ck64(dist); times[r] = elapsed(st);
	}
	double m = median(times);
	emit("dijkstra", N, m, (double)(N * D) / m / 1e6, c);
}

fn uint uf_find(uint[] parent, uint x)
{
	while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
	return x;
}

fn void bench_uf()
{
	const sz N = 1_000_000;
	const sz OPS = N * 4;
	uint[] parent = mem::alloc_array(uint, N);
	char[] rank = mem::alloc_array(char, N);
	uint[] aa = mem::alloc_array(uint, OPS);
	uint[] bb = mem::alloc_array(uint, OPS);
	double[] times = mem::alloc_array(double, 7);
	defer { free(times); free(bb); free(aa); free(rank); free(parent); }
	for (sz i = 0; i < OPS; i++) { aa[i] = mix32((uint)i) % (uint)N; bb[i] = mix32((uint)(i + OPS)) % (uint)N; }
	for (int r = 0; r < 7; r++)
	{
		Clock st = clock::now();
		for (sz i = 0; i < N; i++) { parent[i] = (uint)i; rank[i] = 0; }
		for (sz i = 0; i < OPS; i++)
		{
			uint ra = uf_find(parent, aa[i]); uint rb = uf_find(parent, bb[i]);
			if (ra != rb)
			{
				if (rank[ra] < rank[rb]) { uint z = ra; ra = rb; rb = z; }
				parent[rb] = ra;
				if (rank[ra] == rank[rb]) rank[ra]++;
			}
		}
		times[r] = elapsed(st);
	}
	for (sz i = 0; i < N; i++) parent[i] = uf_find(parent, (uint)i);
	double m = median(times);
	emit("union_find", OPS, m, (double)OPS / m / 1e6, ck32(parent));
}

fn ulong mandel(int w, int mi) @noinline
{
	ulong sum = 0;
	for (int y = 0; y < w; y++)
	{
		double ci = -1.5 + 3.0 * y / (w - 1.0);
		for (int x = 0; x < w; x++)
		{
			double cr = -2.0 + 3.0 * x / (w - 1.0); double zr = 0; double zi = 0;
			int it = 0;
			while (it < mi)
			{
				double a = zr * zr; double b = zi * zi;
				if (a + b > 4.0) break;
				double nz = a - b + cr;
				zi = 2.0 * zr * zi + ci; zr = nz; it++;
			}
			sum += (ulong)it;
		}
	}
	return sum;
}

fn void bench_mandel()
{
	const int W = 1600;
	(void)mandel(128,20);
	double[] times = mem::alloc_array(double,7);
	defer free(times);
	ulong c = 0;
	for (int r = 0; r < 7; r++) { Clock st = clock::now(); c = mandel(W,50); times[r] = elapsed(st); }
	double m = median(times);
	emit("mandelbrot", (ulong)W * W, m, (double)(W * W) / m / 1e6, c);
}

fn uint dynamic_once(uint[] input)
{
	sz cap = 8; sz len = 0;
	uint[] v = mem::alloc_array(uint, cap);
	foreach (x : input)
	{
		if (len == cap)
		{
			sz nc = cap * 2;
			uint[] nv = mem::alloc_array(uint, nc);
			for (sz i = 0; i < len; i++) nv[i] = v[i];
			free(v); v = nv; cap = nc;
		}
		v[len++] = x;
	}
	uint h = 2166136261;
	for (sz i = 0; i < len; i++) { v[i] ^= (uint)i; h = (h ^ v[i]) * 16777619; }
	while (len) { uint x = v[--len]; h = (h ^ (x + (uint)len)) * 16777619; }
	free(v);
	return h;
}

fn void bench_dynamic()
{
	const sz N = 5_000_000;
	uint[] input = mem::alloc_array(uint,N);
	double[] times = mem::alloc_array(double,7);
	defer { free(times); free(input); }
	for (sz i=0;i<N;i++) input[i]=mix32((uint)i);
	uint c=0;
	for (int r=0;r<7;r++) { Clock st=clock::now(); c=dynamic_once(input); times[r]=elapsed(st); }
	double m=median(times);
	emit("dynamic_array",N,m,(double)N/m/1e6,c);
}

fn uint list_once(uint[] next,uint[] val,uint[] base,int passes)
{
	sz n=base.len;
	for(sz i=0;i<n;i++){val[i]=base[i];next[i]=i+1<n?(uint)(i+1):0xffff_ffff;}
	const sz B=64;
	for(sz b=0;b<n;b+=B)
	{
		sz hi=min(b+B,n)-1;
		for(sz i=b;i<=hi;i++) next[i]=i==b?(hi+1<n?(uint)(hi+1):0xffff_ffff):(uint)(i-1);
	}
	uint h=2166136261;
	for(int p=0;p<passes;p++)
	{
		uint cur=B<n?(uint)(B-1):(uint)(n-1);
		sz seen=0;
		while(cur!=0xffff_ffff&&seen<n)
		{
			val[cur]^=(uint)(seen+p);
			h=(h^(val[cur]+cur+(uint)p))*16777619;
			cur=next[cur];seen++;
		}
		h=(h^(uint)seen)*16777619;
	}
	return h;
}

fn void bench_list()
{
	const sz N=4_000_000; const int PASSES=16;
	uint[] next=mem::alloc_array(uint,N); uint[] val=mem::alloc_array(uint,N); uint[] base=mem::alloc_array(uint,N);
	double[] times=mem::alloc_array(double,7);
	defer{free(times);free(base);free(val);free(next);}
	for(sz i=0;i<N;i++)base[i]=mix32((uint)i);
	uint c=0;
	for(int r=0;r<7;r++){Clock st=clock::now();c=list_once(next,val,base,PASSES);times[r]=elapsed(st);}
	double m=median(times);
	emit("linked_list",N*PASSES,m,(double)(N*PASSES)/m/1e6,c);
}

fn uint queue_once(uint[] buf,uint[] input)
{
	sz cap=buf.len; sz h=0; sz t=0; sz cnt=0; uint z=0;
	for(sz i=0;i<input.len;i++)
	{
		if((i&3)!=3)
		{
			if(cnt==cap){z^=buf[h];h=(h+1)%cap;cnt--;}
			buf[t]=input[i];t=(t+1)%cap;cnt++;
		}
		else if(cnt){z^=buf[h];h=(h+1)%cap;cnt--;}
	}
	while(cnt){z^=buf[h];h=(h+1)%cap;cnt--;}
	return z;
}

fn void bench_queue()
{
	const sz OPS=10_000_000; const sz CAP=OPS/2+1024;
	uint[] buf=mem::alloc_array(uint,CAP); uint[] input=mem::alloc_array(uint,OPS);
	double[] times=mem::alloc_array(double,7);
	defer{free(times);free(input);free(buf);}
	for(sz i=0;i<OPS;i++)input[i]=mix32((uint)i);
	uint c=0;
	for(int r=0;r<7;r++){Clock st=clock::now();c=queue_once(buf,input);times[r]=elapsed(st);}
	double m=median(times);
	emit("queue_ring",OPS,m,(double)OPS/m/1e6,c);
}

fn sz next_pow2(sz x){sz p=1;while(p<x)p<<=1;return p;}

fn uint hash_once(uint[] keys,uint[] vals,uint[] ik,uint[] iv)
{
	sz cap=keys.len; sz mask=cap-1; sz n=ik.len;
	for(sz i=0;i<cap;i++)keys[i]=0;
	for(sz i=0;i<n;i++)
	{
		uint key=ik[i];sz p=(sz)hash32(key)&mask;
		while(keys[p]&&keys[p]!=key)p=(p+1)&mask;
		keys[p]=key;vals[p]=iv[i];
	}
	uint h=0;
	for(sz i=0;i<n;i++)
	{
		uint key=ik[i];sz p=(sz)hash32(key)&mask;
		while(keys[p]!=key)p=(p+1)&mask;
		vals[p]^=(uint)i;h^=vals[p];
	}
	return h;
}

fn void bench_hash()
{
	const sz N=1_000_000;sz cap=next_pow2(N*2);
	uint[] keys=mem::alloc_array(uint,cap); uint[] vals=mem::alloc_array(uint,cap); uint[] ik=mem::alloc_array(uint,N); uint[] iv=mem::alloc_array(uint,N);
	double[] times=mem::alloc_array(double,7);
	defer{free(times);free(iv);free(ik);free(vals);free(keys);}
	for(sz i=0;i<N;i++){ik[i]=mix32((uint)i)|1;iv[i]=mix32((uint)i+0x55555555);}
	uint c=0;
	for(int r=0;r<7;r++){Clock st=clock::now();c=hash_once(keys,vals,ik,iv);times[r]=elapsed(st);}
	double m=median(times);
	emit("hash_table",N,m,(double)(N*2)/m/1e6,c);
}

fn void heap_push(uint[] h,sz* size,uint x)
{
	sz i=(*size)++;
	while(i){sz p=(i-1)/2;if(h[p]<=x)break;h[i]=h[p];i=p;}h[i]=x;
}
fn uint heap_pop(uint[] h,sz* size)
{
	uint out=h[0]; uint x=h[--*size]; sz i=0;
	while(true){sz l=i*2+1;if(l>=*size)break;sz r=l+1;sz c=l;if(r<*size&&h[r]<h[l])c=r;if(h[c]>=x)break;h[i]=h[c];i=c;}
	if(*size)h[i]=x;return out;
}

fn void bench_heap()
{
	const sz N=1_000_000;
	uint[] h=mem::alloc_array(uint,N); uint[] input=mem::alloc_array(uint,N);
	double[] times=mem::alloc_array(double,7);
	defer{free(times);free(input);free(h);}
	for(sz i=0;i<N;i++)input[i]=mix32((uint)i);
	uint c=0;
	for(int r=0;r<7;r++)
	{
		Clock st=clock::now();sz size=0;foreach(x:input)heap_push(h,&size,x);uint z=0;
		for(sz i=0;i<N;i++)z^=heap_pop(h,&size)+(uint)i;
		c=z;times[r]=elapsed(st);
	}
	double m=median(times);emit("binary_heap",N,m,(double)(N*2)/m/1e6,c);
}

fn void bench_bst()
{
	const sz N=300_000;
	uint[] keys=mem::alloc_array(uint,N); uint[] input=mem::alloc_array(uint,N);
	int[] left=mem::alloc_array(int,N); int[] right=mem::alloc_array(int,N);
	double[] times=mem::alloc_array(double,7);
	defer{free(times);free(right);free(left);free(input);free(keys);}
	for(sz i=0;i<N;i++)input[i]=mix32((uint)i);
	uint c=0;
	for(int r=0;r<7;r++)
	{
		Clock st=clock::now();int root=-1;
		for(sz i=0;i<N;i++)
		{
			uint key=input[i];keys[i]=key;left[i]=right[i]=-1;int node=(int)i;
			if(root<0){root=node;continue;}
			int cur=root;
			while(true)
			{
				if(key<keys[cur]){if(left[cur]<0){left[cur]=node;break;}cur=left[cur];}
				else{if(right[cur]<0){right[cur]=node;break;}cur=right[cur];}
			}
		}
		uint h=0;
		for(sz i=0;i<N;i+=3)
		{
			uint key=input[i];int cur=root;
			while(cur>=0&&keys[cur]!=key)cur=key<keys[cur]?left[cur]:right[cur];
			if(cur>=0)h^=(uint)cur+1;
		}
		c=h;times[r]=elapsed(st);
	}
	double m=median(times);emit("bst",N,m,(double)N/m/1e6,c);
}

fn void bench_trie()
{
	const sz N=100_000;const int PASSES=32;const sz MX=1+N*8;
	int[] ch=mem::alloc_array(int,MX*16);char[] term=mem::alloc_array(char,MX);uint[] words=mem::alloc_array(uint,N);
	double[] times=mem::alloc_array(double,7);
	defer{free(times);free(words);free(term);free(ch);}
	for(sz i=0;i<N;i++)words[i]=mix32((uint)i);
	uint c=0;
	for(int r=0;r<7;r++)
	{
		Clock st=clock::now();
		for(sz i=0;i<MX*16;i++)ch[i]=-1;for(sz i=0;i<MX;i++)term[i]=0;
		sz used=1;
		foreach(word:words)
		{
			int node=0;
			for(int sh=28;sh>=0;sh-=4)
			{
				int cc=(int)((word>>(uint)sh)&15);sz p=(sz)node*16+(sz)cc;
				if(ch[p]<0)ch[p]=(int)used++;
				node=ch[p];
			}
			term[node]=1;
		}
		uint h=(uint)used;
		for(int p=0;p<PASSES;p++)for(sz i=0;i<N;i+=2)
		{
			uint word=words[i];int node=0;
			for(int sh=28;sh>=0&&node>=0;sh-=4)node=ch[(sz)node*16+((word>>(uint)sh)&15)];
			if(node>=0&&term[node])h^=(uint)node+1+(uint)p;
		}
		c=h;times[r]=elapsed(st);
	}
	double m=median(times);emit("trie",N*PASSES,m,(double)(N*PASSES)/m/1e6,c);
}

fn void main(String[] args)
{
	String k = "integer50";
	if (args.len > 1) k = args[1];
	switch(k)
	{
		case "integer50": bench_integer();
		case "json_escape": bench_json();
		case "merge_sort": bench_merge();
		case "binary_search": bench_bs();
		case "prefix_sum": bench_prefix();
		case "matrix_mul": bench_matrix();
		case "bfs": bench_bfs();
		case "dijkstra": bench_dijkstra();
		case "union_find": bench_uf();
		case "mandelbrot": bench_mandel();
		case "dynamic_array": bench_dynamic();
		case "linked_list": bench_list();
		case "queue_ring": bench_queue();
		case "hash_table": bench_hash();
		case "binary_heap": bench_heap();
		case "bst": bench_bst();
		case "trie": bench_trie();
		default: io::printfn("unknown kernel %s", k);
	}
}
