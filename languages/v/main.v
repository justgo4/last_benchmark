module main

import os
import time

fn now_s() f64 {
	return f64(time.sys_mono_now()) * 1e-9
}

fn median(mut a []f64) f64 {
	a.sort()
	return a[a.len / 2]
}

fn emit(k string, units u64, sec f64, rate f64, checksum u64) {
	println('RESULT kernel=${k} units=${units} rounds=7 seconds=${sec:.9f} rate=${rate:.6f} checksum=${checksum}')
}

@[inline]
fn mix32(x0 u32) u32 {
	mut x := x0 + u32(0x9e3779b9)
	x ^= x >> 16
	x *= u32(0x85ebca6b)
	x ^= x >> 13
	x *= u32(0xc2b2ae35)
	return x ^ (x >> 16)
}

@[inline]
fn hash32(x0 u32) u32 {
	mut x := x0
	x ^= x >> 16
	x *= u32(0x7feb352d)
	x ^= x >> 15
	x *= u32(0x846ca68b)
	return x ^ (x >> 16)
}

fn ck32(a []u32) u32 {
	mut h := u32(2166136261)
	for x in a {
		h = (h ^ x) * u32(16777619)
	}
	return h
}

fn ck_i32(a []i32) u32 {
	mut h := u32(2166136261)
	for x in a {
		h = (h ^ u32(x)) * u32(16777619)
	}
	return h
}

fn ck64(a []u64) u32 {
	mut h := u32(2166136261)
	for x in a {
		h = (h ^ u32(x)) * u32(16777619)
		h = (h ^ u32(x >> 32)) * u32(16777619)
	}
	return h
}

@[direct_array_access]
@[noinline]
fn integer50(n u64) u64 {
	mask := (u64(1) << 50) - 1
	mut x := u64(88172645463325252) & mask
	mut s := u64(0)
	mut i := u64(0)
	for i < n {
		x ^= x >> 7
		x ^= (x << 8) & mask
		x ^= x >> 9
		x &= mask
		s = (s + (x ^ (x >> 17))) & mask
		i++
	}
	return s
}

fn bench_integer() {
	n := u64(200000000)
	_ = integer50(n / 20 + 1)
	mut times := []f64{len: 7}
	mut c := u64(0)
	for r in 0 .. 7 {
		st := now_s()
		c = integer50(n)
		times[r] = now_s() - st
	}
	m := median(mut times)
	emit('integer50', n, m, f64(n) / m / 1e6, c)
}

const pat = [u8(97),108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]!

@[direct_array_access]
fn json_escape(input []u8, mut out []u8) int {
	hx := '0123456789abcdef'
	mut j := 0
	out[j] = 34
	j++
	for c in input {
		match c {
			34 { out[j]=92; out[j+1]=34; j+=2 }
			92 { out[j]=92; out[j+1]=92; j+=2 }
			8 { out[j]=92; out[j+1]=98; j+=2 }
			12 { out[j]=92; out[j+1]=102; j+=2 }
			10 { out[j]=92; out[j+1]=110; j+=2 }
			13 { out[j]=92; out[j+1]=114; j+=2 }
			9 { out[j]=92; out[j+1]=116; j+=2 }
			else {
				if c < 32 {
					out[j]=92; out[j+1]=117; out[j+2]=48; out[j+3]=48
					out[j+4]=hx[int(c>>4)]; out[j+5]=hx[int(c&15)]; j+=6
				} else {
					out[j]=c; j++
				}
			}
		}
	}
	out[j]=34
	return j+1
}

fn bench_json() {
	n := 16000000
	mut input := []u8{len:n}
	mut out := []u8{len:n*6+2}
	for i in 0..n { input[i]=pat[i%23] }
	mut on := json_escape(input, mut out)
	mut times := []f64{len:7}
	for r in 0..7 {
		st:=now_s(); on=json_escape(input, mut out); times[r]=now_s()-st
	}
	mut c:=u64(on)
	for i in 0..on { c += u64(out[i]) }
	m:=median(mut times)
	emit('json_escape',u64(n),m,f64(n)/m/1e9,c)
}

@[direct_array_access]
fn merge_sort(mut a []u32, mut tmp []u32) {
	n:=a.len
	mut src:=a
	mut dst:=tmp
	mut flip:=false
	mut w:=1
	for w<n {
		mut lo:=0
		for lo<n {
			mid:=if lo+w<n { lo+w } else { n }
			hi:=if lo+2*w<n { lo+2*w } else { n }
			mut i:=lo
			mut j:=mid
			mut k:=lo
			for i<mid && j<hi {
				if src[i]<=src[j] { dst[k]=src[i]; i++ } else { dst[k]=src[j]; j++ }
				k++
			}
			for i<mid { dst[k]=src[i]; i++; k++ }
			for j<hi { dst[k]=src[j]; j++; k++ }
			lo += 2*w
		}
		src,dst=dst,src
		flip=!flip
		if w>n/2 { break }
		w*=2
	}
	if flip {
		for i in 0..n { a[i]=src[i] }
	}
}

fn bench_merge() {
	n:=1000000
	mut base:=[]u32{len:n}
	mut a:=[]u32{len:n}
	mut tmp:=[]u32{len:n}
	for i in 0..n { base[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	for r in 0..7 {
		for i in 0..n { a[i]=base[i] }
		st:=now_s(); merge_sort(mut a,mut tmp); times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('merge_sort',u64(n),m,f64(n)/m/1e6,u64(ck32(a)))
}

@[direct_array_access]
fn lower_search(a []u32,x u32) int {
	mut l:=0
	mut h:=a.len
	for l<h {
		m:=l+(h-l)/2
		if a[m]<x { l=m+1 } else { h=m }
	}
	if l<a.len && a[l]==x { return l }
	return -1
}

fn bench_bs() {
	n:=1000000
	nq:=n*4
	mut a:=[]u32{len:n}
	mut q:=[]u32{len:nq}
	for i in 0..n { a[i]=u32(i*2) }
	for i in 0..nq { q[i]=mix32(u32(i))%u32(2*n) }
	mut times:=[]f64{len:7}
	mut c:=u64(0)
	for r in 0..7 {
		st:=now_s(); c=0
		for x in q { p:=lower_search(a,x); if p>=0 { c+=u64(p+1) } }
		times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('binary_search',u64(nq),m,f64(nq)/m/1e6,c)
}

fn bench_prefix() {
	n:=8000000
	mut input:=[]u32{len:n}
	mut out:=[]u64{len:n}
	for i in 0..n { input[i]=mix32(u32(i))&1023 }
	mut times:=[]f64{len:7}
	mut c:=u64(0)
	for r in 0..7 {
		st:=now_s(); c=0
		for p in 0..16 {
			mut s:=u64(p)
			for i in 0..n { s+=u64(input[i]); out[i]=s }
			c^=s
		}
		times[r]=now_s()-st
	}
	c^=u64(ck64(out))
	m:=median(mut times)
	emit('prefix_sum',u64(n*16),m,f64(n*16)/m/1e6,c)
}

fn bench_matrix() {
	n:=320
	nn:=n*n
	mut a:=[]u32{len:nn}
	mut b:=[]u32{len:nn}
	mut out:=[]u64{len:nn}
	for i in 0..nn { a[i]=mix32(u32(i))&15; b[i]=mix32(u32(i+nn))&15 }
	mut times:=[]f64{len:7}
	for r in 0..7 {
		st:=now_s()
		for i in 0..n {
			for j in 0..n {
				mut s:=u64(0)
				for k in 0..n { s+=u64(a[i*n+k])*u64(b[k*n+j]) }
				out[i*n+j]=s
			}
		}
		times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('matrix_mul',u64(n),m,f64(n*n*n)/m/1e6,u64(ck64(out)))
}

fn fill_graph(mut a []u32,mut w []u32,n int,weighted bool) {
	d:=4
	for i in 0..n {
		for e in 0..d {
			p:=i*d+e
			v:=if e==0 { (i+1)%n } else if e==1 { (i+n-1)%n } else { int(mix32(u32(p))%u32(n)) }
			a[p]=u32(v)
			if weighted { w[p]=1+(mix32(u32(0xabc00000)+u32(p))&15) }
		}
	}
}

fn bench_bfs() {
	n:=200000
	d:=4
	passes:=16
	mut a:=[]u32{len:n*d}
	mut dummy:=[]u32{len:n*d}
	fill_graph(mut a,mut dummy,n,false)
	mut dist:=[]i32{len:n,init:-1}
	mut q:=[]int{len:n}
	mut times:=[]f64{len:7}
	mut seen:=u32(0)
	for r in 0..7 {
		st:=now_s()
		for pass in 0..passes {
			for i in 0..n { dist[i]=-1 }
			dist[0]=0; q[0]=0
			mut h:=0; mut t:=1
			for h<t {
				u:=q[h]; h++
				nd:=dist[u]+1
				for e in 0..d {
					v:=int(a[u*d+e])
					if dist[v]<0 { dist[v]=nd; q[t]=v; t++ }
				}
			}
			seen^=u32(t+pass)
		}
		times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('bfs',u64(n*passes),m,f64(n*d*passes)/m/1e6,u64(ck_i32(dist)^seen))
}

struct HeapItem { d u64 v int }

fn hp_push(mut h []HeapItem,mut sz int,x HeapItem) {
	mut i:=sz
	sz++
	for i>0 {
		p:=(i-1)/2
		if h[p].d<=x.d { break }
		h[i]=h[p]; i=p
	}
	h[i]=x
}

fn hp_pop(mut h []HeapItem,mut sz int) HeapItem {
	o:=h[0]
	sz--
	x:=h[sz]
	mut i:=0
	for {
		l:=i*2+1
		if l>=sz { break }
		r:=l+1
		c:=if r<sz && h[r].d<h[l].d { r } else { l }
		if h[c].d>=x.d { break }
		h[i]=h[c]; i=c
	}
	if sz>0 { h[i]=x }
	return o
}

fn bench_dijkstra() {
	n:=100000
	d:=4
	mut a:=[]u32{len:n*d}
	mut w:=[]u32{len:n*d}
	fill_graph(mut a,mut w,n,true)
	mut dist:=[]u64{len:n}
	mut heap:=[]HeapItem{len:n*d*4}
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	inf:=u64(0xffffffffffffffff)/4
	for r in 0..7 {
		st:=now_s()
		for i in 0..n { dist[i]=inf }
		dist[0]=0
		mut sz:=0
		hp_push(mut heap,mut sz,HeapItem{d:0,v:0})
		for sz>0 {
			x:=hp_pop(mut heap,mut sz)
			if x.d!=dist[x.v] { continue }
			for e in 0..d {
				p:=x.v*d+e
				v:=int(a[p])
				nd:=x.d+u64(w[p])
				if nd<dist[v] { dist[v]=nd; hp_push(mut heap,mut sz,HeapItem{d:nd,v:v}) }
			}
		}
		c=ck64(dist); times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('dijkstra',u64(n),m,f64(n*d)/m/1e6,u64(c))
}

fn uf_find(mut parent []int,x0 int) int {
	mut x:=x0
	for parent[x]!=x { parent[x]=parent[parent[x]]; x=parent[x] }
	return x
}

fn bench_uf() {
	n:=1000000
	ops:=n*4
	mut parent:=[]int{len:n}
	mut rank:=[]u8{len:n}
	mut aa:=[]int{len:ops}
	mut bb:=[]int{len:ops}
	for i in 0..ops { aa[i]=int(mix32(u32(i))%u32(n)); bb[i]=int(mix32(u32(i+ops))%u32(n)) }
	mut times:=[]f64{len:7}
	for r in 0..7 {
		st:=now_s()
		for i in 0..n { parent[i]=i; rank[i]=0 }
		for i in 0..ops {
			mut ra:=uf_find(mut parent,aa[i]); mut rb:=uf_find(mut parent,bb[i])
			if ra!=rb {
				if rank[ra]<rank[rb] { ra,rb=rb,ra }
				parent[rb]=ra
				if rank[ra]==rank[rb] { rank[ra]++ }
			}
		}
		times[r]=now_s()-st
	}
	mut h:=u32(2166136261)
	for i in 0..n { parent[i]=uf_find(mut parent,i); h=(h^u32(parent[i]))*u32(16777619) }
	m:=median(mut times)
	emit('union_find',u64(ops),m,f64(ops)/m/1e6,u64(h))
}

@[noinline]
fn mandel(w int,mi int) u64 {
	mut sum:=u64(0)
	for y in 0..w {
		ci:=-1.5+3.0*f64(y)/f64(w-1)
		for x in 0..w {
			cr:=-2.0+3.0*f64(x)/f64(w-1)
			mut zr:=0.0; mut zi:=0.0; mut it:=0
			for it<mi {
				a:=zr*zr; b:=zi*zi
				if a+b>4.0 { break }
				nz:=a-b+cr; zi=2.0*zr*zi+ci; zr=nz; it++
			}
			sum+=u64(it)
		}
	}
	return sum
}

fn bench_mandel() {
	w:=1600
	_ = mandel(128,20)
	mut times:=[]f64{len:7}
	mut c:=u64(0)
	for r in 0..7 { st:=now_s(); c=mandel(w,50); times[r]=now_s()-st }
	m:=median(mut times)
	emit('mandelbrot',u64(w*w),m,f64(w*w)/m/1e6,c)
}

fn bench_dynamic() {
	n:=5000000
	mut input:=[]u32{len:n}
	for i in 0..n { input[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s()
		mut v:=[]u32{cap:8}
		for x in input { v<<x }
		mut h:=u32(2166136261)
		for i in 0..v.len { v[i]^=u32(i); h=(h^v[i])*u32(16777619) }
		for v.len>0 { idx:=v.len-1; x:=v.pop(); h=(h^(x+u32(idx)))*u32(16777619) }
		c=h; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('dynamic_array',u64(n),m,f64(n)/m/1e6,u64(c))
}

fn bench_list() {
	n:=4000000
	passes:=16
	mut next:=[]int{len:n,init:-1}
	mut val:=[]u32{len:n}
	mut base:=[]u32{len:n}
	for i in 0..n { base[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s()
		for i in 0..n { val[i]=base[i]; next[i]=if i+1<n { i+1 } else { -1 } }
		mut b:=0
		for b<n {
			hi:=if b+64<n { b+63 } else { n-1 }
			for i in b..hi+1 { next[i]=if i==b { if hi+1<n { hi+1 } else { -1 } } else { i-1 } }
			b+=64
		}
		mut h:=u32(2166136261)
		for p in 0..passes {
			mut cur:=if 64<n { 63 } else { n-1 }
			mut seen:=0
			for cur>=0 && seen<n {
				val[cur]^=u32(seen+p)
				h=(h^(val[cur]+u32(cur)+u32(p)))*u32(16777619)
				cur=next[cur]; seen++
			}
			h=(h^u32(seen))*u32(16777619)
		}
		c=h; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('linked_list',u64(n*passes),m,f64(n*passes)/m/1e6,u64(c))
}

fn bench_queue() {
	ops:=10000000
	cap:=ops/2+1024
	mut buf:=[]u32{len:cap}
	mut input:=[]u32{len:ops}
	for i in 0..ops { input[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s(); mut h:=0; mut t:=0; mut cnt:=0; mut z:=u32(0)
		for i in 0..ops {
			if (i&3)!=3 {
				if cnt==cap { z^=buf[h]; h=(h+1)%cap; cnt-- }
				buf[t]=input[i]; t=(t+1)%cap; cnt++
			} else if cnt>0 { z^=buf[h]; h=(h+1)%cap; cnt-- }
		}
		for cnt>0 { z^=buf[h]; h=(h+1)%cap; cnt-- }
		c=z; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('queue_ring',u64(ops),m,f64(ops)/m/1e6,u64(c))
}

fn next_pow2(x int) int { mut p:=1; for p<x { p*=2 }; return p }

fn bench_hash() {
	n:=1000000
	cap:=next_pow2(n*2)
	mask:=cap-1
	mut keys:=[]u32{len:cap}
	mut vals:=[]u32{len:cap}
	mut ik:=[]u32{len:n}
	mut iv:=[]u32{len:n}
	for i in 0..n { ik[i]=mix32(u32(i))|1; iv[i]=mix32(u32(i)+u32(0x55555555)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s()
		for i in 0..cap { keys[i]=0 }
		for i in 0..n {
			key:=ik[i]; mut p:=int(hash32(key))&mask
			for keys[p]!=0 && keys[p]!=key { p=(p+1)&mask }
			keys[p]=key; vals[p]=iv[i]
		}
		mut h:=u32(0)
		for i in 0..n {
			key:=ik[i]; mut p:=int(hash32(key))&mask
			for keys[p]!=key { p=(p+1)&mask }
			vals[p]^=u32(i); h^=vals[p]
		}
		c=h; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('hash_table',u64(n),m,f64(n*2)/m/1e6,u64(c))
}

fn heap_push(mut h []u32,mut sz int,x u32) {
	mut i:=sz; sz++
	for i>0 { p:=(i-1)/2; if h[p]<=x { break }; h[i]=h[p]; i=p }
	h[i]=x
}

fn heap_pop(mut h []u32,mut sz int) u32 {
	o:=h[0]; sz--; x:=h[sz]; mut i:=0
	for {
		l:=i*2+1; if l>=sz { break }
		r:=l+1; c:=if r<sz && h[r]<h[l] { r } else { l }
		if h[c]>=x { break }
		h[i]=h[c]; i=c
	}
	if sz>0 { h[i]=x }
	return o
}

fn bench_heap() {
	n:=1000000
	mut h:=[]u32{len:n}
	mut input:=[]u32{len:n}
	for i in 0..n { input[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s(); mut sz:=0
		for x in input { heap_push(mut h,mut sz,x) }
		mut z:=u32(0)
		for i in 0..n { z^=heap_pop(mut h,mut sz)+u32(i) }
		c=z; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('binary_heap',u64(n),m,f64(n*2)/m/1e6,u64(c))
}

fn bench_bst() {
	n:=300000
	mut keys:=[]u32{len:n}
	mut left:=[]int{len:n,init:-1}
	mut right:=[]int{len:n,init:-1}
	mut input:=[]u32{len:n}
	for i in 0..n { input[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s(); mut root:=-1
		for i in 0..n {
			key:=input[i]; keys[i]=key; left[i]=-1; right[i]=-1
			if root<0 { root=i; continue }
			mut cur:=root
			for {
				if key<keys[cur] {
					if left[cur]<0 { left[cur]=i; break }
					cur=left[cur]
				} else {
					if right[cur]<0 { right[cur]=i; break }
					cur=right[cur]
				}
			}
		}
		mut hh:=u32(0)
		mut i:=0
		for i<n {
			key:=input[i]; mut cur:=root
			for cur>=0 && keys[cur]!=key { cur=if key<keys[cur] { left[cur] } else { right[cur] } }
			if cur>=0 { hh^=u32(cur+1) }
			i+=3
		}
		c=hh; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('bst',u64(n),m,f64(n)/m/1e6,u64(c))
}

fn bench_trie() {
	n:=100000
	passes:=32
	mx:=1+n*8
	mut ch:=[]int{len:mx*16,init:-1}
	mut term:=[]u8{len:mx}
	mut words:=[]u32{len:n}
	for i in 0..n { words[i]=mix32(u32(i)) }
	mut times:=[]f64{len:7}
	mut c:=u32(0)
	for r in 0..7 {
		st:=now_s()
		for i in 0..ch.len { ch[i]=-1 }
		for i in 0..term.len { term[i]=0 }
		mut used:=1
		for word in words {
			mut node:=0
			mut sh:=28
			for sh>=0 {
				cc:=int((word>>u32(sh))&15)
				p:=node*16+cc
				if ch[p]<0 { ch[p]=used; used++ }
				node=ch[p]; sh-=4
			}
			term[node]=1
		}
		mut h:=u32(used)
		for p in 0..passes {
			mut i:=0
			for i<n {
				word:=words[i]; mut node:=0; mut sh:=28
				for sh>=0 && node>=0 { node=ch[node*16+int((word>>u32(sh))&15)]; sh-=4 }
				if node>=0 && term[node]!=0 { h^=u32(node+1+p) }
				i+=2
			}
		}
		c=h; times[r]=now_s()-st
	}
	m:=median(mut times)
	emit('trie',u64(n*passes),m,f64(n*passes)/m/1e6,u64(c))
}

fn main() {
	k:=if os.args.len>1 { os.args[1] } else { 'integer50' }
	match k {
		'integer50' { bench_integer() }
		'json_escape' { bench_json() }
		'merge_sort' { bench_merge() }
		'binary_search' { bench_bs() }
		'prefix_sum' { bench_prefix() }
		'matrix_mul' { bench_matrix() }
		'bfs' { bench_bfs() }
		'dijkstra' { bench_dijkstra() }
		'union_find' { bench_uf() }
		'mandelbrot' { bench_mandel() }
		'dynamic_array' { bench_dynamic() }
		'linked_list' { bench_list() }
		'queue_ring' { bench_queue() }
		'hash_table' { bench_hash() }
		'binary_heap' { bench_heap() }
		'bst' { bench_bst() }
		'trie' { bench_trie() }
		else { panic('unknown kernel') }
	}
}
