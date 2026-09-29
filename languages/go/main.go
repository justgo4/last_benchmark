package main
import("fmt";"os";"sort";"strconv";"time")
func now()float64{return float64(time.Now().UnixNano())*1e-9}
func med(v[]float64)float64{sort.Float64s(v);return v[len(v)/2]}
func emit(k string,u uint64,r int,s,rate float64,c uint64){fmt.Printf("RESULT kernel=%s units=%d rounds=%d seconds=%.9f rate=%.6f checksum=%d\n",k,u,r,s,rate,c)}
func mix64(x uint64)uint64{x+=0x9e3779b97f4a7c15;x=(x^(x>>30))*0xbf58476d1ce4e5b9;x=(x^(x>>27))*0x94d049bb133111eb;return x^(x>>31)}
func c32(a[]uint32)uint64{h:=uint64(1469598103934665603);for i,x:=range a{h^=uint64(x)+uint64(i)*0x9e3779b1;h*=1099511628211};return h}
func c64(a[]uint64)uint64{h:=uint64(1469598103934665603);for i,x:=range a{h^=x+uint64(i)*0x9e3779b97f4a7c15;h*=1099511628211};return h}
func timed(r int,f func()uint64)(float64,uint64){t:=make([]float64,r);var c uint64;for i:=0;i<r;i++{a:=now();c=f();t[i]=now()-a};return med(t),c}

func integer50(n uint64)uint64{const mask uint64=(1<<50)-1;x:=uint64(88172645463325252)&mask;var s uint64;for i:=uint64(0);i<n;i++{x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;s=(s+(x^(x>>17)))&mask};return s}
func benchInteger(n uint64,r int){_=integer50(n/20+1);m,c:=timed(r,func()uint64{return integer50(n)});emit("integer50",n,r,m,float64(n)/m/1e6,c)}

var pat=[]byte{97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47}
func jsonEscape(in,out[]byte)int{hex:="0123456789abcdef";j:=0;out[j]=34;j++;for _,c:=range in{switch c{case 34:out[j]=92;out[j+1]=34;j+=2;case 92:out[j]=92;out[j+1]=92;j+=2;case 8:out[j]=92;out[j+1]=98;j+=2;case 12:out[j]=92;out[j+1]=102;j+=2;case 10:out[j]=92;out[j+1]=110;j+=2;case 13:out[j]=92;out[j+1]=114;j+=2;case 9:out[j]=92;out[j+1]=116;j+=2;default:if c<32{out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=hex[c>>4];out[j+5]=hex[c&15];j+=6}else{out[j]=c;j++}}};out[j]=34;return j+1}
func benchJSON(n uint64,r int){in:=make([]byte,n);out:=make([]byte,n*6+2);for i:=range in{in[i]=pat[i%23]};on:=jsonEscape(in,out);t:=make([]float64,r);for i:=0;i<r;i++{a:=now();on=jsonEscape(in,out);t[i]=now()-a};c:=uint64(on);for _,x:=range out[:on]{c+=uint64(x)};m:=med(t);emit("json_escape",n,r,m,float64(n)/m/1e9,c)}

func mergeSort(a,tmp[]uint32){n:=len(a);src:=a;dst:=tmp;srcA:=true;for w:=1;w<n;w*=2{for lo:=0;lo<n;lo+=2*w{mid:=lo+w;if mid>n{mid=n};hi:=lo+2*w;if hi>n{hi=n};i,j,k:=lo,mid,lo;for i<mid&&j<hi{if src[i]<=src[j]{dst[k]=src[i];i++}else{dst[k]=src[j];j++};k++};for i<mid{dst[k]=src[i];i++;k++};for j<hi{dst[k]=src[j];j++;k++}};src,dst=dst,src;srcA=!srcA;if w>n/2{break}};if !srcA{copy(a,src)}}
func benchMerge(n uint64,r int){base:=make([]uint32,n);for i:=range base{base[i]=uint32(mix64(uint64(i)))};work:=make([]uint32,n);tmp:=make([]uint32,n);copy(work,base);mergeSort(work,tmp);t:=make([]float64,r);for x:=0;x<r;x++{copy(work,base);a:=now();mergeSort(work,tmp);t[x]=now()-a};m:=med(t);emit("merge_sort",n,r,m,float64(n)/m/1e6,c32(work))}

func bs(a[]uint32,x uint32)int64{lo,hi:=0,len(a);for lo<hi{m:=lo+(hi-lo)/2;if a[m]<x{lo=m+1}else{hi=m}};if lo<len(a)&&a[lo]==x{return int64(lo)};return -1}
func bsOnce(a[]uint32,q uint64)uint64{var h uint64;for i:=uint64(0);i<q;i++{p:=bs(a,uint32(mix64(i)%uint64(2*len(a))));if p>=0{h+=uint64(p)+1}};return h}
func benchBS(n uint64,r int){a:=make([]uint32,n);for i:=range a{a[i]=uint32(i*2)};q:=n*4;_=bsOnce(a,q/20+1);m,c:=timed(r,func()uint64{return bsOnce(a,q)});emit("binary_search",q,r,m,float64(q)/m/1e6,c)}

func prefixOnce(in[]uint32,out[]uint64,passes int)uint64{var c uint64;for p:=0;p<passes;p++{s:=uint64(p);for i,x:=range in{s+=uint64(x);out[i]=s};c^=s};return c}
func benchPrefix(n uint64,r int){in:=make([]uint32,n);for i:=range in{in[i]=uint32(mix64(uint64(i))&1023)};out:=make([]uint64,n);_=prefixOnce(in,out,1);t:=make([]float64,r);var c uint64;for i:=0;i<r;i++{a:=now();c=prefixOnce(in,out,16);t[i]=now()-a};c^=c64(out);m:=med(t);emit("prefix_sum",n*16,r,m,float64(n)*16/m/1e6,c)}

func mm(a,b[]uint32,c[]uint64,n int){for i:=0;i<n;i++{for j:=0;j<n;j++{var s uint64;for k:=0;k<n;k++{s+=uint64(a[i*n+k])*uint64(b[k*n+j])};c[i*n+j]=s}}}
func benchMM(n uint64,r int){nn:=int(n*n);a:=make([]uint32,nn);b:=make([]uint32,nn);c:=make([]uint64,nn);for i:=0;i<nn;i++{a[i]=uint32(mix64(uint64(i))&15);b[i]=uint32(mix64(uint64(i+nn))&15)};mm(a,b,c,int(n));t:=make([]float64,r);for x:=0;x<r;x++{q:=now();mm(a,b,c,int(n));t[x]=now()-q};m:=med(t);emit("matrix_mul",n,r,m,float64(n*n*n)/m/1e6,c64(c))}

func graph(n,d int,weights bool)([]uint32,[]uint32){a:=make([]uint32,n*d);var w[]uint32;if weights{w=make([]uint32,n*d)};for i:=0;i<n;i++{for e:=0;e<d;e++{p:=i*d+e;var v int;if e==0{v=(i+1)%n}else if e==1{v=(i+n-1)%n}else{v=int(mix64(uint64(p))%uint64(n))};a[p]=uint32(v);if weights{w[p]=uint32(1+(mix64(0xabc00000+uint64(p))&15))}}};return a,w}
func bfsOnce(a[]uint32,n,d int,dist[]int32,q[]uint32)uint64{for i:=range dist{dist[i]=-1};h,t:=0,0;dist[0]=0;q[t]=0;t++;for h<t{u:=int(q[h]);h++;nd:=dist[u]+1;for e:=0;e<d;e++{v:=int(a[u*d+e]);if dist[v]<0{dist[v]=nd;q[t]=uint32(v);t++}}};var c uint64;for i,x:=range dist{c+=uint64(x+1)*uint64(i+1)};return c}
func bfsMany(a[]uint32,n,d int,dist[]int32,q[]uint32,p int)uint64{var h uint64;for x:=0;x<p;x++{h+=bfsOnce(a,n,d,dist,q)^(uint64(x)*0x9e3779b97f4a7c15)};return h}
func benchBFS(n uint64,r int){const d=4;a,_:=graph(int(n),d,false);dist:=make([]int32,n);q:=make([]uint32,n);_=bfsMany(a,int(n),d,dist,q,1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=bfsMany(a,int(n),d,dist,q,16);t[x]=now()-s};m:=med(t);emit("bfs",n*16,r,m,float64(n*d*16)/m/1e6,c)}

type HP struct{d uint64;v uint32}
func hpPush(h[]HP,sz *int,x HP){i:=*sz;*sz++;for i>0{p:=(i-1)/2;if h[p].d<=x.d{break};h[i]=h[p];i=p};h[i]=x}
func hpPop(h[]HP,sz *int)HP{o:=h[0];*sz--;x:=h[*sz];i:=0;for{l:=i*2+1;if l>=*sz{break};rr:=l+1;c:=l;if rr<*sz&&h[rr].d<h[l].d{c=rr};if h[c].d>=x.d{break};h[i]=h[c];i=c};if *sz>0{h[i]=x};return o}
func dijOnce(a,w[]uint32,n,d int,dist[]uint64,h[]HP)uint64{const inf=^uint64(0)/4;for i:=range dist{dist[i]=inf};sz:=0;dist[0]=0;hpPush(h,&sz,HP{0,0});for sz>0{x:=hpPop(h,&sz);if x.d!=dist[x.v]{continue};for e:=0;e<d;e++{p:=int(x.v)*d+e;v:=int(a[p]);nd:=x.d+uint64(w[p]);if nd<dist[v]{dist[v]=nd;hpPush(h,&sz,HP{nd,uint32(v)})}}};var c uint64;for i,x:=range dist{c^=x+uint64(i)*0x9e3779b97f4a7c15};return c}
func benchDij(n uint64,r int){const d=4;a,w:=graph(int(n),d,true);dist:=make([]uint64,n);h:=make([]HP,int(n)*d*4);_=dijOnce(a,w,int(n),d,dist,h);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=dijOnce(a,w,int(n),d,dist,h);t[x]=now()-s};m:=med(t);emit("dijkstra",n,r,m,float64(n*d)/m/1e6,c)}

func ufFind(p[]uint32,x uint32)uint32{for p[x]!=x{p[x]=p[p[x]];x=p[x]};return x}
func ufOnce(p[]uint32,rank[]byte,n int,ops uint64)uint64{for i:=0;i<n;i++{p[i]=uint32(i);rank[i]=0};for i:=uint64(0);i<ops;i++{a:=uint32(mix64(i)%uint64(n));b:=uint32(mix64(i+ops)%uint64(n));ra,rb:=ufFind(p,a),ufFind(p,b);if ra!=rb{if rank[ra]<rank[rb]{ra,rb=rb,ra};p[rb]=ra;if rank[ra]==rank[rb]{rank[ra]++}}};var h uint64;for i:=0;i<n;i+=17{h+=uint64(ufFind(p,uint32(i)))};return h}
func benchUF(n uint64,r int){ops:=n*4;p:=make([]uint32,n);rank:=make([]byte,n);_=ufOnce(p,rank,int(n),ops/20+1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=ufOnce(p,rank,int(n),ops);t[x]=now()-s};m:=med(t);emit("union_find",ops,r,m,float64(ops)/m/1e6,c)}

func mandel(w,mi int)uint64{var sum uint64;for y:=0;y<w;y++{ci:=-1.5+3*float64(y)/float64(w-1);for x:=0;x<w;x++{cr:=-2+3*float64(x)/float64(w-1);zr,zi:=0.0,0.0;it:=0;for it<mi{a,b:=zr*zr,zi*zi;if a+b>4{break};nz:=a-b+cr;zi=2*zr*zi+ci;zr=nz;it++};sum+=uint64(it)}};return sum}
func benchMandel(w uint64,r int){ww:=int(w);if ww>128{ww=128};_=mandel(ww,20);m,c:=timed(r,func()uint64{return mandel(int(w),50)});emit("mandelbrot",w*w,r,m,float64(w*w)/m/1e6,c)}

func vaOnce(n int)uint64{v:=make([]uint64,0);for i:=0;i<n;i++{v=append(v,mix64(uint64(i)))};var h uint64;for i:=0;i<n;i++{v[i]^=uint64(i);h+=v[i]};for len(v)>0{h^=v[len(v)-1];v=v[:len(v)-1]};return h}
func benchVA(n uint64,r int){_=vaOnce(int(n)/20+1);m,c:=timed(r,func()uint64{return vaOnce(int(n))});emit("dynamic_array",n,r,m,float64(n)/m/1e6,c)}

func llOnce(next[]uint32,val[]uint64,n,passes int)uint64{for i:=0;i<n;i++{if i+1<n{next[i]=uint32(i+1)}else{next[i]=^uint32(0)};val[i]=mix64(uint64(i))};const B=64;for base:=0;base<n;base+=B{hi:=base+B;if hi>n{hi=n};hi--;for i:=base;i<=hi;i++{if i==base{if hi+1<n{next[i]=uint32(hi+1)}else{next[i]=^uint32(0)}}else{next[i]=uint32(i-1)}}};var h uint64;for p:=0;p<passes;p++{cur:=uint32(B-1);seen:=0;for cur!=^uint32(0)&&seen<n{u:=int(cur);val[u]^=uint64(seen+p);h+=val[u];cur=next[u];seen++};h^=uint64(seen)};return h}
func benchLL(n uint64,r int){next:=make([]uint32,n);val:=make([]uint64,n);_=llOnce(next,val,int(n),1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=llOnce(next,val,int(n),16);t[x]=now()-s};m:=med(t);emit("linked_list",n*16,r,m,float64(n)*16/m/1e6,c)}

func qrOnce(b[]uint64,ops uint64)uint64{cap:=len(b);h,t,cnt:=0,0,0;var z uint64;for i:=uint64(0);i<ops;i++{if i&3!=3{if cnt==cap{z^=b[h];h=(h+1)%cap;cnt--};b[t]=mix64(i);t=(t+1)%cap;cnt++}else if cnt>0{x:=b[h];h=(h+1)%cap;cnt--;z+=x}};for cnt>0{z^=b[h];h=(h+1)%cap;cnt--};return z}
func benchQR(ops uint64,r int){b:=make([]uint64,ops/2+1024);_=qrOnce(b,ops/20+1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=qrOnce(b,ops);t[x]=now()-s};m:=med(t);emit("queue_ring",ops,r,m,float64(ops)/m/1e6,c)}

func np2(x int)int{p:=1;for p<x{p<<=1};return p}
func htOnce(k,v[]uint64,n int)uint64{for i:=range k{k[i]=0};mask:=len(k)-1;var h uint64;for i:=0;i<n;i++{key:=mix64(uint64(i))|1;val:=mix64(uint64(i)+0x55555555);p:=int(mix64(key))&mask;for k[p]!=0&&k[p]!=key{p=(p+1)&mask};k[p]=key;v[p]=val};for i:=0;i<n;i++{key:=mix64(uint64(i))|1;p:=int(mix64(key))&mask;for k[p]!=key{p=(p+1)&mask};v[p]^=uint64(i);h+=v[p]};return h}
func benchHT(n uint64,r int){cap:=np2(int(n)*2);k:=make([]uint64,cap);v:=make([]uint64,cap);_=htOnce(k,v,int(n)/20+1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=htOnce(k,v,int(n));t[x]=now()-s};m:=med(t);emit("hash_table",n,r,m,float64(n)*2/m/1e6,c)}

func bhPush(h[]uint64,sz *int,x uint64){i:=*sz;*sz++;for i>0{p:=(i-1)/2;if h[p]<=x{break};h[i]=h[p];i=p};h[i]=x}
func bhPop(h[]uint64,sz *int)uint64{o:=h[0];*sz--;x:=h[*sz];i:=0;for{l:=i*2+1;if l>=*sz{break};rr:=l+1;c:=l;if rr<*sz&&h[rr]<h[l]{c=rr};if h[c]>=x{break};h[i]=h[c];i=c};if *sz>0{h[i]=x};return o}
func bhOnce(h[]uint64,n int)uint64{sz:=0;for i:=0;i<n;i++{bhPush(h,&sz,mix64(uint64(i)))};var c uint64;for i:=0;i<n;i++{c^=bhPop(h,&sz)+uint64(i)};return c}
func benchBH(n uint64,r int){h:=make([]uint64,n);_=bhOnce(h,int(n)/20+1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=bhOnce(h,int(n));t[x]=now()-s};m:=med(t);emit("binary_heap",n,r,m,float64(n)*2/m/1e6,c)}

func bstOnce(k[]uint64,l,rr[]int32,n int)uint64{root:=int32(-1);for i:=0;i<n;i++{key:=mix64(uint64(i));k[i]=key;l[i]=-1;rr[i]=-1;node:=int32(i);if root<0{root=node;continue};cur:=root;for{u:=int(cur);if key<k[u]{if l[u]<0{l[u]=node;break};cur=l[u]}else{if rr[u]<0{rr[u]=node;break};cur=rr[u]}}};var h uint64;for i:=0;i<n;i+=3{key:=mix64(uint64(i));cur:=root;for cur>=0&&k[cur]!=key{u:=int(cur);if key<k[u]{cur=l[u]}else{cur=rr[u]}};if cur>=0{h+=uint64(cur)+1}};return h}
func benchBST(n uint64,r int){k:=make([]uint64,n);l:=make([]int32,n);rr:=make([]int32,n);_=bstOnce(k,l,rr,int(n)/20+1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=bstOnce(k,l,rr,int(n));t[x]=now()-s};m:=med(t);emit("bst",n,r,m,float64(n)/m/1e6,c)}

func trieOnce(ch[]int32,term[]byte,words,passes int)uint64{for i:=range ch{ch[i]=-1};for i:=range term{term[i]=0};used:=1;for i:=0;i<words;i++{w:=uint32(mix64(uint64(i)));node:=0;for sh:=28;sh>=0;sh-=4{c:=int((w>>sh)&15);p:=node*16+c;if ch[p]<0{ch[p]=int32(used);used++};node=int(ch[p])};term[node]=1};h:=uint64(used);for p:=0;p<passes;p++{for i:=0;i<words;i+=2{w:=uint32(mix64(uint64(i)));node:=int32(0);for sh:=28;sh>=0&&node>=0;sh-=4{node=ch[int(node)*16+int((w>>sh)&15)]};if node>=0&&term[node]!=0{h+=uint64(node)+1+uint64(p)}}};return h}
func benchTrie(n uint64,r int){mx:=1+int(n)*8;ch:=make([]int32,mx*16);term:=make([]byte,mx);_=trieOnce(ch,term,int(n)/20+1,1);t:=make([]float64,r);var c uint64;for x:=0;x<r;x++{s:=now();c=trieOnce(ch,term,int(n),32);t[x]=now()-s};m:=med(t);emit("trie",n*32,r,m,float64(n)*32/m/1e6,c)}

func size(k string)uint64{switch k{case"integer50":return 200000000;case"json_escape":return 16000000;case"merge_sort","binary_search","union_find","hash_table","binary_heap":return 1000000;case"prefix_sum":return 8000000;case"matrix_mul":return 320;case"bfs":return 200000;case"dijkstra","trie":return 100000;case"mandelbrot":return 1600;case"dynamic_array":return 5000000;case"linked_list":return 4000000;case"queue_ring":return 10000000;case"bst":return 300000};return 0}
func main(){k:="integer50";if len(os.Args)>1{k=os.Args[1]};n:=size(k);if len(os.Args)>2{n,_=strconv.ParseUint(os.Args[2],10,64)};r:=7;if len(os.Args)>3{r,_=strconv.Atoi(os.Args[3])};switch k{case"integer50":benchInteger(n,r);case"json_escape":benchJSON(n,r);case"merge_sort":benchMerge(n,r);case"binary_search":benchBS(n,r);case"prefix_sum":benchPrefix(n,r);case"matrix_mul":benchMM(n,r);case"bfs":benchBFS(n,r);case"dijkstra":benchDij(n,r);case"union_find":benchUF(n,r);case"mandelbrot":benchMandel(n,r);case"dynamic_array":benchVA(n,r);case"linked_list":benchLL(n,r);case"queue_ring":benchQR(n,r);case"hash_table":benchHT(n,r);case"binary_heap":benchBH(n,r);case"bst":benchBST(n,r);case"trie":benchTrie(n,r);default:panic("unknown kernel")}}
