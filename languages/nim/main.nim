import std/[os, strutils, times, algorithm, strformat]
proc now(): float64 = epochTime()
proc med(a: var seq[float64]): float64 =
  a.sort()
  let n=a.len
  if (n and 1)==1: a[n div 2] else: (a[n div 2-1]+a[n div 2])/2
proc emit(k:string,u:uint64,r:int,s,rate:float64,c:uint64)=
  echo &"RESULT kernel={k} units={u} rounds={r} seconds={s:.9f} rate={rate:.6f} checksum={c}"

proc integer50(n:uint64):uint64 =
  let mask=(1'u64 shl 50)-1
  var x=88172645463325252'u64 and mask
  var sum=0'u64
  for i in 0'u64..<n:
    x=x xor (x shr 7); x=x xor ((x shl 8) and mask); x=x xor (x shr 9); x=x and mask
    sum=(sum+(x xor (x shr 17))) and mask
  sum
proc benchInteger(n:uint64,r:int)=
  discard integer50(n div 20+1)
  var t=newSeq[float64](r); var c=0'u64
  for i in 0..<r:
    let a=now(); c=integer50(n); t[i]=now()-a
  let m=med(t); emit("integer50",n,r,m,float64(n)/m/1e6,c)

const pattern=array[23,uint8]([97'u8,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47])
proc jsonEscape(inp:seq[uint8],outp:var seq[uint8]):int =
  const hex="0123456789abcdef"
  var j=0; outp[j]=34; inc j
  for c in inp:
    case c
    of 34'u8: outp[j]=92;outp[j+1]=34;j+=2
    of 92'u8: outp[j]=92;outp[j+1]=92;j+=2
    of 8'u8: outp[j]=92;outp[j+1]=98;j+=2
    of 12'u8: outp[j]=92;outp[j+1]=102;j+=2
    of 10'u8: outp[j]=92;outp[j+1]=110;j+=2
    of 13'u8: outp[j]=92;outp[j+1]=114;j+=2
    of 9'u8: outp[j]=92;outp[j+1]=116;j+=2
    else:
      if c<32:
        outp[j]=92;outp[j+1]=117;outp[j+2]=48;outp[j+3]=48
        outp[j+4]=uint8(hex[int(c shr 4)].ord);outp[j+5]=uint8(hex[int(c and 15)].ord);j+=6
      else: outp[j]=c;inc j
  outp[j]=34; j+1
proc benchJson(bytes:uint64,r:int)=
  var inp=newSeq[uint8](int(bytes)); var outp=newSeq[uint8](int(bytes)*6+2)
  for i in 0..<inp.len: inp[i]=pattern[i mod pattern.len]
  var outn=jsonEscape(inp,outp); var t=newSeq[float64](r)
  for i in 0..<r:
    let a=now(); outn=jsonEscape(inp,outp); t[i]=now()-a
  var c=uint64(outn)
  for i in 0..<outn: c+=uint64(outp[i])
  let m=med(t); emit("json_escape",bytes,r,m,float64(bytes)/m/1e9,c)

type Node=ref object
  l,r:Node
proc makeTree(d:int):Node =
  new(result)
  if d>0:
    result.l=makeTree(d-1);result.r=makeTree(d-1)
proc checkTree(n:Node):uint64 =
  if n.isNil: 0 else: 1+checkTree(n.l)+checkTree(n.r)
proc treesOnce(mx:int):uint64 =
  let stretch=makeTree(mx+1)
  var total=checkTree(stretch)
  let longl=makeTree(mx)
  var d=4
  while d<=mx:
    let iters=1 shl (mx-d+4)
    var s=0'u64
    for i in 0..<iters:
      let n=makeTree(d)
      s+=checkTree(n)
    total+=s;d+=2
  total+checkTree(longl)
proc benchTrees(depth:uint64,r:int)=
  discard treesOnce(min(int(depth),6))
  var t=newSeq[float64](r);var c=0'u64
  for i in 0..<r:
    let a=now(); c=treesOnce(int(depth)); t[i]=now()-a
  let m=med(t); emit("binary_trees",depth,r,m,1/m,c)

proc mandel(w,maxIter:int):uint64 =
  var sum=0'u64
  for y in 0..<w:
    let ci = -1.5 + 3.0*float64(y)/float64(w-1)
    for x in 0..<w:
      let cr = -2.0 + 3.0*float64(x)/float64(w-1)
      var zr=0.0;var zi=0.0;var it=0
      while it<maxIter:
        let zr2=zr*zr;let zi2=zi*zi
        if zr2+zi2>4.0: break
        let nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;inc it
      sum+=uint64(it)
  sum
proc benchMandel(w:uint64,r:int)=
  discard mandel(min(int(w),128),20)
  var t=newSeq[float64](r);var c=0'u64
  for i in 0..<r:
    let a=now(); c=mandel(int(w),50);t[i]=now()-a
  let m=med(t);let pix=w*w;emit("mandelbrot",pix,r,m,float64(pix)/m/1e6,c)

proc defSize(k:string):uint64 =
  case k
  of "integer50":200000000'u64
  of "json_escape":16000000'u64
  of "binary_trees":16'u64
  of "mandelbrot":1600'u64
  else:0'u64
let k=if paramCount()>=1:paramStr(1) else:"integer50"
let n=if paramCount()>=2:parseUInt(paramStr(2)).uint64 else:defSize(k)
let r=if paramCount()>=3:parseInt(paramStr(3)) else:7
case k
of "integer50":benchInteger(n,r)
of "json_escape":benchJson(n,r)
of "binary_trees":benchTrees(n,r)
of "mandelbrot":benchMandel(n,r)
else:quit(64)
