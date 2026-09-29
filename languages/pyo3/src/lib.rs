use pyo3::prelude::*;
use std::time::Instant;

fn median(mut v:[f64;7])->f64{v.sort_by(|a,b|a.total_cmp(b));v[3]}
fn integer50(n:u64)->u64{let mask=(1u64<<50)-1;let mut x=88172645463325252u64&mask;let mut s=0u64;for _ in 0..n{x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;s=(s.wrapping_add(x^(x>>17)))&mask;}s}
struct Node{l:Option<Box<Node>>,r:Option<Box<Node>>}
fn tree(d:u32)->Box<Node>{if d==0{Box::new(Node{l:None,r:None})}else{Box::new(Node{l:Some(tree(d-1)),r:Some(tree(d-1))})}}
fn check(n:&Node)->u64{1+n.l.as_deref().map_or(0,check)+n.r.as_deref().map_or(0,check)}
fn trees_once(mx:u32)->u64{let s=tree(mx+1);let mut total=check(&s);let long=tree(mx);let mut d=4;while d<=mx{let iters=1u64<<(mx-d+4);let mut z=0;for _ in 0..iters{let n=tree(d);z+=check(&n);}total+=z;d+=2;}total+check(&long)}
fn mandel(w:u32,mi:u32)->u64{let mut sum=0;for y in 0..w{let ci=-1.5+3.0*y as f64/(w-1) as f64;for x in 0..w{let cr=-2.0+3.0*x as f64/(w-1) as f64;let(mut zr,mut zi,mut it)=(0.0f64,0.0f64,0u32);while it<mi{let zr2=zr*zr;let zi2=zi*zi;if zr2+zi2>4.0{break}let nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;it+=1;}sum+=it as u64;}}sum}
const P:[u8;23]=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47];
fn escape(input:&[u8],out:&mut[u8])->usize{const H:&[u8;16]=b"0123456789abcdef";let mut j=0;out[j]=34;j+=1;for &c in input{match c{34=>{out[j]=92;out[j+1]=34;j+=2},92=>{out[j]=92;out[j+1]=92;j+=2},8=>{out[j]=92;out[j+1]=98;j+=2},12=>{out[j]=92;out[j+1]=102;j+=2},10=>{out[j]=92;out[j+1]=110;j+=2},13=>{out[j]=92;out[j+1]=114;j+=2},9=>{out[j]=92;out[j+1]=116;j+=2},0..=31=>{out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=H[(c>>4)as usize];out[j+5]=H[(c&15)as usize];j+=6},_=>{out[j]=c;j+=1}}}out[j]=34;j+1}

#[pyfunction]
fn run(kernel:&str,size:u64)->PyResult<(String,u64,f64,f64,u64)>{
    let mut t=[0.0;7];let mut checksum=0u64;
    match kernel{
        "integer50"=>{let n=size;let _=integer50(n/20+1);for r in 0..7{let a=Instant::now();checksum=integer50(n);t[r]=a.elapsed().as_secs_f64();}let m=median(t);Ok((kernel.into(),n,m,n as f64/m/1e6,checksum))}
        "json_escape"=>{let n=size as usize;let mut input=vec![0u8;n];for i in 0..n{input[i]=P[i%23]}let mut out=vec![0u8;n*6+2];let mut outn=escape(&input,&mut out);for r in 0..7{let a=Instant::now();outn=escape(&input,&mut out);t[r]=a.elapsed().as_secs_f64();}checksum=outn as u64+out[..outn].iter().map(|&x|x as u64).sum::<u64>();let m=median(t);Ok((kernel.into(),n as u64,m,n as f64/m/1e9,checksum))}
        "binary_trees"=>{let d=size;let _=trees_once(6);for r in 0..7{let a=Instant::now();checksum=trees_once(d as u32);t[r]=a.elapsed().as_secs_f64();}let m=median(t);Ok((kernel.into(),d,m,1.0/m,checksum))}
        "mandelbrot"=>{let w=size;let _=mandel(128,20);for r in 0..7{let a=Instant::now();checksum=mandel(w as u32,50);t[r]=a.elapsed().as_secs_f64();}let m=median(t);let pix=w*w;Ok((kernel.into(),pix,m,pix as f64/m/1e6,checksum))}
        _=>Err(pyo3::exceptions::PyValueError::new_err("unknown kernel"))
    }
}
#[pymodule]
fn bench_ext(m:&Bound<'_,PyModule>)->PyResult<()>{m.add_function(wrap_pyfunction!(run,m)?)?;Ok(())}
