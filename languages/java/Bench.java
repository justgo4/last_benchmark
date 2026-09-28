import java.util.*;

public final class Bench {
  static double now(){ return System.nanoTime()*1e-9; }
  static double median(double[] a){ Arrays.sort(a); int n=a.length; return (n&1)==1?a[n/2]:.5*(a[n/2-1]+a[n/2]); }
  static void result(String k,long units,int rounds,double sec,double rate,long checksum){
    System.out.printf(Locale.ROOT,"RESULT kernel=%s units=%d rounds=%d seconds=%.9f rate=%.6f checksum=%d%n",k,units,rounds,sec,rate,checksum);
  }
  static long integer50(long n){ final long mask=(1L<<50)-1; long x=88172645463325252L&mask,sum=0; for(long i=0;i<n;i++){x^=x>>>7;x^=(x<<8)&mask;x^=x>>>9;x&=mask;sum=(sum+(x^(x>>>17)))&mask;} return sum; }
  static void benchInteger(long n,int rounds){ integer50(n/20+1); double[] t=new double[rounds]; long c=0; for(int r=0;r<rounds;r++){double a=now();c=integer50(n);t[r]=now()-a;} double m=median(t);result("integer50",n,rounds,m,n/m/1e6,c); }

  static int laneAt(long i,int p){ long x=i*1103515245L+12345L; return (int)((x>>>8)%p); }
  static void stablePartition(short[] lanes,int p,long[] order,long[] counts,long[] cursor){Arrays.fill(counts,0);for(short sv:lanes){int l=sv&0xffff;if(l>=p)throw new IllegalStateException();counts[l]++;}long off=0;for(int l=0;l<p;l++){cursor[l]=off;off+=counts[l];}for(int i=0;i<lanes.length;i++){int l=lanes[i]&0xffff;order[(int)cursor[l]++]=i;}}
  static long checksumOrder(long[] p){long h=0;for(int i=0;i<p.length;i++)h+=(p[i]%1000003L)+(((long)i*17L)%1000003L);return h;}
  static void benchPartition(long n0,int rounds){int n=Math.toIntExact(n0),parts=16;short[] lanes=new short[n];long[] order=new long[n],counts=new long[parts],cursor=new long[parts];for(int i=0;i<n;i++)lanes[i]=(short)laneAt(i,parts);stablePartition(lanes,parts,order,counts,cursor);double[]t=new double[rounds];for(int r=0;r<rounds;r++){double a=now();stablePartition(lanes,parts,order,counts,cursor);t[r]=now()-a;}long covered=0;for(long v:counts)covered+=v;if(covered!=n)throw new IllegalStateException();long c=checksumOrder(order);double m=median(t);result("stable_partition",n,rounds,m,n/m/1e6,c);}

  static int u16(byte[]p,int o){return (p[o]&255)|((p[o+1]&255)<<8);} static int u24(byte[]p,int o){return (p[o]&255)|((p[o+1]&255)<<8)|((p[o+2]&255)<<16);} static long u32(byte[]p,int o){return ((long)(p[o]&255))|((long)(p[o+1]&255)<<8)|((long)(p[o+2]&255)<<16)|((long)(p[o+3]&255)<<24);} static long u64(byte[]p,int o){return u32(p,o)|(u32(p,o+4)<<32);}
  static void put16(byte[]p,int o,long v){p[o]=(byte)v;p[o+1]=(byte)(v>>>8);} static void put24(byte[]p,int o,long v){p[o]=(byte)v;p[o+1]=(byte)(v>>>8);p[o+2]=(byte)(v>>>16);} static void put32(byte[]p,int o,long v){for(int i=0;i<4;i++)p[o+i]=(byte)(v>>>(8*i));} static void put64(byte[]p,int o,long v){for(int i=0;i<8;i++)p[o+i]=(byte)(v>>>(8*i));}
  static final int BIN_REC=35;
  static void makeBin(byte[]p,int o,long i){int k=(int)(i&3);p[o]=(byte)k;if(k==0){p[o+1]=(byte)(i%250);Arrays.fill(p,o+2,o+10,(byte)0);}else if(k==1){p[o+1]=(byte)0xfc;put16(p,o+2,i);Arrays.fill(p,o+4,o+10,(byte)0);}else if(k==2){p[o+1]=(byte)0xfd;put24(p,o+2,i);Arrays.fill(p,o+5,o+10,(byte)0);}else{p[o+1]=(byte)0xfe;put64(p,o+2,i);}for(int j=0;j<8;j++)p[o+10+j]=(byte)((i>>>(j%6))^(0xA5+j));put16(p,o+18,i*3);put24(p,o+20,i*5);put32(p,o+23,i*7);put64(p,o+27,i*11+17);}
  static int bitCount(byte[]b,int o){int c=0;for(int i=0;i<64;i++)c+=((b[o+(i>>>3)]&255) >>> (i&7))&1;return c;}
  static long decodeBin(byte[]buf,int rows){long h=0;for(int i=0;i<rows;i++){int o=i*BIN_REC;int k=buf[o]&255,pos=o+1;int f=buf[pos++]&255;long le;if(f<0xfb)le=f;else if(f==0xfc){le=u16(buf,pos);pos+=2;}else if(f==0xfd){le=u24(buf,pos);pos+=3;}else if(f==0xfe){le=u64(buf,pos);pos+=8;}else throw new IllegalStateException();pos=o+10;int bc=bitCount(buf,pos);pos+=8;long v16=u16(buf,pos);pos+=2;long v24=u24(buf,pos);pos+=3;long v32=u32(buf,pos);pos+=4;long v64=u64(buf,pos);h+=k+le+bc+v16+v24+v32+v64;}return h;}
  static void benchBinary(long rows0,int rounds){int rows=Math.toIntExact(rows0);byte[]buf=new byte[Math.multiplyExact(rows,BIN_REC)];for(int i=0;i<rows;i++)makeBin(buf,i*BIN_REC,i);decodeBin(buf,rows);double[]t=new double[rounds];long c=0;for(int r=0;r<rounds;r++){double a=now();c=decodeBin(buf,rows);t[r]=now()-a;}double m=median(t);result("binary_decode",rows,rounds,m,buf.length/m/1e9,c);}

  static int digits(byte[]p,int o,int n){int v=0;for(int i=0;i<n;i++){int c=p[o+i]&255;if(c<'0'||c>'9')throw new IllegalStateException();v=v*10+c-'0';}return v;}
  static long parseInt19(byte[]p,int o){boolean neg=p[o]=='-';long v=0;for(int i=1;i<19;i++)v=v*10+(p[o+i]-'0');return neg?-v:v;}
  static long daysFromCivil(int y,int m,int d){if(m<=2)y--;int era=y>=0?y/400:(y-399)/400;int yoe=y-era*400;int mp=m>2?m-3:m+9;int doy=(153*mp+2)/5+d-1;int doe=yoe*365+yoe/4-yoe/100+doy;return (long)era*146097L+doe-719468L;}
  static long parseDT(byte[]p,int o){int y=digits(p,o,4),mo=digits(p,o+5,2),d=digits(p,o+8,2),h=digits(p,o+11,2),mi=digits(p,o+14,2),s=digits(p,o+17,2),us=digits(p,o+20,6);return ((daysFromCivil(y,mo,d)*86400+h*3600L+mi*60L+s)*1000000L)+us;}
  static final int TEXT_REC=46; static final byte[] PREFIX="2026-09-28 19:39:12.".getBytes(java.nio.charset.StandardCharsets.US_ASCII);
  static void writeDigits(byte[]p,int o,int n,long v){for(int j=n-1;j>=0;j--){p[o+j]=(byte)('0'+v%10);v/=10;}}
  static void makeText(byte[]p,int o,long i){p[o]=(byte)((i&1)!=0?'-':'+');long v=100000000000000000L+(i%800000000000000000L);writeDigits(p,o+1,18,v);p[o+19]='|';System.arraycopy(PREFIX,0,p,o+20,20);writeDigits(p,o+40,6,i%1000000);}
  static long parseTexts(byte[]buf,int rows){long h=0;for(int i=0;i<rows;i++){int o=i*TEXT_REC;long v=parseInt19(buf,o),ts=parseDT(buf,o+20),av=v<0?-v:v;h+=(av%1000003L)+(ts%1000003L);}return h;}
  static void benchText(long rows0,int rounds){int rows=Math.toIntExact(rows0);byte[]buf=new byte[Math.multiplyExact(rows,TEXT_REC)];for(int i=0;i<rows;i++)makeText(buf,i*TEXT_REC,i);parseTexts(buf,rows);double[]t=new double[rounds];long c=0;for(int r=0;r<rounds;r++){double a=now();c=parseTexts(buf,rows);t[r]=now()-a;}double m=median(t);result("text_parse",rows,rounds,m,rows/m/1e6,c);}

  static final byte[] PATTERN=new byte[]{'a','l','p','h','a','"','b','e','t','a','\\','g','a','m','m','a','\n','\t',1,'x','y','z','/'};
  static void fillJSON(byte[]p){for(int i=0;i<p.length;i++)p[i]=PATTERN[i%PATTERN.length];}
  static int jsonEscape(byte[]in,byte[]out){byte[]hex="0123456789abcdef".getBytes(java.nio.charset.StandardCharsets.US_ASCII);int j=0;out[j++]='"';for(byte bv:in){int c=bv&255;switch(c){case '"':out[j++]='\\';out[j++]='"';break;case '\\':out[j++]='\\';out[j++]='\\';break;case '\b':out[j++]='\\';out[j++]='b';break;case '\f':out[j++]='\\';out[j++]='f';break;case '\n':out[j++]='\\';out[j++]='n';break;case '\r':out[j++]='\\';out[j++]='r';break;case '\t':out[j++]='\\';out[j++]='t';break;default:if(c<0x20){out[j++]='\\';out[j++]='u';out[j++]='0';out[j++]='0';out[j++]=hex[c>>>4];out[j++]=hex[c&15];}else out[j++]=(byte)c;}}out[j++]='"';return j;}
  static void benchJSON(long bytes0,int rounds){int bytes=Math.toIntExact(bytes0);byte[]in=new byte[bytes],out=new byte[Math.addExact(Math.multiplyExact(bytes,6),2)];fillJSON(in);int outn=jsonEscape(in,out);double[]t=new double[rounds];for(int r=0;r<rounds;r++){double a=now();outn=jsonEscape(in,out);t[r]=now()-a;}long c=outn;for(int i=0;i<outn;i++)c+=out[i]&255;double m=median(t);result("json_escape",bytes,rounds,m,bytes/m/1e9,c);}

  static final class Node{Node l,r;Node(int d){if(d>0){l=new Node(d-1);r=new Node(d-1);}}}
  static long checkTree(Node n){return n==null?0:1+checkTree(n.l)+checkTree(n.r);}
  static long binaryTreesOnce(int maxDepth){final int minDepth=4;Node stretch=new Node(maxDepth+1);long total=checkTree(stretch);stretch=null;Node longLived=new Node(maxDepth);for(int depth=minDepth;depth<=maxDepth;depth+=2){long iters=1L<<(maxDepth-depth+minDepth),s=0;for(long i=0;i<iters;i++){Node n=new Node(depth);s+=checkTree(n);}total+=s;}total+=checkTree(longLived);return total;}
  static void benchTrees(long depth0,int rounds){int depth=(int)depth0;binaryTreesOnce(Math.min(depth,6));double[]t=new double[rounds];long c=0;for(int r=0;r<rounds;r++){double a=now();c=binaryTreesOnce(depth);t[r]=now()-a;}double m=median(t);result("binary_trees",depth,rounds,m,1/m,c);}

  static long mandelbrot(int width,int maxIter){long sum=0;for(int y=0;y<width;y++){double ci=-1.5+3.0*y/(width-1.0);for(int x=0;x<width;x++){double cr=-2.0+3.0*x/(width-1.0),zr=0,zi=0;int it=0;while(it<maxIter){double zr2=zr*zr,zi2=zi*zi;if(zr2+zi2>4.0)break;double nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;it++;}sum+=it;}}return sum;}
  static void benchMandel(long width0,int rounds){int width=(int)width0;mandelbrot(Math.min(width,128),20);double[]t=new double[rounds];long c=0;for(int r=0;r<rounds;r++){double a=now();c=mandelbrot(width,50);t[r]=now()-a;}double m=median(t);long pix=width0*width0;result("mandelbrot",pix,rounds,m,pix/m/1e6,c);}

  static long defaultSize(String k){return switch(k){case "integer50"->200000000L;case "stable_partition","binary_decode","text_parse"->5000000L;case "json_escape"->16000000L;case "binary_trees"->18L;case "mandelbrot"->1600L;default->0L;};}
  static void runOne(String k,long size,int rounds){switch(k){case "integer50"->benchInteger(size,rounds);case "stable_partition"->benchPartition(size,rounds);case "binary_decode"->benchBinary(size,rounds);case "text_parse"->benchText(size,rounds);case "json_escape"->benchJSON(size,rounds);case "binary_trees"->benchTrees(size,rounds);case "mandelbrot"->benchMandel(size,rounds);default->throw new IllegalArgumentException(k);}}
  public static void main(String[]args){String k=args.length>0?args[0]:"all";int rounds=args.length>2?Integer.parseInt(args[2]):7;if(k.equals("all")){for(String q:new String[]{"integer50","stable_partition","binary_decode","text_parse","json_escape","binary_trees","mandelbrot"})runOne(q,defaultSize(q),rounds);return;}long size=args.length>1?Long.parseLong(args[1]):defaultSize(k);runOne(k,size,rounds);}
}
