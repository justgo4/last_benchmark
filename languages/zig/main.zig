const std = @import("std");
extern fn bench_black_box_u64(x: u64) u64;
const c = @cImport({ @cInclude("time.h"); });

fn now() f64 {
    var ts: c.struct_timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_MONOTONIC, &ts);
    return @as(f64,@floatFromInt(ts.tv_sec)) + @as(f64,@floatFromInt(ts.tv_nsec))*1e-9;
}
fn median(v:*[7]f64) f64 {
    var i:usize=1;
    while(i<7):(i+=1){const x=v[i];var j=i;while(j>0 and v[j-1]>x):(j-=1)v[j]=v[j-1];v[j]=x;}
    return v[3];
}
fn emit(k:[]const u8,u:u64,s:f64,rate:f64,ck:u64) void {
    std.debug.print("RESULT kernel={s} units={d} rounds=7 seconds={d:.9} rate={d:.6} checksum={d}\n",.{k,u,s,rate,ck});
}
fn mix32(x0:u32) u32 {var x=x0 +% 0x9e3779b9;x^=x>>16;x*%=0x85ebca6b;x^=x>>13;x*%=0xc2b2ae35;return x^(x>>16);}
fn hash32(x0:u32) u32 {var x=x0;x^=x>>16;x*%=0x7feb352d;x^=x>>15;x*%=0x846ca68b;return x^(x>>16);}
fn ck32(a:[]const u32) u32 {var h:u32=2166136261;for(a)|x|{h^=x;h*%=16777619;}return h;}
fn ckI32(a:[]const i32) u32 {var h:u32=2166136261;for(a)|x|{h^=@bitCast(x);h*%=16777619;}return h;}
fn ck64(a:[]const u64) u32 {var h:u32=2166136261;for(a)|x|{h^=@truncate(x);h*%=16777619;h^=@truncate(x>>32);h*%=16777619;}return h;}

noinline fn integer50(n:u64)u64{const mask:u64=(@as(u64,1)<<50)-1;var x:u64=88172645463325252&mask;var s:u64=0;var i:u64=0;while(i<n):(i+=1){x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;s=(s+%(x^(x>>17)))&mask;}return s;}
fn benchInteger(n:u64)void{_ = integer50(n/20+1);var t:[7]f64=undefined;var ck:u64=0;for(0..7)|r|{const a=now();ck=bench_black_box_u64(integer50(bench_black_box_u64(n)));t[r]=now()-a;}const m=median(&t);emit("integer50",n,m,@as(f64,@floatFromInt(n))/m/1e6,ck);}

const pat=[_]u8{97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47};
fn jsonEscape(input:[]const u8,out:[]u8)usize{const hx="0123456789abcdef";var j:usize=0;out[j]=34;j+=1;for(input)|ch|{switch(ch){34=>{out[j]=92;out[j+1]=34;j+=2;},92=>{out[j]=92;out[j+1]=92;j+=2;},8=>{out[j]=92;out[j+1]=98;j+=2;},12=>{out[j]=92;out[j+1]=102;j+=2;},10=>{out[j]=92;out[j+1]=110;j+=2;},13=>{out[j]=92;out[j+1]=114;j+=2;},9=>{out[j]=92;out[j+1]=116;j+=2;},else=>{if(ch<32){out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=hx[ch>>4];out[j+5]=hx[ch&15];j+=6;}else{out[j]=ch;j+=1;}}}}out[j]=34;return j+1;}
fn benchJson(nu:u64)!void{const n:usize=@intCast(nu);const a=std.heap.c_allocator;const input=try a.alloc(u8,n);defer a.free(input);const out=try a.alloc(u8,n*6+2);defer a.free(out);for(input,0..)|*p,i|p.*=pat[i%23];var on=jsonEscape(input,out);var t:[7]f64=undefined;for(0..7)|r|{const s=now();on=jsonEscape(input,out);t[r]=now()-s;}var ck:u64=on;for(out[0..on])|b|ck+=b;const m=median(&t);emit("json_escape",nu,m,@as(f64,@floatFromInt(n))/m/1e9,ck);}

fn mergeSort(a:[]u32,tmp:[]u32)void{const n=a.len;var src=a;var dst=tmp;var flip=false;var w:usize=1;while(w<n){var lo:usize=0;while(lo<n):(lo+=2*w){const mid=@min(lo+w,n);const hi=@min(lo+2*w,n);var i=lo;var j=mid;var k=lo;while(i<mid and j<hi){if(src[i]<=src[j]){dst[k]=src[i];i+=1;}else{dst[k]=src[j];j+=1;}k+=1;}while(i<mid){dst[k]=src[i];i+=1;k+=1;}while(j<hi){dst[k]=src[j];j+=1;k+=1;}}const z=src;src=dst;dst=z;flip=!flip;if(w>n/2)break;w*=2;}if(flip)@memcpy(a,src);}
fn benchMerge(nu:u64)!void{const n:usize=@intCast(nu);const al=std.heap.c_allocator;const base=try al.alloc(u32,n);defer al.free(base);const a=try al.alloc(u32,n);defer al.free(a);const tmp=try al.alloc(u32,n);defer al.free(tmp);for(base,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;for(0..7)|r|{@memcpy(a,base);const s=now();mergeSort(a,tmp);t[r]=now()-s;}const m=median(&t);emit("merge_sort",nu,m,@as(f64,@floatFromInt(n))/m/1e6,ck32(a));}

fn bs(a:[]const u32,x:u32)i32{var l:usize=0;var h=a.len;while(l<h){const m=l+(h-l)/2;if(a[m]<x)l=m+1 else h=m;}return if(l<a.len and a[l]==x)@intCast(l) else -1;}
fn benchBS(nu:u64)!void{const n:usize=@intCast(nu);const nq=n*4;const al=std.heap.c_allocator;const a=try al.alloc(u32,n);defer al.free(a);const q=try al.alloc(u32,nq);defer al.free(q);for(a,0..)|*p,i|p.*=@intCast(i*2);for(q,0..)|*p,i|p.*=mix32(@intCast(i))%@as(u32,@intCast(2*n));var t:[7]f64=undefined;var ck:u64=0;for(0..7)|r|{const s=now();ck=0;for(q)|x|{const p=bs(a,x);if(p>=0)ck+=@as(u64,@intCast(p))+1;}t[r]=now()-s;}const m=median(&t);emit("binary_search",nq,m,@as(f64,@floatFromInt(nq))/m/1e6,ck);}

fn benchPrefix(nu:u64)!void{const n:usize=@intCast(nu);const al=std.heap.c_allocator;const input=try al.alloc(u32,n);defer al.free(input);const out=try al.alloc(u64,n);defer al.free(out);for(input,0..)|*p,i|p.*=mix32(@intCast(i))&1023;var t:[7]f64=undefined;var ck:u64=0;for(0..7)|r|{const st=now();ck=0;for(0..16)|pass|{var s:u64=pass;for(input,0..)|x,i|{s+=x;out[i]=s;}ck^=s;}t[r]=now()-st;}ck^=ck64(out);const m=median(&t);emit("prefix_sum",nu*16,m,@as(f64,@floatFromInt(n))*16/m/1e6,ck);}

fn benchMM(nu:u64)!void{
    const n:usize=@intCast(nu);
    const nn=n*n;
    const al=std.heap.c_allocator;
    const a=try al.alloc(u32,nn); defer al.free(a);
    const b=try al.alloc(u32,nn); defer al.free(b);
    const out=try al.alloc(u64,nn); defer al.free(out);
    for(0..nn)|i|{
        a[i]=mix32(@intCast(i))&15;
        b[i]=mix32(@intCast(i+nn))&15;
    }
    var t:[7]f64=undefined;
    for(0..7)|r|{
        const st=now();
        for(0..n)|i|{
            for(0..n)|j|{
                var s:u64=0;
                for(0..n)|k|{
                    s += @as(u64,a[i*n+k]) * b[k*n+j];
                }
                out[i*n+j]=s;
            }
        }
        t[r]=now()-st;
    }
    const m=median(&t);
    emit("matrix_mul",nu,m,@as(f64,@floatFromInt(n*n*n))/m/1e6,ck64(out));
}

fn fillGraph(a:[]u32,w:?[]u32,n:usize,d:usize)void{
    for(0..n)|i|{
        for(0..d)|e|{
            const p=i*d+e;
            a[p]=if(e==0)
                @intCast((i+1)%n)
            else if(e==1)
                @intCast((i+n-1)%n)
            else
                mix32(@intCast(p))%@as(u32,@intCast(n));
            if(w)|ww|{
                ww[p]=1+(mix32(0xabc00000+%@as(u32,@intCast(p)))&15);
            }
        }
    }
}
fn benchBFS(nu:u64)!void{const n:usize=@intCast(nu);const d:usize=4;const passes:usize=16;const al=std.heap.c_allocator;const a=try al.alloc(u32,n*d);defer al.free(a);const dist=try al.alloc(i32,n);defer al.free(dist);const q=try al.alloc(u32,n);defer al.free(q);fillGraph(a,null,n,d);var t:[7]f64=undefined;var seen:u32=0;for(0..7)|r|{const st=now();for(0..passes)|p|{@memset(dist,-1);var h:usize=0;var tt:usize=0;dist[0]=0;q[tt]=0;tt+=1;while(h<tt){const u=q[h];h+=1;const nd=dist[u]+1;for(0..d)|e|{const v=a[@as(usize,u)*d+e];if(dist[v]<0){dist[v]=nd;q[tt]=v;tt+=1;}}}seen^=@as(u32,@intCast(tt+p));}t[r]=now()-st;}const m=median(&t);emit("bfs",nu*passes,m,@as(f64,@floatFromInt(n*d*passes))/m/1e6,ckI32(dist)^seen);}

const HP=struct{d:u64,v:u32};
fn hpPush(h:[]HP,sz:*usize,x:HP)void{var i=sz.*;sz.*+=1;while(i>0){const p=(i-1)/2;if(h[p].d<=x.d)break;h[i]=h[p];i=p;}h[i]=x;}
fn hpPop(h:[]HP,sz:*usize)HP{const o=h[0];sz.*-=1;const x=h[sz.*];var i:usize=0;while(true){const l=i*2+1;if(l>=sz.*)break;const rr=l+1;const cc=if(rr<sz.* and h[rr].d<h[l].d)rr else l;if(h[cc].d>=x.d)break;h[i]=h[cc];i=cc;}if(sz.*>0)h[i]=x;return o;}
fn benchDij(nu:u64)!void{const n:usize=@intCast(nu);const d:usize=4;const al=std.heap.c_allocator;const a=try al.alloc(u32,n*d);defer al.free(a);const w=try al.alloc(u32,n*d);defer al.free(w);const dist=try al.alloc(u64,n);defer al.free(dist);const heap=try al.alloc(HP,n*d*4);defer al.free(heap);fillGraph(a,w,n,d);var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();@memset(dist,std.math.maxInt(u64)/4);var sz:usize=0;dist[0]=0;hpPush(heap,&sz,.{.d=0,.v=0});while(sz>0){const x=hpPop(heap,&sz);if(x.d!=dist[x.v])continue;for(0..d)|e|{const p=@as(usize,x.v)*d+e;const v=a[p];const nd=x.d+w[p];if(nd<dist[v]){dist[v]=nd;hpPush(heap,&sz,.{.d=nd,.v=v});}}}ck=ck64(dist);t[r]=now()-st;}const m=median(&t);emit("dijkstra",nu,m,@as(f64,@floatFromInt(n*d))/m/1e6,ck);}

fn ufFind(p:[]u32,x0:u32)u32{var x=x0;while(p[x]!=x){p[x]=p[p[x]];x=p[x];}return x;}
fn benchUF(nu:u64)!void{const n:usize=@intCast(nu);const ops=n*4;const al=std.heap.c_allocator;const p=try al.alloc(u32,n);defer al.free(p);const rank=try al.alloc(u8,n);defer al.free(rank);const aa=try al.alloc(u32,ops);defer al.free(aa);const bb=try al.alloc(u32,ops);defer al.free(bb);for(0..ops)|i|{aa[i]=mix32(@intCast(i))%@as(u32,@intCast(n));bb[i]=mix32(@intCast(i+ops))%@as(u32,@intCast(n));}var t:[7]f64=undefined;for(0..7)|r|{const st=now();for(p,0..)|*x,i|{x.*=@intCast(i);rank[i]=0;}for(0..ops)|i|{var ra=ufFind(p,aa[i]);var rb=ufFind(p,bb[i]);if(ra!=rb){if(rank[ra]<rank[rb]){const z=ra;ra=rb;rb=z;}p[rb]=ra;if(rank[ra]==rank[rb])rank[ra]+=1;}}t[r]=now()-st;}for(p,0..)|*x,i|x.*=ufFind(p,@intCast(i));const m=median(&t);emit("union_find",ops,m,@as(f64,@floatFromInt(ops))/m/1e6,ck32(p));}

noinline fn mandel(w:u32,mi:u32)u64{var sum:u64=0;var y:u32=0;while(y<w):(y+=1){const ci=-1.5+3.0*@as(f64,@floatFromInt(y))/@as(f64,@floatFromInt(w-1));var x:u32=0;while(x<w):(x+=1){const cr=-2.0+3.0*@as(f64,@floatFromInt(x))/@as(f64,@floatFromInt(w-1));var zr:f64=0;var zi:f64=0;var it:u32=0;while(it<mi):(it+=1){const aa=zr*zr;const bb=zi*zi;if(aa+bb>4)break;const nz=aa-bb+cr;zi=2*zr*zi+ci;zr=nz;}sum+=it;}}return sum;}
fn benchMandel(wu:u64)void{const w:u32=@intCast(wu);_ = mandel(@min(w,128),20);var t:[7]f64=undefined;var ck:u64=0;for(0..7)|r|{const st=now();ck=bench_black_box_u64(mandel(@intCast(bench_black_box_u64(w)),50));t[r]=now()-st;}const m=median(&t);emit("mandelbrot",wu*wu,m,@as(f64,@floatFromInt(wu*wu))/m/1e6,ck);}

fn benchVA(nu:u64)!void{const n:usize=@intCast(nu);const al=std.heap.c_allocator;const input=try al.alloc(u32,n);defer al.free(input);for(input,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();var v=try al.alloc(u32,8);var len:usize=0;for(input)|x|{if(len==v.len)v=try al.realloc(v,v.len*2);v[len]=x;len+=1;}var h:u32=2166136261;for(0..len)|i|{v[i]^=@intCast(i);h^=v[i];h*%=16777619;}while(len>0){len-=1;h^=v[len]+%@as(u32,@intCast(len));h*%=16777619;}al.free(v);ck=h;t[r]=now()-st;}const m=median(&t);emit("dynamic_array",nu,m,@as(f64,@floatFromInt(n))/m/1e6,ck);}

fn benchLL(nu:u64)!void{const n:usize=@intCast(nu);const passes:usize=16;const al=std.heap.c_allocator;const next=try al.alloc(u32,n);defer al.free(next);const val=try al.alloc(u32,n);defer al.free(val);const base=try al.alloc(u32,n);defer al.free(base);for(base,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();@memcpy(val,base);for(next,0..)|*p,i|p.*=if(i+1<n)@intCast(i+1) else std.math.maxInt(u32);const B:usize=64;var b:usize=0;while(b<n):(b+=B){const hi=@min(b+B,n)-1;var i=b;while(i<=hi):(i+=1)p: { next[i]=if(i==b)if(hi+1<n)@intCast(hi+1) else std.math.maxInt(u32) else @intCast(i-1); break :p; }}var h:u32=2166136261;for(0..passes)|pass|{var cur:u32=if(B<n)B-1 else @intCast(n-1);var seen:usize=0;while(cur!=std.math.maxInt(u32) and seen<n){const u:usize=cur;val[u]^=@intCast(seen+pass);h^=val[u]+%cur+%@as(u32,@intCast(pass));h*%=16777619;cur=next[u];seen+=1;}h^=@intCast(seen);h*%=16777619;}ck=h;t[r]=now()-st;}const m=median(&t);emit("linked_list",nu*passes,m,@as(f64,@floatFromInt(n*passes))/m/1e6,ck);}

fn benchQR(opsu:u64)!void{const ops:usize=@intCast(opsu);const cap=ops/2+1024;const al=std.heap.c_allocator;const b=try al.alloc(u32,cap);defer al.free(b);const input=try al.alloc(u32,ops);defer al.free(input);for(input,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();var h:usize=0;var tt:usize=0;var cnt:usize=0;var z:u32=0;for(input,0..)|x,i|{if((i&3)!=3){if(cnt==cap){z^=b[h];h=(h+1)%cap;cnt-=1;}b[tt]=x;tt=(tt+1)%cap;cnt+=1;}else if(cnt>0){z^=b[h];h=(h+1)%cap;cnt-=1;}}while(cnt>0){z^=b[h];h=(h+1)%cap;cnt-=1;}ck=z;t[r]=now()-st;}const m=median(&t);emit("queue_ring",opsu,m,@as(f64,@floatFromInt(ops))/m/1e6,ck);}

fn np2(x:usize)usize{var p:usize=1;while(p<x)p<<=1;return p;}
fn benchHT(nu:u64)!void{const n:usize=@intCast(nu);const cap=np2(n*2);const mask=cap-1;const al=std.heap.c_allocator;const keys=try al.alloc(u32,cap);defer al.free(keys);const vals=try al.alloc(u32,cap);defer al.free(vals);const ik=try al.alloc(u32,n);defer al.free(ik);const iv=try al.alloc(u32,n);defer al.free(iv);for(0..n)|i|{ik[i]=mix32(@intCast(i))|1;iv[i]=mix32(@as(u32,@intCast(i))+%0x55555555);}var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();@memset(keys,0);for(0..n)|i|{const key=ik[i];var p=@as(usize,hash32(key))&mask;while(keys[p]!=0 and keys[p]!=key)p=(p+1)&mask;keys[p]=key;vals[p]=iv[i];}var h:u32=0;for(0..n)|i|{const key=ik[i];var p=@as(usize,hash32(key))&mask;while(keys[p]!=key)p=(p+1)&mask;vals[p]^=@intCast(i);h^=vals[p];}ck=h;t[r]=now()-st;}const m=median(&t);emit("hash_table",nu,m,@as(f64,@floatFromInt(n*2))/m/1e6,ck);}

fn hp32Push(h:[]u32,sz:*usize,x:u32)void{var i=sz.*;sz.*+=1;while(i>0){const p=(i-1)/2;if(h[p]<=x)break;h[i]=h[p];i=p;}h[i]=x;}
fn hp32Pop(h:[]u32,sz:*usize)u32{const o=h[0];sz.*-=1;const x=h[sz.*];var i:usize=0;while(true){const l=i*2+1;if(l>=sz.*)break;const rr=l+1;const cc=if(rr<sz.* and h[rr]<h[l])rr else l;if(h[cc]>=x)break;h[i]=h[cc];i=cc;}if(sz.*>0)h[i]=x;return o;}
fn benchBH(nu:u64)!void{const n:usize=@intCast(nu);const al=std.heap.c_allocator;const h=try al.alloc(u32,n);defer al.free(h);const input=try al.alloc(u32,n);defer al.free(input);for(input,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();var sz:usize=0;for(input)|x|hp32Push(h,&sz,x);var z:u32=0;for(0..n)|i|z^=hp32Pop(h,&sz)+%@as(u32,@intCast(i));ck=z;t[r]=now()-st;}const m=median(&t);emit("binary_heap",nu,m,@as(f64,@floatFromInt(n*2))/m/1e6,ck);}

fn benchBST(nu:u64)!void{const n:usize=@intCast(nu);const al=std.heap.c_allocator;const keys=try al.alloc(u32,n);defer al.free(keys);const left=try al.alloc(i32,n);defer al.free(left);const right=try al.alloc(i32,n);defer al.free(right);const input=try al.alloc(u32,n);defer al.free(input);for(input,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();var root:i32=-1;for(input,0..)|key,i|{keys[i]=key;left[i]=-1;right[i]=-1;if(root<0){root=@intCast(i);continue;}var cur=root;while(true){const u:usize=@intCast(cur);if(key<keys[u]){if(left[u]<0){left[u]=@intCast(i);break;}cur=left[u];}else{if(right[u]<0){right[u]=@intCast(i);break;}cur=right[u];}}}var h:u32=0;var i:usize=0;while(i<n):(i+=3){const key=input[i];var cur=root;while(cur>=0 and keys[@intCast(cur)]!=key){const u:usize=@intCast(cur);cur=if(key<keys[u])left[u] else right[u];}if(cur>=0)h^=@as(u32,@intCast(cur))+1;}ck=h;t[r]=now()-st;}const m=median(&t);emit("bst",nu,m,@as(f64,@floatFromInt(n))/m/1e6,ck);}

fn benchTrie(nu:u64)!void{const n:usize=@intCast(nu);const passes:usize=32;const mx=1+n*8;const al=std.heap.c_allocator;const ch=try al.alloc(i32,mx*16);defer al.free(ch);const term=try al.alloc(u8,mx);defer al.free(term);const words=try al.alloc(u32,n);defer al.free(words);for(words,0..)|*p,i|p.*=mix32(@intCast(i));var t:[7]f64=undefined;var ck:u32=0;for(0..7)|r|{const st=now();@memset(ch,-1);@memset(term,0);var used:usize=1;for(words)|word|{var node:usize=0;var sh:i32=28;while(sh>=0):(sh-=4){const cc=(word>>@intCast(sh))&15;const p=node*16+cc;if(ch[p]<0){ch[p]=@intCast(used);used+=1;}node=@intCast(ch[p]);}term[node]=1;}var h:u32=@intCast(used);for(0..passes)|pass|{var i:usize=0;while(i<n):(i+=2){const word=words[i];var node:i32=0;var sh:i32=28;while(sh>=0 and node>=0):(sh-=4)node=ch[@as(usize,@intCast(node))*16+((word>>@intCast(sh))&15)];if(node>=0 and term[@intCast(node)]!=0)h^=@as(u32,@intCast(node))+1+%@as(u32,@intCast(pass));}}ck=h;t[r]=now()-st;}const m=median(&t);emit("trie",nu*passes,m,@as(f64,@floatFromInt(n*passes))/m/1e6,ck);}

fn ds(k:[]const u8)u64{
    if(std.mem.eql(u8,k,"integer50"))return 200000000;
    if(std.mem.eql(u8,k,"json_escape"))return 16000000;
    if(std.mem.eql(u8,k,"merge_sort") or std.mem.eql(u8,k,"binary_search") or std.mem.eql(u8,k,"union_find") or std.mem.eql(u8,k,"hash_table") or std.mem.eql(u8,k,"binary_heap"))return 1000000;
    if(std.mem.eql(u8,k,"prefix_sum"))return 8000000;if(std.mem.eql(u8,k,"matrix_mul"))return 320;if(std.mem.eql(u8,k,"bfs"))return 200000;
    if(std.mem.eql(u8,k,"dijkstra") or std.mem.eql(u8,k,"trie"))return 100000;if(std.mem.eql(u8,k,"mandelbrot"))return 1600;
    if(std.mem.eql(u8,k,"dynamic_array"))return 5000000;if(std.mem.eql(u8,k,"linked_list"))return 4000000;if(std.mem.eql(u8,k,"queue_ring"))return 10000000;if(std.mem.eql(u8,k,"bst"))return 300000;return 0;
}
fn run(k:[]const u8,n:u64)!void{
    if(std.mem.eql(u8,k,"integer50"))benchInteger(n)
    else if(std.mem.eql(u8,k,"json_escape"))try benchJson(n)
    else if(std.mem.eql(u8,k,"merge_sort"))try benchMerge(n)
    else if(std.mem.eql(u8,k,"binary_search"))try benchBS(n)
    else if(std.mem.eql(u8,k,"prefix_sum"))try benchPrefix(n)
    else if(std.mem.eql(u8,k,"matrix_mul"))try benchMM(n)
    else if(std.mem.eql(u8,k,"bfs"))try benchBFS(n)
    else if(std.mem.eql(u8,k,"dijkstra"))try benchDij(n)
    else if(std.mem.eql(u8,k,"union_find"))try benchUF(n)
    else if(std.mem.eql(u8,k,"mandelbrot"))benchMandel(n)
    else if(std.mem.eql(u8,k,"dynamic_array"))try benchVA(n)
    else if(std.mem.eql(u8,k,"linked_list"))try benchLL(n)
    else if(std.mem.eql(u8,k,"queue_ring"))try benchQR(n)
    else if(std.mem.eql(u8,k,"hash_table"))try benchHT(n)
    else if(std.mem.eql(u8,k,"binary_heap"))try benchBH(n)
    else if(std.mem.eql(u8,k,"bst"))try benchBST(n)
    else if(std.mem.eql(u8,k,"trie"))try benchTrie(n)
    else return error.UnknownKernel;
}
pub export fn main(argc:c_int,argv:[*]const [*:0]const u8)c_int{
    if(argc<2)return 64;const k=std.mem.span(argv[1]);
    const n=if(argc>2)std.fmt.parseInt(u64,std.mem.span(argv[2]),10) catch return 65 else ds(k);
    if(n==0)return 64;run(k,n) catch return 1;return 0;
}
