use std::{env,time::Instant};

fn median(mut v: Vec<f64>) -> f64 { v.sort_by(|a,b| a.total_cmp(b)); let n=v.len(); if n%2==1 {v[n/2]} else {(v[n/2-1]+v[n/2])/2.0} }
fn result(k:&str,u:u64,r:usize,s:f64,rate:f64,c:u64){println!("RESULT kernel={} units={} rounds={} seconds={:.9} rate={:.6} checksum={}",k,u,r,s,rate,c);}

fn integer50(n:u64)->u64{let mask=(1u64<<50)-1;let mut x=88172645463325252u64&mask;let mut sum=0u64;for _ in 0..n{x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;sum=(sum+(x^(x>>17)))&mask;}sum}
fn bench_integer(n:u64,r:usize){let _=integer50(n/20+1);let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let a=Instant::now();c=integer50(n);t.push(a.elapsed().as_secs_f64());}let m=median(t);result("integer50",n,r,m,n as f64/m/1e6,c)}

const PATTERN:[u8;23]=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47];
fn json_escape(input:&[u8],out:&mut [u8])->usize{const HEX:&[u8;16]=b"0123456789abcdef";let mut j=0;out[j]=b'"';j+=1;for &c in input{match c{b'"'=>{out[j]=b'\\';out[j+1]=b'"';j+=2},b'\\'=>{out[j]=b'\\';out[j+1]=b'\\';j+=2},8=>{out[j]=b'\\';out[j+1]=b'b';j+=2},12=>{out[j]=b'\\';out[j+1]=b'f';j+=2},10=>{out[j]=b'\\';out[j+1]=b'n';j+=2},13=>{out[j]=b'\\';out[j+1]=b'r';j+=2},9=>{out[j]=b'\\';out[j+1]=b't';j+=2},0..=31=>{out[j]=b'\\';out[j+1]=b'u';out[j+2]=b'0';out[j+3]=b'0';out[j+4]=HEX[(c>>4) as usize];out[j+5]=HEX[(c&15) as usize];j+=6},_=>{out[j]=c;j+=1}}}out[j]=b'"';j+1}
fn bench_json(bytes:u64,r:usize){let mut input=vec![0u8;bytes as usize];for i in 0..input.len(){input[i]=PATTERN[i%PATTERN.len()];}let mut out=vec![0u8;bytes as usize*6+2];let mut outn=json_escape(&input,&mut out);let mut t=Vec::with_capacity(r);for _ in 0..r{let a=Instant::now();outn=json_escape(&input,&mut out);t.push(a.elapsed().as_secs_f64());}let mut c=outn as u64;for &b in &out[..outn]{c+=b as u64;}let m=median(t);result("json_escape",bytes,r,m,bytes as f64/m/1e9,c)}

struct Node{l:Option<Box<Node>>,r:Option<Box<Node>>}
fn make_tree(d:u32)->Box<Node>{if d==0{Box::new(Node{l:None,r:None})}else{Box::new(Node{l:Some(make_tree(d-1)),r:Some(make_tree(d-1))})}}
fn check_tree(n:&Node)->u64{1+n.l.as_deref().map_or(0,check_tree)+n.r.as_deref().map_or(0,check_tree)}
fn trees_once(max_depth:u32)->u64{let stretch=make_tree(max_depth+1);let mut total=check_tree(&stretch);let long=make_tree(max_depth);let mut d=4;while d<=max_depth{let iters=1u64<<(max_depth-d+4);let mut s=0;for _ in 0..iters{let n=make_tree(d);s+=check_tree(&n);}total+=s;d+=2;}total+check_tree(&long)}
fn bench_trees(depth:u64,r:usize){let _=trees_once((depth as u32).min(6));let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let a=Instant::now();c=trees_once(depth as u32);t.push(a.elapsed().as_secs_f64());}let m=median(t);result("binary_trees",depth,r,m,1.0/m,c)}

fn mandelbrot(w:u32,max_iter:u32)->u64{let mut sum=0u64;for y in 0..w{let ci=-1.5+3.0*(y as f64)/((w-1) as f64);for x in 0..w{let cr=-2.0+3.0*(x as f64)/((w-1) as f64);let(mut zr,mut zi,mut it)=(0.0f64,0.0f64,0u32);while it<max_iter{let zr2=zr*zr;let zi2=zi*zi;if zr2+zi2>4.0{break}let nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;it+=1;}sum+=it as u64;}}sum}
fn bench_mandel(w:u64,r:usize){let _=mandelbrot((w as u32).min(128),20);let mut t=Vec::with_capacity(r);let mut c=0;for _ in 0..r{let a=Instant::now();c=mandelbrot(w as u32,50);t.push(a.elapsed().as_secs_f64());}let m=median(t);let pix=w*w;result("mandelbrot",pix,r,m,pix as f64/m/1e6,c)}

fn size(k:&str)->u64{match k{"integer50"=>200_000_000,"json_escape"=>16_000_000,"binary_trees"=>16,"mandelbrot"=>1600,_=>0}}
fn main(){let a:Vec<String>=env::args().collect();let k=a.get(1).map(String::as_str).unwrap_or("integer50");let n=a.get(2).and_then(|x|x.parse().ok()).unwrap_or_else(||size(k));let r=a.get(3).and_then(|x|x.parse().ok()).unwrap_or(7usize);match k{"integer50"=>bench_integer(n,r),"json_escape"=>bench_json(n,r),"binary_trees"=>bench_trees(n,r),"mandelbrot"=>bench_mandel(n,r),_=>panic!("unknown kernel")}}
