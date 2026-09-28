#include <nanobind/nanobind.h>
#include <nanobind/stl/string.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <string>
#include <tuple>
#include <vector>
namespace nb=nanobind;
using steady_clock_t=std::chrono::steady_clock;
static double now(){return std::chrono::duration<double>(steady_clock_t::now().time_since_epoch()).count();}
static double med(double a[7]){std::sort(a,a+7);return a[3];}
static uint64_t integer50(uint64_t n){const uint64_t mask=(1ull<<50)-1;uint64_t x=88172645463325252ull&mask,s=0;for(uint64_t i=0;i<n;i++){x^=x>>7;x^=(x<<8)&mask;x^=x>>9;x&=mask;s=(s+(x^(x>>17)))&mask;}return s;}
struct Node{Node*l=nullptr,*r=nullptr;};
static Node* make_tree(int d){auto*n=new Node;if(d>0){n->l=make_tree(d-1);n->r=make_tree(d-1);}return n;}
static uint64_t check_tree(Node*n){return n?1+check_tree(n->l)+check_tree(n->r):0;}
static void free_tree(Node*n){if(n){free_tree(n->l);free_tree(n->r);delete n;}}
static uint64_t trees_once(int mx){Node*s=make_tree(mx+1);uint64_t total=check_tree(s);free_tree(s);Node*longl=make_tree(mx);for(int d=4;d<=mx;d+=2){uint64_t iters=1ull<<(mx-d+4),z=0;for(uint64_t i=0;i<iters;i++){Node*n=make_tree(d);z+=check_tree(n);free_tree(n);}total+=z;}total+=check_tree(longl);free_tree(longl);return total;}
static uint64_t mandel(int w,int mi){uint64_t sum=0;for(int y=0;y<w;y++){double ci=-1.5+3.0*y/(w-1.0);for(int x=0;x<w;x++){double cr=-2.0+3.0*x/(w-1.0),zr=0,zi=0;int it=0;while(it<mi){double zr2=zr*zr,zi2=zi*zi;if(zr2+zi2>4.0)break;double nzr=zr2-zi2+cr;zi=2*zr*zi+ci;zr=nzr;++it;}sum+=it;}}return sum;}
static size_t escape_json(const std::vector<uint8_t>&in,std::vector<uint8_t>&out){static const char*hex="0123456789abcdef";size_t j=0;out[j++]='"';for(uint8_t c:in){switch(c){case '"':out[j++]='\\';out[j++]='"';break;case '\\':out[j++]='\\';out[j++]='\\';break;case 8:out[j++]='\\';out[j++]='b';break;case 12:out[j++]='\\';out[j++]='f';break;case 10:out[j++]='\\';out[j++]='n';break;case 13:out[j++]='\\';out[j++]='r';break;case 9:out[j++]='\\';out[j++]='t';break;default:if(c<32){out[j++]='\\';out[j++]='u';out[j++]='0';out[j++]='0';out[j++]=hex[c>>4];out[j++]=hex[c&15];}else out[j++]=c;}}out[j++]='"';return j;}
static nb::tuple run(const std::string&k){
  double t[7],a,m,rate;uint64_t checksum=0,units=0;
  if(k=="integer50"){units=200000000;integer50(units/20+1);for(int r=0;r<7;r++){a=now();checksum=integer50(units);t[r]=now()-a;}m=med(t);rate=units/m/1e6;}
  else if(k=="json_escape"){units=16000000;static const uint8_t p[]={97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47};std::vector<uint8_t>in(units),out(units*6+2);for(size_t i=0;i<in.size();i++)in[i]=p[i%23];size_t n=escape_json(in,out);for(int r=0;r<7;r++){a=now();n=escape_json(in,out);t[r]=now()-a;}checksum=n;for(size_t i=0;i<n;i++)checksum+=out[i];m=med(t);rate=units/m/1e9;}
  else if(k=="binary_trees"){units=16;trees_once(6);for(int r=0;r<7;r++){a=now();checksum=trees_once((int)units);t[r]=now()-a;}m=med(t);rate=1.0/m;}
  else if(k=="mandelbrot"){uint64_t w=1600;mandel(128,20);for(int r=0;r<7;r++){a=now();checksum=mandel((int)w,50);t[r]=now()-a;}m=med(t);units=w*w;rate=units/m/1e6;}
  else throw std::runtime_error("unknown kernel");
  return nb::make_tuple(k,units,m,rate,checksum);
}
NB_MODULE(bench_ext,m){m.def("run",&run);}
