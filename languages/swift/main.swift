import Foundation
import Dispatch

@_silgen_name("bench_black_box_u64") func blackBox(_ x: UInt64) -> UInt64

@inline(__always) func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) * 1e-9 }
func median(_ a:[Double]) -> Double { let b=a.sorted(); return b.count % 2 == 1 ? b[b.count/2] : (b[b.count/2-1]+b[b.count/2])/2 }
func emit(_ k:String,_ u:UInt64,_ r:Int,_ s:Double,_ rate:Double,_ c:UInt64){ print(String(format:"RESULT kernel=%@ units=%llu rounds=%d seconds=%.9f rate=%.6f checksum=%llu",k,u,r,s,rate,c)) }

@inline(never) func integer50(_ n:UInt64)->UInt64{let mask=(UInt64(1)<<50)-1;var x=UInt64(88172645463325252)&mask;var sum:UInt64=0;var i:UInt64=0;while i<n{x ^= x>>7;x ^= (x<<8)&mask;x ^= x>>9;x &= mask;sum=(sum &+ (x ^ (x>>17))) & mask;i+=1};return sum}
func benchInteger(_ n:UInt64,_ r:Int){_ = integer50(n/20+1);var t=[Double]();var c:UInt64=0;for _ in 0..<r{let nn=blackBox(n);let a=now();c=blackBox(integer50(nn));t.append(now()-a)};let m=median(t);emit("integer50",n,r,m,Double(n)/m/1e6,c)}

let pattern:[UInt8]=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]
func jsonEscape(_ input:[UInt8],_ out:inout [UInt8])->Int{let hex=Array("0123456789abcdef".utf8);var j=0;out[j]=34;j+=1;for c in input{switch c{case 34:out[j]=92;out[j+1]=34;j+=2;case 92:out[j]=92;out[j+1]=92;j+=2;case 8:out[j]=92;out[j+1]=98;j+=2;case 12:out[j]=92;out[j+1]=102;j+=2;case 10:out[j]=92;out[j+1]=110;j+=2;case 13:out[j]=92;out[j+1]=114;j+=2;case 9:out[j]=92;out[j+1]=116;j+=2;default:if c<32{out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=hex[Int(c>>4)];out[j+5]=hex[Int(c&15)];j+=6}else{out[j]=c;j+=1}}};out[j]=34;return j+1}
func benchJSON(_ bytes:UInt64,_ r:Int){var input=[UInt8](repeating:0,count:Int(bytes));for i in input.indices{input[i]=pattern[i%pattern.count]};var out=[UInt8](repeating:0,count:Int(bytes)*6+2);var outn=jsonEscape(input,&out);var t=[Double]();for _ in 0..<r{let a=now();outn=jsonEscape(input,&out);t.append(now()-a)};var c=UInt64(outn);for i in 0..<outn{c += UInt64(out[i])};let m=median(t);emit("json_escape",bytes,r,m,Double(bytes)/m/1e9,c)}

final class Node{var l:Node?;var r:Node?;init(_ d:Int){if d>0{l=Node(d-1);r=Node(d-1)}}}
func checkTree(_ n:Node?)->UInt64{guard let n=n else{return 0};return 1+checkTree(n.l)+checkTree(n.r)}
@inline(never) func treesOnce(_ mx:Int)->UInt64{let stretch=Node(mx+1);var total=checkTree(stretch);let longl=Node(mx);var d=4;while d<=mx{let iters=1<<(mx-d+4);var s:UInt64=0;for _ in 0..<iters{let n=Node(d);s+=checkTree(n)};total+=s;d+=2};return total+checkTree(longl)}
func benchTrees(_ depth:UInt64,_ r:Int){_ = treesOnce(min(Int(depth),6));var t=[Double]();var c:UInt64=0;for _ in 0..<r{let dd=blackBox(depth);let a=now();c=blackBox(treesOnce(Int(dd)));t.append(now()-a)};let m=median(t);emit("binary_trees",depth,r,m,1/m,c)}

@inline(never) func mandel(_ w:Int,_ maxIter:Int)->UInt64{var sum:UInt64=0;for y in 0..<w{let ci = -1.5 + 3.0*Double(y)/Double(w-1);for x in 0..<w{let cr = -2.0 + 3.0*Double(x)/Double(w-1);var zr=0.0,zi=0.0;var it=0;while it<maxIter{let zr2=zr*zr,zi2=zi*zi;if zr2+zi2>4.0{break};let nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;it+=1};sum+=UInt64(it)}};return sum}
func benchMandel(_ w:UInt64,_ r:Int){_ = mandel(min(Int(w),128),20);var t=[Double]();var c:UInt64=0;for _ in 0..<r{let ww=blackBox(w);let a=now();c=blackBox(mandel(Int(ww),50));t.append(now()-a)};let m=median(t),pix=w*w;emit("mandelbrot",pix,r,m,Double(pix)/m/1e6,c)}

func defSize(_ k:String)->UInt64{switch k{case "integer50":return 200000000;case "json_escape":return 16000000;case "binary_trees":return 16;case "mandelbrot":return 1600;default:return 0}}
let args=CommandLine.arguments;let k=args.count>1 ? args[1]:"integer50";let n=args.count>2 ? UInt64(args[2])!:defSize(k);let r=args.count>3 ? Int(args[3])!:7
switch k{case "integer50":benchInteger(n,r);case "json_escape":benchJSON(n,r);case "binary_trees":benchTrees(n,r);case "mandelbrot":benchMandel(n,r);default:exit(64)}
