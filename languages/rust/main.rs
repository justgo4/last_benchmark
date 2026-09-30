use std::{env, time::Instant};
use std::cell::{Cell, RefCell};
use std::hint::black_box;

fn median(mut v: Vec<f64>) -> f64 { v.sort_by(|a,b| a.total_cmp(b)); v[v.len()/2] }
#[derive(Clone)]
pub struct BenchResult{pub kernel:String,pub units:u64,pub rounds:usize,pub seconds:f64,pub rate:f64,pub checksum:u64}
thread_local!{
    static LAST:RefCell<Option<BenchResult>>=const{RefCell::new(None)};
    static QUIET:Cell<bool>=const{Cell::new(false)};
}
fn emit(k:&str,u:u64,r:usize,s:f64,rate:f64,c:u64){
    LAST.with(|x|*x.borrow_mut()=Some(BenchResult{kernel:k.to_string(),units:u,rounds:r,seconds:s,rate,checksum:c}));
    QUIET.with(|q|if !q.get(){println!("RESULT kernel={} units={} rounds={} seconds={:.9} rate={:.6} checksum={}",k,u,r,s,rate,c);});
}
fn mix32(mut x:u32)->u32{x=x.wrapping_add(0x9e3779b9);x^=x>>16;x=x.wrapping_mul(0x85ebca6b);x^=x>>13;x=x.wrapping_mul(0xc2b2ae35);x^(x>>16)}
fn hash32(mut x:u32)->u32{x^=x>>16;x=x.wrapping_mul(0x7feb352d);x^=x>>15;x=x.wrapping_mul(0x846ca68b);x^(x>>16)}
fn ck32(a:&[u32])->u32{let mut h=2166136261u32;for &x in a{h^=x;h=h.wrapping_mul(16777619);}h}
fn ck64(a:&[u64])->u32{let mut h=2166136261u32;for &x in a{h^=x as u32;h=h.wrapping_mul(16777619);h^=(x>>32)as u32;h=h.wrapping_mul(16777619);}h}

fn integer50(n:u64)->u64{let mask=(1u64<<50)-1;let mut x=88172645463325252u64&mask;let mut s=0u64;for _ in 0..n{x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;s=s.wrapping_add(x^(x>>17))&mask;}s}
fn bench_integer(n:u64,r:usize){let _=integer50(n/20+1);let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let a=Instant::now();c=black_box(integer50(black_box(n)));t.push(a.elapsed().as_secs_f64());}let m=median(t);emit("integer50",n,r,m,n as f64/m/1e6,c);}

const PAT:[u8;23]=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47];
fn json_escape(input:&[u8],out:&mut[u8])->usize{const H:&[u8;16]=b"0123456789abcdef";let mut j=0;out[j]=34;j+=1;for &c in input{match c{34=>{out[j]=92;out[j+1]=34;j+=2},92=>{out[j]=92;out[j+1]=92;j+=2},8=>{out[j]=92;out[j+1]=98;j+=2},12=>{out[j]=92;out[j+1]=102;j+=2},10=>{out[j]=92;out[j+1]=110;j+=2},13=>{out[j]=92;out[j+1]=114;j+=2},9=>{out[j]=92;out[j+1]=116;j+=2},0..=31=>{out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=H[(c>>4)as usize];out[j+5]=H[(c&15)as usize];j+=6},_=>{out[j]=c;j+=1}}}out[j]=34;j+1}
fn bench_json(n:u64,r:usize){let mut input=vec![0u8;n as usize];for i in 0..input.len(){input[i]=PAT[i%23];}let mut out=vec![0u8;n as usize*6+2];let mut on=json_escape(&input,&mut out);let mut t=Vec::with_capacity(r);for _ in 0..r{let a=Instant::now();on=json_escape(&input,&mut out);t.push(a.elapsed().as_secs_f64());}let mut c=on as u64;for &x in &out[..on]{c+=x as u64;}let m=median(t);emit("json_escape",n,r,m,n as f64/m/1e9,c);}

fn merge_pass(src:&[u32],dst:&mut[u32],w:usize){let n=src.len();let mut lo=0;while lo<n{let mid=(lo+w).min(n);let hi=(lo+2*w).min(n);let(mut i,mut j,mut k)=(lo,mid,lo);while i<mid&&j<hi{if src[i]<=src[j]{dst[k]=src[i];i+=1}else{dst[k]=src[j];j+=1}k+=1;}while i<mid{dst[k]=src[i];i+=1;k+=1;}while j<hi{dst[k]=src[j];j+=1;k+=1;}lo+=2*w;}}
fn merge_sort(a:&mut[u32],tmp:&mut[u32]){let n=a.len();let mut from_a=true;let mut w=1usize;while w<n{if from_a{merge_pass(a,tmp,w)}else{merge_pass(tmp,a,w)}from_a=!from_a;if w>n/2{break}w*=2;}if !from_a{a.copy_from_slice(tmp);}}
fn bench_merge(n:u64,r:usize){let n=n as usize;let base:Vec<u32>=(0..n).map(|i|mix32(i as u32)).collect();let mut a=vec![0u32;n];let mut tmp=vec![0u32;n];let mut t=Vec::with_capacity(r);for _ in 0..r{a.copy_from_slice(&base);let q=Instant::now();merge_sort(&mut a,&mut tmp);t.push(q.elapsed().as_secs_f64());}let m=median(t);emit("merge_sort",n as u64,r,m,n as f64/m/1e6,ck32(&a)as u64);}

fn bs(a:&[u32],x:u32)->i32{let(mut l,mut h)=(0usize,a.len());while l<h{let m=l+(h-l)/2;if a[m]<x{l=m+1}else{h=m}}if l<a.len()&&a[l]==x{l as i32}else{-1}}
fn bs_once(a:&[u32],q:&[u32])->u64{let mut h=0u64;for &x in q{let p=bs(a,x);if p>=0{h+=p as u64+1;}}h}
fn bench_bs(n:u64,r:usize){let n=n as usize;let a:Vec<u32>=(0..n).map(|i|(i*2)as u32).collect();let q:Vec<u32>=(0..n*4).map(|i|mix32(i as u32)%(2*n)as u32).collect();let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=black_box(bs_once(black_box(&a),black_box(&q)));t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("binary_search",q.len()as u64,r,m,q.len()as f64/m/1e6,c);}

fn prefix(input:&[u32],out:&mut[u64],passes:usize)->u64{let mut c=0u64;for p in 0..passes{let mut s=p as u64;for(i,&x)in input.iter().enumerate(){s+=x as u64;out[i]=s;}c^=s;}c}
fn bench_prefix(n:u64,r:usize){let input:Vec<u32>=(0..n as usize).map(|i|mix32(i as u32)&1023).collect();let mut out=vec![0u64;n as usize];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=prefix(&input,&mut out,16);t.push(s.elapsed().as_secs_f64());}c^=ck64(&out)as u64;let m=median(t);emit("prefix_sum",n*16,r,m,n as f64*16.0/m/1e6,c);}

fn mm(a:&[u32],b:&[u32],c:&mut[u64],n:usize){for i in 0..n{for j in 0..n{let mut s=0u64;for k in 0..n{s+=(a[i*n+k]as u64)*(b[k*n+j]as u64);}c[i*n+j]=s;}}}
fn bench_mm(n:u64,r:usize){let nn=(n*n)as usize;let a:Vec<u32>=(0..nn).map(|i|mix32(i as u32)&15).collect();let b:Vec<u32>=(0..nn).map(|i|mix32((i+nn)as u32)&15).collect();let mut c=vec![0u64;nn];let mut t=Vec::with_capacity(r);for _ in 0..r{let s=Instant::now();mm(&a,&b,&mut c,n as usize);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("matrix_mul",n,r,m,(n as f64).powi(3)/m/1e6,ck64(&c)as u64);}

fn graph(n:usize,d:usize,weights:bool)->(Vec<u32>,Vec<u32>){let mut a=vec![0u32;n*d];let mut w=if weights{vec![0u32;n*d]}else{Vec::new()};for i in 0..n{for e in 0..d{let p=i*d+e;let v=if e==0{(i+1)%n}else if e==1{(i+n-1)%n}else{(mix32(p as u32)%n as u32)as usize};a[p]=v as u32;if weights{w[p]=1+(mix32(0xabc00000u32.wrapping_add(p as u32))&15);}}}(a,w)}
fn bfs_once(a:&[u32],n:usize,d:usize,dist:&mut[i32],q:&mut[u32])->u32{dist.fill(-1);let(mut h,mut t)=(0usize,0usize);dist[0]=0;q[t]=0;t+=1;while h<t{let u=q[h]as usize;h+=1;let nd=dist[u]+1;for e in 0..d{let v=a[u*d+e]as usize;if dist[v]<0{dist[v]=nd;q[t]=v as u32;t+=1;}}}t as u32}
fn bench_bfs(n:u64,r:usize){let n=n as usize;let d=4;let passes=16;let(a,_)=graph(n,d,false);let mut dist=vec![0i32;n];let mut q=vec![0u32;n];let mut t=Vec::with_capacity(r);let mut seen=0u32;for _ in 0..r{let s=Instant::now();for z in 0..passes{seen^=bfs_once(&a,n,d,&mut dist,&mut q)+(z as u32);}t.push(s.elapsed().as_secs_f64());}let dv:Vec<u32>=dist.iter().map(|&x|x as u32).collect();let c=ck32(&dv)^seen;let m=median(t);emit("bfs",(n*passes)as u64,r,m,(n*d*passes)as f64/m/1e6,c as u64);}

#[derive(Clone,Copy)]struct HP{d:u64,v:u32}
fn hp_push(h:&mut[HP],sz:&mut usize,x:HP){let mut i=*sz;*sz+=1;while i>0{let p=(i-1)/2;if h[p].d<=x.d{break}h[i]=h[p];i=p;}h[i]=x;}
fn hp_pop(h:&mut[HP],sz:&mut usize)->HP{let o=h[0];*sz-=1;let x=h[*sz];let mut i=0;loop{let l=i*2+1;if l>=*sz{break}let rr=l+1;let c=if rr<*sz&&h[rr].d<h[l].d{rr}else{l};if h[c].d>=x.d{break}h[i]=h[c];i=c;}if *sz>0{h[i]=x;}o}
fn dijkstra(a:&[u32],w:&[u32],n:usize,d:usize,dist:&mut[u64],heap:&mut[HP])->u32{dist.fill(u64::MAX/4);let mut sz=0;dist[0]=0;hp_push(heap,&mut sz,HP{d:0,v:0});while sz>0{let x=hp_pop(heap,&mut sz);if x.d!=dist[x.v as usize]{continue}for e in 0..d{let p=x.v as usize*d+e;let v=a[p]as usize;let nd=x.d+w[p]as u64;if nd<dist[v]{dist[v]=nd;hp_push(heap,&mut sz,HP{d:nd,v:v as u32});}}}ck64(dist)}
fn bench_dij(n:u64,r:usize){let n=n as usize;let d=4;let(a,w)=graph(n,d,true);let mut dist=vec![0u64;n];let mut heap=vec![HP{d:0,v:0};n*d*4];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=dijkstra(&a,&w,n,d,&mut dist,&mut heap);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("dijkstra",n as u64,r,m,(n*d)as f64/m/1e6,c as u64);}

fn uf_find(p:&mut[u32],mut x:u32)->u32{while p[x as usize]!=x{p[x as usize]=p[p[x as usize]as usize];x=p[x as usize];}x}
fn uf_run(p:&mut[u32],rank:&mut[u8],aa:&[u32],bb:&[u32]){for i in 0..p.len(){p[i]=i as u32;rank[i]=0;}for i in 0..aa.len(){let(mut ra,mut rb)=(uf_find(p,aa[i]),uf_find(p,bb[i]));if ra!=rb{if rank[ra as usize]<rank[rb as usize]{std::mem::swap(&mut ra,&mut rb);}p[rb as usize]=ra;if rank[ra as usize]==rank[rb as usize]{rank[ra as usize]+=1;}}}}
fn bench_uf(n:u64,r:usize){let n=n as usize;let ops=n*4;let aa:Vec<u32>=(0..ops).map(|i|mix32(i as u32)%n as u32).collect();let bb:Vec<u32>=(0..ops).map(|i|mix32((i+ops)as u32)%n as u32).collect();let mut p=vec![0u32;n];let mut rank=vec![0u8;n];let mut t=Vec::with_capacity(r);for _ in 0..r{let s=Instant::now();uf_run(&mut p,&mut rank,&aa,&bb);t.push(s.elapsed().as_secs_f64());}for i in 0..n{p[i]=uf_find(&mut p,i as u32);}let m=median(t);emit("union_find",ops as u64,r,m,ops as f64/m/1e6,ck32(&p)as u64);}

fn mandel(w:usize,mi:usize)->u64{let mut sum=0;for y in 0..w{let ci=-1.5+3.0*y as f64/(w-1)as f64;for x in 0..w{let cr=-2.0+3.0*x as f64/(w-1)as f64;let(mut zr,mut zi,mut it)=(0.0,0.0,0);while it<mi{let(a,b)=(zr*zr,zi*zi);if a+b>4.0{break}let nz=a-b+cr;zi=2.0*zr*zi+ci;zr=nz;it+=1;}sum+=it as u64;}}sum}
fn bench_mandel(w:u64,r:usize){let _=mandel((w as usize).min(128),20);let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=black_box(mandel(black_box(w as usize),black_box(50usize)));t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("mandelbrot",w*w,r,m,(w*w)as f64/m/1e6,c);}

fn vector_once(input:&[u32])->u32{let mut v=Vec::new();for &x in input{v.push(x);}let mut h=2166136261u32;for i in 0..v.len(){v[i]^=i as u32;h=(h^v[i]).wrapping_mul(16777619);}while let Some(x)=v.pop(){h=(h^x.wrapping_add(v.len()as u32)).wrapping_mul(16777619);}h}
fn bench_va(n:u64,r:usize){let input:Vec<u32>=(0..n as usize).map(|i|mix32(i as u32)).collect();let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=vector_once(&input);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("dynamic_array",n,r,m,n as f64/m/1e6,c as u64);}

fn list_once(next:&mut[u32],val:&mut[u32],base:&[u32],passes:usize)->u32{val.copy_from_slice(base);let n=base.len();for i in 0..n{next[i]=if i+1<n{(i+1)as u32}else{u32::MAX};}let b=64usize;let mut base_i=0;while base_i<n{let hi=(base_i+b).min(n)-1;for i in base_i..=hi{next[i]=if i==base_i{if hi+1<n{(hi+1)as u32}else{u32::MAX}}else{(i-1)as u32};}base_i+=b;}let mut h=2166136261u32;for p in 0..passes{let mut cur=if b<n{(b-1)as u32}else{(n-1)as u32};let mut seen=0usize;while cur!=u32::MAX&&seen<n{let u=cur as usize;val[u]^=(seen+p)as u32;h=(h^val[u].wrapping_add(cur).wrapping_add(p as u32)).wrapping_mul(16777619);cur=next[u];seen+=1;}h=(h^seen as u32).wrapping_mul(16777619);}h}
fn bench_ll(n:u64,r:usize){let base:Vec<u32>=(0..n as usize).map(|i|mix32(i as u32)).collect();let mut next=vec![0u32;n as usize];let mut val=vec![0u32;n as usize];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=list_once(&mut next,&mut val,&base,16);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("linked_list",n*16,r,m,n as f64*16.0/m/1e6,c as u64);}

fn queue_once(buf:&mut[u32],input:&[u32])->u32{let cap=buf.len();let(mut h,mut t,mut cnt)=(0usize,0usize,0usize);let mut z=0u32;for(i,&x)in input.iter().enumerate(){if i&3!=3{if cnt==cap{z^=buf[h];h=(h+1)%cap;cnt-=1;}buf[t]=x;t=(t+1)%cap;cnt+=1;}else if cnt>0{z^=buf[h];h=(h+1)%cap;cnt-=1;}}while cnt>0{z^=buf[h];h=(h+1)%cap;cnt-=1;}z}
fn bench_qr(ops:u64,r:usize){let input:Vec<u32>=(0..ops as usize).map(|i|mix32(i as u32)).collect();let mut buf=vec![0u32;ops as usize/2+1024];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=queue_once(&mut buf,&input);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("queue_ring",ops,r,m,ops as f64/m/1e6,c as u64);}

fn np2(x:usize)->usize{let mut p=1;while p<x{p<<=1;}p}
fn hash_once(keys:&mut[u32],vals:&mut[u32],ik:&[u32],iv:&[u32])->u32{keys.fill(0);let mask=keys.len()-1;let mut h=0u32;for i in 0..ik.len(){let key=ik[i];let mut p=hash32(key)as usize&mask;while keys[p]!=0&&keys[p]!=key{p=(p+1)&mask;}keys[p]=key;vals[p]=iv[i];}for(i,&key)in ik.iter().enumerate(){let mut p=hash32(key)as usize&mask;while keys[p]!=key{p=(p+1)&mask;}vals[p]^=i as u32;h^=vals[p];}h}
fn bench_ht(n:u64,r:usize){let n=n as usize;let cap=np2(n*2);let ik:Vec<u32>=(0..n).map(|i|mix32(i as u32)|1).collect();let iv:Vec<u32>=(0..n).map(|i|mix32((i as u32).wrapping_add(0x55555555))).collect();let mut keys=vec![0u32;cap];let mut vals=vec![0u32;cap];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=hash_once(&mut keys,&mut vals,&ik,&iv);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("hash_table",n as u64,r,m,n as f64*2.0/m/1e6,c as u64);}

fn heap_push(h:&mut[u32],sz:&mut usize,x:u32){let mut i=*sz;*sz+=1;while i>0{let p=(i-1)/2;if h[p]<=x{break}h[i]=h[p];i=p;}h[i]=x;}
fn heap_pop(h:&mut[u32],sz:&mut usize)->u32{let o=h[0];*sz-=1;let x=h[*sz];let mut i=0;loop{let l=i*2+1;if l>=*sz{break}let rr=l+1;let c=if rr<*sz&&h[rr]<h[l]{rr}else{l};if h[c]>=x{break}h[i]=h[c];i=c;}if *sz>0{h[i]=x;}o}
fn heap_once(h:&mut[u32],input:&[u32])->u32{let mut sz=0;for &x in input{heap_push(h,&mut sz,x);}let mut c=0;for i in 0..input.len(){c^=heap_pop(h,&mut sz).wrapping_add(i as u32);}c}
fn bench_bh(n:u64,r:usize){let input:Vec<u32>=(0..n as usize).map(|i|mix32(i as u32)).collect();let mut h=vec![0u32;n as usize];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=heap_once(&mut h,&input);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("binary_heap",n,r,m,n as f64*2.0/m/1e6,c as u64);}

fn bst_once(keys:&mut[u32],left:&mut[i32],right:&mut[i32],input:&[u32])->u32{let mut root=-1i32;for(i,&key)in input.iter().enumerate(){keys[i]=key;left[i]=-1;right[i]=-1;let node=i as i32;if root<0{root=node;continue}let mut cur=root;loop{let u=cur as usize;if key<keys[u]{if left[u]<0{left[u]=node;break}cur=left[u];}else{if right[u]<0{right[u]=node;break}cur=right[u];}}}let mut h=0u32;for i in (0..input.len()).step_by(3){let key=input[i];let mut cur=root;while cur>=0&&keys[cur as usize]!=key{let u=cur as usize;cur=if key<keys[u]{left[u]}else{right[u]};}if cur>=0{h^=cur as u32+1;}}h}
fn bench_bst(n:u64,r:usize){let input:Vec<u32>=(0..n as usize).map(|i|mix32(i as u32)).collect();let mut keys=vec![0u32;n as usize];let mut left=vec![0i32;n as usize];let mut right=vec![0i32;n as usize];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=bst_once(&mut keys,&mut left,&mut right,&input);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("bst",n,r,m,n as f64/m/1e6,c as u64);}

fn trie_once(ch:&mut[i32],term:&mut[u8],words:&[u32],passes:usize)->u32{ch.fill(-1);term.fill(0);let mut used=1usize;for &w in words{let mut node=0i32;for sh in (0..=28).rev().step_by(4){let c=((w>>sh)&15)as usize;let p=node as usize*16+c;if ch[p]<0{ch[p]=used as i32;used+=1;}node=ch[p];}term[node as usize]=1;}let mut h=used as u32;for p in 0..passes{for i in (0..words.len()).step_by(2){let w=words[i];let mut node=0i32;for sh in (0..=28).rev().step_by(4){if node<0{break}node=ch[node as usize*16+((w>>sh)&15)as usize];}if node>=0&&term[node as usize]!=0{h^=node as u32+1+p as u32;}}}h}
fn bench_trie(n:u64,r:usize){let words:Vec<u32>=(0..n as usize).map(|i|mix32(i as u32)).collect();let mx=1+n as usize*8;let mut ch=vec![-1i32;mx*16];let mut term=vec![0u8;mx];let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let s=Instant::now();c=trie_once(&mut ch,&mut term,&words,32);t.push(s.elapsed().as_secs_f64());}let m=median(t);emit("trie",n*32,r,m,n as f64*32.0/m/1e6,c as u64);}

fn size(k:&str)->u64{match k{"integer50"=>200000000,"json_escape"=>16000000,"merge_sort"|"binary_search"|"union_find"|"hash_table"|"binary_heap"=>1000000,"prefix_sum"=>8000000,"matrix_mul"=>320,"bfs"=>200000,"dijkstra"|"trie"=>100000,"mandelbrot"=>1600,"dynamic_array"=>5000000,"linked_list"=>4000000,"queue_ring"=>10000000,"bst"=>300000,_=>0}}
fn dispatch(k:&str,n:u64,r:usize){match k{"integer50"=>bench_integer(n,r),"json_escape"=>bench_json(n,r),"merge_sort"=>bench_merge(n,r),"binary_search"=>bench_bs(n,r),"prefix_sum"=>bench_prefix(n,r),"matrix_mul"=>bench_mm(n,r),"bfs"=>bench_bfs(n,r),"dijkstra"=>bench_dij(n,r),"union_find"=>bench_uf(n,r),"mandelbrot"=>bench_mandel(n,r),"dynamic_array"=>bench_va(n,r),"linked_list"=>bench_ll(n,r),"queue_ring"=>bench_qr(n,r),"hash_table"=>bench_ht(n,r),"binary_heap"=>bench_bh(n,r),"bst"=>bench_bst(n,r),"trie"=>bench_trie(n,r),_=>panic!("unknown kernel")}}
pub fn run_capture(k:&str,n:u64,r:usize)->BenchResult{
    QUIET.with(|q|q.set(true));
    dispatch(k,n,r);
    QUIET.with(|q|q.set(false));
    LAST.with(|x|x.borrow_mut().take().expect("missing benchmark result"))
}
fn main(){
    let a:Vec<String>=env::args().collect();
    let k=a.get(1).map(String::as_str).unwrap_or("integer50");
    let n=a.get(2).and_then(|x|x.parse().ok()).unwrap_or_else(||size(k));
    let r=a.get(3).and_then(|x|x.parse().ok()).unwrap_or(7usize);
    dispatch(k,n,r);
}
