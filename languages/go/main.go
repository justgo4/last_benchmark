package main

import (
	"fmt"
	"os"
	"sort"
	"strconv"
	"time"
)

func now() float64 { return float64(time.Now().UnixNano()) * 1e-9 }
func med(v []float64) float64 { sort.Float64s(v); return v[len(v)/2] }
func emit(k string, u uint64, r int, s, rate float64, c uint64) {
	fmt.Printf("RESULT kernel=%s units=%d rounds=%d seconds=%.9f rate=%.6f checksum=%d\n", k, u, r, s, rate, c)
}
func mix32(x uint32) uint32 {
	x += 0x9e3779b9
	x ^= x >> 16
	x *= 0x85ebca6b
	x ^= x >> 13
	x *= 0xc2b2ae35
	return x ^ (x >> 16)
}
func hash32(x uint32) uint32 {
	x ^= x >> 16
	x *= 0x7feb352d
	x ^= x >> 15
	x *= 0x846ca68b
	return x ^ (x >> 16)
}
func ck32(a []uint32) uint32 {
	h := uint32(2166136261)
	for _, x := range a { h ^= x; h *= 16777619 }
	return h
}
func ck64(a []uint64) uint32 {
	h := uint32(2166136261)
	for _, x := range a {
		h ^= uint32(x); h *= 16777619
		h ^= uint32(x >> 32); h *= 16777619
	}
	return h
}

func integer50(n uint64) uint64 {
	const mask uint64 = (1 << 50) - 1
	x := uint64(88172645463325252) & mask
	var s uint64
	for i := uint64(0); i < n; i++ {
		x ^= x >> 7; x ^= (x << 8) & mask; x ^= x >> 9; x &= mask
		s = (s + (x ^ (x >> 17))) & mask
	}
	return s
}
func benchInteger(n uint64, r int) {
	_ = integer50(n/20 + 1); t := make([]float64, r); var c uint64
	for i:=0;i<r;i++ { a:=now(); c=integer50(n); t[i]=now()-a }
	m:=med(t); emit("integer50",n,r,m,float64(n)/m/1e6,c)
}

var pat=[]byte{97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47}
func jsonEscape(in,out []byte) int {
	hex:="0123456789abcdef"; j:=0; out[j]=34; j++
	for _,c:=range in {
		switch c {
		case 34: out[j]=92;out[j+1]=34;j+=2
		case 92: out[j]=92;out[j+1]=92;j+=2
		case 8: out[j]=92;out[j+1]=98;j+=2
		case 12: out[j]=92;out[j+1]=102;j+=2
		case 10: out[j]=92;out[j+1]=110;j+=2
		case 13: out[j]=92;out[j+1]=114;j+=2
		case 9: out[j]=92;out[j+1]=116;j+=2
		default:
			if c<32 { out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=hex[c>>4];out[j+5]=hex[c&15];j+=6 } else { out[j]=c;j++ }
		}
	}
	out[j]=34; return j+1
}
func benchJSON(n uint64,r int) {
	in:=make([]byte,n);out:=make([]byte,n*6+2);for i:=range in{in[i]=pat[i%23]}
	on:=jsonEscape(in,out);t:=make([]float64,r)
	for i:=0;i<r;i++{a:=now();on=jsonEscape(in,out);t[i]=now()-a}
	c:=uint64(on);for _,x:=range out[:on]{c+=uint64(x)}
	m:=med(t);emit("json_escape",n,r,m,float64(n)/m/1e9,c)
}

func mergeSort(a,tmp []uint32) {
	n:=len(a); src,dst:=a,tmp; flip:=false
	for w:=1;w<n;w*=2 {
		for lo:=0;lo<n;lo+=2*w {
			mid:=lo+w;if mid>n{mid=n};hi:=lo+2*w;if hi>n{hi=n}
			i,j,k:=lo,mid,lo
			for i<mid&&j<hi { if src[i]<=src[j]{dst[k]=src[i];i++}else{dst[k]=src[j];j++};k++ }
			for i<mid{dst[k]=src[i];i++;k++};for j<hi{dst[k]=src[j];j++;k++}
		}
		src,dst=dst,src;flip=!flip;if w>n/2{break}
	}
	if flip{copy(a,src)}
}
func benchMerge(n uint64,r int){
	base:=make([]uint32,n);a:=make([]uint32,n);tmp:=make([]uint32,n);for i:=range base{base[i]=mix32(uint32(i))}
	t:=make([]float64,r);for x:=0;x<r;x++{copy(a,base);q:=now();mergeSort(a,tmp);t[x]=now()-q}
	m:=med(t);emit("merge_sort",n,r,m,float64(n)/m/1e6,uint64(ck32(a)))
}

func bs(a []uint32,x uint32) int32 {
	l,h:=0,len(a);for l<h{m:=l+(h-l)/2;if a[m]<x{l=m+1}else{h=m}}
	if l<len(a)&&a[l]==x{return int32(l)};return -1
}
func bsOnce(a,q []uint32) uint64 {
	var h uint64;for _,x:=range q{p:=bs(a,x);if p>=0{h+=uint64(uint32(p))+1}};return h
}
func benchBS(n uint64,r int){
	nn:=int(n);nq:=nn*4;a:=make([]uint32,nn);q:=make([]uint32,nq)
	for i:=range a{a[i]=uint32(i*2)};for i:=range q{q[i]=mix32(uint32(i))%uint32(2*nn)}
	t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=bsOnce(a,q);t[x]=now()-s}
	m:=med(t);emit("binary_search",uint64(nq),r,m,float64(nq)/m/1e6,c)
}

func prefix(in []uint32,out []uint64,passes int) uint64 {
	var c uint64;for p:=0;p<passes;p++{s:=uint64(p);for i,x:=range in{s+=uint64(x);out[i]=s};c^=s};return c
}
func benchPrefix(n uint64,r int){
	in:=make([]uint32,n);out:=make([]uint64,n);for i:=range in{in[i]=mix32(uint32(i))&1023}
	t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=prefix(in,out,16);t[x]=now()-s};c^=uint64(ck64(out))
	m:=med(t);emit("prefix_sum",n*16,r,m,float64(n)*16/m/1e6,c)
}

func matrixMul(a,b []uint32,c []uint64,n int){
	for i:=0;i<n;i++{for j:=0;j<n;j++{var s uint64;for k:=0;k<n;k++{s+=uint64(a[i*n+k])*uint64(b[k*n+j])};c[i*n+j]=s}}
}
func benchMM(n uint64,r int){
	nn:=int(n*n);a:=make([]uint32,nn);b:=make([]uint32,nn);c:=make([]uint64,nn)
	for i:=0;i<nn;i++{a[i]=mix32(uint32(i))&15;b[i]=mix32(uint32(i+nn))&15}
	t:=make([]float64,r);for x:=0;x<r;x++{s:=now();matrixMul(a,b,c,int(n));t[x]=now()-s}
	m:=med(t);emit("matrix_mul",n,r,m,float64(n*n*n)/m/1e6,uint64(ck64(c)))
}

func graph(n,d int,weights bool)([]uint32,[]uint32){
	a:=make([]uint32,n*d);var w []uint32;if weights{w=make([]uint32,n*d)}
	for i:=0;i<n;i++{for e:=0;e<d;e++{p:=i*d+e;var v int;if e==0{v=(i+1)%n}else if e==1{v=(i+n-1)%n}else{v=int(mix32(uint32(p))%uint32(n))};a[p]=uint32(v);if weights{w[p]=1+(mix32(0xabc00000+uint32(p))&15)}}}
	return a,w
}
func bfsOnce(a []uint32,n,d int,dist []int32,q []uint32) uint32 {
	for i:=range dist{dist[i]=-1};h,t:=0,0;dist[0]=0;q[t]=0;t++
	for h<t{u:=int(q[h]);h++;nd:=dist[u]+1;for e:=0;e<d;e++{v:=int(a[u*d+e]);if dist[v]<0{dist[v]=nd;q[t]=uint32(v);t++}}}
	return uint32(t)
}
func benchBFS(n uint64,r int){
	const d=4;const passes=16;a,_:=graph(int(n),d,false);dist:=make([]int32,n);q:=make([]uint32,n);t:=make([]float64,r);var seen uint32
	for x:=0;x<r;x++{s:=now();for z:=0;z<passes;z++{seen^=bfsOnce(a,int(n),d,dist,q)+uint32(z)};t[x]=now()-s}
	d32:=make([]uint32,len(dist));for i,x:=range dist{d32[i]=uint32(x)}
	c:=ck32(d32)^seen;m:=med(t);emit("bfs",n*passes,r,m,float64(n*d*passes)/m/1e6,uint64(c))
}

type hpItem struct{d uint64;v uint32}
func hpPush(h []hpItem,sz *int,x hpItem){i:=*sz;*sz++;for i>0{p:=(i-1)/2;if h[p].d<=x.d{break};h[i]=h[p];i=p};h[i]=x}
func hpPop(h []hpItem,sz *int)hpItem{o:=h[0];*sz--;x:=h[*sz];i:=0;for{l:=i*2+1;if l>=*sz{break};rr:=l+1;c:=l;if rr<*sz&&h[rr].d<h[l].d{c=rr};if h[c].d>=x.d{break};h[i]=h[c];i=c};if *sz>0{h[i]=x};return o}
func dijkstra(a,w []uint32,n,d int,dist []uint64,h []hpItem)uint32{
	const inf=^uint64(0)/4;for i:=range dist{dist[i]=inf};sz:=0;dist[0]=0;hpPush(h,&sz,hpItem{0,0})
	for sz>0{x:=hpPop(h,&sz);if x.d!=dist[x.v]{continue};for e:=0;e<d;e++{p:=int(x.v)*d+e;v:=int(a[p]);nd:=x.d+uint64(w[p]);if nd<dist[v]{dist[v]=nd;hpPush(h,&sz,hpItem{nd,uint32(v)})}}}
	return ck64(dist)
}
func benchDij(n uint64,r int){
	const d=4;a,w:=graph(int(n),d,true);dist:=make([]uint64,n);h:=make([]hpItem,int(n)*d*4);t:=make([]float64,r);var c uint32
	for x:=0;x<r;x++{s:=now();c=dijkstra(a,w,int(n),d,dist,h);t[x]=now()-s}
	m:=med(t);emit("dijkstra",n,r,m,float64(n*d)/m/1e6,uint64(c))
}

func ufFind(p []uint32,x uint32)uint32{for p[x]!=x{p[x]=p[p[x]];x=p[x]};return x}
func ufRun(p []uint32,rank []byte,A,B []uint32){
	for i:=range p{p[i]=uint32(i);rank[i]=0}
	for i:=range A{ra,rb:=ufFind(p,A[i]),ufFind(p,B[i]);if ra!=rb{if rank[ra]<rank[rb]{ra,rb=rb,ra};p[rb]=ra;if rank[ra]==rank[rb]{rank[ra]++}}}
}
func benchUF(n uint64,r int){
	nn:=int(n);ops:=nn*4;p:=make([]uint32,nn);rank:=make([]byte,nn);A:=make([]uint32,ops);B:=make([]uint32,ops)
	for i:=0;i<ops;i++{A[i]=mix32(uint32(i))%uint32(nn);B[i]=mix32(uint32(i+ops))%uint32(nn)}
	t:=make([]float64,r);for x:=0;x<r;x++{s:=now();ufRun(p,rank,A,B);t[x]=now()-s}
	for i:=range p{p[i]=ufFind(p,uint32(i))}
	m:=med(t);emit("union_find",uint64(ops),r,m,float64(ops)/m/1e6,uint64(ck32(p)))
}

func mandel(w,mi int)uint64{var sum uint64;for y:=0;y<w;y++{ci:=-1.5+3*float64(y)/float64(w-1);for x:=0;x<w;x++{cr:=-2+3*float64(x)/float64(w-1);zr,zi:=0.0,0.0;it:=0;for it<mi{a,b:=zr*zr,zi*zi;if a+b>4{break};nz:=a-b+cr;zi=2*zr*zi+ci;zr=nz;it++};sum+=uint64(it)}};return sum}
func benchMandel(w uint64,r int){ww:=int(w);if ww>128{ww=128};_=mandel(ww,20);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=mandel(int(w),50);t[x]=now()-s};m:=med(t);emit("mandelbrot",w*w,r,m,float64(w*w)/m/1e6,c)}

func vecOnce(in []uint32)uint32{
	v:=make([]uint32,0);for _,x:=range in{v=append(v,x)}
	h:=uint32(2166136261);for i:=range v{v[i]^=uint32(i);h=(h^v[i])*16777619}
	for len(v)>0{x:=v[len(v)-1];v=v[:len(v)-1];h=(h^(x+uint32(len(v))))*16777619};return h
}
func benchVA(n uint64,r int){
	in:=make([]uint32,n);for i:=range in{in[i]=mix32(uint32(i))};t:=make([]float64,r);var c uint32
	for x:=0;x<r;x++{s:=now();c=vecOnce(in);t[x]=now()-s}
	m:=med(t);emit("dynamic_array",n,r,m,float64(n)/m/1e6,uint64(c))
}

func listOnce(next,val,base []uint32,passes int)uint32{
	copy(val,base);n:=len(base);for i:=0;i<n;i++{if i+1<n{next[i]=uint32(i+1)}else{next[i]=^uint32(0)}}
	const B=64;for b:=0;b<n;b+=B{hi:=b+B;if hi>n{hi=n};hi--;for i:=b;i<=hi;i++{if i==b{if hi+1<n{next[i]=uint32(hi+1)}else{next[i]=^uint32(0)}}else{next[i]=uint32(i-1)}}}
	h:=uint32(2166136261);for p:=0;p<passes;p++{cur:=uint32(B-1);if B>=n{cur=uint32(n-1)};seen:=0;for cur!=^uint32(0)&&seen<n{u:=int(cur);val[u]^=uint32(seen+p);h=(h^(val[u]+cur+uint32(p)))*16777619;cur=next[u];seen++};h=(h^uint32(seen))*16777619};return h
}
func benchLL(n uint64,r int){
	next:=make([]uint32,n);val:=make([]uint32,n);base:=make([]uint32,n);for i:=range base{base[i]=mix32(uint32(i))}
	t:=make([]float64,r);var c uint32;for x:=0;x<r;x++{s:=now();c=listOnce(next,val,base,16);t[x]=now()-s}
	m:=med(t);emit("linked_list",n*16,r,m,float64(n)*16/m/1e6,uint64(c))
}

func queueOnce(b,in []uint32)uint32{
	cap:=len(b);h,t,cnt:=0,0,0;var z uint32
	for i,x:=range in{if i&3!=3{if cnt==cap{z^=b[h];h=(h+1)%cap;cnt--};b[t]=x;t=(t+1)%cap;cnt++}else if cnt>0{z^=b[h];h=(h+1)%cap;cnt--}}
	for cnt>0{z^=b[h];h=(h+1)%cap;cnt--};return z
}
func benchQR(ops uint64,r int){
	b:=make([]uint32,ops/2+1024);in:=make([]uint32,ops);for i:=range in{in[i]=mix32(uint32(i))}
	t:=make([]float64,r);var c uint32;for x:=0;x<r;x++{s:=now();c=queueOnce(b,in);t[x]=now()-s}
	m:=med(t);emit("queue_ring",ops,r,m,float64(ops)/m/1e6,uint64(c))
}

func np2(x int)int{p:=1;for p<x{p<<=1};return p}
func hashOnce(k,v,ik,iv []uint32)uint32{
	for i:=range k{k[i]=0};mask:=len(k)-1;var h uint32
	for i,key:=range ik{val:=iv[i];p:=int(hash32(key))&mask;for k[p]!=0&&k[p]!=key{p=(p+1)&mask};k[p]=key;v[p]=val}
	for i,key:=range ik{p:=int(hash32(key))&mask;for k[p]!=key{p=(p+1)&mask};v[p]^=uint32(i);h^=v[p]};return h
}
func benchHT(n uint64,r int){
	nn:=int(n);cap:=np2(nn*2);k:=make([]uint32,cap);v:=make([]uint32,cap);ik:=make([]uint32,nn);iv:=make([]uint32,nn)
	for i:=0;i<nn;i++{ik[i]=mix32(uint32(i))|1;iv[i]=mix32(uint32(i)+0x55555555)}
	t:=make([]float64,r);var c uint32;for x:=0;x<r;x++{s:=now();c=hashOnce(k,v,ik,iv);t[x]=now()-s}
	m:=med(t);emit("hash_table",n,r,m,float64(n)*2/m/1e6,uint64(c))
}

func heapPush(h []uint32,sz *int,x uint32){i:=*sz;*sz++;for i>0{p:=(i-1)/2;if h[p]<=x{break};h[i]=h[p];i=p};h[i]=x}
func heapPop(h []uint32,sz *int)uint32{o:=h[0];*sz--;x:=h[*sz];i:=0;for{l:=i*2+1;if l>=*sz{break};rr:=l+1;c:=l;if rr<*sz&&h[rr]<h[l]{c=rr};if h[c]>=x{break};h[i]=h[c];i=c};if *sz>0{h[i]=x};return o}
func heapOnce(h,in []uint32)uint32{sz:=0;for _,x:=range in{heapPush(h,&sz,x)};var c uint32;for i:=range in{c^=heapPop(h,&sz)+uint32(i)};return c}
func benchBH(n uint64,r int){
	h:=make([]uint32,n);in:=make([]uint32,n);for i:=range in{in[i]=mix32(uint32(i))}
	t:=make([]float64,r);var c uint32;for x:=0;x<r;x++{s:=now();c=heapOnce(h,in);t[x]=now()-s}
	m:=med(t);emit("binary_heap",n,r,m,float64(n)*2/m/1e6,uint64(c))
}

func bstOnce(k []uint32,l,rr []int32,in []uint32)uint32{
	root:=int32(-1);for i,key:=range in{k[i]=key;l[i]=-1;rr[i]=-1;node:=int32(i);if root<0{root=node;continue};cur:=root;for{u:=int(cur);if key<k[u]{if l[u]<0{l[u]=node;break};cur=l[u]}else{if rr[u]<0{rr[u]=node;break};cur=rr[u]}}}
	var h uint32;for i:=0;i<len(in);i+=3{key:=in[i];cur:=root;for cur>=0&&k[cur]!=key{u:=int(cur);if key<k[u]{cur=l[u]}else{cur=rr[u]}};if cur>=0{h^=uint32(cur)+1}};return h
}
func benchBST(n uint64,r int){
	k:=make([]uint32,n);l:=make([]int32,n);rr:=make([]int32,n);in:=make([]uint32,n);for i:=range in{in[i]=mix32(uint32(i))}
	t:=make([]float64,r);var c uint32;for x:=0;x<r;x++{s:=now();c=bstOnce(k,l,rr,in);t[x]=now()-s}
	m:=med(t);emit("bst",n,r,m,float64(n)/m/1e6,uint64(c))
}

func trieOnce(ch []int32,term []byte,words []uint32,passes int)uint32{
	for i:=range ch{ch[i]=-1};for i:=range term{term[i]=0};used:=1
	for _,w:=range words{node:=int32(0);for sh:=28;sh>=0;sh-=4{c:=int((w>>sh)&15);p:=int(node)*16+c;if ch[p]<0{ch[p]=int32(used);used++};node=ch[p]};term[node]=1}
	h:=uint32(used);for p:=0;p<passes;p++{for i:=0;i<len(words);i+=2{w:=words[i];node:=int32(0);for sh:=28;sh>=0&&node>=0;sh-=4{node=ch[int(node)*16+int((w>>sh)&15)]};if node>=0&&term[node]!=0{h^=uint32(node)+1+uint32(p)}}};return h
}
func benchTrie(n uint64,r int){
	nn:=int(n);mx:=1+nn*8;ch:=make([]int32,mx*16);term:=make([]byte,mx);words:=make([]uint32,nn);for i:=range words{words[i]=mix32(uint32(i))}
	t:=make([]float64,r);var c uint32;for x:=0;x<r;x++{s:=now();c=trieOnce(ch,term,words,32);t[x]=now()-s}
	m:=med(t);emit("trie",n*32,r,m,float64(n)*32/m/1e6,uint64(c))
}

func size(k string)uint64{
	switch k{
	case"integer50":return 200000000
	case"json_escape":return 16000000
	case"merge_sort","binary_search","union_find","hash_table","binary_heap":return 1000000
	case"prefix_sum":return 8000000
	case"matrix_mul":return 320
	case"bfs":return 200000
	case"dijkstra","trie":return 100000
	case"mandelbrot":return 1600
	case"dynamic_array":return 5000000
	case"linked_list":return 4000000
	case"queue_ring":return 10000000
	case"bst":return 300000
	};return 0
}
func main(){
	k:="integer50";if len(os.Args)>1{k=os.Args[1]};n:=size(k);if len(os.Args)>2{n,_=strconv.ParseUint(os.Args[2],10,64)};r:=7;if len(os.Args)>3{r,_=strconv.Atoi(os.Args[3])}
	switch k{
	case"integer50":benchInteger(n,r);case"json_escape":benchJSON(n,r);case"merge_sort":benchMerge(n,r);case"binary_search":benchBS(n,r);case"prefix_sum":benchPrefix(n,r);case"matrix_mul":benchMM(n,r);case"bfs":benchBFS(n,r);case"dijkstra":benchDij(n,r);case"union_find":benchUF(n,r);case"mandelbrot":benchMandel(n,r);case"dynamic_array":benchVA(n,r);case"linked_list":benchLL(n,r);case"queue_ring":benchQR(n,r);case"hash_table":benchHT(n,r);case"binary_heap":benchBH(n,r);case"bst":benchBST(n,r);case"trie":benchTrie(n,r);default:panic("unknown kernel")}
}
