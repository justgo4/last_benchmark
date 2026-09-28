#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_s(void){struct timespec ts;clock_gettime(CLOCK_MONOTONIC,&ts);return (double)ts.tv_sec+(double)ts.tv_nsec*1e-9;}
static int cmp_double(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return(x>y)-(x<y);}
static double median(double*v,int n){qsort(v,(size_t)n,sizeof(*v),cmp_double);return(n&1)?v[n/2]:0.5*(v[n/2-1]+v[n/2]);}
static void print_result(const char*k,uint64_t units,int rounds,double sec,double rate,uint64_t checksum){printf("RESULT kernel=%s units=%" PRIu64 " rounds=%d seconds=%.9f rate=%.6f checksum=%" PRIu64 "\n",k,units,rounds,sec,rate,checksum);}

static uint64_t integer50(uint64_t n){const uint64_t mask=(1ULL<<50)-1;uint64_t x=88172645463325252ULL&mask,sum=0;for(uint64_t i=0;i<n;i++){x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;sum=(sum+(x^(x>>17)))&mask;}return sum;}
static int bench_integer(uint64_t n,int rounds){(void)integer50(n/20+1);double*t=malloc((size_t)rounds*sizeof(*t));if(!t)return 2;uint64_t c=0;for(int r=0;r<rounds;r++){double a=now_s();c=integer50(n);t[r]=now_s()-a;}double m=median(t,rounds);print_result("integer50",n,rounds,m,(double)n/m/1e6,c);free(t);return 0;}

static uint16_t lane_at(uint64_t i,uint32_t p){uint64_t x=i*1103515245ULL+12345ULL;return(uint16_t)((x>>8)%p);}
static int stable_partition_u16(const uint16_t*lanes,uint64_t n,uint32_t p,uint64_t*order,uint64_t*counts,uint64_t*cursor){if(!lanes||!order||!counts||!cursor||p==0||p>65536)return 1;for(uint32_t j=0;j<p;j++)counts[j]=0;for(uint64_t i=0;i<n;i++){uint32_t l=lanes[i];if(l>=p)return 2;counts[l]++;}uint64_t off=0;for(uint32_t l=0;l<p;l++){cursor[l]=off;off+=counts[l];}for(uint64_t i=0;i<n;i++){uint32_t l=lanes[i];order[cursor[l]++]=i;}return 0;}
static uint64_t checksum_order(const uint64_t*p,uint64_t n){uint64_t h=0;for(uint64_t i=0;i<n;i++)h+=(p[i]%1000003ULL)+((i*17ULL)%1000003ULL);return h;}
static int bench_partition(uint64_t n,int rounds){const uint32_t parts=16;uint16_t*lanes=malloc((size_t)n*sizeof(*lanes));uint64_t*order=malloc((size_t)n*sizeof(*order));uint64_t*counts=calloc(parts,sizeof(*counts));uint64_t*cursor=calloc(parts,sizeof(*cursor));double*t=malloc((size_t)rounds*sizeof(*t));if(!lanes||!order||!counts||!cursor||!t)return 2;for(uint64_t i=0;i<n;i++)lanes[i]=lane_at(i,parts);stable_partition_u16(lanes,n,parts,order,counts,cursor);for(int r=0;r<rounds;r++){double a=now_s();if(stable_partition_u16(lanes,n,parts,order,counts,cursor))return 3;t[r]=now_s()-a;}uint64_t covered=0;for(uint32_t l=0;l<parts;l++)covered+=counts[l];if(covered!=n)return 4;uint64_t c=checksum_order(order,n);double m=median(t,rounds);print_result("stable_partition",n,rounds,m,(double)n/m/1e6,c);free(t);free(cursor);free(counts);free(order);free(lanes);return 0;}

struct Cursor{const uint8_t*data;size_t size,pos;};
static uint16_t u16le(const uint8_t*p){return(uint16_t)p[0]|((uint16_t)p[1]<<8);}
static uint32_t u24le(const uint8_t*p){return(uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16);}
static uint32_t u32le(const uint8_t*p){return(uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint64_t u64le(const uint8_t*p){return(uint64_t)u32le(p)|((uint64_t)u32le(p+4)<<32);}
static int take(struct Cursor*c,size_t n,const uint8_t**out){if(n>c->size-c->pos)return EINVAL;*out=c->data+c->pos;c->pos+=n;return 0;}
static int cu8(struct Cursor*c,uint8_t*out){const uint8_t*p;if(take(c,1,&p))return EINVAL;*out=*p;return 0;}
static int cu16(struct Cursor*c,uint16_t*out){const uint8_t*p;if(take(c,2,&p))return EINVAL;*out=u16le(p);return 0;}
static int cu32(struct Cursor*c,uint32_t*out){const uint8_t*p;if(take(c,4,&p))return EINVAL;*out=u32le(p);return 0;}
static int cu64(struct Cursor*c,uint64_t*out){const uint8_t*p;if(take(c,8,&p))return EINVAL;*out=u64le(p);return 0;}
static int lenenc(struct Cursor*c,uint64_t*out){uint8_t f;if(cu8(c,&f))return EINVAL;if(f<0xfb){*out=f;return 0;}const uint8_t*p;if(f==0xfc){if(take(c,2,&p))return EINVAL;*out=u16le(p);return 0;}if(f==0xfd){if(take(c,3,&p))return EINVAL;*out=u24le(p);return 0;}if(f==0xfe){if(take(c,8,&p))return EINVAL;*out=u64le(p);return 0;}return EINVAL;}
static int bit_count(const uint8_t*b,int nbits){int c=0;for(int i=0;i<nbits;i++)c+=(b[i>>3]>>(i&7))&1;return c;}
#define BIN_REC_BYTES 35u
static void put16(uint8_t*p,uint16_t v){p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8);}
static void put24(uint8_t*p,uint32_t v){p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8);p[2]=(uint8_t)(v>>16);}
static void put32(uint8_t*p,uint32_t v){for(int i=0;i<4;i++)p[i]=(uint8_t)(v>>(8*i));}
static void put64(uint8_t*p,uint64_t v){for(int i=0;i<8;i++)p[i]=(uint8_t)(v>>(8*i));}
static void make_bin(uint8_t*p,uint64_t i){uint8_t k=(uint8_t)(i&3);p[0]=k;if(k==0){p[1]=(uint8_t)(i%250);memset(p+2,0,8);}else if(k==1){p[1]=0xfc;put16(p+2,(uint16_t)i);memset(p+4,0,6);}else if(k==2){p[1]=0xfd;put24(p+2,(uint32_t)i);memset(p+5,0,5);}else{p[1]=0xfe;put64(p+2,i);}for(int j=0;j<8;j++)p[10+j]=(uint8_t)((i>>(j%6))^(uint64_t)(0xA5u+j));put16(p+18,(uint16_t)(i*3u));put24(p+20,(uint32_t)(i*5u));put32(p+23,(uint32_t)(i*7u));put64(p+27,i*11u+17u);}
static int decode_bin(const uint8_t*buf,uint64_t rows,uint64_t*out){uint64_t h=0;for(uint64_t i=0;i<rows;i++){struct Cursor c={buf+(size_t)i*BIN_REC_BYTES,BIN_REC_BYTES,0};uint8_t k;uint64_t le,v64;uint16_t v16;uint32_t v32;const uint8_t*b,*p3;if(cu8(&c,&k)||lenenc(&c,&le))return 1;size_t used=1u+(k==0?1u:k==1?3u:k==2?4u:9u);if(used<10u&&take(&c,10u-used,&p3))return 2;if(take(&c,8,&b)||cu16(&c,&v16)||take(&c,3,&p3))return 3;uint32_t v24=u24le(p3);if(cu32(&c,&v32)||cu64(&c,&v64))return 4;h+=(uint64_t)k+le+(uint64_t)bit_count(b,64)+v16+v24+v32+v64;}*out=h;return 0;}
static int bench_binary(uint64_t rows,int rounds){size_t bytes=(size_t)rows*BIN_REC_BYTES;uint8_t*buf=malloc(bytes);double*t=malloc((size_t)rounds*sizeof(*t));if(!buf||!t)return 2;for(uint64_t i=0;i<rows;i++)make_bin(buf+(size_t)i*BIN_REC_BYTES,i);uint64_t c=0;decode_bin(buf,rows,&c);for(int r=0;r<rounds;r++){double a=now_s();if(decode_bin(buf,rows,&c))return 3;t[r]=now_s()-a;}double m=median(t,rounds);print_result("binary_decode",rows,rounds,m,(double)bytes/m/1e9,c);free(t);free(buf);return 0;}

static int digits(const uint8_t*p,size_t n,int*out){if(!n)return EINVAL;int v=0;for(size_t i=0;i<n;i++){if(p[i]<'0'||p[i]>'9')return EINVAL;v=v*10+(p[i]-'0');}*out=v;return 0;}
static int parse_uint(const uint8_t*p,size_t n,uint64_t*out){if(!n)return EINVAL;uint64_t v=0;for(size_t i=0;i<n;i++){if(p[i]<'0'||p[i]>'9')return EINVAL;uint64_t d=(uint64_t)(p[i]-'0');if(v>(UINT64_MAX-d)/10)return ERANGE;v=v*10+d;}*out=v;return 0;}
static int parse_int(const uint8_t*p,size_t n,int64_t*out){if(!n)return EINVAL;int neg=p[0]=='-',pos=p[0]=='+';size_t s=(neg||pos)?1:0;if(s==n)return EINVAL;uint64_t v;if(parse_uint(p+s,n-s,&v))return EINVAL;if(neg){uint64_t lim=(uint64_t)INT64_MAX+1;if(v>lim)return ERANGE;*out=v==lim?INT64_MIN:-(int64_t)v;}else{if(v>(uint64_t)INT64_MAX)return ERANGE;*out=(int64_t)v;}return 0;}
static int64_t days_from_civil(int y,unsigned m,unsigned d){y-=m<=2;const int era=(y>=0?y:y-399)/400;const unsigned yoe=(unsigned)(y-era*400);const unsigned mp=m>2?m-3:m+9;const unsigned doy=(153*mp+2)/5+d-1;const unsigned doe=yoe*365+yoe/4-yoe/100+doy;return(int64_t)era*146097+(int64_t)doe-719468;}
static int parse_dt(const uint8_t*p,size_t n,int64_t*out){int y,mo,d,h,mi,s,us;if(n!=26||p[4]!='-'||p[7]!='-'||p[10]!=' '||p[13]!=':'||p[16]!=':'||p[19]!='.')return EINVAL;if(digits(p,4,&y)||digits(p+5,2,&mo)||digits(p+8,2,&d)||digits(p+11,2,&h)||digits(p+14,2,&mi)||digits(p+17,2,&s)||digits(p+20,6,&us))return EINVAL;if(y<1||mo<1||mo>12||d<1||d>31||h>23||mi>59||s>59)return EINVAL;*out=((days_from_civil(y,(unsigned)mo,(unsigned)d)*86400+h*3600+mi*60+s)*1000000)+us;return 0;}
#define TEXT_REC_BYTES 46u
static void make_text(uint8_t*p,uint64_t i){int64_t v=(int64_t)(100000000000000000ULL+(i%800000000000000000ULL));char tmp[64];int n=snprintf(tmp,sizeof(tmp),"%c%018" PRId64 "|2026-09-28 19:39:12.%06u",(i&1)?'-':'+',v,(unsigned)(i%1000000u));if(n!=(int)TEXT_REC_BYTES)abort();memcpy(p,tmp,TEXT_REC_BYTES);}
static int parse_texts(const uint8_t*buf,uint64_t rows,uint64_t*out){uint64_t h=0;for(uint64_t i=0;i<rows;i++){const uint8_t*p=buf+(size_t)i*TEXT_REC_BYTES;int64_t v,ts;if(parse_int(p,19,&v)||p[19]!='|'||parse_dt(p+20,26,&ts))return 1;uint64_t av=(uint64_t)(v<0?-v:v);h+=(av%1000003ULL)+((uint64_t)ts%1000003ULL);}*out=h;return 0;}
static int bench_text(uint64_t rows,int rounds){size_t bytes=(size_t)rows*TEXT_REC_BYTES;uint8_t*buf=malloc(bytes);double*t=malloc((size_t)rounds*sizeof(*t));if(!buf||!t)return 2;for(uint64_t i=0;i<rows;i++)make_text(buf+(size_t)i*TEXT_REC_BYTES,i);uint64_t c=0;parse_texts(buf,rows,&c);for(int r=0;r<rounds;r++){double a=now_s();if(parse_texts(buf,rows,&c))return 3;t[r]=now_s()-a;}double m=median(t,rounds);print_result("text_parse",rows,rounds,m,(double)rows/m/1e6,c);free(t);free(buf);return 0;}

static const uint8_t PATTERN[]={'a','l','p','h','a','"','b','e','t','a','\\','g','a','m','m','a','\n','\t',1,'x','y','z','/'};
static void fill_json_input(uint8_t*p,size_t n){for(size_t i=0;i<n;i++)p[i]=PATTERN[i%(sizeof(PATTERN)/sizeof(PATTERN[0]))];}
static size_t json_escape(const uint8_t*in,size_t n,uint8_t*out){static const char hex[]="0123456789abcdef";size_t j=0;out[j++]='"';for(size_t i=0;i<n;i++){uint8_t c=in[i];switch(c){case '"':out[j++]='\\';out[j++]='"';break;case '\\':out[j++]='\\';out[j++]='\\';break;case '\b':out[j++]='\\';out[j++]='b';break;case '\f':out[j++]='\\';out[j++]='f';break;case '\n':out[j++]='\\';out[j++]='n';break;case '\r':out[j++]='\\';out[j++]='r';break;case '\t':out[j++]='\\';out[j++]='t';break;default:if(c<0x20){out[j++]='\\';out[j++]='u';out[j++]='0';out[j++]='0';out[j++]=(uint8_t)hex[c>>4];out[j++]=(uint8_t)hex[c&15];}else out[j++]=c;}}out[j++]='"';return j;}
static int bench_json(uint64_t bytes,int rounds){uint8_t*in=malloc((size_t)bytes),*out=malloc((size_t)bytes*6+2);double*t=malloc((size_t)rounds*sizeof(*t));if(!in||!out||!t)return 2;fill_json_input(in,(size_t)bytes);size_t outn=json_escape(in,(size_t)bytes,out);for(int r=0;r<rounds;r++){double a=now_s();outn=json_escape(in,(size_t)bytes,out);t[r]=now_s()-a;}uint64_t c=outn;for(size_t i=0;i<outn;i++)c+=out[i];double m=median(t,rounds);print_result("json_escape",bytes,rounds,m,(double)bytes/m/1e9,c);free(t);free(out);free(in);return 0;}

struct Node{struct Node*l,*r;};
static struct Node*make_tree(int depth){struct Node*n=malloc(sizeof(*n));if(!n)abort();if(depth>0){n->l=make_tree(depth-1);n->r=make_tree(depth-1);}else n->l=n->r=NULL;return n;}
static uint64_t check_tree(const struct Node*n){return n?1ULL+check_tree(n->l)+check_tree(n->r):0ULL;}
static void free_tree(struct Node*n){if(!n)return;free_tree(n->l);free_tree(n->r);free(n);}
static uint64_t binary_trees_once(int max_depth){const int min_depth=4;struct Node*stretch=make_tree(max_depth+1);uint64_t total=check_tree(stretch);free_tree(stretch);struct Node*long_lived=make_tree(max_depth);for(int depth=min_depth;depth<=max_depth;depth+=2){uint64_t iters=1ULL<<(max_depth-depth+min_depth);uint64_t sum=0;for(uint64_t i=0;i<iters;i++){struct Node*n=make_tree(depth);sum+=check_tree(n);free_tree(n);}total+=sum;}total+=check_tree(long_lived);free_tree(long_lived);return total;}
static int bench_trees(uint64_t depth_u,int rounds){int depth=(int)depth_u;(void)binary_trees_once(depth>6?6:depth);double*t=malloc((size_t)rounds*sizeof(*t));if(!t)return 2;uint64_t c=0;for(int r=0;r<rounds;r++){double a=now_s();c=binary_trees_once(depth);t[r]=now_s()-a;}double m=median(t,rounds);print_result("binary_trees",(uint64_t)depth,rounds,m,1.0/m,c);free(t);return 0;}

static uint64_t mandelbrot(int width,int max_iter){uint64_t sum=0;for(int y=0;y<width;y++){double ci=-1.5+3.0*(double)y/(double)(width-1);for(int x=0;x<width;x++){double cr=-2.0+3.0*(double)x/(double)(width-1),zr=0.0,zi=0.0;int it=0;while(it<max_iter){double zr2=zr*zr,zi2=zi*zi;if(zr2+zi2>4.0)break;double nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;it++;}sum+=(uint64_t)it;}}return sum;}
static int bench_mandel(uint64_t width_u,int rounds){int width=(int)width_u;(void)mandelbrot(width>128?128:width,20);double*t=malloc((size_t)rounds*sizeof(*t));if(!t)return 2;uint64_t c=0;for(int r=0;r<rounds;r++){double a=now_s();c=mandelbrot(width,50);t[r]=now_s()-a;}double m=median(t,rounds);uint64_t pix=(uint64_t)width*(uint64_t)width;print_result("mandelbrot",pix,rounds,m,(double)pix/m/1e6,c);free(t);return 0;}

static uint64_t default_size(const char*k){if(!strcmp(k,"integer50"))return 200000000ULL;if(!strcmp(k,"stable_partition"))return 5000000ULL;if(!strcmp(k,"binary_decode"))return 5000000ULL;if(!strcmp(k,"text_parse"))return 5000000ULL;if(!strcmp(k,"json_escape"))return 16000000ULL;if(!strcmp(k,"binary_trees"))return 18ULL;if(!strcmp(k,"mandelbrot"))return 1600ULL;return 0;}
static int run_one(const char*k,uint64_t size,int rounds){if(!strcmp(k,"integer50"))return bench_integer(size,rounds);if(!strcmp(k,"stable_partition"))return bench_partition(size,rounds);if(!strcmp(k,"binary_decode"))return bench_binary(size,rounds);if(!strcmp(k,"text_parse"))return bench_text(size,rounds);if(!strcmp(k,"json_escape"))return bench_json(size,rounds);if(!strcmp(k,"binary_trees"))return bench_trees(size,rounds);if(!strcmp(k,"mandelbrot"))return bench_mandel(size,rounds);return 64;}
int main(int argc,char**argv){const char*k=argc>1?argv[1]:"all";int rounds=argc>3?atoi(argv[3]):7;if(rounds<1)rounds=1;if(!strcmp(k,"all")){const char*ks[]={"integer50","stable_partition","binary_decode","text_parse","json_escape","binary_trees","mandelbrot"};for(size_t i=0;i<sizeof(ks)/sizeof(ks[0]);i++){int rc=run_one(ks[i],default_size(ks[i]),rounds);if(rc)return rc;}return 0;}uint64_t size=argc>2?strtoull(argv[2],NULL,10):default_size(k);if(!size){fprintf(stderr,"unknown kernel\n");return 64;}return run_one(k,size,rounds);}
