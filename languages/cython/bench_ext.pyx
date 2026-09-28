# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True, initializedcheck=False
from libc.stdint cimport uint64_t, uint8_t
from libc.stdlib cimport malloc, free
from libc.time cimport clock_gettime, timespec, CLOCK_MONOTONIC
from cython cimport sizeof

cdef inline double now() noexcept nogil:
    cdef timespec ts
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return <double>ts.tv_sec + <double>ts.tv_nsec * 1e-9

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
        x ^= x >> 7
        x ^= (x << 8) & mask
        x ^= x >> 9
        x &= mask
        s = (s + (x ^ (x >> 17))) & mask
    return s

cdef struct Node:
    Node* l
    Node* r

cdef Node* make_tree(int d) noexcept nogil:
    cdef Node* n=<Node*>malloc(sizeof(Node))
    if n==NULL: return NULL
    n.l=NULL; n.r=NULL
    if d>0:
        n.l=make_tree(d-1); n.r=make_tree(d-1)
    return n

cdef uint64_t check_tree(Node* n) noexcept nogil:
    if n==NULL: return 0
    return 1+check_tree(n.l)+check_tree(n.r)

cdef void free_tree(Node* n) noexcept nogil:
    if n!=NULL:
        free_tree(n.l); free_tree(n.r); free(n)

cdef uint64_t trees_once(int mx) noexcept nogil:
    cdef Node* stretch=make_tree(mx+1)
    cdef Node* longl
    cdef Node* n
    cdef uint64_t total=check_tree(stretch),s,iters,i
    cdef int d=4
    free_tree(stretch)
    longl=make_tree(mx)
    while d<=mx:
        iters=<uint64_t>1 << (mx-d+4); s=0
        for i in range(iters):
            n=make_tree(d); s+=check_tree(n); free_tree(n)
        total+=s; d+=2
    total+=check_tree(longl); free_tree(longl)
    return total

cdef uint64_t mandelbrot(int w,int max_iter) noexcept nogil:
    cdef uint64_t total=0
    cdef int x,y,it
    cdef double ci,cr,zr,zi,zr2,zi2,nzr
    for y in range(w):
        ci=-1.5+3.0*y/(w-1.0)
        for x in range(w):
            cr=-2.0+3.0*x/(w-1.0)
            zr=0.0; zi=0.0; it=0
            while it<max_iter:
                zr2=zr*zr; zi2=zi*zi
                if zr2+zi2>4.0: break
                nzr=zr2-zi2+cr
                zi=2.0*zr*zi+ci
                zr=nzr; it+=1
            total+=it
    return total

cdef int json_escape(uint8_t* inp,int n,uint8_t* out) noexcept nogil:
    cdef char* hex="0123456789abcdef"
    cdef int i,j=0
    cdef uint8_t ch
    out[j]=34; j+=1
    for i in range(n):
        ch=inp[i]
        if ch==34: out[j]=92; out[j+1]=34; j+=2
        elif ch==92: out[j]=92; out[j+1]=92; j+=2
        elif ch==8: out[j]=92; out[j+1]=98; j+=2
        elif ch==12: out[j]=92; out[j+1]=102; j+=2
        elif ch==10: out[j]=92; out[j+1]=110; j+=2
        elif ch==13: out[j]=92; out[j+1]=114; j+=2
        elif ch==9: out[j]=92; out[j+1]=116; j+=2
        elif ch<32:
            out[j]=92; out[j+1]=117; out[j+2]=48; out[j+3]=48
            out[j+4]=hex[ch>>4]; out[j+5]=hex[ch&15]; j+=6
        else: out[j]=ch; j+=1
    out[j]=34
    return j+1

def run(str kernel):
    cdef double t[7]
    cdef double a,m,rate
    cdef int r,i,outn
    cdef uint64_t checksum=0
    cdef uint64_t n
    cdef uint8_t* inp
    cdef uint8_t* out
    cdef uint8_t pattern[23]
    if kernel=="integer50":
        n=200000000
        integer50(n//20+1)
        for r in range(7):
            a=now(); checksum=integer50(n); t[r]=now()-a
        m=median7(t); rate=n/m/1e6
        return kernel,n,m,rate,checksum
    if kernel=="json_escape":
        n=16000000
        pattern[:]=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]
        inp=<uint8_t*>malloc(n); out=<uint8_t*>malloc(n*6+2)
        if inp==NULL or out==NULL: raise MemoryError()
        for i in range(n): inp[i]=pattern[i%23]
        outn=json_escape(inp,<int>n,out)
        for r in range(7):
            a=now(); outn=json_escape(inp,<int>n,out); t[r]=now()-a
        checksum=outn
        for i in range(outn): checksum+=out[i]
        m=median7(t); rate=n/m/1e9
        free(inp); free(out)
        return kernel,n,m,rate,checksum
    if kernel=="binary_trees":
        n=16; trees_once(6)
        for r in range(7):
            a=now(); checksum=trees_once(<int>n); t[r]=now()-a
        m=median7(t); return kernel,n,m,1.0/m,checksum
    if kernel=="mandelbrot":
        n=1600; mandelbrot(128,20)
        for r in range(7):
            a=now(); checksum=mandelbrot(<int>n,50); t[r]=now()-a
        m=median7(t); return kernel,n*n,m,(n*n)/m/1e6,checksum
    raise ValueError(kernel)
