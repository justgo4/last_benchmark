const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});

fn now() f64 {
    var ts: c.struct_timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_MONOTONIC, &ts);
    return @as(f64, @floatFromInt(ts.tv_sec)) + @as(f64, @floatFromInt(ts.tv_nsec)) * 1e-9;
}
fn median(v: *[7]f64) f64 {
    var i: usize = 1;
    while (i < 7) : (i += 1) {
        const x = v[i];
        var j = i;
        while (j > 0 and v[j - 1] > x) : (j -= 1) v[j] = v[j - 1];
        v[j] = x;
    }
    return v[3];
}
fn emit(k: []const u8, units: u64, sec: f64, rate: f64, checksum: u64) void {
    std.debug.print("RESULT kernel={s} units={d} rounds=7 seconds={d:.9} rate={d:.6} checksum={d}\n", .{ k, units, sec, rate, checksum });
}
fn integer50(n: u64) u64 {
    const mask: u64 = (@as(u64, 1) << 50) - 1;
    var x: u64 = 88172645463325252 & mask;
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < n) : (i += 1) {
        x ^= x >> 7;
        x ^= (x << 8) & mask;
        x ^= x >> 9;
        x &= mask;
        sum = (sum +% (x ^ (x >> 17))) & mask;
    }
    return sum;
}
fn benchInteger() void {
    const n: u64 = 200_000_000;
    _ = integer50(n / 20 + 1);
    var t: [7]f64 = undefined;
    var checksum: u64 = 0;
    for (0..7) |r| {
        const a = now();
        checksum = integer50(n);
        t[r] = now() - a;
    }
    const m = median(&t);
    emit("integer50", n, m, @as(f64, @floatFromInt(n)) / m / 1e6, checksum);
}

const pattern = [_]u8{ 97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47 };
fn jsonEscape(input: []const u8, out: []u8) usize {
    const hex = "0123456789abcdef";
    var j: usize = 0;
    out[j] = '"'; j += 1;
    for (input) |ch| {
        switch (ch) {
            '"' => { out[j]='\\'; out[j+1]='"'; j+=2; },
            '\\' => { out[j]='\\'; out[j+1]='\\'; j+=2; },
            8 => { out[j]='\\'; out[j+1]='b'; j+=2; },
            12 => { out[j]='\\'; out[j+1]='f'; j+=2; },
            10 => { out[j]='\\'; out[j+1]='n'; j+=2; },
            13 => { out[j]='\\'; out[j+1]='r'; j+=2; },
            9 => { out[j]='\\'; out[j+1]='t'; j+=2; },
            else => {
                if (ch < 32) { out[j]='\\'; out[j+1]='u'; out[j+2]='0'; out[j+3]='0'; out[j+4]=hex[ch>>4]; out[j+5]=hex[ch&15]; j+=6; }
                else { out[j]=ch; j+=1; }
            },
        }
    }
    out[j]='"'; return j+1;
}
fn benchJson() !void {
    const bytes: usize = 16_000_000;
    const a = std.heap.c_allocator;
    const input = try a.alloc(u8, bytes); defer a.free(input);
    const out = try a.alloc(u8, bytes*6+2); defer a.free(out);
    for (input, 0..) |*p,i| p.* = pattern[i % pattern.len];
    var outn = jsonEscape(input,out);
    var t:[7]f64=undefined;
    for (0..7)|r| { const s=now(); outn=jsonEscape(input,out); t[r]=now()-s; }
    var checksum:u64=@intCast(outn);
    for(out[0..outn])|b| checksum += b;
    const m=median(&t);
    emit("json_escape",bytes,m,@as(f64,@floatFromInt(bytes))/m/1e9,checksum);
}

const Node=struct{l:?*Node=null,r:?*Node=null};
fn makeTree(a:std.mem.Allocator,d:u32)!*Node{
    const n=try a.create(Node); n.*=.{};
    if(d>0){n.l=try makeTree(a,d-1);n.r=try makeTree(a,d-1);}
    return n;
}
fn checkTree(n:?*const Node)u64{if(n)|p| return 1+checkTree(p.l)+checkTree(p.r); return 0;}
fn freeTree(a:std.mem.Allocator,n:?*Node)void{if(n)|p|{freeTree(a,p.l);freeTree(a,p.r);a.destroy(p);}}
fn treesOnce(a:std.mem.Allocator,mx:u32)!u64{
    const stretch=try makeTree(a,mx+1);var total=checkTree(stretch);freeTree(a,stretch);
    const long=try makeTree(a,mx);
    var d:u32=4;
    while(d<=mx):(d+=2){
        const iters:u64=@as(u64,1)<<@intCast(mx-d+4);var s:u64=0;var i:u64=0;
        while(i<iters):(i+=1){const n=try makeTree(a,d);s+=checkTree(n);freeTree(a,n);}
        total+=s;
    }
    total+=checkTree(long);freeTree(a,long);return total;
}
fn benchTrees()!void{
    const a=std.heap.c_allocator;const depth:u64=16;_ = try treesOnce(a,6);
    var t:[7]f64=undefined;var checksum:u64=0;
    for(0..7)|r|{const s=now();checksum=try treesOnce(a,@intCast(depth));t[r]=now()-s;}
    const m=median(&t);emit("binary_trees",depth,m,1.0/m,checksum);
}
fn mandelbrot(w:u32,max_iter:u32)u64{
    var sum:u64=0;var y:u32=0;
    while(y<w):(y+=1){
        const ci=-1.5+3.0*@as(f64,@floatFromInt(y))/@as(f64,@floatFromInt(w-1));
        var x:u32=0;while(x<w):(x+=1){
            const cr=-2.0+3.0*@as(f64,@floatFromInt(x))/@as(f64,@floatFromInt(w-1));
            var zr:f64=0;var zi:f64=0;var it:u32=0;
            while(it<max_iter):(it+=1){const zr2=zr*zr;const zi2=zi*zi;if(zr2+zi2>4.0)break;const nzr=zr2-zi2+cr;zi=2.0*zr*zi+ci;zr=nzr;}
            sum+=it;
        }
    } return sum;
}
fn benchMandel()void{
    const w:u32=1600;_ = mandelbrot(128,20);var t:[7]f64=undefined;var checksum:u64=0;
    for(0..7)|r|{const s=now();checksum=mandelbrot(w,50);t[r]=now()-s;}
    const m=median(&t);const pix:u64=@as(u64,w)*w;emit("mandelbrot",pix,m,@as(f64,@floatFromInt(pix))/m/1e6,checksum);
}
fn run(k:[]const u8)!void{
    if(std.mem.eql(u8,k,"integer50")) benchInteger()
    else if(std.mem.eql(u8,k,"json_escape")) try benchJson()
    else if(std.mem.eql(u8,k,"binary_trees")) try benchTrees()
    else if(std.mem.eql(u8,k,"mandelbrot")) benchMandel()
    else return error.UnknownKernel;
}
pub export fn main(argc:c_int,argv:[*]const [*:0]const u8)c_int{
    if(argc<2)return 64;
    const k=std.mem.span(argv[1]);
    run(k) catch return 1;
    return 0;
}
