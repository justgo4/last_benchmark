import scala.util.Sorting

object Bench:
  inline def now(): Double = System.nanoTime().toDouble * 1e-9
  def median(a: Array[Double]): Double =
    Sorting.quickSort(a)
    a(3)
  def emit(k:String,u:Long,s:Double,rate:Double,c:Long):Unit =
    println(f"RESULT kernel=$k units=$u rounds=7 seconds=$s%.9f rate=$rate%.6f checksum=$c")

  def integer50(n:Long):Long =
    val mask=(1L<<50)-1
    var x=88172645463325252L & mask
    var sum=0L
    var i=0L
    while i<n do
      x ^= x >>> 7
      x ^= (x << 8) & mask
      x ^= x >>> 9
      x &= mask
      sum=(sum + (x ^ (x >>> 17))) & mask
      i+=1
    sum
  def benchInteger():Unit =
    val n=200000000L
    integer50(n/20+1)
    val t=new Array[Double](7)
    var c=0L
    var r=0
    while r < 7 do
      val a = now()
      c = integer50(n)
      t(r) = now() - a
      r += 1
    val m=median(t); emit("integer50",n,m,n.toDouble/m/1e6,c)

  val pattern=Array[Byte](97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47)
  def jsonEscape(in:Array[Byte],out:Array[Byte]):Int =
    val hex="0123456789abcdef"
    var j=0; out(j)=34; j+=1
    var i=0
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
            out(j+4)=hex.charAt(c>>>4).toByte;out(j+5)=hex.charAt(c&15).toByte;j+=6
          else
            out(j) = c.toByte
            j += 1
      i+=1
    out(j)=34;j+1
  def benchJson():Unit =
    val n=16000000
    val in=new Array[Byte](n)
    var i=0
    while i < n do
      in(i) = pattern(i % pattern.length)
      i += 1
    val out=new Array[Byte](n*6+2)
    var outn=jsonEscape(in,out)
    val t=new Array[Double](7)
    var r=0
    while r < 7 do
      val a = now()
      outn = jsonEscape(in,out)
      t(r) = now() - a
      r += 1
    var c=outn.toLong;i=0
    while i < outn do
      c += out(i) & 255
      i += 1
    val m=median(t);emit("json_escape",n,m,n.toDouble/m/1e9,c)

  final class Node(val l:Node,val r:Node)
  def makeTree(d:Int):Node = if d==0 then new Node(null,null) else new Node(makeTree(d-1),makeTree(d-1))
  def checkTree(n:Node):Long = if n==null then 0 else 1+checkTree(n.l)+checkTree(n.r)
  def treesOnce(mx:Int):Long =
    var total=checkTree(makeTree(mx+1))
    val longl=makeTree(mx)
    var d=4
    while d<=mx do
      val iters=1 << (mx-d+4)
      var s=0L;var i=0
      while i < iters do
        s += checkTree(makeTree(d))
        i += 1
      total+=s;d+=2
    total+checkTree(longl)
  def benchTrees():Unit =
    val depth=16
    treesOnce(6)
    val t=new Array[Double](7);var c=0L;var r=0
    while r < 7 do
      val a = now()
      c = treesOnce(depth)
      t(r) = now() - a
      r += 1
    val m=median(t);emit("binary_trees",depth,m,1/m,c)

  def mandelbrot(w:Int,maxIter:Int):Long =
    var sum=0L;var y=0
    while y<w do
      val ci = -1.5 + 3.0 * y.toDouble / (w - 1).toDouble
      var x=0
      while x<w do
        val cr = -2.0 + 3.0 * x.toDouble / (w - 1).toDouble
        var zr=0.0;var zi=0.0;var it=0
        while it<maxIter && zr*zr+zi*zi<=4.0 do
          val zr2=zr*zr;val zi2=zi*zi;val nzr=zr2-zi2+cr
          zi=2.0*zr*zi+ci;zr=nzr;it+=1
        sum+=it;x+=1
      y+=1
    sum
  def benchMandel():Unit =
    val w=1600;mandelbrot(128,20)
    val t=new Array[Double](7);var c=0L;var r=0
    while r < 7 do
      val a = now()
      c = mandelbrot(w,50)
      t(r) = now() - a
      r += 1
    val m=median(t);val pix=w.toLong*w;emit("mandelbrot",pix,m,pix.toDouble/m/1e6,c)

  def main(args:Array[String]):Unit =
    (if args.nonEmpty then args(0) else "integer50") match
      case "integer50" => benchInteger()
      case "json_escape" => benchJson()
      case "binary_trees" => benchTrees()
      case "mandelbrot" => benchMandel()
      case _ => sys.error("unknown kernel")
