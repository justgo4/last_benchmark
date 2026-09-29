import scala.util.Sorting

object Bench:
  inline def now(): Double = System.nanoTime().toDouble * 1e-9
  def median(a:Array[Double]):Double = { Sorting.quickSort(a); a(a.length/2) }
  def emit(k:String,u:Long,s:Double,rate:Double,c:Long):Unit =
    println(f"RESULT kernel=$k units=$u rounds=7 seconds=$s%.9f rate=$rate%.6f checksum=$c")
  inline def u32(x:Int):Long = Integer.toUnsignedLong(x)
  def mix32(xx:Int):Int =
    var x=xx + 0x9e3779b9
    x ^= x >>> 16; x *= 0x85ebca6b; x ^= x >>> 13; x *= 0xc2b2ae35; x ^ (x >>> 16)
  def hash32(xx:Int):Int =
    var x=xx
    x ^= x >>> 16; x *= 0x7feb352d; x ^= x >>> 15; x *= 0x846ca68b; x ^ (x >>> 16)
  def ck32(a:Array[Int]):Int =
    var h=0x811c9dc5; var i=0
    while i<a.length do { h=(h ^ a(i))*0x01000193; i+=1 }
    h
  def ck64(a:Array[Long]):Int =
    var h=0x811c9dc5; var i=0
    while i<a.length do
      val x=a(i); h=(h ^ x.toInt)*0x01000193; h=(h ^ (x>>>32).toInt)*0x01000193; i+=1
    h

  def integer50(n:Long):Long =
    val mask=(1L<<50)-1; var x=88172645463325252L & mask; var s=0L; var i=0L
    while i<n do { x ^= x>>>7; x ^= (x<<8)&mask; x ^= x>>>9; x &= mask; s=(s+(x^(x>>>17)))&mask; i+=1 }
    s
  def benchInteger(n:Long):Unit =
    integer50(n/20+1); val t=new Array[Double](7); var c=0L; var r=0
    while r<7 do { val a=now(); c=integer50(n); t(r)=now()-a; r+=1 }
    val m=median(t); emit("integer50",n,m,n.toDouble/m/1e6,c)

  val pattern=Array[Byte](97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47)
  def jsonEscape(in:Array[Byte],out:Array[Byte]):Int =
    val hx="0123456789abcdef"; var j=0; out(j)=34; j+=1; var i=0
    while i<in.length do
      val c=in(i)&255
      c match
        case 34 => out(j)=92;out(j+1)=34;j+=2
        case 92 => out(j)=92;out(j+1)=92;j+=2
        case 8 => out(j)=92;out(j+1)=98;j+=2
        case 12 => out(j)=92;out(j+1)=102;j+=2
        case 10 => out(j)=92;out(j+1)=110;j+=2
        case 13 => out(j)=92;out(j+1)=114;j+=2
        case 9 => out(j)=92;out(j+1)=116;j+=2
        case _ =>
          if c<32 then
            out(j)=92;out(j+1)=117;out(j+2)=48;out(j+3)=48
            out(j+4)=hx.charAt(c>>>4).toByte;out(j+5)=hx.charAt(c&15).toByte;j+=6
          else
            out(j)=c.toByte
            j+=1
      i+=1
    out(j)=34; j+1
  def benchJson(n0:Long):Unit =
    val n=n0.toInt; val in=new Array[Byte](n); var i=0
    while i<n do { in(i)=pattern(i%23); i+=1 }
    val out=new Array[Byte](n*6+2); var on=jsonEscape(in,out); val t=new Array[Double](7); var r=0
    while r<7 do { val a=now(); on=jsonEscape(in,out); t(r)=now()-a; r+=1 }
    var c=on.toLong;i=0;while i<on do { c += (out(i)&255).toLong; i+=1 }
    val m=median(t);emit("json_escape",n0,m,n0/m/1e9,c)

  def mergeSort(a:Array[Int],tmp:Array[Int]):Unit =
    val n=a.length; var src=a; var dst=tmp; var w=1; var flip=false
    while w<n do
      var lo=0
      while lo<n do
        val mid=Math.min(lo+w,n); val hi=Math.min(lo+2*w,n); var i=lo; var j=mid; var k=lo
        while i<mid && j<hi do
          if Integer.compareUnsigned(src(i),src(j))<=0 then {dst(k)=src(i);i+=1} else {dst(k)=src(j);j+=1}
          k+=1
        while i<mid do {dst(k)=src(i);i+=1;k+=1}
        while j<hi do {dst(k)=src(j);j+=1;k+=1}
        lo+=2*w
      val z=src;src=dst;dst=z;flip = !flip
      if w>n/2 then w=n else w*=2
    if flip then System.arraycopy(src,0,a,0,n)
  def benchMerge(n0:Long):Unit =
    val n=n0.toInt; val base=Array.tabulate(n)(i=>mix32(i)); val a=new Array[Int](n); val tmp=new Array[Int](n); val t=new Array[Double](7); var r=0
    while r<7 do { System.arraycopy(base,0,a,0,n); val q=now(); mergeSort(a,tmp); t(r)=now()-q; r+=1 }
    val m=median(t);emit("merge_sort",n0,m,n0/m/1e6,u32(ck32(a)))

  def bs(a:Array[Int],x:Int):Int =
    var l=0;var h=a.length
    while l<h do { val m=l+(h-l)/2; if Integer.compareUnsigned(a(m),x)<0 then l=m+1 else h=m }
    if l<a.length && a(l)==x then l else -1
  def benchBS(n0:Long):Unit =
    val n=n0.toInt;val nq=n*4;val a=Array.tabulate(n)(i=>i*2);val q=Array.tabulate(nq)(i=>Integer.remainderUnsigned(mix32(i),2*n))
    val t=new Array[Double](7);var c=0L;var r=0
    while r<7 do
      val s=now();c=0;var i=0
      while i<nq do {val p=bs(a,q(i));if p>=0 then c+=p+1L;i+=1}
      t(r)=now()-s;r+=1
    val m=median(t);emit("binary_search",nq,m,nq.toDouble/m/1e6,c)

  def benchPrefix(n0:Long):Unit =
    val n=n0.toInt;val in=Array.tabulate(n)(i=>mix32(i)&1023);val out=new Array[Long](n);val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s0=now();c=0;var p=0
      while p<16 do
        var s=p.toLong;var i=0
        while i<n do {s+=u32(in(i));out(i)=s;i+=1}
        c ^= s.toInt;p+=1
      t(r)=now()-s0;r+=1
    c ^= ck64(out);val m=median(t);emit("prefix_sum",n0*16,m,n0*16/m/1e6,u32(c))

  def benchMatrix(n0:Long):Unit =
    val n=n0.toInt;val nn=n*n;val a=Array.tabulate(nn)(i=>mix32(i)&15);val b=Array.tabulate(nn)(i=>mix32(i+nn)&15);val c=new Array[Long](nn);val t=new Array[Double](7);var r=0
    while r<7 do
      val q=now();var i=0
      while i<n do
        var j=0
        while j<n do
          var s=0L;var k=0
          while k<n do {s += a(i*n+k).toLong*b(k*n+j).toLong;k+=1}
          c(i*n+j)=s;j+=1
        i+=1
      t(r)=now()-q;r+=1
    val m=median(t);emit("matrix_mul",n0,m,n.toDouble*n*n/m/1e6,u32(ck64(c)))

  def graph(n:Int,d:Int,weighted:Boolean):(Array[Int],Array[Int]) =
    val a=new Array[Int](n*d);val w=if weighted then new Array[Int](n*d) else Array.emptyIntArray
    var i=0
    while i<n do
      var e=0
      while e<d do
        val p=i*d+e
        a(p)=if e==0 then (i+1)%n else if e==1 then (i+n-1)%n else Integer.remainderUnsigned(mix32(p),n)
        if weighted then w(p)=1+(mix32(0xabc00000+p)&15)
        e+=1
      i+=1
    (a,w)

  def benchBFS(n0:Long):Unit =
    val n=n0.toInt;val d=4;val passes=16;val(a,_)=graph(n,d,false);val dist=new Array[Int](n);val q=new Array[Int](n);val t=new Array[Double](7);var seen=0;var r=0
    while r<7 do
      val s=now();var z=0
      while z<passes do
        java.util.Arrays.fill(dist,-1);var h=0;var tt=0;dist(0)=0;q(tt)=0;tt+=1
        while h<tt do
          val u=q(h);h+=1;val nd=dist(u)+1;var e=0
          while e<d do {val v=a(u*d+e);if dist(v)<0 then {dist(v)=nd;q(tt)=v;tt+=1};e+=1}
        seen ^= tt+z;z+=1
      t(r)=now()-s;r+=1
    val c=ck32(dist)^seen;val m=median(t);emit("bfs",n0*passes,m,n.toDouble*d*passes/m/1e6,u32(c))

  final class HP(var d:Long,var v:Int)
  def hpPush(h:Array[HP],sz:Array[Int],x:HP):Unit =
    var i=sz(0);sz(0)+=1
    while i>0 do {val p=(i-1)/2;if h(p).d<=x.d then {h(i)=x;return};h(i)=h(p);i=p}
    h(i)=x
  def hpPop(h:Array[HP],sz:Array[Int]):HP =
    val o=h(0);sz(0)-=1;val x=h(sz(0));var i=0;var done=false
    while !done do
      val l=i*2+1
      if l>=sz(0) then done=true
      else
        val rr=l+1;val c=if rr<sz(0)&&h(rr).d<h(l).d then rr else l
        if h(c).d>=x.d then done=true else {h(i)=h(c);i=c}
    if sz(0)>0 then h(i)=x
    o
  def benchDij(n0:Long):Unit =
    val n=n0.toInt;val d=4;val(a,w)=graph(n,d,true);val dist=new Array[Long](n);val heap=Array.fill(n*d*4)(new HP(0,0));val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();java.util.Arrays.fill(dist,Long.MaxValue/4);val sz=Array(0);dist(0)=0;hpPush(heap,sz,new HP(0,0))
      while sz(0)>0 do
        val x=hpPop(heap,sz)
        if x.d==dist(x.v) then
          var e=0
          while e<d do
            val p=x.v*d+e;val v=a(p);val nd=x.d+w(p)
            if nd<dist(v) then {dist(v)=nd;hpPush(heap,sz,new HP(nd,v))}
            e+=1
      c=ck64(dist);t(r)=now()-s;r+=1
    val m=median(t);emit("dijkstra",n0,m,n.toDouble*d/m/1e6,u32(c))

  def ufFind(p:Array[Int],xx:Int):Int =
    var x=xx
    while p(x)!=x do {p(x)=p(p(x));x=p(x)}
    x
  def benchUF(n0:Long):Unit =
    val n=n0.toInt;val ops=n*4;val p=new Array[Int](n);val rank=new Array[Byte](n);val aa=Array.tabulate(ops)(i=>Integer.remainderUnsigned(mix32(i),n));val bb=Array.tabulate(ops)(i=>Integer.remainderUnsigned(mix32(i+ops),n));val t=new Array[Double](7);var r=0
    while r<7 do
      val s=now();var i=0
      while i<n do {p(i)=i;rank(i)=0;i+=1}
      i=0
      while i<ops do
        var ra=ufFind(p,aa(i));var rb=ufFind(p,bb(i))
        if ra!=rb then
          if (rank(ra)&255)<(rank(rb)&255) then {val z=ra;ra=rb;rb=z}
          p(rb)=ra;if rank(ra)==rank(rb) then rank(ra)=(rank(ra)+1).toByte
        i+=1
      t(r)=now()-s;r+=1
    var i=0;while i<n do {p(i)=ufFind(p,i);i+=1}
    val m=median(t);emit("union_find",ops,m,ops.toDouble/m/1e6,u32(ck32(p)))

  def mandel(w:Int,mi:Int):Long =
    var sum=0L;var y=0
    while y<w do
      val ci= -1.5+3.0*y/(w-1.0);var x=0
      while x<w do
        val cr= -2+3.0*x/(w-1.0);var zr=0.0;var zi=0.0;var it=0;var done=false
        while it<mi && !done do
          val aa=zr*zr;val bb=zi*zi
          if aa+bb>4 then done=true else {val nz=aa-bb+cr;zi=2*zr*zi+ci;zr=nz;it+=1}
        sum+=it;x+=1
      y+=1
    sum
  def benchMandel(w0:Long):Unit =
    val w=w0.toInt;mandel(Math.min(w,128),20);val t=new Array[Double](7);var c=0L;var r=0
    while r<7 do {val s=now();c=mandel(w,50);t(r)=now()-s;r+=1}
    val m=median(t);emit("mandelbrot",w0*w0,m,w0*w0/m/1e6,c)

  def benchArray(n0:Long):Unit =
    val n=n0.toInt;val in=Array.tabulate(n)(i=>mix32(i));val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();val v=new scala.collection.mutable.ArrayBuffer[Int](8);var i=0
      while i<n do {v+=in(i);i+=1}
      var h=0x811c9dc5;i=0
      while i<n do {v(i)^=i;h=(h^v(i))*0x01000193;i+=1}
      while v.nonEmpty do {val x=v.remove(v.length-1);h=(h^(x+v.length))*0x01000193}
      c=h;t(r)=now()-s;r+=1
    val m=median(t);emit("dynamic_array",n0,m,n0/m/1e6,u32(c))

  def benchList(n0:Long):Unit =
    val n=n0.toInt;val passes=16;val base=Array.tabulate(n)(i=>mix32(i));val next=new Array[Int](n);val value=new Array[Int](n);val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();System.arraycopy(base,0,value,0,n);var i=0
      while i<n do {next(i)=if i+1<n then i+1 else -1;i+=1}
      var b=0
      while b<n do {val hi=Math.min(b+64,n)-1;i=b;while i<=hi do {next(i)=if i==b then (if hi+1<n then hi+1 else -1) else i-1;i+=1};b+=64}
      var h=0x811c9dc5;var p=0
      while p<passes do
        var cur=if 64<n then 63 else n-1;var seen=0
        while cur>=0 && seen<n do {value(cur)^=seen+p;h=(h^(value(cur)+cur+p))*0x01000193;cur=next(cur);seen+=1}
        h=(h^seen)*0x01000193;p+=1
      c=h;t(r)=now()-s;r+=1
    val m=median(t);emit("linked_list",n0*passes,m,n0*passes/m/1e6,u32(c))

  def benchQueue(ops0:Long):Unit =
    val ops=ops0.toInt;val cap=ops/2+1024;val b=new Array[Int](cap);val in=Array.tabulate(ops)(i=>mix32(i));val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();var h=0;var tt=0;var cnt=0;var z=0;var i=0
      while i<ops do
        if (i&3)!=3 then {if cnt==cap then {z^=b(h);h=(h+1)%cap;cnt-=1};b(tt)=in(i);tt=(tt+1)%cap;cnt+=1}
        else if cnt>0 then {z^=b(h);h=(h+1)%cap;cnt-=1}
        i+=1
      while cnt>0 do {z^=b(h);h=(h+1)%cap;cnt-=1}
      c=z;t(r)=now()-s;r+=1
    val m=median(t);emit("queue_ring",ops0,m,ops0/m/1e6,u32(c))

  def np2(x:Int):Int = {var p=1;while p<x do p<<=1;p}
  def benchHash(n0:Long):Unit =
    val n=n0.toInt;val cap=np2(n*2);val mask=cap-1;val keys=new Array[Int](cap);val vals=new Array[Int](cap);val ik=Array.tabulate(n)(i=>mix32(i)|1);val iv=Array.tabulate(n)(i=>mix32(i+0x55555555));val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();java.util.Arrays.fill(keys,0);var i=0
      while i<n do {val key=ik(i);var p=hash32(key)&mask;while keys(p)!=0 && keys(p)!=key do p=(p+1)&mask;keys(p)=key;vals(p)=iv(i);i+=1}
      var h=0;i=0
      while i<n do {val key=ik(i);var p=hash32(key)&mask;while keys(p)!=key do p=(p+1)&mask;vals(p)^=i;h^=vals(p);i+=1}
      c=h;t(r)=now()-s;r+=1
    val m=median(t);emit("hash_table",n0,m,n0*2/m/1e6,u32(c))

  def heapPush(h:Array[Int],sz:Array[Int],x:Int):Unit =
    var i=sz(0);sz(0)+=1
    while i>0 do {val p=(i-1)/2;if Integer.compareUnsigned(h(p),x)<=0 then {h(i)=x;return};h(i)=h(p);i=p}
    h(i)=x
  def heapPop(h:Array[Int],sz:Array[Int]):Int =
    val o=h(0);sz(0)-=1;val x=h(sz(0));var i=0;var done=false
    while !done do
      val l=i*2+1
      if l>=sz(0) then done=true
      else
        val rr=l+1;val c=if rr<sz(0)&&Integer.compareUnsigned(h(rr),h(l))<0 then rr else l
        if Integer.compareUnsigned(h(c),x)>=0 then done=true else {h(i)=h(c);i=c}
    if sz(0)>0 then h(i)=x
    o
  def benchHeap(n0:Long):Unit =
    val n=n0.toInt;val in=Array.tabulate(n)(i=>mix32(i));val h=new Array[Int](n);val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();val sz=Array(0);var i=0;while i<n do {heapPush(h,sz,in(i));i+=1};var z=0;i=0
      while i<n do {z ^= heapPop(h,sz)+i;i+=1}
      c=z;t(r)=now()-s;r+=1
    val m=median(t);emit("binary_heap",n0,m,n0*2/m/1e6,u32(c))

  def benchBST(n0:Long):Unit =
    val n=n0.toInt;val in=Array.tabulate(n)(i=>mix32(i));val keys=new Array[Int](n);val left=new Array[Int](n);val right=new Array[Int](n);val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();var root= -1;var i=0
      while i<n do
        val key=in(i);keys(i)=key;left(i)= -1;right(i)= -1
        if root<0 then root=i else
          var cur=root;var done=false
          while !done do
            if Integer.compareUnsigned(key,keys(cur))<0 then {if left(cur)<0 then {left(cur)=i;done=true}else cur=left(cur)}
            else {if right(cur)<0 then {right(cur)=i;done=true}else cur=right(cur)}
        i+=1
      var h=0;i=0
      while i<n do
        val key=in(i);var cur=root
        while cur>=0 && keys(cur)!=key do cur=if Integer.compareUnsigned(key,keys(cur))<0 then left(cur) else right(cur)
        if cur>=0 then h^=cur+1;i+=3
      c=h;t(r)=now()-s;r+=1
    val m=median(t);emit("bst",n0,m,n0/m/1e6,u32(c))

  def benchTrie(n0:Long):Unit =
    val n=n0.toInt;val passes=32;val mx=1+n*8;val ch=new Array[Int](mx*16);val term=new Array[Byte](mx);val words=Array.tabulate(n)(i=>mix32(i));val t=new Array[Double](7);var c=0;var r=0
    while r<7 do
      val s=now();java.util.Arrays.fill(ch,-1);java.util.Arrays.fill(term,0.toByte);var used=1;var i=0
      while i<n do
        val w=words(i);var node=0;var sh=28
        while sh>=0 do {val cc=(w>>>sh)&15;val idx=node*16+cc;if ch(idx)<0 then {ch(idx)=used;used+=1};node=ch(idx);sh-=4}
        term(node)=1;i+=1
      var h=used;var p=0
      while p<passes do
        i=0
        while i<n do
          val w=words(i);var node=0;var sh=28
          while sh>=0 && node>=0 do {node=ch(node*16+((w>>>sh)&15));sh-=4}
          if node>=0 && term(node)!=0 then h^=node+1+p
          i+=2
        p+=1
      c=h;t(r)=now()-s;r+=1
    val m=median(t);emit("trie",n0*passes,m,n0*passes/m/1e6,u32(c))

  def size(k:String):Long = k match
    case "integer50"=>200000000L
    case "json_escape"=>16000000L
    case "merge_sort"|"binary_search"|"union_find"|"hash_table"|"binary_heap"=>1000000L
    case "prefix_sum"=>8000000L
    case "matrix_mul"=>320L
    case "bfs"=>200000L
    case "dijkstra"|"trie"=>100000L
    case "mandelbrot"=>1600L
    case "dynamic_array"=>5000000L
    case "linked_list"=>4000000L
    case "queue_ring"=>10000000L
    case "bst"=>300000L
    case _=>0L

  def main(args:Array[String]):Unit =
    val k=if args.nonEmpty then args(0) else "integer50";val n=if args.length>1 then args(1).toLong else size(k)
    k match
      case "integer50"=>benchInteger(n)
      case "json_escape"=>benchJson(n)
      case "merge_sort"=>benchMerge(n)
      case "binary_search"=>benchBS(n)
      case "prefix_sum"=>benchPrefix(n)
      case "matrix_mul"=>benchMatrix(n)
      case "bfs"=>benchBFS(n)
      case "dijkstra"=>benchDij(n)
      case "union_find"=>benchUF(n)
      case "mandelbrot"=>benchMandel(n)
      case "dynamic_array"=>benchArray(n)
      case "linked_list"=>benchList(n)
      case "queue_ring"=>benchQueue(n)
      case "hash_table"=>benchHash(n)
      case "binary_heap"=>benchHeap(n)
      case "bst"=>benchBST(n)
      case "trie"=>benchTrie(n)
      case _=>sys.error("unknown kernel")
