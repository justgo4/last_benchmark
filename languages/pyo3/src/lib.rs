use pyo3::prelude::*;

mod core {
    include!("../../rust/main.rs");
}

#[pyfunction]
#[pyo3(signature=(kernel, size))]
fn run(kernel:&str,size:u64)->PyResult<(String,u64,f64,f64,u64)>{
    let r=core::run_capture(kernel,size,7);
    Ok((r.kernel,r.units,r.seconds,r.rate,r.checksum))
}

#[pymodule]
fn bench_ext(m:&Bound<'_,PyModule>)->PyResult<()>{
    m.add_function(wrap_pyfunction!(run,m)?)?;
    Ok(())
}
