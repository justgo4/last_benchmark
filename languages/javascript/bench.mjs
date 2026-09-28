import { performance } from 'node:perf_hooks';
const now=()=>performance.now()/1000;
const median=a=>{a.sort((x,y)=>x-y);const n=a.length;return n&1?a[n>>1]:(a[(n>>1)-1]+a[n>>1])/2};
const result=(k,u,r,s,rate,c)=>console.log(`RESULT kernel=${k} units=${u} rounds=${r} seconds=${s.toFixed(9)} rate=${rate.toFixed(6)} checksum=${Math.trunc(c)}`);

function integer50(n){
  let xh=82061, xl=3418323524>>>0, sh=0, sl=0;
  for(let i=0;i<n;i++){
    let rh=xh>>>7, rl=((xl>>>7)|((xh&0x7f)<<25))>>>0; xh=(xh^rh)&0x3ffff; xl=(xl^rl)>>>0;
    let lh=((xh<<8)|(xl>>>24))&0x3ffff, ll=(xl<<8)>>>0; xh=(xh^lh)&0x3ffff; xl=(xl^ll)>>>0;
    rh=xh>>>9; rl=((xl>>>9)|((xh&0x1ff)<<23))>>>0; xh=(xh^rh)&0x3ffff; xl=(xl^rl)>>>0;
    rh=xh>>>17; rl=((xl>>>17)|((xh&0x1ffff)<<15))>>>0;
    const th=(xh^rh)&0x3ffff, tl=(xl^rl)>>>0;
    const lo=sl+tl, nlo=lo>>>0, carry=lo>=4294967296?1:0;
    sl=nlo; sh=(sh+th+carry)&0x3ffff;
  }
  return sh*4294967296+sl;
}
function benchInteger(n,rounds){integer50(Math.floor(n/20)+1);const t=[];let c=0;for(let r=0;r<rounds;r++){const a=now();c=integer50(n);t.push(now()-a)}const m=median(t);result('integer50',n,rounds,m,n/m/1e6,c)}

const laneAt=(i,p)=>Math.floor(((i*1103515245+12345)/256))%p;
function stablePartition(lanes,p,order,counts,cursor){counts.fill(0);for(let i=0;i<lanes.length;i++){const l=lanes[i];if(l>=p)throw Error('lane');counts[l]++}let off=0;for(let l=0;l<p;l++){cursor[l]=off;off+=counts[l]}for(let i=0;i<lanes.length;i++){const l=lanes[i];order[cursor[l]++]=i}}
function checksumOrder(p){let h=0;for(let i=0;i<p.length;i++)h+=(p[i]%1000003)+((i*17)%1000003);return h}
function benchPartition(n,rounds){const parts=16,lanes=new Uint16Array(n),order=new Float64Array(n),counts=new Float64Array(parts),cursor=new Float64Array(parts);for(let i=0;i<n;i++)lanes[i]=laneAt(i,parts);stablePartition(lanes,parts,order,counts,cursor);const t=[];for(let r=0;r<rounds;r++){const a=now();stablePartition(lanes,parts,order,counts,cursor);t.push(now()-a)}let covered=0;for(const v of counts)covered+=v;if(covered!==n)throw Error('covered');const c=checksumOrder(order),m=median(t);result('stable_partition',n,rounds,m,n/m/1e6,c)}

const u16=(b,o)=>(b[o]|(b[o+1]<<8))>>>0;
const u24=(b,o)=>(b[o]|(b[o+1]<<8)|(b[o+2]<<16))>>>0;
const u32=(b,o)=>(b[o]+b[o+1]*256+b[o+2]*65536+b[o+3]*16777216);
const u64=(b,o)=>u32(b,o)+u32(b,o+4)*4294967296;
function put16(b,o,v){b[o]=v;b[o+1]=v>>>8}function put24(b,o,v){b[o]=v;b[o+1]=v>>>8;b[o+2]=v>>>16}
function put32(b,o,v){for(let i=0;i<4;i++)b[o+i]=Math.floor(v/2**(8*i))&255}
function put64(b,o,v){const lo=v>>>0,hi=Math.floor(v/4294967296)>>>0;put32(b,o,lo);put32(b,o+4,hi)}
const BIN=35;
function makeBin(b,o,i){const k=i&3;b[o]=k;if(k===0){b[o+1]=i%250;b.fill(0,o+2,o+10)}else if(k===1){b[o+1]=0xfc;put16(b,o+2,i);b.fill(0,o+4,o+10)}else if(k===2){b[o+1]=0xfd;put24(b,o+2,i);b.fill(0,o+5,o+10)}else{b[o+1]=0xfe;put64(b,o+2,i)}for(let j=0;j<8;j++)b[o+10+j]=((Math.floor(i/2**(j%6)))^(0xA5+j))&255;put16(b,o+18,i*3);put24(b,o+20,i*5);put32(b,o+23,i*7);put64(b,o+27,i*11+17)}
function bitCount(b,o){let c=0;for(let i=0;i<64;i++)c+=(b[o+(i>>3)]>>(i&7))&1;return c}
function decodeBin(b,rows){let h=0;for(let i=0;i<rows;i++){const o=i*BIN,k=b[o];let pos=o+1,f=b[pos++],le;if(f<0xfb)le=f;else if(f===0xfc){le=u16(b,pos);pos+=2}else if(f===0xfd){le=u24(b,pos);pos+=3}else if(f===0xfe){le=u64(b,pos);pos+=8}else throw Error('lenenc');pos=o+10;const bc=bitCount(b,pos);pos+=8;const v16=u16(b,pos);pos+=2;const v24=u24(b,pos);pos+=3;const v32=u32(b,pos);pos+=4;const v64=u64(b,pos);h+=k+le+bc+v16+v24+v32+v64}return h}
function benchBinary(rows,rounds){const b=Buffer.allocUnsafe(rows*BIN);for(let i=0;i<rows;i++)makeBin(b,i*BIN,i);decodeBin(b,rows);const t=[];let c=0;for(let r=0;r<rounds;r++){const a=now();c=decodeBin(b,rows);t.push(now()-a)}const m=median(t);result('binary_decode',rows,rounds,m,b.length/m/1e9,c)}

const M=1000003, TWO32MOD=4294967296%M;
function parseU64PairMod(b,o,n){let hi=0,lo=0;for(let i=0;i<n;i++){const d=b[o+i]-48;const prod=lo*10+d;lo=prod>>>0;const carry=Math.floor(prod/4294967296);hi=(hi*10+carry)>>>0}return ((hi%M)*TWO32MOD+(lo%M))%M}
function digits(b,o,n){let v=0;for(let i=0;i<n;i++)v=v*10+(b[o+i]-48);return v}
function daysFromCivil(y,m,d){y-=m<=2?1:0;const era=Math.floor((y>=0?y:y-399)/400),yoe=y-era*400,mp=m>2?m-3:m+9,doy=Math.floor((153*mp+2)/5)+d-1,doe=yoe*365+Math.floor(yoe/4)-Math.floor(yoe/100)+doy;return era*146097+doe-719468}
function parseDT(b,o){const y=digits(b,o,4),mo=digits(b,o+5,2),d=digits(b,o+8,2),h=digits(b,o+11,2),mi=digits(b,o+14,2),s=digits(b,o+17,2),us=digits(b,o+20,6);return ((daysFromCivil(y,mo,d)*86400+h*3600+mi*60+s)*1000000)+us}
const TEXT=46,PREFIX=Buffer.from('2026-09-28 19:39:12.','ascii');
function writeDigits(b,o,n,v){for(let j=n-1;j>=0;j--){b[o+j]=48+(v%10);v=Math.floor(v/10)}}
function makeText(b,o,i){b[o]=(i&1)?45:43;const v=100000000000000000n+BigInt(i);for(let j=17;j>=0;j--){b[o+1+j]=48+Number(v/10n**BigInt(17-j)%10n)}b[o+19]=124;PREFIX.copy(b,o+20);writeDigits(b,o+40,6,i%1000000)}
function parseTexts(b,rows){let h=0;for(let i=0;i<rows;i++){const o=i*TEXT,rem=parseU64PairMod(b,o+1,18),ts=parseDT(b,o+20);h+=rem+(ts%M)}return h}
function benchText(rows,rounds){const b=Buffer.allocUnsafe(rows*TEXT);for(let i=0;i<rows;i++)makeText(b,i*TEXT,i);parseTexts(b,rows);const t=[];let c=0;for(let r=0;r<rounds;r++){const a=now();c=parseTexts(b,rows);t.push(now()-a)}const m=median(t);result('text_parse',rows,rounds,m,rows/m/1e6,c)}

const PATTERN=Buffer.from([97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]);
function fillJSON(b){for(let i=0;i<b.length;i++)b[i]=PATTERN[i%PATTERN.length]}
function jsonEscape(input,out){const hex='0123456789abcdef';let j=0;out[j++]=34;for(let i=0;i<input.length;i++){const c=input[i];if(c===34){out[j++]=92;out[j++]=34}else if(c===92){out[j++]=92;out[j++]=92}else if(c===8){out[j++]=92;out[j++]=98}else if(c===12){out[j++]=92;out[j++]=102}else if(c===10){out[j++]=92;out[j++]=110}else if(c===13){out[j++]=92;out[j++]=114}else if(c===9){out[j++]=92;out[j++]=116}else if(c<32){out[j++]=92;out[j++]=117;out[j++]=48;out[j++]=48;out[j++]=hex.charCodeAt(c>>4);out[j++]=hex.charCodeAt(c&15)}else out[j++]=c}out[j++]=34;return j}
function benchJSON(bytes,rounds){const input=Buffer.allocUnsafe(bytes),out=Buffer.allocUnsafe(bytes*6+2);fillJSON(input);let outn=jsonEscape(input,out);const t=[];for(let r=0;r<rounds;r++){const a=now();outn=jsonEscape(input,out);t.push(now()-a)}let c=outn;for(let i=0;i<outn;i++)c+=out[i];const m=median(t);result('json_escape',bytes,rounds,m,bytes/m/1e9,c)}

class Node{constructor(d){this.l=null;this.r=null;if(d>0){this.l=new Node(d-1);this.r=new Node(d-1)}}}
function checkTree(n){return n===null?0:1+checkTree(n.l)+checkTree(n.r)}
function treesOnce(maxDepth){const minDepth=4;let stretch=new Node(maxDepth+1),total=checkTree(stretch);stretch=null;const longLived=new Node(maxDepth);for(let depth=minDepth;depth<=maxDepth;depth+=2){const iters=2**(maxDepth-depth+minDepth);let s=0;for(let i=0;i<iters;i++){const n=new Node(depth);s+=checkTree(n)}total+=s}total+=checkTree(longLived);return total}
function benchTrees(depth,rounds){treesOnce(Math.min(depth,6));const t=[];let c=0;for(let r=0;r<rounds;r++){const a=now();c=treesOnce(depth);t.push(now()-a)}const m=median(t);result('binary_trees',depth,rounds,m,1/m,c)}

function mandelbrot(width,maxIter){let sum=0;for(let y=0;y<width;y++){const ci=-1.5+3*y/(width-1);for(let x=0;x<width;x++){const cr=-2+3*x/(width-1);let zr=0,zi=0,it=0;while(it<maxIter){const zr2=zr*zr,zi2=zi*zi;if(zr2+zi2>4)break;const nzr=zr2-zi2+cr;zi=2*zr*zi+ci;zr=nzr;it++}sum+=it}}return sum}
function benchMandel(width,rounds){mandelbrot(Math.min(width,128),20);const t=[];let c=0;for(let r=0;r<rounds;r++){const a=now();c=mandelbrot(width,50);t.push(now()-a)}const m=median(t),pix=width*width;result('mandelbrot',pix,rounds,m,pix/m/1e6,c)}

function defaultSize(k){return {integer50:200000000,stable_partition:5000000,binary_decode:5000000,text_parse:5000000,json_escape:16000000,binary_trees:16,mandelbrot:1600}[k]??0}
function runOne(k,size,rounds){({integer50:benchInteger,stable_partition:benchPartition,binary_decode:benchBinary,text_parse:benchText,json_escape:benchJSON,binary_trees:benchTrees,mandelbrot:benchMandel}[k])(size,rounds)}
const args=process.argv.slice(2),k=args[0]??'all',rounds=args[2]?Number(args[2]):7;if(k==='all'){for(const q of ['integer50','stable_partition','binary_decode','text_parse','json_escape','binary_trees','mandelbrot'])runOne(q,defaultSize(q),rounds)}else runOne(k,args[1]?Number(args[1]):defaultSize(k),rounds);
