import scala.util.Sorting
import java.util.Arrays

object Bench:
  inline def now(): Double = System.nanoTime().toDouble * 1e-9
  def median(a:Array[Double]):Double = { Sorting.quickSort(a); a(a.length/2) }
  def emit(k:String,u:Long,r:Int,s:Double,rate:Double,c:Long):Unit =
    println(f"RESULT kernel=$k units=$u rounds=$r seconds=$s%.9f rate=$rate%.6f checksum=$c")
  inline def u32(x:Int):Long = Integer.toUnsignedLong(x)
  def mix32(x0:Int):Int =
    var x=x0+0x9e3779b9
    x ^= x >>> 16; x *= 0x85ebca6b
    x ^= x >>> 13; x *= 0xc2b2ae35
    x ^ (x >>> 16)
  def hash32(x0:Int):Int =
    var x=x0
    x ^= x >>> 16; x *= 0x7feb352d
    x ^= x >>> 15; x *= 0x846ca68b
    x ^ (x >>> 16)
  def ck32(a:Array[Int]):Int =
    var h=0x811c9dc5; var i=0
    while i<a.length do { h=(h^a(i))*0x01000193; i+=1 }
    h
  def ck64(a:Array[Long]):Int =
    var h=0x811c9dc5; var i=0
    while i<a.length do
      val x=a(i); h=(h^x.toInt)*0x01000193; h=(h^(x>>>32).toInt)*0x01000193; i+=1
    h

  def integer50(n:Long):Long =
    val mask=(1L<<50)-1; var x=88172645463325252L & mask; var s=0L; var i=0L
    while i<n do { x ^= x>>>7; x ^= (x<<8)&mask; x ^= x>>>9; x &= mask; s=(s+(x^(x>>>17)))&mask; i+=1 }
    s
  def benchInteger(n:Long,r:Int):Unit =
    integer50(n/20+1); val t=new Array[Double](r); var c=0L; var i=0
    while i<r do { val a=now(); c=integer50(n); t(i)=now()-a; i+=1 }
    val m=median(t); emit("integer50",n,r,m,n.toDouble/m/1e6,c)

  val PAT=Array[Byte](97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47)
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
          else { out(j)=c.toByte; j+=1 }
      i+=1
    out(j)=34; j+1
  def benchJson(n0:Long,r:Int):Unit =
    val n=n0.toInt; val in=new Array[Byte](n); val out=new Array[Byte](n*6+2); var i=0
    while i<n do { in(i)=PAT(i%23); i+=1 }
    var on=jsonEscape(in,out); val t=new Array[Double](r); var x=0
    while x<r do { val a=now(); on=jsonEscape(in,out); t(x)=now()-a; x+=1 }
    var c=on.toLong; i=0; while i<on do { c += out(i)&255; i+=1 }
    val m=median(t); emit("json_escape",n0,r,m,n0.toDouble/m/1e9,c)

  def mergeSort(a:Array[Int],tmp:Array[Int]):Unit =
    val n=a.length; var src=a; var dst=tmp; var flip=false; var w=1
    while w<n do
      var lo=0
      while lo<n do
        val mid=Math.min(lo+w,n); val hi=Math.min(lo+2*w,n); var i=lo; var j=mid; var k=lo
        while i<mid && j<hi do
          if Integer.compareUnsigned(src(i),src(j))<=0 then { dst(k)=src(i); i+=1 } else { dst(k)=src(j); j+=1 }
          k+=1
        while i<mid do { dst(k)=src(i);i+=1;k+=1 }
        while j<hi do { dst(k)=src(j);j+=1;k+=1 }
        lo+=2*w
      val z=src; src=dst; dst=z; flip=!flip
      if w>n/2 then w=n else w*=2
    if flip then System.arraycopy(src,0,a,0,n)
  def benchMerge(n0:Long,r:Int):Unit =
    val n=n0.toInt; val base=Array.tabulate(n)(mix32); val a=new Array[Int](n); val tmp=new Array[Int](n); val t=new Array[Double](r); var x=0
    while x<r do { System.arraycopy(base,0,a,0,n); val q=now(); mergeSort(a,tmp); t(x)=now()-q; x+=1 }
    val m=median(t); emit("merge_sort",n0,r,m,n0.toDouble/m/1e6,u32(ck32(a)))

  def bs(a:Array[Int],x:Int):Int =
    var l=0; var h=a.length
    while l<h do { val m=l+(h-l)/2; if Integer.compareUnsigned(a(m),x)<0 then l=m+1 else h=m }
    if l<a.length && a(l)==x then l else -1
  def benchBS(n0:Long,r:Int):Unit =
    val n=n0.toInt; val nq=n*4; val a=Array.tabulate(n)(_ * 2); val q=Array.tabulate(nq)(i=>Integer.remainderUnsigned(mix32(i),2*n))
    val t=new Array[Double](r); var c=0L; var z=0
    while z<r do { val s=now(); c=0; var i=0; while i<nq do { val p=bs(a,q(i)); if p>=0 then c+=p+1L; i+=1 }; t(z)=now()-s; z+=1 }
    val m=median(t); emit("binary_search",nq,r,m,nq.toDouble/m/1e6,c)

  def benchPrefix(n0:Long,r:Int):Unit =
    val n=n0.toInt; val in=Array.tabulate(n)(i=>mix32(i)&1023); val out=new Array[Long](n); val t=new Array[Double](r); var c=0L; var z=0
    while z<r do
      val st=now(); c=0; var p=0
      while p<16 do { var s=p.toLong; var i=0; while i<n do { s+=u32(in(i)); out(i)=s; i+=1 }; c ^= s; p+=1 }
      t(z)=now()-st; z+=1
    c ^= u32(ck64(out)); val m=median(t); emit("prefix_sum",n0*16,r,m,n0*16.0/m/1e6,c)

  def benchMM(n0:Long,r:Int):Unit =
    val n=n0.toInt; val nn=n*n; val a=Array.tabulate(nn)(i=>mix32(i)&15); val b=Array.tabulate(nn)(i=>mix32(i+nn)&15); val c=new Array[Long](nn); val t=new Array[Double](r); var z=0
    while z<r do
      val st=now(); var i=0
      while i<n do { var j=0; while j<n do { var s=0L; var k=0; while k<n do { s+=a(i*n+k).toLong*b(k*n+j).toLong;k+=1 };c(i*n+j)=s;j+=1 };i+=1 }
      t(z)=now()-st; z+=1
    val m=median(t); emit("matrix_mul",n0,r,m,n.toDouble*n*n/m/1e6,u32(ck64(c)))

  def graph(n:Int,d:Int,weights:Boolean):(Array[Int],Array[Int]) =
    val a=new Array[Int](n*d); val w=if weights then new Array[Int](n*d) else null
    var i=0
    while i<n do { var e=0; while e<d do { val p=i*d+e; val v=if e==0 then (i+1)%n else if e==1 then (i+n-1)%n else Integer.remainderUnsigned(mix32(p),n); a(p)=v; if weights then w(p)=1+(mix32(0xabc00000+p)&15); e+=1 }; i+=1 }
    (a,w)
  def benchBFS(n0:Long,r:Int):Unit =
    val n=n0.toInt; val d=4; val passes=16; val (a,_)=graph(n,d,false); val dist=new Array[Int](n); val q=new Array[Int](n); val t=new Array[Double](r); var seen=0; var z=0
    while z<r do
      val st=now(); var pass=0
      while pass<passes do
        Arrays.fill(dist,-1); var h=0; var tt=0; dist(0)=0; q(tt)=0;tt+=1
        while h<tt do { val u=q(h);h+=1;val nd=dist(u)+1;var e=0;while e<d do { val v=a(u*d+e);if dist(v)<0 then {dist(v)=nd;q(tt)=v;tt+=1};e+=1 } }
        seen ^= tt+pass; pass+=1
      t(z)=now()-st; z+=1
    val m=median(t); emit("bfs",n0*passes,r,m,n.toDouble*d*passes/m/1e6,u32(ck32(dist)^seen))

  final class HP(var d:Long,var v:Int)
  def hpPush(h:Array[HP],sz:Array[Int],x:HP):Unit =
    var i=sz(0);sz(0)+=1
    while i>0 do { val p=(i-1)/2; if h(p).d<=x.d then { h(i)=x; return }; h(i)=h(p); i=p }
    h(i)=x
  def hpPop(h:Array[HP],sz:Array[Int]):HP =
    val o=h(0); sz(0)-=1; val x=h(sz(0)); var i=0
    while true do
      val l=i*2+1
      if l>=sz(0) then { if sz(0)>0 then h(i)=x; return o }
      val rr=l+1; val c=if rr<sz(0)&&h(rr).d<h(l).d then rr else l
      if h(c).d>=x.d then { if sz(0)>0 then h(i)=x; return o }
      h(i)=h(c); i=c
    o
  def benchDij(n0:Long,r:Int):Unit =
    val n=n0.toInt; val d=4; val (a,w)=graph(n,d,true); val dist=new Array[Long](n); val heap=new Array[HP](n*d*4); val t=new Array[Double](r); var ck=0; var z=0
    while z<r do
      val st=now(); Arrays.fill(dist,Long.MaxValue/4); val sz=Array(0); dist(0)=0; hpPush(heap,sz,new HP(0,0))
      while sz(0)>0 do
        val x=hpPop(heap,sz)
        if x.d==dist(x.v) then { var e=0; while e<d do { val p=x.v*d+e; val v=a(p); val nd=x.d+w(p); if nd<dist(v) then {dist(v)=nd;hpPush(heap,sz,new HP(nd,v))};e+=1 } }
      ck=ck64(dist); t(z)=now()-st; z+=1
    val m=median(t); emit("dijkstra",n0,r,m,n.toDouble*d/m/1e6,u32(ck))

  def ufFind(p:Array[Int],x0:Int):Int =
    var x=x0; while p(x)!=x do { p(x)=p(p(x)); x=p(x) }; x
  def benchUF(n0:Long,r:Int):Unit =
    val n=n0.toInt; val ops=n*4; val p=new Array[Int](n); val rank=new Array[Byte](n); val A=Array.tabulate(ops)(i=>Integer.remainderUnsigned(mix32(i),n)); val B=Array.tabulate(ops)(i=>Integer.remainderUnsigned(mix32(i+ops),n)); val t=new Array[Double](r); var z=0
    while z<r do
      val st=now(); var i=0; while i<n do {p(i)=i;rank(i)=0;i+=1}
      i=0;while i<ops do { var ra=ufFind(p,A(i));var rb=ufFind(p,B(i));if ra!=rb then {if (rank(ra)&255)<(rank(rb)&255) then {val q=ra;ra=rb;rb=q};p(rb)=ra;if rank(ra)==rank(rb) then rank(ra)=(rank(ra)+1).toByte};i+=1}
      t(z)=now()-st;z+=1
    var i=0;while i<n do {p(i)=ufFind(p,i);i+=1};val m=median(t);emit("union_find",ops,r,m,ops.toDouble/m/1e6,u32(ck32(p)))

  def mandel(w:Int,mi:Int):Long =
    var sum=0L;var y=0;while y<w do {val ci=-1.5+3.0*y/(w-1.0);var x=0;while x<w do {val cr=-2.0+3.0*x/(w-1.0);var zr=0.0;var zi=0.0;var it=0;while it<mi do {val a=zr*zr;val b=zi*zi;if a+b>4.0 then {it=it; var stop=true; while stop do {stop=false}; x=x; } else {val nz=a-b+cr;zi=2*zr*zi+ci;zr=nz;it+=1}; if a+b>4.0 then {it=it; break}};sum+=it;x+=1};y+=1};sum
  def mandel2(w:Int,mi:Int):Long =
    var sum=0L;var y=0
    while y<w do
      val ci=-1.5+3.0*y.toDouble/(w-1).toDouble;var x=0
      while x<w do
        val cr=-2.0+3.0*x.toDouble/(w-1).toDouble;var zr=0.0;var zi=0.0;var it=0;var done=false
        while it<mi && !done do { val a=zr*zr;val b=zi*zi;if a+b>4.0 then done=true else {val nz=a-b+cr;zi=2*zr*zi+ci;zr=nz;it+=1} }
        sum+=it;x+=1
      y+=1
    sum
  def benchMandel(w0:Long,r:Int):Unit =
    val w=w0.toInt;mandel2(Math.min(w,128),20);val t=new Array[Double](r);var c=0L;var z=0
    while z<r do {val st=now();c=mandel2(w,50);t(z)=now()-st;z+=1}
    val m=median(t);emit("mandelbrot",w0*w0,r,m,w0*w0/m/1e6,c)

  def benchVA(n0:Long,r:Int):Unit =
    val n=n0.toInt; val in=Array.tabulate(n)(mix32);val t=new Array[Double](r);var c=0;var z=0
    while z<r do
      val st=now();var v=new Array[Int](8);var nn=0;var i=0
      while i<n do {if nn==v.length then v=Arrays.copyOf(v,v.length*2);v(nn)=in(i);nn+=1;i+=1}
      var h=0x811c9dc5;i=0;while i<nn do {v(i)^=i;h=(h^v(i))*0x01000193;i+=1};while nn>0 do {nn-=1;h=(h^(v(nn)+nn))*0x01000193};c=h;t(z)=now()-st;z+=1
    val m=median(t);emit("dynamic_array",n0,r,m,n0/m/1e6,u32(c))

  def benchLL(n0:Long,r:Int):Unit =
    val n=n0.toInt;val next=new Array[Int](n);val value=new Array[Int](n);val base=Array.tabulate(n)(mix32);val t=new Array[Double](r);var c=0;var z=0
    while z<r do
      val st=now();System.arraycopy(base,0,value,0,n);var i=0;while i<n do {next(i)=if i+1<n then i+1 else -1;i+=1};val B=64;var b=0
      while b<n do {val hi=Math.min(b+B,n)-1;i=b;while i<=hi do {next(i)=if i==b then (if hi+1<n then hi+1 else -1) else i-1;i+=1};b+=B}
      var h=0x811c9dc5;var p=0;while p<16 do {var cur=if B<n then B-1 else n-1;var seen=0;while cur>=0&&seen<n do {value(cur)^=seen+p;h=(h^(value(cur)+cur+p))*0x01000193;cur=next(cur);seen+=1};h=(h^seen)*0x01000193;p+=1};c=h;t(z)=now()-st;z+=1
    val m=median(t);emit("linked_list",n0*16,r,m,n0*16/m/1e6,u32(c))

  def benchQR(ops0:Long,r:Int):Unit =
    val ops=ops0.toInt;val b=new Array[Int](ops/2+1024);val in=Array.tabulate(ops)(mix32);val t=new Array[Double](r);var c=0;var z=0
    while z<r do
      val st=now();var h=0;var tt=0;var cnt=0;var zz=0;var i=0
      while i<ops do {if((i&3)!=3){if cnt==b.length then {zz^=b(h);h=(h+1)%b.length;cnt-=1};b(tt)=in(i);tt=(tt+1)%b.length;cnt+=1}else if cnt>0 then {zz^=b(h);h=(h+1)%b.length;cnt-=1};i+=1};while cnt>0 do {zz^=b(h);h=(h+1)%b.length;cnt-=1};c=zz;t(z)=now()-st;z+=1
    val m=median(t);emit("queue_ring",ops0,r,m,ops0/m/1e6,u32(c))

  def np2(x:Int):Int = {var p=1;while p<x do p<<=1;p}
  def benchHT(n0:Long,r:Int):Unit =
    val n=n0.toInt;val cap=np2(n*2);val keys=new Array[Int](cap);val vals=new Array[Int](cap);val ik=Array.tabulate(n)(i=>mix32(i)|1);val iv=Array.tabulate(n)(i=>mix32(i+0x55555555));val t=new Array[Double](r);var c=0;var z=0
    while z<r do
      val st=now();Arrays.fill(keys,0);var i=0;val mask=cap-1
      while i<n do {val key=ik(i);var p=hash32(key)&mask;while keys(p)!=0&&keys(p)!=key do p=(p+1)&mask;keys(p)=key;vals(p)=iv(i);i+=1}
      var h=0;i=0;while i<n do {val key=ik(i);var p=hash32(key)&mask;while keys(p)!=key do p=(p+1)&mask;vals(p)^=i;h^=vals(p);i+=1};c=h;t(z)=now()-st;z+=1
    val m=median(t);emit("hash_table",n0,r,m,n0*2/m/1e6,u32(c))

  def heapPush(h:Array[Int],sz:Array[Int],x:Int):Unit =
    var i=sz(0);sz(0)+=1;while i>0 do {val p=(i-1)/2;if Integer.compareUnsigned(h(p),x)<=0 then {h(i)=x;return};h(i)=h(p);i=p};h(i)=x
  def heapPop(h:Array[Int],sz:Array[Int]):Int =
    val o=h(0);sz(0)-=1;val x=h(sz(0));var i=0
    while true do {val l=i*2+1;if l>=sz(0) then {if sz(0)>0 then h(i)=x;return o};val rr=l+1;val c=if rr<sz(0)&&Integer.compareUnsigned(h(rr),h(l))<0 then rr else l;if Integer.compareUnsigned(h(c),x)>=0 then {if sz(0)>0 then h(i)=x;return o};h(i)=h(c);i=c};o
  def benchBH(n0:Long,r:Int):Unit =
    val n=n0.toInt;val h=new Array[Int](n);val in=Array.tabulate(n)(mix32);val t=new Array[Double](r);var c=0;var z=0
    while z<r do {val st=now();val sz=Array(0);var i=0;while i<n do {heapPush(h,sz,in(i));i+=1};var x=0;i=0;while i<n do {x^=heapPop(h,sz)+i;i+=1};c=x;t(z)=now()-st;z+=1}
    val m=median(t);emit("binary_heap",n0,r,m,n0*2/m/1e6,u32(c))

  def benchBST(n0:Long,r:Int):Unit =
    val n=n0.toInt;val keys=new Array[Int](n);val l=new Array[Int](n);val rr=new Array[Int](n);val in=Array.tabulate(n)(mix32);val t=new Array[Double](r);var c=0;var z=0
    while z<r do
      val st=now();var root=-1;var i=0
      while i<n do {val key=in(i);keys(i)=key;l(i)=-1;rr(i)=-1;if root<0 then root=i else {var cur=root;var done=false;while !done do {if Integer.compareUnsigned(key,keys(cur))<0 then {if l(cur)<0 then {l(cur)=i;done=true}else cur=l(cur)} else {if rr(cur)<0 then {rr(cur)=i;done=true}else cur=rr(cur)}}};i+=1}
      var h=0;i=0;while i<n do {val key=in(i);var cur=root;while cur>=0&&keys(cur)!=key do cur=if Integer.compareUnsigned(key,keys(cur))<0 then l(cur) else rr(cur);if cur>=0 then h^=cur+1;i+=3};c=h;t(z)=now()-st;z+=1
    val m=median(t);emit("bst",n0,r,m,n0/m/1e6,u32(c))

  def benchTrie(n0:Long,r:Int):Unit =
    val n=n0.toInt;val mx=1+n*8;val ch=new Array[Int](mx*16);val term=new Array[Byte](mx);val words=Array.tabulate(n)(mix32);val t=new Array[Double](r);var c=0;var z=0
    while z<r do
      val st=now();Arrays.fill(ch,-1);Arrays.fill(term,0.toByte);var used=1;var i=0
      while i<n do {val w=words(i);var node=0;var sh=28;while sh>=0 do {val cc=(w>>>sh)&15;val p=node*16+cc;if ch(p)<0 then {ch(p)=used;used+=1};node=ch(p);sh-=4};term(node)=1;i+=1}
      var h=used;var p=0;while p<32 do {i=0;while i<n do {val w=words(i);var node=0;var sh=28;while sh>=0&&node>=0 do {node=ch(node*16+((w>>>sh)&15));sh-=4};if node>=0&&term(node)!=0 then h^=node+1+p;i+=2};p+=1};c=h;t(z)=now()-st;z+=1
    val m=median(t);emit("trie",n0*32,r,m,n0*32/m/1e6,u32(c))

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
    val k=if args.nonEmpty then args(0) else "integer50";val n=if args.length>1 then args(1).toLong else size(k);val r=if args.length>2 then args(2).toInt else 7
    k match
      case "integer50"=>benchInteger(n,r)
      case "json_escape"=>benchJson(n,r)
      case "merge_sort"=>benchMerge(n,r)
      case "binary_search"=>benchBS(n,r)
      case "prefix_sum"=>benchPrefix(n,r)
      case "matrix_mul"=>benchMM(n,r)
      case "bfs"=>benchBFS(n,r)
      case "dijkstra"=>benchDij(n,r)
      case "union_find"=>benchUF(n,r)
      case "mandelbrot"=>benchMandel(n,r)
      case "dynamic_array"=>benchVA(n,r)
      case "linked_list"=>benchLL(n,r)
      case "queue_ring"=>benchQR(n,r)
      case "hash_table"=>benchHT(n,r)
      case "binary_heap"=>benchBH(n,r)
      case "bst"=>benchBST(n,r)
      case "trie"=>benchTrie(n,r)
      case _=>sys.error("unknown kernel")
