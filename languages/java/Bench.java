import java.util.*;
public final class Bench{
static double now(){return System.nanoTime()*1e-9;}static double med(double[]a){Arrays.sort(a);return a[a.length/2];}
static void emit(String k,long u,int r,double s,double rate,long c){System.out.printf(Locale.ROOT,"RESULT kernel=%s units=%s rounds=%d seconds=%.9f rate=%.6f checksum=%s%n",k,Long.toUnsignedString(u),r,s,rate,Long.toUnsignedString(c));}
static long mix64(long x){x+=0x9e3779b97f4a7c15L;x=(x^(x>>>30))*0xbf58476d1ce4e5b9L;x=(x^(x>>>27))*0x94d049bb133111ebL;return x^(x>>>31);}
static long c32(int[]a){long h=1469598103934665603L;for(int i=0;i<a.length;i++){h^=Integer.toUnsignedLong(a[i])+(long)i*0x9e3779b1L;h*=1099511628211L;}return h;}
static long c64(long[]a){long h=1469598103934665603L;for(int i=0;i<a.length;i++){h^=a[i]+(long)i*0x9e3779b97f4a7c15L;h*=1099511628211L;}return h;}
interface F{long run();}static long[] timed(int r,F f,double[]sec){long c=0;for(int i=0;i<r;i++){double a=now();c=f.run();sec[i]=now()-a;}return new long[]{c};}

static long integer50(long n){long mask=(1L<<50)-1,x=88172645463325252L&mask,s=0;for(long i=0;i<n;i++){x^=x>>>7;x^=(x<<8)&mask;x^=x>>>9;x&=mask;s=(s+(x^(x>>>17)))&mask;}return s;}
static void benchInteger(long n,int r){integer50(n/20+1);double[]t=new double[r];long c=0;for(int i=0;i<r;i++){double a=now();c=integer50(n);t[i]=now()-a;}double m=med(t);emit("integer50",n,r,m,n/m/1e6,c);}

static final byte[]PAT={97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47};
static int jsonEscape(byte[]in,byte[]out){byte[]h="0123456789abcdef".getBytes(java.nio.charset.StandardCharsets.US_ASCII);int j=0;out[j++]=34;for(byte bv:in){int c=bv&255;switch(c){case 34-> {out[j++]=92;out[j++]=34;}case 92->{out[j++]=92;out[j++]=92;}case 8->{out[j++]=92;out[j++]=98;}case 12->{out[j++]=92;out[j++]=102;}case 10->{out[j++]=92;out[j++]=110;}case 13->{out[j++]=92;out[j++]=114;}case 9->{out[j++]=92;out[j++]=116;}default->{if(c<32){out[j++]=92;out[j++]=117;out[j++]=48;out[j++]=48;out[j++]=h[c>>>4];out[j++]=h[c&15];}else out[j++]=(byte)c;}}}out[j++]=34;return j;}
static void benchJSON(long n0,int r){int n=Math.toIntExact(n0);byte[]in=new byte[n],out=new byte[n*6+2];for(int i=0;i<n;i++)in[i]=PAT[i%23];int on=jsonEscape(in,out);double[]t=new double[r];for(int x=0;x<r;x++){double a=now();on=jsonEscape(in,out);t[x]=now()-a;}long c=on;for(int i=0;i<on;i++)c+=out[i]&255;double m=med(t);emit("json_escape",n0,r,m,n0/m/1e9,c);}

static void mergeSort(int[]a,int[]tmp){int n=a.length;int[]src=a,dst=tmp;boolean srcA=true;for(int w=1;w<n;w*=2){for(int lo=0;lo<n;lo+=2*w){int mid=Math.min(lo+w,n),hi=Math.min(lo+2*w,n),i=lo,j=mid,k=lo;while(i<mid&&j<hi)dst[k++]=Integer.compareUnsigned(src[i],src[j])<=0?src[i++]:src[j++];while(i<mid)dst[k++]=src[i++];while(j<hi)dst[k++]=src[j++];}int[]z=src;src=dst;dst=z;srcA=!srcA;if(w>n/2)break;}if(!srcA)System.arraycopy(src,0,a,0,n);}
static void benchMerge(long n0,int r){int n=Math.toIntExact(n0);int[]base=new int[n],work=new int[n],tmp=new int[n];for(int i=0;i<n;i++)base[i]=(int)mix64(i);System.arraycopy(base,0,work,0,n);mergeSort(work,tmp);double[]t=new double[r];for(int x=0;x<r;x++){System.arraycopy(base,0,work,0,n);double a=now();mergeSort(work,tmp);t[x]=now()-a;}double m=med(t);emit("merge_sort",n0,r,m,n0/m/1e6,c32(work));}

static int bs(int[]a,int x){int lo=0,hi=a.length;while(lo<hi){int m=lo+(hi-lo)/2;if(Integer.compareUnsigned(a[m],x)<0)lo=m+1;else hi=m;}return lo<a.length&&a[lo]==x?lo:-1;}
static long bsOnce(int[]a,long q){long h=0;long mod=2L*a.length;for(long i=0;i<q;i++){int x=(int)Long.remainderUnsigned(mix64(i),mod);int p=bs(a,x);if(p>=0)h+=p+1L;}return h;}
static void benchBS(long n0,int r){int n=Math.toIntExact(n0);int[]a=new int[n];for(int i=0;i<n;i++)a[i]=i*2;long q=n0*4;bsOnce(a,q/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=bsOnce(a,q);t[x]=now()-s;}double m=med(t);emit("binary_search",q,r,m,q/m/1e6,c);}

static long prefixOnce(int[]in,long[]out,int passes){long c=0;for(int p=0;p<passes;p++){long s=p;for(int i=0;i<in.length;i++){s+=Integer.toUnsignedLong(in[i]);out[i]=s;}c^=s;}return c;}
static void benchPrefix(long n0,int r){int n=Math.toIntExact(n0);int[]in=new int[n];long[]out=new long[n];for(int i=0;i<n;i++)in[i]=(int)(mix64(i)&1023);prefixOnce(in,out,1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=prefixOnce(in,out,16);t[x]=now()-s;}c^=c64(out);double m=med(t);emit("prefix_sum",n0*16,r,m,n0*16/m/1e6,c);}

static void mm(int[]a,int[]b,long[]c,int n){for(int i=0;i<n;i++)for(int j=0;j<n;j++){long s=0;for(int k=0;k<n;k++)s+=(long)a[i*n+k]*b[k*n+j];c[i*n+j]=s;}}
static void benchMM(long n0,int r){int n=(int)n0,nn=n*n;int[]a=new int[nn],b=new int[nn];long[]c=new long[nn];for(int i=0;i<nn;i++){a[i]=(int)(mix64(i)&15);b[i]=(int)(mix64(i+nn)&15);}mm(a,b,c,n);double[]t=new double[r];for(int x=0;x<r;x++){double s=now();mm(a,b,c,n);t[x]=now()-s;}double m=med(t);emit("matrix_mul",n0,r,m,(double)n*n*n/m/1e6,c64(c));}

static int[][]graph(int n,int d,boolean weights){int[]a=new int[n*d],w=weights?new int[n*d]:null;for(int i=0;i<n;i++)for(int e=0;e<d;e++){int p=i*d+e,v;if(e==0)v=(i+1)%n;else if(e==1)v=(i+n-1)%n;else v=(int)Long.remainderUnsigned(mix64(p),n);a[p]=v;if(weights)w[p]=(int)(1+(mix64(0xabc00000L+p)&15));}return new int[][]{a,w};}
static long bfsOnce(int[]a,int n,int d,int[]dist,int[]q){Arrays.fill(dist,-1);int h=0,t=0;dist[0]=0;q[t++]=0;while(h<t){int u=q[h++],nd=dist[u]+1;for(int e=0;e<d;e++){int v=a[u*d+e];if(dist[v]<0){dist[v]=nd;q[t++]=v;}}}long c=0;for(int i=0;i<n;i++)c+=(long)(dist[i]+1)*(i+1L);return c;}
static long bfsMany(int[]a,int n,int d,int[]dist,int[]q,int passes){long h=0;for(int p=0;p<passes;p++)h+=bfsOnce(a,n,d,dist,q)^((long)p*0x9e3779b97f4a7c15L);return h;}
static void benchBFS(long n0,int r){int n=(int)n0,d=4;int[]a=graph(n,d,false)[0],dist=new int[n],q=new int[n];bfsMany(a,n,d,dist,q,1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=bfsMany(a,n,d,dist,q,16);t[x]=now()-s;}double m=med(t);emit("bfs",n0*16,r,m,(double)n*d*16/m/1e6,c);}

static final class HP{long d;int v;HP(long d,int v){this.d=d;this.v=v;}}
static void hpPush(HP[]h,int[]sz,HP x){int i=sz[0]++;while(i>0){int p=(i-1)/2;if(h[p].d<=x.d)break;h[i]=h[p];i=p;}h[i]=x;}
static HP hpPop(HP[]h,int[]sz){HP o=h[0],x=h[--sz[0]];int i=0;while(true){int l=i*2+1;if(l>=sz[0])break;int rr=l+1,c=rr<sz[0]&&h[rr].d<h[l].d?rr:l;if(h[c].d>=x.d)break;h[i]=h[c];i=c;}if(sz[0]>0)h[i]=x;return o;}
static long dijOnce(int[]a,int[]w,int n,int d,long[]dist,HP[]h){Arrays.fill(dist,Long.MAX_VALUE/4);int[]sz={0};dist[0]=0;hpPush(h,sz,new HP(0,0));while(sz[0]>0){HP x=hpPop(h,sz);if(x.d!=dist[x.v])continue;for(int e=0;e<d;e++){int p=x.v*d+e,v=a[p];long nd=x.d+w[p];if(nd<dist[v]){dist[v]=nd;hpPush(h,sz,new HP(nd,v));}}}long c=0;for(int i=0;i<n;i++)c^=dist[i]+(long)i*0x9e3779b97f4a7c15L;return c;}
static void benchDij(long n0,int r){int n=(int)n0,d=4;int[][]g=graph(n,d,true);long[]dist=new long[n];HP[]h=new HP[n*d*4];dijOnce(g[0],g[1],n,d,dist,h);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=dijOnce(g[0],g[1],n,d,dist,h);t[x]=now()-s;}double m=med(t);emit("dijkstra",n0,r,m,(double)n*d/m/1e6,c);}

static int ufFind(int[]p,int x){while(p[x]!=x){p[x]=p[p[x]];x=p[x];}return x;}
static long ufOnce(int[]p,byte[]rank,int n,long ops){for(int i=0;i<n;i++){p[i]=i;rank[i]=0;}for(long i=0;i<ops;i++){int a=(int)Long.remainderUnsigned(mix64(i),n),b=(int)Long.remainderUnsigned(mix64(i+ops),n),ra=ufFind(p,a),rb=ufFind(p,b);if(ra!=rb){if((rank[ra]&255)<(rank[rb]&255)){int z=ra;ra=rb;rb=z;}p[rb]=ra;if(rank[ra]==rank[rb])rank[ra]++;}}long h=0;for(int i=0;i<n;i+=17)h+=ufFind(p,i);return h;}
static void benchUF(long n0,int r){int n=(int)n0;long ops=n0*4;int[]p=new int[n];byte[]rank=new byte[n];ufOnce(p,rank,n,ops/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=ufOnce(p,rank,n,ops);t[x]=now()-s;}double m=med(t);emit("union_find",ops,r,m,ops/m/1e6,c);}

static long mandel(int w,int mi){long sum=0;for(int y=0;y<w;y++){double ci=-1.5+3.0*y/(w-1.0);for(int x=0;x<w;x++){double cr=-2+3.0*x/(w-1.0),zr=0,zi=0;int it=0;while(it<mi){double a=zr*zr,b=zi*zi;if(a+b>4)break;double nz=a-b+cr;zi=2*zr*zi+ci;zr=nz;it++;}sum+=it;}}return sum;}
static void benchMandel(long w0,int r){int w=(int)w0;mandel(Math.min(w,128),20);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=mandel(w,50);t[x]=now()-s;}double m=med(t);emit("mandelbrot",w0*w0,r,m,w0*w0/m/1e6,c);}

static long vaOnce(int n){long[]v=new long[8];int size=0;for(int i=0;i<n;i++){if(size==v.length)v=Arrays.copyOf(v,v.length*2);v[size++]=mix64(i);}long h=0;for(int i=0;i<n;i++){v[i]^=i;h+=v[i];}while(size>0)h^=v[--size];return h;}
static void benchVA(long n0,int r){vaOnce((int)n0/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=vaOnce((int)n0);t[x]=now()-s;}double m=med(t);emit("dynamic_array",n0,r,m,n0/m/1e6,c);}

static long llOnce(int[]next,long[]val,int n,int passes){for(int i=0;i<n;i++){next[i]=i+1<n?i+1:-1;val[i]=mix64(i);}int B=64;for(int base=0;base<n;base+=B){int hi=Math.min(base+B,n)-1;for(int i=base;i<=hi;i++)next[i]=i==base?(hi+1<n?hi+1:-1):i-1;}long h=0;for(int p=0;p<passes;p++){int cur=B<n?B-1:n-1,seen=0;while(cur>=0&&seen<n){val[cur]^=seen+p;h+=val[cur];cur=next[cur];seen++;}h^=seen;}return h;}
static void benchLL(long n0,int r){int n=(int)n0;int[]next=new int[n];long[]val=new long[n];llOnce(next,val,n,1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=llOnce(next,val,n,16);t[x]=now()-s;}double m=med(t);emit("linked_list",n0*16,r,m,n0*16/m/1e6,c);}

static long qrOnce(long[]b,long ops){int cap=b.length,h=0,t=0,cnt=0;long z=0;for(long i=0;i<ops;i++){if((i&3)!=3){if(cnt==cap){z^=b[h];h=(h+1)%cap;cnt--;}b[t]=mix64(i);t=(t+1)%cap;cnt++;}else if(cnt>0){long x=b[h];h=(h+1)%cap;cnt--;z+=x;}}while(cnt>0){z^=b[h];h=(h+1)%cap;cnt--;}return z;}
static void benchQR(long ops,int r){long[]b=new long[(int)(ops/2+1024)];qrOnce(b,ops/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=qrOnce(b,ops);t[x]=now()-s;}double m=med(t);emit("queue_ring",ops,r,m,ops/m/1e6,c);}

static int np2(int x){int p=1;while(p<x)p<<=1;return p;}
static long htOnce(long[]k,long[]v,int n){Arrays.fill(k,0);int mask=k.length-1;long h=0;for(int i=0;i<n;i++){long key=mix64(i)|1,val=mix64(i+0x55555555L);int p=(int)mix64(key)&mask;while(k[p]!=0&&k[p]!=key)p=(p+1)&mask;k[p]=key;v[p]=val;}for(int i=0;i<n;i++){long key=mix64(i)|1;int p=(int)mix64(key)&mask;while(k[p]!=key)p=(p+1)&mask;v[p]^=i;h+=v[p];}return h;}
static void benchHT(long n0,int r){int n=(int)n0,cap=np2(n*2);long[]k=new long[cap],v=new long[cap];htOnce(k,v,n/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=htOnce(k,v,n);t[x]=now()-s;}double m=med(t);emit("hash_table",n0,r,m,n0*2/m/1e6,c);}

static boolean ule(long a,long b){return Long.compareUnsigned(a,b)<=0;}
static void bhPush(long[]h,int[]sz,long x){int i=sz[0]++;while(i>0){int p=(i-1)/2;if(ule(h[p],x))break;h[i]=h[p];i=p;}h[i]=x;}
static long bhPop(long[]h,int[]sz){long o=h[0],x=h[--sz[0]];int i=0;while(true){int l=i*2+1;if(l>=sz[0])break;int rr=l+1,c=rr<sz[0]&&Long.compareUnsigned(h[rr],h[l])<0?rr:l;if(Long.compareUnsigned(h[c],x)>=0)break;h[i]=h[c];i=c;}if(sz[0]>0)h[i]=x;return o;}
static long bhOnce(long[]h,int n){int[]sz={0};for(int i=0;i<n;i++)bhPush(h,sz,mix64(i));long c=0;for(int i=0;i<n;i++)c^=bhPop(h,sz)+i;return c;}
static void benchBH(long n0,int r){int n=(int)n0;long[]h=new long[n];bhOnce(h,n/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=bhOnce(h,n);t[x]=now()-s;}double m=med(t);emit("binary_heap",n0,r,m,n0*2/m/1e6,c);}

static long bstOnce(long[]k,int[]l,int[]rr,int n){int root=-1;for(int i=0;i<n;i++){long key=mix64(i);k[i]=key;l[i]=rr[i]=-1;if(root<0){root=i;continue;}int cur=root;while(true){if(Long.compareUnsigned(key,k[cur])<0){if(l[cur]<0){l[cur]=i;break;}cur=l[cur];}else{if(rr[cur]<0){rr[cur]=i;break;}cur=rr[cur];}}}long h=0;for(int i=0;i<n;i+=3){long key=mix64(i);int cur=root;while(cur>=0&&k[cur]!=key)cur=Long.compareUnsigned(key,k[cur])<0?l[cur]:rr[cur];if(cur>=0)h+=cur+1L;}return h;}
static void benchBST(long n0,int r){int n=(int)n0;long[]k=new long[n];int[]l=new int[n],rr=new int[n];bstOnce(k,l,rr,n/20+1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=bstOnce(k,l,rr,n);t[x]=now()-s;}double m=med(t);emit("bst",n0,r,m,n0/m/1e6,c);}

static long trieOnce(int[]ch,byte[]term,int words,int passes){Arrays.fill(ch,-1);Arrays.fill(term,(byte)0);int used=1;for(int i=0;i<words;i++){int w=(int)mix64(i),node=0;for(int sh=28;sh>=0;sh-=4){int c=(w>>>sh)&15,p=node*16+c;if(ch[p]<0)ch[p]=used++;node=ch[p];}term[node]=1;}long h=used;for(int p=0;p<passes;p++)for(int i=0;i<words;i+=2){int w=(int)mix64(i),node=0;for(int sh=28;sh>=0&&node>=0;sh-=4)node=ch[node*16+((w>>>sh)&15)];if(node>=0&&term[node]!=0)h+=node+1L+p;}return h;}
static void benchTrie(long n0,int r){int n=(int)n0,mx=1+n*8;int[]ch=new int[mx*16];byte[]term=new byte[mx];trieOnce(ch,term,n/20+1,1);double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=trieOnce(ch,term,n,32);t[x]=now()-s;}double m=med(t);emit("trie",n0*32,r,m,n0*32/m/1e6,c);}

static long size(String k){return switch(k){case"integer50"->200000000L;case"json_escape"->16000000L;case"merge_sort","binary_search","union_find","hash_table","binary_heap"->1000000L;case"prefix_sum"->8000000L;case"matrix_mul"->320L;case"bfs"->200000L;case"dijkstra","trie"->100000L;case"mandelbrot"->1600L;case"dynamic_array"->5000000L;case"linked_list"->4000000L;case"queue_ring"->10000000L;case"bst"->300000L;default->0L;};}
public static void main(String[]args){String k=args.length>0?args[0]:"integer50";long n=args.length>1?Long.parseLong(args[1]):size(k);int r=args.length>2?Integer.parseInt(args[2]):7;switch(k){case"integer50"->benchInteger(n,r);case"json_escape"->benchJSON(n,r);case"merge_sort"->benchMerge(n,r);case"binary_search"->benchBS(n,r);case"prefix_sum"->benchPrefix(n,r);case"matrix_mul"->benchMM(n,r);case"bfs"->benchBFS(n,r);case"dijkstra"->benchDij(n,r);case"union_find"->benchUF(n,r);case"mandelbrot"->benchMandel(n,r);case"dynamic_array"->benchVA(n,r);case"linked_list"->benchLL(n,r);case"queue_ring"->benchQR(n,r);case"hash_table"->benchHT(n,r);case"binary_heap"->benchBH(n,r);case"bst"->benchBST(n,r);case"trie"->benchTrie(n,r);default->throw new IllegalArgumentException(k);}}
}