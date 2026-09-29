import java.util.*;

public final class Bench {
  static double now(){ return System.nanoTime()*1e-9; }
  static double med(double[] a){ Arrays.sort(a); return a[a.length/2]; }
  static void emit(String k,long u,int r,double s,double rate,long c){
    System.out.printf(Locale.ROOT,"RESULT kernel=%s units=%d rounds=%d seconds=%.9f rate=%.6f checksum=%s%n",
      k,u,r,s,rate,Long.toUnsignedString(c));
  }
  static int mix32(int x){ x+=0x9e3779b9; x^=x>>>16; x*=0x85ebca6b; x^=x>>>13; x*=0xc2b2ae35; return x^(x>>>16); }
  static int hash32(int x){ x^=x>>>16; x*=0x7feb352d; x^=x>>>15; x*=0x846ca68b; return x^(x>>>16); }
  static int ck32(int[] a){ int h=0x811c9dc5; for(int x:a){h^=x;h*=0x01000193;} return h; }
  static int ck64(long[] a){ int h=0x811c9dc5; for(long x:a){h^=(int)x;h*=0x01000193;h^=(int)(x>>>32);h*=0x01000193;} return h; }
  static long u32(int x){ return Integer.toUnsignedLong(x); }

  static long integer50(long n){
    final long mask=(1L<<50)-1; long x=88172645463325252L&mask,s=0;
    for(long i=0;i<n;i++){x^=x>>>7;x^=(x<<8)&mask;x^=x>>>9;x&=mask;s=(s+(x^(x>>>17)))&mask;} return s;
  }
  static void benchInteger(long n,int r){
    integer50(n/20+1);double[]t=new double[r];long c=0;
    for(int i=0;i<r;i++){double a=now();c=integer50(n);t[i]=now()-a;}
    double m=med(t);emit("integer50",n,r,m,n/m/1e6,c);
  }

  static final byte[] PAT={97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47};
  static int jsonEscape(byte[] in,byte[] out){
    byte[]hx="0123456789abcdef".getBytes(java.nio.charset.StandardCharsets.US_ASCII);int j=0;out[j++]=34;
    for(byte bv:in){int c=bv&255;switch(c){
      case 34->{out[j++]=92;out[j++]=34;} case 92->{out[j++]=92;out[j++]=92;}
      case 8->{out[j++]=92;out[j++]=98;} case 12->{out[j++]=92;out[j++]=102;}
      case 10->{out[j++]=92;out[j++]=110;} case 13->{out[j++]=92;out[j++]=114;}
      case 9->{out[j++]=92;out[j++]=116;} default->{if(c<32){out[j++]=92;out[j++]=117;out[j++]=48;out[j++]=48;out[j++]=hx[c>>>4];out[j++]=hx[c&15];}else out[j++]=(byte)c;}
    }} out[j++]=34;return j;
  }
  static void benchJSON(long n0,int r){
    int n=Math.toIntExact(n0);byte[]in=new byte[n],out=new byte[n*6+2];for(int i=0;i<n;i++)in[i]=PAT[i%23];
    int on=jsonEscape(in,out);double[]t=new double[r];for(int x=0;x<r;x++){double a=now();on=jsonEscape(in,out);t[x]=now()-a;}
    long c=on;for(int i=0;i<on;i++)c+=out[i]&255;double m=med(t);emit("json_escape",n0,r,m,n0/m/1e9,c);
  }

  static void mergeSort(int[] a,int[] tmp){
    int n=a.length;int[]src=a,dst=tmp;boolean flip=false;
    for(int w=1;w<n;w*=2){
      for(int lo=0;lo<n;lo+=2*w){
        int mid=Math.min(lo+w,n),hi=Math.min(lo+2*w,n),i=lo,j=mid,k=lo;
        while(i<mid&&j<hi)dst[k++]=Integer.compareUnsigned(src[i],src[j])<=0?src[i++]:src[j++];
        while(i<mid)dst[k++]=src[i++];while(j<hi)dst[k++]=src[j++];
      }
      int[]z=src;src=dst;dst=z;flip=!flip;if(w>n/2)break;
    }
    if(flip)System.arraycopy(src,0,a,0,n);
  }
  static void benchMerge(long n0,int r){
    int n=Math.toIntExact(n0);int[]base=new int[n],a=new int[n],tmp=new int[n];for(int i=0;i<n;i++)base[i]=mix32(i);
    double[]t=new double[r];for(int x=0;x<r;x++){System.arraycopy(base,0,a,0,n);double q=now();mergeSort(a,tmp);t[x]=now()-q;}
    double m=med(t);emit("merge_sort",n0,r,m,n0/m/1e6,u32(ck32(a)));
  }

  static int bs(int[]a,int x){
    int l=0,h=a.length;while(l<h){int m=l+(h-l)/2;if(Integer.compareUnsigned(a[m],x)<0)l=m+1;else h=m;}
    return l<a.length&&a[l]==x?l:-1;
  }
  static long bsOnce(int[]a,int[]q){long h=0;for(int x:q){int p=bs(a,x);if(p>=0)h+=p+1L;}return h;}
  static void benchBS(long n0,int r){
    int n=(int)n0,nq=n*4;int[]a=new int[n],q=new int[nq];for(int i=0;i<n;i++)a[i]=i*2;for(int i=0;i<nq;i++)q[i]=Integer.remainderUnsigned(mix32(i),2*n);
    double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=bsOnce(a,q);t[x]=now()-s;}
    double m=med(t);emit("binary_search",nq,r,m,nq/m/1e6,c);
  }

  static long prefix(int[]in,long[]out,int passes){
    long c=0;for(int p=0;p<passes;p++){long s=p;for(int i=0;i<in.length;i++){s+=u32(in[i]);out[i]=s;}c^=s;}return c;
  }
  static void benchPrefix(long n0,int r){
    int n=(int)n0;int[]in=new int[n];long[]out=new long[n];for(int i=0;i<n;i++)in[i]=mix32(i)&1023;
    double[]t=new double[r];long c=0;for(int x=0;x<r;x++){double s=now();c=prefix(in,out,16);t[x]=now()-s;}c^=u32(ck64(out));
    double m=med(t);emit("prefix_sum",n0*16,r,m,n0*16/m/1e6,c);
  }

  static void mm(int[]a,int[]b,long[]c,int n){
    for(int i=0;i<n;i++)for(int j=0;j<n;j++){long s=0;for(int k=0;k<n;k++)s+=(long)a[i*n+k]*b[k*n+j];c[i*n+j]=s;}
  }
  static void benchMM(long n0,int r){
    int n=(int)n0,nn=n*n;int[]a=new int[nn],b=new int[nn];long[]c=new long[nn];
    for(int i=0;i<nn;i++){a[i]=mix32(i)&15;b[i]=mix32(i+nn)&15;}
    double[]t=new double[r];for(int x=0;x<r;x++){double s=now();mm(a,b,c,n);t[x]=now()-s;}
    double m=med(t);emit("matrix_mul",n0,r,m,(double)n*n*n/m/1e6,u32(ck64(c)));
  }

  static int[][] graph(int n,int d,boolean weights){
    int[]a=new int[n*d],w=weights?new int[n*d]:null;
    for(int i=0;i<n;i++)for(int e=0;e<d;e++){int p=i*d+e,v;if(e==0)v=(i+1)%n;else if(e==1)v=(i+n-1)%n;else v=Integer.remainderUnsigned(mix32(p),n);a[p]=v;if(weights)w[p]=1+(mix32(0xabc00000+p)&15);}
    return new int[][]{a,w};
  }
  static int bfsOnce(int[]a,int n,int d,int[]dist,int[]q){
    Arrays.fill(dist,-1);int h=0,t=0;dist[0]=0;q[t++]=0;
    while(h<t){int u=q[h++],nd=dist[u]+1;for(int e=0;e<d;e++){int v=a[u*d+e];if(dist[v]<0){dist[v]=nd;q[t++]=v;}}}return t;
  }
  static void benchBFS(long n0,int r){
    int n=(int)n0,d=4,passes=16;int[]a=graph(n,d,false)[0],dist=new int[n],q=new int[n];double[]t=new double[r];int seen=0;
    for(int x=0;x<r;x++){double s=now();for(int z=0;z<passes;z++)seen^=bfsOnce(a,n,d,dist,q)+z;t[x]=now()-s;}
    int c=ck32(dist)^seen;double m=med(t);emit("bfs",n0*passes,r,m,(double)n*d*passes/m/1e6,u32(c));
  }

  static final class HP{long d;int v;HP(long d,int v){this.d=d;this.v=v;}}
  static void hpPush(HP[]h,int[]sz,HP x){int i=sz[0]++;while(i>0){int p=(i-1)/2;if(h[p].d<=x.d)break;h[i]=h[p];i=p;}h[i]=x;}
  static HP hpPop(HP[]h,int[]sz){HP o=h[0],x=h[--sz[0]];int i=0;while(true){int l=i*2+1;if(l>=sz[0])break;int rr=l+1,c=rr<sz[0]&&h[rr].d<h[l].d?rr:l;if(h[c].d>=x.d)break;h[i]=h[c];i=c;}if(sz[0]>0)h[i]=x;return o;}
  static int dijkstra(int[]a,int[]w,int n,int d,long[]dist,HP[]heap){
    Arrays.fill(dist,Long.MAX_VALUE/4);int[]sz={0};dist[0]=0;hpPush(heap,sz,new HP(0,0));
    while(sz[0]>0){HP x=hpPop(heap,sz);if(x.d!=dist[x.v])continue;for(int e=0;e<d;e++){int p=x.v*d+e,v=a[p];long nd=x.d+w[p];if(nd<dist[v]){dist[v]=nd;hpPush(heap,sz,new HP(nd,v));}}}
    return ck64(dist);
  }
  static void benchDij(long n0,int r){
    int n=(int)n0,d=4;int[][]g=graph(n,d,true);long[]dist=new long[n];HP[]heap=new HP[n*d*4];double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=dijkstra(g[0],g[1],n,d,dist,heap);t[x]=now()-s;}
    double m=med(t);emit("dijkstra",n0,r,m,(double)n*d/m/1e6,u32(c));
  }

  static int ufFind(int[]p,int x){while(p[x]!=x){p[x]=p[p[x]];x=p[x];}return x;}
  static void ufRun(int[]p,byte[]rank,int[]A,int[]B){
    for(int i=0;i<p.length;i++){p[i]=i;rank[i]=0;}
    for(int i=0;i<A.length;i++){int ra=ufFind(p,A[i]),rb=ufFind(p,B[i]);if(ra!=rb){if((rank[ra]&255)<(rank[rb]&255)){int z=ra;ra=rb;rb=z;}p[rb]=ra;if(rank[ra]==rank[rb])rank[ra]++;}}
  }
  static void benchUF(long n0,int r){
    int n=(int)n0,ops=n*4;int[]p=new int[n],A=new int[ops],B=new int[ops];byte[]rank=new byte[n];
    for(int i=0;i<ops;i++){A[i]=Integer.remainderUnsigned(mix32(i),n);B[i]=Integer.remainderUnsigned(mix32(i+ops),n);}
    double[]t=new double[r];for(int x=0;x<r;x++){double s=now();ufRun(p,rank,A,B);t[x]=now()-s;}
    for(int i=0;i<n;i++)p[i]=ufFind(p,i);double m=med(t);emit("union_find",ops,r,m,(double)ops/m/1e6,u32(ck32(p)));
  }

  static long mandel(int w,int mi){
    long sum=0;for(int y=0;y<w;y++){double ci=-1.5+3.0*y/(w-1.0);for(int x=0;x<w;x++){double cr=-2+3.0*x/(w-1.0),zr=0,zi=0;int it=0;while(it<mi){double a=zr*zr,b=zi*zi;if(a+b>4)break;double nz=a-b+cr;zi=2*zr*zi+ci;zr=nz;it++;}sum+=it;}}return sum;
  }
  static void benchMandel(long w0,int r){
    int w=(int)w0;mandel(Math.min(w,128),20);double[]t=new double[r];long c=0;
    for(int x=0;x<r;x++){double s=now();c=mandel(w,50);t[x]=now()-s;}
    double m=med(t);emit("mandelbrot",w0*w0,r,m,w0*w0/m/1e6,c);
  }

  static int vectorOnce(int[]in){
    int[]v=new int[8];int n=0;for(int x:in){if(n==v.length)v=Arrays.copyOf(v,v.length*2);v[n++]=x;}
    int h=0x811c9dc5;for(int i=0;i<n;i++){v[i]^=i;h=(h^v[i])*0x01000193;}
    while(n>0){int x=v[--n];h=(h^(x+n))*0x01000193;}return h;
  }
  static void benchVA(long n0,int r){
    int n=(int)n0;int[]in=new int[n];for(int i=0;i<n;i++)in[i]=mix32(i);double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=vectorOnce(in);t[x]=now()-s;}
    double m=med(t);emit("dynamic_array",n0,r,m,n0/m/1e6,u32(c));
  }

  static int listOnce(int[]next,int[]val,int[]base,int passes){
    System.arraycopy(base,0,val,0,base.length);int n=base.length;for(int i=0;i<n;i++)next[i]=i+1<n?i+1:-1;
    int B=64;for(int b=0;b<n;b+=B){int hi=Math.min(b+B,n)-1;for(int i=b;i<=hi;i++)next[i]=i==b?(hi+1<n?hi+1:-1):i-1;}
    int h=0x811c9dc5;for(int p=0;p<passes;p++){int cur=B<n?B-1:n-1,seen=0;while(cur>=0&&seen<n){val[cur]^=seen+p;h=(h^(val[cur]+cur+p))*0x01000193;cur=next[cur];seen++;}h=(h^seen)*0x01000193;}return h;
  }
  static void benchLL(long n0,int r){
    int n=(int)n0;int[]next=new int[n],val=new int[n],base=new int[n];for(int i=0;i<n;i++)base[i]=mix32(i);double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=listOnce(next,val,base,16);t[x]=now()-s;}
    double m=med(t);emit("linked_list",n0*16,r,m,n0*16/m/1e6,u32(c));
  }

  static int queueOnce(int[]b,int[]in){
    int cap=b.length,h=0,t=0,cnt=0,z=0;
    for(int i=0;i<in.length;i++){if((i&3)!=3){if(cnt==cap){z^=b[h];h=(h+1)%cap;cnt--;}b[t]=in[i];t=(t+1)%cap;cnt++;}else if(cnt>0){z^=b[h];h=(h+1)%cap;cnt--;}}
    while(cnt>0){z^=b[h];h=(h+1)%cap;cnt--;}return z;
  }
  static void benchQR(long ops0,int r){
    int ops=(int)ops0;int[]b=new int[ops/2+1024],in=new int[ops];for(int i=0;i<ops;i++)in[i]=mix32(i);double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=queueOnce(b,in);t[x]=now()-s;}
    double m=med(t);emit("queue_ring",ops0,r,m,ops0/m/1e6,u32(c));
  }

  static int np2(int x){int p=1;while(p<x)p<<=1;return p;}
  static int hashOnce(int[]k,int[]v,int[]ik,int[]iv){
    Arrays.fill(k,0);int mask=k.length-1,h=0;
    for(int i=0;i<ik.length;i++){int key=ik[i],val=iv[i],p=hash32(key)&mask;while(k[p]!=0&&k[p]!=key)p=(p+1)&mask;k[p]=key;v[p]=val;}
    for(int i=0;i<ik.length;i++){int key=ik[i],p=hash32(key)&mask;while(k[p]!=key)p=(p+1)&mask;v[p]^=i;h^=v[p];}return h;
  }
  static void benchHT(long n0,int r){
    int n=(int)n0,cap=np2(n*2);int[]k=new int[cap],v=new int[cap],ik=new int[n],iv=new int[n];
    for(int i=0;i<n;i++){ik[i]=mix32(i)|1;iv[i]=mix32(i+0x55555555);}
    double[]t=new double[r];int c=0;for(int x=0;x<r;x++){double s=now();c=hashOnce(k,v,ik,iv);t[x]=now()-s;}
    double m=med(t);emit("hash_table",n0,r,m,n0*2/m/1e6,u32(c));
  }

  static boolean ule(int a,int b){return Integer.compareUnsigned(a,b)<=0;}
  static void heapPush(int[]h,int[]sz,int x){int i=sz[0]++;while(i>0){int p=(i-1)/2;if(ule(h[p],x))break;h[i]=h[p];i=p;}h[i]=x;}
  static int heapPop(int[]h,int[]sz){int o=h[0],x=h[--sz[0]],i=0;while(true){int l=i*2+1;if(l>=sz[0])break;int rr=l+1,c=rr<sz[0]&&Integer.compareUnsigned(h[rr],h[l])<0?rr:l;if(Integer.compareUnsigned(h[c],x)>=0)break;h[i]=h[c];i=c;}if(sz[0]>0)h[i]=x;return o;}
  static int heapOnce(int[]h,int[]in){int[]sz={0};for(int x:in)heapPush(h,sz,x);int c=0;for(int i=0;i<in.length;i++)c^=heapPop(h,sz)+i;return c;}
  static void benchBH(long n0,int r){
    int n=(int)n0;int[]h=new int[n],in=new int[n];for(int i=0;i<n;i++)in[i]=mix32(i);double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=heapOnce(h,in);t[x]=now()-s;}
    double m=med(t);emit("binary_heap",n0,r,m,n0*2/m/1e6,u32(c));
  }

  static int bstOnce(int[]k,int[]l,int[]rr,int[]in){
    int root=-1;for(int i=0;i<in.length;i++){int key=in[i];k[i]=key;l[i]=rr[i]=-1;if(root<0){root=i;continue;}int cur=root;while(true){if(Integer.compareUnsigned(key,k[cur])<0){if(l[cur]<0){l[cur]=i;break;}cur=l[cur];}else{if(rr[cur]<0){rr[cur]=i;break;}cur=rr[cur];}}}
    int h=0;for(int i=0;i<in.length;i+=3){int key=in[i],cur=root;while(cur>=0&&k[cur]!=key)cur=Integer.compareUnsigned(key,k[cur])<0?l[cur]:rr[cur];if(cur>=0)h^=cur+1;}return h;
  }
  static void benchBST(long n0,int r){
    int n=(int)n0;int[]k=new int[n],l=new int[n],rr=new int[n],in=new int[n];for(int i=0;i<n;i++)in[i]=mix32(i);double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=bstOnce(k,l,rr,in);t[x]=now()-s;}
    double m=med(t);emit("bst",n0,r,m,n0/m/1e6,u32(c));
  }

  static int trieOnce(int[]ch,byte[]term,int[]words,int passes){
    Arrays.fill(ch,-1);Arrays.fill(term,(byte)0);int used=1;
    for(int w:words){int node=0;for(int sh=28;sh>=0;sh-=4){int c=(w>>>sh)&15,p=node*16+c;if(ch[p]<0)ch[p]=used++;node=ch[p];}term[node]=1;}
    int h=used;for(int p=0;p<passes;p++)for(int i=0;i<words.length;i+=2){int w=words[i],node=0;for(int sh=28;sh>=0&&node>=0;sh-=4)node=ch[node*16+((w>>>sh)&15)];if(node>=0&&term[node]!=0)h^=node+1+p;}return h;
  }
  static void benchTrie(long n0,int r){
    int n=(int)n0,mx=1+n*8;int[]ch=new int[mx*16],words=new int[n];byte[]term=new byte[mx];for(int i=0;i<n;i++)words[i]=mix32(i);double[]t=new double[r];int c=0;
    for(int x=0;x<r;x++){double s=now();c=trieOnce(ch,term,words,32);t[x]=now()-s;}
    double m=med(t);emit("trie",n0*32,r,m,n0*32/m/1e6,u32(c));
  }

  static long size(String k){return switch(k){
    case"integer50"->200000000L;case"json_escape"->16000000L;
    case"merge_sort","binary_search","union_find","hash_table","binary_heap"->1000000L;
    case"prefix_sum"->8000000L;case"matrix_mul"->320L;case"bfs"->200000L;
    case"dijkstra","trie"->100000L;case"mandelbrot"->1600L;case"dynamic_array"->5000000L;
    case"linked_list"->4000000L;case"queue_ring"->10000000L;case"bst"->300000L;default->0L;};
  }
  public static void main(String[]args){
    String k=args.length>0?args[0]:"integer50";long n=args.length>1?Long.parseLong(args[1]):size(k);int r=args.length>2?Integer.parseInt(args[2]):7;
    switch(k){
      case"integer50"->benchInteger(n,r);case"json_escape"->benchJSON(n,r);case"merge_sort"->benchMerge(n,r);
      case"binary_search"->benchBS(n,r);case"prefix_sum"->benchPrefix(n,r);case"matrix_mul"->benchMM(n,r);
      case"bfs"->benchBFS(n,r);case"dijkstra"->benchDij(n,r);case"union_find"->benchUF(n,r);
      case"mandelbrot"->benchMandel(n,r);case"dynamic_array"->benchVA(n,r);case"linked_list"->benchLL(n,r);
      case"queue_ring"->benchQR(n,r);case"hash_table"->benchHT(n,r);case"binary_heap"->benchBH(n,r);
      case"bst"->benchBST(n,r);case"trie"->benchTrie(n,r);default->throw new IllegalArgumentException(k);
    }
  }
}
