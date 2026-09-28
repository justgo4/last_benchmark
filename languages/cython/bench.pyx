# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True, initializedcheck=False, nonecheck=False
from libc.stdint cimport uint64_t, uint8_t
from libc.stdlib cimport malloc, free

cdef extern from "time.h" nogil:
    ctypedef struct timespec:
        long tv_sec
        long tv_nsec
    int clock_gettime(int, timespec*)
    int CLOCK_MONOTONIC

cdef double now_s() noexcept nogil:
    cdef timespec ts
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return ts.tv_sec + ts.tv_nsec * 1e-9

cdef double median7(double* a) noexcept nogil:
    cdef int i,j
    cdef double x
    for i in range(1,7):
        x=a[i]; j=i
        while j>0 and a[j-1]>x:
            a[j]=a[j-1]; j-=1
        a[j]=x
    return a[3]

cdef uint64_t integer50(uint64_t n) noexcept nogil:
    cdef uint64_t mask=(<uint64_t>1<<50)-1
    cdef uint64_t x=88172645463325252 & mask
    cdef uint64_t s=0,i
    for i in range(n):
        x ^= x>>7; x ^= (x<<8)&mask; x ^= x>>9; x &= mask
        s=(s+(x^(x>>17)))&mask
    return s

cdef tuple bench_integer():
    cdef uint64_t n=200000000,c=0
    cdef double t[7],a,m
    cdef int r
    integer50(n//20+1)
    for r in range(7):
        a=now_s(); c=integer50(n); t[r]=now_s()-a
    m=median7(t)
    return n,m,n/m/1e6,c

cdef size_t json_escape(const uint8_t* inp,size_t n,uint8_t* out) noexcept nogil:
    cdef const char* hx=b"0123456789abcdef"
    cdef size_t i,j=0
    cdef uint8_t ch
    out[j]=34; j+=1
    for i in range(n):
        ch=inp[i]
        if ch==34: out[j]=92;out[j+1]=34;j+=2
        elif ch==92: out[j]=92;out[j+1]=92;j+=2
        elif ch==8: out[j]=92;out[j+1]=98;j+=2
        elif ch==12: out[j]=92;out[j+1]=102;j+=2
        elif ch==10: out[j]=92;out[j+1]=110;j+=2
        elif ch==13: out[j]=92;out[j+1]=114;j+=2
        elif ch==9: out[j]=92;out[j+1]=116;j+=2
        elif ch<32:
            out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48
            out[j+4]=<uint8_t>hx[ch>>4];out[j+5]=<uint8_t>hx[ch&15];j+=6
        else: out[j]=ch;j+=1
    out[j]=34
    return j+1

cdef tuple bench_json():
    cdef size_t n=16000000,i,outn
    cdef uint8_t* inp=<uint8_t*>malloc(n)
    cdef uint8_t* out=<uint8_t*>malloc(n*6+2)
    cdef const char* pat=b"alpha\"beta\\gamma\n\t\x01xyz/"
    cdef double t[7],a,m
    cdef uint64_t c
    cdef int r
    if inp==NULL or out==NULL: raise MemoryError()
    try:
        for i in range(n): inp[i]=<uint8_t>pat[i%23]
        outn=json_escape(inp,n,out)
        for r in range(7):
            a=now_s(); outn=json_escape(inp,n,out); t[r]=now_s()-a
        c=outn
        for i in range(outn): c+=out[i]
        m=median7(t)
        return n,m,n/m/1e9,c
    finally:
        free(inp); free(out)

cdef struct Node:
    Node* l
    Node* r
cdef Node* make_tree(int d) noexcept nogil:
    cdef Node* n=<Node*>malloc(sizeof(Node))
    if n==NULL: return NULL
    n.l=NULL;n.r=NULL
    if d>0:
        n.l=make_tree(d-1);n.r=make_tree(d-1)
    return n
cdef uint64_t check_tree(Node* n) noexcept nogil:
    if n==NULL: return 0
    return 1+check_tree(n.l)+check_tree(n.r)
cdef void free_tree(Node* n) noexcept nogil:
    if n!=NULL:
        free_tree(n.l);free_tree(n.r);free(n)
cdef uint64_t trees_once(int mx) noexcept nogil:
    cdef Node* n
    cdef uint64_t total,s,iters,i
    cdef int d
    n=make_tree(mx+1);total=check_tree(n);free_tree(n)
    cdef Node* longl=make_tree(mx)
    d=4
    while d<=mx:
        iters=<uint64_t>1 << (mx-d+4);s=0
        for i in range(iters):
            n=make_tree(d);s+=check_tree(n);free_tree(n)
        total+=s;d+=2
    total+=check_tree(longl);free_tree(longl)
    return total
cdef tuple bench_trees():
    cdef uint64_t depth=16,c=0
    cdef double t[7],a,m
    cdef int r
    trees_once(6)
    for r in range(7):
        a=now_s();c=trees_once(16);t[r]=now_s()-a
    m=median7(t)
    return depth,m,1/m,c

cdef uint64_t mandelbrot(int w,int maxiter) noexcept nogil:
    cdef int x,y,it
    cdef double ci,cr,zr,zi,zr2,zi2,nzr
    cdef uint64_t s=0
    for y in range(w):
        ci=-1.5+3.0*y/(w-1.0)
        for x in range(w):
            cr=-2.0+3.0*x/(w-1.0);zr=0;zi=0;it=0
            while it<maxiter:
                zr2=zr*zr;zi2=zi*zi
                if zr2+zi2>4.0: break
                nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;it+=1
            s+=it
    return s
cdef tuple bench_mandel():
    cdef uint64_t pix=2560000,c=0
    cdef double t[7],a,m
    cdef int r
    mandelbrot(128,20)
    for r in range(7):
        a=now_s();c=mandelbrot(1600,50);t[r]=now_s()-a
    m=median7(t)
    return pix,m,pix/m/1e6,c

def bench(str kernel):
    cdef tuple x
    if kernel=="integer50": x=bench_integer()
    elif kernel=="json_escape": x=bench_json()
    elif kernel=="binary_trees": x=bench_trees()
    elif kernel=="mandelbrot": x=bench_mandel()
    else: raise ValueError(kernel)
    print(f"RESULT kernel={kernel} units={x[0]} rounds=7 seconds={x[1]:.9f} rate={x[2]:.6f} checksum={x[3]}")
