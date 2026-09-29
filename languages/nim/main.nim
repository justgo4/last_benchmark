import std/[os, strutils, times, algorithm, strformat]

proc now(): float64 = epochTime()
proc med(a: var seq[float64]): float64 = a.sort(); a[a.len div 2]
proc emit(k:string,u:uint64,r:int,s,rate:float64,c:uint64)=
  echo &"RESULT kernel={k} units={u} rounds={r} seconds={s:.9f} rate={rate:.6f} checksum={c}"

proc mix32(x0:uint32):uint32 =
  var x=x0 +% 0x9e3779b9'u32
  x=x xor (x shr 16);x=x *% 0x85ebca6b'u32
  x=x xor (x shr 13);x=x *% 0xc2b2ae35'u32
  x xor (x shr 16)
proc hash32(x0:uint32):uint32 =
  var x=x0
  x=x xor (x shr 16);x=x *% 0x7feb352d'u32
  x=x xor (x shr 15);x=x *% 0x846ca68b'u32
  x xor (x shr 16)
proc ck32(a:openArray[uint32]):uint32 =
  var h=2166136261'u32
  for x in a:h=(h xor x) *% 16777619'u32
  h
proc ck64(a:openArray[uint64]):uint32 =
  var h=2166136261'u32
  for x in a:
    h=(h xor uint32(x)) *% 16777619'u32
    h=(h xor uint32(x shr 32)) *% 16777619'u32
  h

proc integer50(n:uint64):uint64 =
  let mask=(1'u64 shl 50)-1
  var x=88172645463325252'u64 and mask
  var s=0'u64
  var i=0'u64
  while i<n:
    x=x xor (x shr 7);x=x xor ((x shl 8) and mask);x=x xor (x shr 9);x=x and mask
    s=(s +% (x xor (x shr 17))) and mask
    inc i
  s
proc benchInteger(n:uint64,r:int)=
  discard integer50(n div 20+1)
  var t=newSeq[float64](r)
  var c=0'u64
  for i in 0..<r:
    let a=now()
    c=integer50(n)
    t[i]=now()-a
  let m=med(t);emit("integer50",n,r,m,float64(n)/m/1e6,c)

const pat=[97'u8,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]
proc jsonEscape(inp:seq[uint8],outp:var seq[uint8]):int =
  const hx="0123456789abcdef"
  var j=0;outp[j]=34;inc j
  for c in inp:
    case c
    of 34'u8:outp[j]=92;outp[j+1]=34;j+=2
    of 92'u8:outp[j]=92;outp[j+1]=92;j+=2
    of 8'u8:outp[j]=92;outp[j+1]=98;j+=2
    of 12'u8:outp[j]=92;outp[j+1]=102;j+=2
    of 10'u8:outp[j]=92;outp[j+1]=110;j+=2
    of 13'u8:outp[j]=92;outp[j+1]=114;j+=2
    of 9'u8:outp[j]=92;outp[j+1]=116;j+=2
    else:
      if c<32:
        outp[j]=92;outp[j+1]=117;outp[j+2]=48;outp[j+3]=48
        outp[j+4]=uint8(hx[int(c shr 4)].ord);outp[j+5]=uint8(hx[int(c and 15)].ord);j+=6
      else: outp[j]=c;inc j
  outp[j]=34;j+1
proc benchJson(n0:uint64,r:int)=
  let n=int(n0)
  var inp=newSeq[uint8](n)
  var outp=newSeq[uint8](n*6+2)
  for i in 0..<n:inp[i]=pat[i mod pat.len]
  var on=jsonEscape(inp,outp)
  var t=newSeq[float64](r)
  for x in 0..<r:
    let a=now()
    on=jsonEscape(inp,outp)
    t[x]=now()-a
  var c=uint64(on)
  for i in 0..<on:c+=uint64(outp[i])
  let m=med(t);emit("json_escape",n0,r,m,float64(n0)/m/1e9,c)

proc mergeSort(a:var seq[uint32],tmp:var seq[uint32]) =
  let n=a.len
  var src=newSeq[uint32](n);src=a
  var dst=tmp
  var w=1
  while w<n:
    var lo=0
    while lo<n:
      let mid=min(lo+w,n)
      let hi=min(lo+2*w,n)
      var i=lo
      var j=mid
      var k=lo
      while i<mid and j<hi:
        if src[i]<=src[j]:dst[k]=src[i];inc i else: dst[k]=src[j];inc j
        inc k
      while i<mid:dst[k]=src[i];inc i;inc k
      while j<hi:dst[k]=src[j];inc j;inc k
      lo+=2*w
    swap(src,dst)
    if w>n div 2:break
    w*=2
  a=src
proc benchMerge(n0:uint64,r:int)=
  let n=int(n0)
  var base=newSeq[uint32](n)
  var a=newSeq[uint32](n)
  var tmp=newSeq[uint32](n)
  for i in 0..<n:base[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  for x in 0..<r:
    a=base
    let q=now();mergeSort(a,tmp);t[x]=now()-q
  let m=med(t);emit("merge_sort",n0,r,m,float64(n0)/m/1e6,uint64(ck32(a)))

proc bs(a:seq[uint32],x:uint32):int =
  var l=0
  var h=a.len
  while l<h:
    let m=l+(h-l) div 2
    if a[m]<x:l=m+1 else: h=m
  if l<a.len and a[l]==x:l else: -1
proc benchBS(n0:uint64,r:int)=
  let n=int(n0)
  let nq=n*4
  var a=newSeq[uint32](n)
  var q=newSeq[uint32](nq)
  for i in 0..<n:a[i]=uint32(i*2)
  for i in 0..<nq:q[i]=mix32(uint32(i)) mod uint32(2*n)
  var t=newSeq[float64](r)
  var c=0'u64
  for z in 0..<r:
    let st=now();c=0
    for x in q:
      let p=bs(a,x);if p>=0:c+=uint64(p+1)
    t[z]=now()-st
  let m=med(t);emit("binary_search",uint64(nq),r,m,float64(nq)/m/1e6,c)

proc benchPrefix(n0:uint64,r:int)=
  let n=int(n0)
  var inp=newSeq[uint32](n)
  var outp=newSeq[uint64](n)
  for i in 0..<n:inp[i]=mix32(uint32(i)) and 1023
  var t=newSeq[float64](r)
  var c=0'u64
  for z in 0..<r:
    let st=now();c=0
    for p in 0..<16:
      var s=uint64(p)
      for i in 0..<n:s+=uint64(inp[i]);outp[i]=s
      c=c xor s
    t[z]=now()-st
  c=c xor uint64(ck64(outp))
  let m=med(t);emit("prefix_sum",n0*16,r,m,float64(n0)*16/m/1e6,c)

proc benchMM(n0:uint64,r:int)=
  let n=int(n0)
  let nn=n*n
  var a=newSeq[uint32](nn)
  var b=newSeq[uint32](nn)
  var c=newSeq[uint64](nn)
  for i in 0..<nn:a[i]=mix32(uint32(i)) and 15;b[i]=mix32(uint32(i+nn)) and 15
  var t=newSeq[float64](r)
  for z in 0..<r:
    let st=now()
    for i in 0..<n:
      for j in 0..<n:
        var s=0'u64
        for k in 0..<n:s+=uint64(a[i*n+k])*uint64(b[k*n+j])
        c[i*n+j]=s
    t[z]=now()-st
  let m=med(t);emit("matrix_mul",n0,r,m,float64(n*n*n)/m/1e6,uint64(ck64(c)))

proc graph(n,d:int,weighted:bool):(seq[uint32],seq[uint32]) =
  var a=newSeq[uint32](n*d)
  var w=if weighted:newSeq[uint32](n*d) else: @[]
  for i in 0..<n:
    for e in 0..<d:
      let p=i*d+e
      a[p]=if e==0:uint32((i+1) mod n) elif e==1:uint32((i+n-1) mod n) else: mix32(uint32(p)) mod uint32(n)
      if weighted:w[p]=1+(mix32(0xabc00000'u32 +% uint32(p)) and 15)
  (a,w)
proc benchBFS(n0:uint64,r:int)=
  let n=int(n0)
  let d=4
  let passes=16
  let (a,_)=graph(n,d,false)
  var dist=newSeq[int32](n)
  var q=newSeq[uint32](n)
  var t=newSeq[float64](r)
  var seen=0'u32
  for z in 0..<r:
    let st=now()
    for p in 0..<passes:
      for i in 0..<n:dist[i]=-1
      var h=0
      var tt=0;dist[0]=0;q[tt]=0;inc tt
      while h<tt:
        let u=int(q[h]);inc h
        let nd=dist[u]+1
        for e in 0..<d:
          let v=int(a[u*d+e])
          if dist[v]<0:dist[v]=nd;q[tt]=uint32(v);inc tt
      seen=seen xor uint32(tt+p)
    t[z]=now()-st
  var dv=newSeq[uint32](n)
  for i in 0..<n:dv[i]=cast[uint32](dist[i])
  let c=ck32(dv) xor seen
  let m=med(t);emit("bfs",n0*uint64(passes),r,m,float64(n*d*passes)/m/1e6,uint64(c))

type HP=object
  d:uint64
  v:uint32
proc hpPush(h:var seq[HP],sz:var int,x:HP)=
  var i=sz;inc sz
  while i>0:
    let p=(i-1) div 2
    if h[p].d<=x.d:break
    h[i]=h[p];i=p
  h[i]=x
proc hpPop(h:var seq[HP],sz:var int):HP =
  result=h[0];dec sz
  let x=h[sz]
  var i=0
  while true:
    let l=i*2+1
    if l>=sz:break
    let rr=l+1
    let c=if rr<sz and h[rr].d<h[l].d:rr else: l
    if h[c].d>=x.d:break
    h[i]=h[c];i=c
  if sz>0:h[i]=x
proc benchDij(n0:uint64,r:int)=
  let n=int(n0)
  let d=4
  let (a,w)=graph(n,d,true)
  var dist=newSeq[uint64](n)
  var heap=newSeq[HP](n*d*4)
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    for i in 0..<n:dist[i]=high(uint64) div 4
    var sz=0;dist[0]=0;hpPush(heap,sz,HP(d:0,v:0))
    while sz>0:
      let x=hpPop(heap,sz);if x.d!=dist[int(x.v)]:continue
      for e in 0..<d:
        let p=int(x.v)*d+e
        let v=int(a[p])
        let nd=x.d+uint64(w[p])
        if nd<dist[v]:dist[v]=nd;hpPush(heap,sz,HP(d:nd,v:uint32(v)))
    c=ck64(dist);t[z]=now()-st
  let m=med(t);emit("dijkstra",n0,r,m,float64(n*d)/m/1e6,uint64(c))

proc ufFind(p:var seq[uint32],x0:uint32):uint32 =
  var x=x0
  while p[int(x)]!=x:p[int(x)]=p[int(p[int(x)])];x=p[int(x)]
  x
proc benchUF(n0:uint64,r:int)=
  let n=int(n0)
  let ops=n*4
  var p=newSeq[uint32](n)
  var rank=newSeq[uint8](n)
  var A=newSeq[uint32](ops)
  var B=newSeq[uint32](ops)
  for i in 0..<ops:A[i]=mix32(uint32(i)) mod uint32(n);B[i]=mix32(uint32(i+ops)) mod uint32(n)
  var t=newSeq[float64](r)
  for z in 0..<r:
    let st=now()
    for i in 0..<n:p[i]=uint32(i);rank[i]=0
    for i in 0..<ops:
      var ra=ufFind(p,A[i])
      var rb=ufFind(p,B[i])
      if ra!=rb:
        if rank[int(ra)]<rank[int(rb)]:swap(ra,rb)
        p[int(rb)]=ra;if rank[int(ra)]==rank[int(rb)]:inc rank[int(ra)]
    t[z]=now()-st
  for i in 0..<n:p[i]=ufFind(p,uint32(i))
  let m=med(t);emit("union_find",uint64(ops),r,m,float64(ops)/m/1e6,uint64(ck32(p)))

proc mandel(w,mi:int):uint64 =
  var sum=0'u64
  for y in 0..<w:
    let ci = -1.5+3.0*float64(y)/float64(w-1)
    for x in 0..<w:
      let cr = -2.0+3.0*float64(x)/float64(w-1)\n      var zr=0.0\n      var zi=0.0\n      var it=0
      while it<mi:
        let a=zr*zr
        let b=zi*zi
        if a+b>4.0:break
        let nz=a-b+cr;zi=2*zr*zi+ci;zr=nz;inc it
      sum+=uint64(it)
  sum
proc benchMandel(w0:uint64,r:int)=
  let w=int(w0)
  discard mandel(min(w,128),20)
  var t=newSeq[float64](r)
  var c=0'u64
  for z in 0..<r:
    let st=now()
    c=mandel(w,50)
    t[z]=now()-st
  let m=med(t);emit("mandelbrot",w0*w0,r,m,float64(w0*w0)/m/1e6,c)

proc benchVA(n0:uint64,r:int)=
  let n=int(n0)
  var inp=newSeq[uint32](n)
  for i in 0..<n:inp[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    var v=newSeqOfCap[uint32](8)
    for x in inp:v.add(x)
    var h=2166136261'u32
    for i in 0..<v.len:v[i]=v[i] xor uint32(i);h=(h xor v[i]) *% 16777619'u32
    while v.len>0:
      let nn=v.len-1
      let x=v.pop()
      h=(h xor (x +% uint32(nn))) *% 16777619'u32
    c=h;t[z]=now()-st
  let m=med(t);emit("dynamic_array",n0,r,m,float64(n0)/m/1e6,uint64(c))

proc benchLL(n0:uint64,r:int)=
  let n=int(n0)
  let passes=16
  var next=newSeq[uint32](n)
  var val=newSeq[uint32](n)
  var base=newSeq[uint32](n)
  for i in 0..<n:base[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now();val=base
    for i in 0..<n:next[i]=if i+1<n:uint32(i+1) else: high(uint32)
    const B=64
    var b=0
    while b<n:
      let hi=min(b+B,n)-1
      for i in b..hi:next[i]=if i==b:(if hi+1<n:uint32(hi+1) else: high(uint32)) else: uint32(i-1)
      b+=B
    var h=2166136261'u32
    for p in 0..<passes:
      var cur=if B<n:uint32(B-1) else: uint32(n-1)
      var seen=0
      while cur!=high(uint32) and seen<n:
        let u=int(cur);val[u]=val[u] xor uint32(seen+p);h=(h xor (val[u] +% cur +% uint32(p))) *% 16777619'u32;cur=next[u];inc seen
      h=(h xor uint32(seen)) *% 16777619'u32
    c=h;t[z]=now()-st
  let m=med(t);emit("linked_list",n0*uint64(passes),r,m,float64(n0*uint64(passes))/m/1e6,uint64(c))

proc benchQR(ops0:uint64,r:int)=
  let ops=int(ops0)
  let cap=ops div 2+1024
  var b=newSeq[uint32](cap)
  var inp=newSeq[uint32](ops)
  for i in 0..<ops:inp[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    var h=0
    var tt=0
    var cnt=0
    var x=0'u32
    for i in 0..<ops:
      if (i and 3)!=3:
        if cnt==cap:x=x xor b[h];h=(h+1) mod cap;dec cnt
        b[tt]=inp[i];tt=(tt+1) mod cap;inc cnt
      elif cnt>0:x=x xor b[h];h=(h+1) mod cap;dec cnt
    while cnt>0:x=x xor b[h];h=(h+1) mod cap;dec cnt
    c=x;t[z]=now()-st
  let m=med(t);emit("queue_ring",ops0,r,m,float64(ops0)/m/1e6,uint64(c))

proc np2(x:int):int =
  var p=1
  while p<x: p=p shl 1
  p
proc benchHT(n0:uint64,r:int)=
  let n=int(n0)
  let cap=np2(n*2)
  let mask=cap-1
  var keys=newSeq[uint32](cap)
  var vals=newSeq[uint32](cap)
  var ik=newSeq[uint32](n)
  var iv=newSeq[uint32](n)
  for i in 0..<n:ik[i]=mix32(uint32(i)) or 1;iv[i]=mix32(uint32(i) +% 0x55555555'u32)
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    for i in 0..<cap:keys[i]=0
    for i in 0..<n:
      let key=ik[i]
      var p=int(hash32(key)) and mask
      while keys[p]!=0 and keys[p]!=key:p=(p+1) and mask
      keys[p]=key;vals[p]=iv[i]
    var h=0'u32
    for i in 0..<n:
      let key=ik[i]
      var p=int(hash32(key)) and mask
      while keys[p]!=key:p=(p+1) and mask
      vals[p]=vals[p] xor uint32(i);h=h xor vals[p]
    c=h;t[z]=now()-st
  let m=med(t);emit("hash_table",n0,r,m,float64(n0)*2/m/1e6,uint64(c))

proc hp32Push(h:var seq[uint32],sz:var int,x:uint32)=
  var i=sz;inc sz
  while i>0:
    let p=(i-1) div 2
    if h[p]<=x:break
    h[i]=h[p];i=p
  h[i]=x
proc hp32Pop(h:var seq[uint32],sz:var int):uint32 =
  result=h[0];dec sz
  let x=h[sz]
  var i=0
  while true:
    let l=i*2+1;if l>=sz:break
    let rr=l+1
    let c=if rr<sz and h[rr]<h[l]:rr else: l
    if h[c]>=x:break
    h[i]=h[c];i=c
  if sz>0:h[i]=x
proc benchBH(n0:uint64,r:int)=
  let n=int(n0)
  var h=newSeq[uint32](n)
  var inp=newSeq[uint32](n)
  for i in 0..<n:inp[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    var sz=0
    for x in inp:hp32Push(h,sz,x)
    var x=0'u32
    for i in 0..<n:x=x xor (hp32Pop(h,sz) +% uint32(i))
    c=x;t[z]=now()-st
  let m=med(t);emit("binary_heap",n0,r,m,float64(n0)*2/m/1e6,uint64(c))

proc benchBST(n0:uint64,r:int)=
  let n=int(n0)
  var keys=newSeq[uint32](n)
  var l=newSeq[int32](n)
  var rr=newSeq[int32](n)
  var inp=newSeq[uint32](n)
  for i in 0..<n:inp[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    var root=-1'i32
    for i in 0..<n:
      let key=inp[i];keys[i]=key;l[i]=-1;rr[i]=-1
      if root<0:root=int32(i)
      else:
        var cur=root
        while true:
          let u=int(cur)
          if key<keys[u]:
            if l[u]<0:l[u]=int32(i);break
            cur=l[u]
          else:
            if rr[u]<0:rr[u]=int32(i);break
            cur=rr[u]
    var h=0'u32
    var i=0
    while i<n:
      let key=inp[i]
      var cur=root
      while cur>=0 and keys[int(cur)]!=key:
        let u=int(cur);cur=if key<keys[u]:l[u] else: rr[u]
      if cur>=0:h=h xor uint32(cur+1)
      i+=3
    c=h;t[z]=now()-st
  let m=med(t);emit("bst",n0,r,m,float64(n0)/m/1e6,uint64(c))

proc benchTrie(n0:uint64,r:int)=
  let n=int(n0)
  let passes=32
  let mx=1+n*8
  var ch=newSeq[int32](mx*16)
  var term=newSeq[uint8](mx)
  var words=newSeq[uint32](n)
  for i in 0..<n:words[i]=mix32(uint32(i))
  var t=newSeq[float64](r)
  var c=0'u32
  for z in 0..<r:
    let st=now()
    for i in 0..<ch.len:ch[i]=-1
    for i in 0..<term.len:term[i]=0
    var used=1
    for w in words:
      var node=0
      var sh=28
      while sh>=0:
        let cc=int((w shr sh) and 15)
        let p=node*16+cc
        if ch[p]<0:ch[p]=int32(used);inc used
        node=int(ch[p]);sh-=4
      term[node]=1
    var h=uint32(used)
    for p in 0..<passes:
      var i=0
      while i<n:
        let w=words[i]
        var node=0
        var sh=28
        while sh>=0 and node>=0:node=int(ch[node*16+int((w shr sh) and 15)]);sh-=4
        if node>=0 and term[node]!=0:h=h xor uint32(node+1+p)
        i+=2
    c=h;t[z]=now()-st
  let m=med(t);emit("trie",n0*uint64(passes),r,m,float64(n0*uint64(passes))/m/1e6,uint64(c))

proc defSize(k:string):uint64 =
  case k
  of "integer50":200000000'u64
  of "json_escape":16000000'u64
  of "merge_sort","binary_search","union_find","hash_table","binary_heap":1000000'u64
  of "prefix_sum":8000000'u64
  of "matrix_mul":320'u64
  of "bfs":200000'u64
  of "dijkstra","trie":100000'u64
  of "mandelbrot":1600'u64
  of "dynamic_array":5000000'u64
  of "linked_list":4000000'u64
  of "queue_ring":10000000'u64
  of "bst":300000'u64
  else: 0'u64
let k=if paramCount()>=1:paramStr(1) else:"integer50"
let n=if paramCount()>=2:parseUInt(paramStr(2)).uint64 else: defSize(k)
let r=if paramCount()>=3:parseInt(paramStr(3)) else: 7
case k
of "integer50":benchInteger(n,r)
of "json_escape":benchJson(n,r)
of "merge_sort":benchMerge(n,r)
of "binary_search":benchBS(n,r)
of "prefix_sum":benchPrefix(n,r)
of "matrix_mul":benchMM(n,r)
of "bfs":benchBFS(n,r)
of "dijkstra":benchDij(n,r)
of "union_find":benchUF(n,r)
of "mandelbrot":benchMandel(n,r)
of "dynamic_array":benchVA(n,r)
of "linked_list":benchLL(n,r)
of "queue_ring":benchQR(n,r)
of "hash_table":benchHT(n,r)
of "binary_heap":benchBH(n,r)
of "bst":benchBST(n,r)
of "trie":benchTrie(n,r)
else: quit(64)
