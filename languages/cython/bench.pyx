# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True, initializedcheck=False, nonecheck=False
from libc.stdint cimport uint64_t, uint32_t, int32_t, uint8_t
from libc.stdlib cimport malloc, free, realloc
from libc.string cimport memcpy, memset
from libc.stddef cimport size_t

cdef extern from *:
    """
    #include <time.h>
    static inline double bench_now_s(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (double)t.tv_sec+(double)t.tv_nsec*1e-9;}
    static inline uint64_t bench_black_box_u64(uint64_t x){__asm__ __volatile__("" : "+r"(x) : : "memory");return x;}
    """
    double bench_now_s() noexcept nogil
    uint64_t bench_black_box_u64(uint64_t) noexcept nogil

cdef inline double now_s() noexcept nogil:return bench_now_s()
cdef double med7(double* a) noexcept nogil:
    cdef int i,j
    cdef double x
    for i in range(1,7):
        x=a[i];j=i
        while j>0 and a[j-1]>x:a[j]=a[j-1];j-=1
        a[j]=x
    return a[3]
cdef inline uint32_t mix32(uint32_t x) noexcept nogil:
    x+=<uint32_t>0x9e3779b9;x^=x>>16;x*=<uint32_t>0x85ebca6b;x^=x>>13;x*=<uint32_t>0xc2b2ae35;return x^(x>>16)
cdef inline uint32_t hash32(uint32_t x) noexcept nogil:
    x^=x>>16;x*=<uint32_t>0x7feb352d;x^=x>>15;x*=<uint32_t>0x846ca68b;return x^(x>>16)
cdef uint32_t ck32(uint32_t* a,size_t n) noexcept nogil:
    cdef uint32_t h=2166136261
    cdef size_t i
    for i in range(n):h=(h^a[i])*<uint32_t>16777619
    return h
cdef uint32_t ck64(uint64_t* a,size_t n) noexcept nogil:
    cdef uint32_t h=2166136261
    cdef size_t i
    cdef uint64_t v
    for i in range(n):
        v=a[i];h=(h^<uint32_t>v)*<uint32_t>16777619;h=(h^<uint32_t>(v>>32))*<uint32_t>16777619
    return h

cdef uint64_t integer50(uint64_t n) noexcept nogil:
    cdef uint64_t m=(<uint64_t>1<<50)-1,x=(<uint64_t>88172645463325252)&m,s=0,i
    for i in range(n):x^=x>>7;x^=(x<<8)&m;x^=x>>9;x&=m;s=(s+(x^(x>>17)))&m
    return s
cdef tuple b_integer(uint64_t n):
    cdef double t[7],a,m
    cdef int r
    cdef uint64_t c=0
    integer50(n//20+1)
    for r in range(7):a=now_s();c=bench_black_box_u64(integer50(bench_black_box_u64(n)));t[r]=now_s()-a
    m=med7(t);return n,m,n/m/1e6,c

cdef const unsigned char* PAT=b"alpha\"beta\\gamma\n\t\x01xyz/"
cdef size_t je(uint8_t* inp,size_t n,uint8_t* out) noexcept nogil:
    cdef const char* hx=b"0123456789abcdef"
    cdef size_t i,j=0
    cdef uint8_t c
    out[j]=34;j+=1
    for i in range(n):
        c=inp[i]
        if c==34:out[j]=92;out[j+1]=34;j+=2
        elif c==92:out[j]=92;out[j+1]=92;j+=2
        elif c==8:out[j]=92;out[j+1]=98;j+=2
        elif c==12:out[j]=92;out[j+1]=102;j+=2
        elif c==10:out[j]=92;out[j+1]=110;j+=2
        elif c==13:out[j]=92;out[j+1]=114;j+=2
        elif c==9:out[j]=92;out[j+1]=116;j+=2
        elif c<32:out[j]=92;out[j+1]=117;out[j+2]=48;out[j+3]=48;out[j+4]=<uint8_t>hx[c>>4];out[j+5]=<uint8_t>hx[c&15];j+=6
        else:out[j]=c;j+=1
    out[j]=34;return j+1
cdef tuple b_json(size_t n):
    cdef uint8_t* inp=<uint8_t*>malloc(n)
    cdef uint8_t* out=<uint8_t*>malloc(n*6+2)
    cdef size_t i,on
    cdef double t[7],a,m
    cdef int r
    cdef uint64_t c
    if inp==NULL or out==NULL:raise MemoryError()
    try:
        for i in range(n):inp[i]=PAT[i%23]
        on=je(inp,n,out)
        for r in range(7):a=now_s();on=je(inp,n,out);t[r]=now_s()-a
        c=on
        for i in range(on):c+=out[i]
        m=med7(t);return n,m,n/m/1e9,c
    finally:free(inp);free(out)

cdef void merge_sort(uint32_t* a,uint32_t* tmp,size_t n) noexcept nogil:
    cdef uint32_t *s=a,*d=tmp,*z
    cdef int flip=0
    cdef size_t w=1,lo,mid,hi,i,j,k
    while w<n:
        lo=0
        while lo<n:
            mid=lo+w if lo+w<n else n;hi=lo+2*w if lo+2*w<n else n;i=lo;j=mid;k=lo
            while i<mid and j<hi:
                if s[i]<=s[j]:d[k]=s[i];i+=1
                else:d[k]=s[j];j+=1
                k+=1
            while i<mid:d[k]=s[i];i+=1;k+=1
            while j<hi:d[k]=s[j];j+=1;k+=1
            lo+=2*w
        z=s;s=d;d=z;flip^=1
        if w>n//2:break
        w*=2
    if flip:memcpy(a,s,n*4)
cdef tuple b_merge(size_t n):
    cdef uint32_t* base=<uint32_t*>malloc(n*4)
    cdef uint32_t* a=<uint32_t*>malloc(n*4)
    cdef uint32_t* tmp=<uint32_t*>malloc(n*4)
    cdef size_t i
    cdef int r
    cdef double t[7],q,m
    if base==NULL or a==NULL or tmp==NULL:raise MemoryError()
    try:
        for i in range(n):base[i]=mix32(<uint32_t>i)
        for r in range(7):memcpy(a,base,n*4);q=now_s();merge_sort(a,tmp,n);t[r]=now_s()-q
        m=med7(t);return n,m,n/m/1e6,ck32(a,n)
    finally:free(base);free(a);free(tmp)

cdef inline int32_t bsearch(uint32_t* a,size_t n,uint32_t x) noexcept nogil:
    cdef size_t l=0,h=n,m
    while l<h:
        m=l+(h-l)//2
        if a[m]<x:l=m+1
        else:h=m
    return <int32_t>l if l<n and a[l]==x else -1
cdef tuple b_bs(size_t n):
    cdef size_t nq=n*4,i
    cdef uint32_t* a=<uint32_t*>malloc(n*4)
    cdef uint32_t* q=<uint32_t*>malloc(nq*4)
    cdef int r
    cdef int32_t p
    cdef uint64_t c
    cdef double t[7],s,m
    try:
        for i in range(n):a[i]=<uint32_t>(i*2)
        for i in range(nq):q[i]=mix32(<uint32_t>i)%<uint32_t>(2*n)
        for r in range(7):
            s=now_s();c=0
            for i in range(nq):p=bsearch(a,n,q[i]);c+=<uint32_t>(p+1) if p>=0 else 0
            t[r]=now_s()-s
        m=med7(t);return nq,m,nq/m/1e6,c
    finally:free(a);free(q)

cdef tuple b_prefix(size_t n):
    cdef uint32_t* inp=<uint32_t*>malloc(n*4)
    cdef uint64_t* out=<uint64_t*>malloc(n*8)
    cdef size_t i
    cdef int r,z
    cdef uint64_t s
    cdef uint32_t c
    cdef double t[7],q,m
    try:
        for i in range(n):inp[i]=mix32(<uint32_t>i)&1023
        for r in range(7):
            q=now_s();c=0
            for z in range(16):
                s=z
                for i in range(n):s+=inp[i];out[i]=s
                c^=<uint32_t>s
            t[r]=now_s()-q
        c^=ck64(out,n);m=med7(t);return n*16,m,n*16/m/1e6,c
    finally:free(inp);free(out)

cdef tuple b_matrix(size_t n):
    cdef size_t nn=n*n,i,j,k
    cdef uint32_t* a=<uint32_t*>malloc(nn*4)
    cdef uint32_t* b=<uint32_t*>malloc(nn*4)
    cdef uint64_t* c=<uint64_t*>malloc(nn*8)
    cdef uint64_t s
    cdef int r
    cdef double t[7],q,m
    try:
        for i in range(nn):a[i]=mix32(<uint32_t>i)&15;b[i]=mix32(<uint32_t>(i+nn))&15
        for r in range(7):
            q=now_s()
            for i in range(n):
                for j in range(n):
                    s=0
                    for k in range(n):s+=<uint64_t>a[i*n+k]*b[k*n+j]
                    c[i*n+j]=s
            t[r]=now_s()-q
        m=med7(t);return n,m,n*n*n/m/1e6,ck64(c,nn)
    finally:free(a);free(b);free(c)

cdef void make_graph(uint32_t* a,uint32_t* w,size_t n,int d) noexcept nogil:
    cdef size_t i,p
    cdef int e
    for i in range(n):
        for e in range(d):
            p=i*d+e
            if e==0:a[p]=<uint32_t>((i+1)%n)
            elif e==1:a[p]=<uint32_t>((i+n-1)%n)
            else:a[p]=mix32(<uint32_t>p)%<uint32_t>n
            if w!=NULL:w[p]=1+(mix32((<uint32_t>0xabc00000)+<uint32_t>p)&15)
cdef tuple b_bfs(size_t n):
    cdef int d=4,passes=16,r,z,e
    cdef uint32_t* a=<uint32_t*>malloc(n*d*4)
    cdef uint32_t* qq=<uint32_t*>malloc(n*4)
    cdef int32_t* dist=<int32_t*>malloc(n*4)
    cdef size_t i,h,tt
    cdef uint32_t u,v,seen=0
    cdef int32_t nd
    cdef double t[7],s,m
    try:
        make_graph(a,NULL,n,d)
        for r in range(7):
            s=now_s()
            for z in range(passes):
                for i in range(n):dist[i]=-1
                h=0;tt=0;dist[0]=0;qq[tt]=0;tt+=1
                while h<tt:
                    u=qq[h];h+=1;nd=dist[u]+1
                    for e in range(d):
                        v=a[<size_t>u*d+e]
                        if dist[v]<0:dist[v]=nd;qq[tt]=v;tt+=1
                seen^=<uint32_t>(tt+z)
            t[r]=now_s()-s
        m=med7(t);return n*passes,m,n*d*passes/m/1e6,ck32(<uint32_t*>dist,n)^seen
    finally:free(a);free(qq);free(dist)

cdef struct HP:
    uint64_t d
    uint32_t v
cdef inline void hp_push(HP* h,size_t* sz,uint64_t d,uint32_t v) noexcept nogil:
    cdef size_t i=sz[0],p
    sz[0]+=1
    while i:
        p=(i-1)//2
        if h[p].d<=d:break
        h[i]=h[p];i=p
    h[i].d=d;h[i].v=v
cdef inline HP hp_pop(HP* h,size_t* sz) noexcept nogil:
    cdef HP o=h[0],x
    cdef size_t i=0,l,rr,c
    sz[0]-=1;x=h[sz[0]]
    while True:
        l=i*2+1
        if l>=sz[0]:break
        rr=l+1;c=rr if rr<sz[0] and h[rr].d<h[l].d else l
        if h[c].d>=x.d:break
        h[i]=h[c];i=c
    if sz[0]:h[i]=x
    return o
cdef tuple b_dij(size_t n):
    cdef int d=4,r,e
    cdef uint32_t* a=<uint32_t*>malloc(n*d*4)
    cdef uint32_t* w=<uint32_t*>malloc(n*d*4)
    cdef uint64_t* dist=<uint64_t*>malloc(n*8)
    cdef HP* h=<HP*>malloc(n*d*4*sizeof(HP))
    cdef size_t i,p,sz
    cdef HP x
    cdef uint32_t v,c=0
    cdef uint64_t nd
    cdef double t[7],s,m
    try:
        make_graph(a,w,n,d)
        for r in range(7):
            s=now_s()
            for i in range(n):dist[i]=(<uint64_t>-1)//4
            sz=0;dist[0]=0;hp_push(h,&sz,0,0)
            while sz:
                x=hp_pop(h,&sz)
                if x.d!=dist[x.v]:continue
                for e in range(d):
                    p=<size_t>x.v*d+e;v=a[p];nd=x.d+w[p]
                    if nd<dist[v]:dist[v]=nd;hp_push(h,&sz,nd,v)
            c=ck64(dist,n);t[r]=now_s()-s
        m=med7(t);return n,m,n*d/m/1e6,c
    finally:free(a);free(w);free(dist);free(h)

cdef inline uint32_t uf_find(uint32_t* p,uint32_t x) noexcept nogil:
    while p[x]!=x:p[x]=p[p[x]];x=p[x]
    return x
cdef tuple b_uf(size_t n):
    cdef size_t ops=n*4,i
    cdef uint32_t* p=<uint32_t*>malloc(n*4)
    cdef uint8_t* rank=<uint8_t*>malloc(n)
    cdef uint32_t* A=<uint32_t*>malloc(ops*4)
    cdef uint32_t* B=<uint32_t*>malloc(ops*4)
    cdef uint32_t ra,rb,z
    cdef int r
    cdef double t[7],s,m
    try:
        for i in range(ops):A[i]=mix32(<uint32_t>i)%<uint32_t>n;B[i]=mix32(<uint32_t>(i+ops))%<uint32_t>n
        for r in range(7):
            s=now_s()
            for i in range(n):p[i]=<uint32_t>i;rank[i]=0
            for i in range(ops):
                ra=uf_find(p,A[i]);rb=uf_find(p,B[i])
                if ra!=rb:
                    if rank[ra]<rank[rb]:z=ra;ra=rb;rb=z
                    p[rb]=ra
                    if rank[ra]==rank[rb]:rank[ra]+=1
            t[r]=now_s()-s
        for i in range(n):p[i]=uf_find(p,<uint32_t>i)
        m=med7(t);return ops,m,ops/m/1e6,ck32(p,n)
    finally:free(p);free(rank);free(A);free(B)

cdef uint64_t mandel(int w,int mi) noexcept nogil:
    cdef int x,y,it
    cdef double ci,cr,zr,zi,a,b,nz
    cdef uint64_t total=0
    for y in range(w):
        ci=-1.5+3.0*y/(w-1.0)
        for x in range(w):
            cr=-2+3.0*x/(w-1.0);zr=0;zi=0;it=0
            while it<mi:
                a=zr*zr;b=zi*zi
                if a+b>4:break
                nz=a-b+cr;zi=2*zr*zi+ci;zr=nz;it+=1
            total+=it
    return total
cdef tuple b_mandel(int w):
    cdef int r
    cdef double t[7],s,m
    cdef uint64_t c=0,pix=<uint64_t>w*w
    mandel(128 if w>128 else w,20)
    for r in range(7):s=now_s();c=mandel(w,50);t[r]=now_s()-s
    m=med7(t);return pix,m,pix/m/1e6,c

cdef tuple b_array(size_t n):
    cdef uint32_t* inp=<uint32_t*>malloc(n*4)
    cdef uint32_t* v=NULL
    cdef size_t i,nn,cap
    cdef int r
    cdef uint32_t h,x
    cdef double t[7],s,m
    try:
        for i in range(n):inp[i]=mix32(<uint32_t>i)
        for r in range(7):
            s=now_s();v=NULL;nn=0;cap=0
            for i in range(n):
                if nn==cap:cap=cap*2 if cap else 8;v=<uint32_t*>realloc(v,cap*4)
                v[nn]=inp[i];nn+=1
            h=2166136261
            for i in range(n):v[i]^=<uint32_t>i;h=(h^v[i])*<uint32_t>16777619
            while nn:nn-=1;x=v[nn];h=(h^(x+<uint32_t>nn))*<uint32_t>16777619
            free(v);v=NULL;t[r]=now_s()-s
        m=med7(t);return n,m,n/m/1e6,h
    finally:
        if v!=NULL:free(v)
        free(inp)

cdef tuple b_list(size_t n):
    cdef int passes=16,r,p
    cdef size_t i,b,hi,seen
    cdef uint32_t* nxt=<uint32_t*>malloc(n*4)
    cdef uint32_t* val=<uint32_t*>malloc(n*4)
    cdef uint32_t* base=<uint32_t*>malloc(n*4)
    cdef uint32_t h,cur
    cdef double t[7],s,m
    try:
        for i in range(n):base[i]=mix32(<uint32_t>i)
        for r in range(7):
            s=now_s();memcpy(val,base,n*4)
            for i in range(n):nxt[i]=<uint32_t>(i+1) if i+1<n else <uint32_t>0xffffffff
            b=0
            while b<n:
                hi=(b+64 if b+64<n else n)-1
                i=b
                while i<=hi:nxt[i]=<uint32_t>(hi+1) if i==b and hi+1<n else (<uint32_t>0xffffffff if i==b else <uint32_t>(i-1));i+=1
                b+=64
            h=2166136261
            for p in range(passes):
                cur=63 if 64<n else <uint32_t>(n-1);seen=0
                while cur!=<uint32_t>0xffffffff and seen<n:
                    val[cur]^=<uint32_t>(seen+p);h=(h^(val[cur]+cur+<uint32_t>p))*<uint32_t>16777619;cur=nxt[cur];seen+=1
                h=(h^<uint32_t>seen)*<uint32_t>16777619
            t[r]=now_s()-s
        m=med7(t);return n*passes,m,n*passes/m/1e6,h
    finally:free(nxt);free(val);free(base)

cdef tuple b_queue(size_t ops):
    cdef size_t cap=ops//2+1024,i,h,tt,cnt
    cdef uint32_t* b=<uint32_t*>malloc(cap*4)
    cdef uint32_t* inp=<uint32_t*>malloc(ops*4)
    cdef uint32_t z
    cdef int r
    cdef double t[7],s,m
    try:
        for i in range(ops):inp[i]=mix32(<uint32_t>i)
        for r in range(7):
            s=now_s();h=0;tt=0;cnt=0;z=0
            for i in range(ops):
                if (i&3)!=3:
                    if cnt==cap:z^=b[h];h=(h+1)%cap;cnt-=1
                    b[tt]=inp[i];tt=(tt+1)%cap;cnt+=1
                elif cnt:z^=b[h];h=(h+1)%cap;cnt-=1
            while cnt:z^=b[h];h=(h+1)%cap;cnt-=1
            t[r]=now_s()-s
        m=med7(t);return ops,m,ops/m/1e6,z
    finally:free(b);free(inp)

cdef size_t np2(size_t x) noexcept nogil:
    cdef size_t p=1
    while p<x:p<<=1
    return p
cdef tuple b_hash(size_t n):
    cdef size_t cap=np2(n*2),mask=cap-1,i,p
    cdef uint32_t* k=<uint32_t*>malloc(cap*4)
    cdef uint32_t* v=<uint32_t*>malloc(cap*4)
    cdef uint32_t* ik=<uint32_t*>malloc(n*4)
    cdef uint32_t* iv=<uint32_t*>malloc(n*4)
    cdef uint32_t key,h
    cdef int r
    cdef double t[7],s,m
    try:
        for i in range(n):ik[i]=mix32(<uint32_t>i)|1;iv[i]=mix32(<uint32_t>(i+0x55555555))
        for r in range(7):
            s=now_s();memset(k,0,cap*4)
            for i in range(n):
                key=ik[i];p=hash32(key)&mask
                while k[p] and k[p]!=key:p=(p+1)&mask
                k[p]=key;v[p]=iv[i]
            h=0
            for i in range(n):
                key=ik[i];p=hash32(key)&mask
                while k[p]!=key:p=(p+1)&mask
                v[p]^=<uint32_t>i;h^=v[p]
            t[r]=now_s()-s
        m=med7(t);return n,m,n*2/m/1e6,h
    finally:free(k);free(v);free(ik);free(iv)

cdef inline void heap_push(uint32_t* h,size_t* sz,uint32_t x) noexcept nogil:
    cdef size_t i=sz[0],p
    sz[0]+=1
    while i:
        p=(i-1)//2
        if h[p]<=x:break
        h[i]=h[p];i=p
    h[i]=x
cdef inline uint32_t heap_pop(uint32_t* h,size_t* sz) noexcept nogil:
    cdef uint32_t o=h[0],x
    cdef size_t i=0,l,rr,c
    sz[0]-=1;x=h[sz[0]]
    while True:
        l=i*2+1
        if l>=sz[0]:break
        rr=l+1;c=rr if rr<sz[0] and h[rr]<h[l] else l
        if h[c]>=x:break
        h[i]=h[c];i=c
    if sz[0]:h[i]=x
    return o
cdef tuple b_heap(size_t n):
    cdef uint32_t* h=<uint32_t*>malloc(n*4)
    cdef uint32_t* inp=<uint32_t*>malloc(n*4)
    cdef size_t i,sz
    cdef uint32_t c,x
    cdef int r
    cdef double t[7],s,m
    try:
        for i in range(n):inp[i]=mix32(<uint32_t>i)
        for r in range(7):
            s=now_s();sz=0
            for i in range(n):heap_push(h,&sz,inp[i])
            c=0
            for i in range(n):x=heap_pop(h,&sz);c^=x+<uint32_t>i
            t[r]=now_s()-s
        m=med7(t);return n,m,n*2/m/1e6,c
    finally:free(h);free(inp)

cdef tuple b_bst(size_t n):
    cdef uint32_t* k=<uint32_t*>malloc(n*4)
    cdef uint32_t* inp=<uint32_t*>malloc(n*4)
    cdef int32_t* l=<int32_t*>malloc(n*4)
    cdef int32_t* rr=<int32_t*>malloc(n*4)
    cdef size_t i
    cdef int32_t root,node,cur
    cdef uint32_t key,h
    cdef int r
    cdef double t[7],s,m
    try:
        for i in range(n):inp[i]=mix32(<uint32_t>i)
        for r in range(7):
            s=now_s();root=-1
            for i in range(n):
                key=inp[i];k[i]=key;l[i]=-1;rr[i]=-1;node=<int32_t>i
                if root<0:root=node;continue
                cur=root
                while True:
                    if key<k[cur]:
                        if l[cur]<0:l[cur]=node;break
                        cur=l[cur]
                    else:
                        if rr[cur]<0:rr[cur]=node;break
                        cur=rr[cur]
            h=0;i=0
            while i<n:
                key=inp[i];cur=root
                while cur>=0 and k[cur]!=key:cur=l[cur] if key<k[cur] else rr[cur]
                if cur>=0:h^=<uint32_t>(cur+1)
                i+=3
            t[r]=now_s()-s
        m=med7(t);return n,m,n/m/1e6,h
    finally:free(k);free(inp);free(l);free(rr)

cdef tuple b_trie(size_t n):
    cdef int passes=32,r,sh,cc,p
    cdef size_t mx=1+n*8,i,used,idx
    cdef int32_t* ch=<int32_t*>malloc(mx*16*4)
    cdef uint8_t* term=<uint8_t*>malloc(mx)
    cdef uint32_t* words=<uint32_t*>malloc(n*4)
    cdef uint32_t w,h
    cdef int32_t node,v
    cdef double t[7],s,m
    try:
        for i in range(n):words[i]=mix32(<uint32_t>i)
        for r in range(7):
            s=now_s()
            for i in range(mx*16):ch[i]=-1
            memset(term,0,mx);used=1
            for i in range(n):
                w=words[i];node=0;sh=28
                while sh>=0:
                    cc=(w>>sh)&15;idx=<size_t>node*16+cc;v=ch[idx]
                    if v<0:v=<int32_t>used;used+=1;ch[idx]=v
                    node=v;sh-=4
                term[node]=1
            h=<uint32_t>used
            for p in range(passes):
                i=0
                while i<n:
                    w=words[i];node=0;sh=28
                    while sh>=0 and node>=0:node=ch[<size_t>node*16+((w>>sh)&15)];sh-=4
                    if node>=0 and term[node]:h^=<uint32_t>(node+1+p)
                    i+=2
            t[r]=now_s()-s
        m=med7(t);return n*passes,m,n*passes/m/1e6,h
    finally:free(ch);free(term);free(words)

def bench(str kernel, uint64_t size):
    cdef tuple x
    if kernel=="integer50":x=b_integer(size)
    elif kernel=="json_escape":x=b_json(<size_t>size)
    elif kernel=="merge_sort":x=b_merge(<size_t>size)
    elif kernel=="binary_search":x=b_bs(<size_t>size)
    elif kernel=="prefix_sum":x=b_prefix(<size_t>size)
    elif kernel=="matrix_mul":x=b_matrix(<size_t>size)
    elif kernel=="bfs":x=b_bfs(<size_t>size)
    elif kernel=="dijkstra":x=b_dij(<size_t>size)
    elif kernel=="union_find":x=b_uf(<size_t>size)
    elif kernel=="mandelbrot":x=b_mandel(<int>size)
    elif kernel=="dynamic_array":x=b_array(<size_t>size)
    elif kernel=="linked_list":x=b_list(<size_t>size)
    elif kernel=="queue_ring":x=b_queue(<size_t>size)
    elif kernel=="hash_table":x=b_hash(<size_t>size)
    elif kernel=="binary_heap":x=b_heap(<size_t>size)
    elif kernel=="bst":x=b_bst(<size_t>size)
    elif kernel=="trie":x=b_trie(<size_t>size)
    else:raise ValueError(kernel)
    print(f"RESULT kernel={kernel} units={x[0]} rounds=7 seconds={x[1]:.9f} rate={x[2]:.6f} checksum={x[3]}")
