from std.collections import List
from std.sys.arg import argv
from std.time import perf_counter_ns

@inline(.always)
def now_s() -> Float64:
    return Float64(perf_counter_ns()) * 1.0e-9

def median7(mut values: List[Float64]) -> Float64:
    for i in range(1, 7):
        var x = values[i]
        var j = i
        while j > 0 and values[j - 1] > x:
            values[j] = values[j - 1]
            j -= 1
        values[j] = x
    return values[3]

def emit(k: String, units: UInt64, sec: Float64, rate: Float64, checksum: UInt64):
    print(t"RESULT kernel={k} units={units} rounds=7 seconds={sec} rate={rate} checksum={checksum}")

@inline(.always)
def mix32(x0: UInt32) -> UInt32:
    var x = x0 + UInt32(0x9e3779b9)
    x ^= x >> 16
    x *= UInt32(0x85ebca6b)
    x ^= x >> 13
    x *= UInt32(0xc2b2ae35)
    return x ^ (x >> 16)

@inline(.always)
def hash32(x0: UInt32) -> UInt32:
    var x = x0
    x ^= x >> 16
    x *= UInt32(0x7feb352d)
    x ^= x >> 15
    x *= UInt32(0x846ca68b)
    return x ^ (x >> 16)

def ck32(a: List[UInt32]) -> UInt32:
    var h = UInt32(2166136261)
    for i in range(len(a)):
        h = (h ^ a[i]) * UInt32(16777619)
    return h

def ck64(a: List[UInt64]) -> UInt32:
    var h = UInt32(2166136261)
    for i in range(len(a)):
        var x = a[i]
        h = (h ^ UInt32(x)) * UInt32(16777619)
        h = (h ^ UInt32(x >> 32)) * UInt32(16777619)
    return h

@inline(.always)
def integer50(n: UInt64) -> UInt64:
    var mask = (UInt64(1) << 50) - 1
    var x = UInt64(88172645463325252) & mask
    var checksum = UInt64(0)
    var i = UInt64(0)
    while i < n:
        x ^= x >> 7
        x ^= (x << 8) & mask
        x ^= x >> 9
        x &= mask
        checksum = (checksum + (x ^ (x >> 17))) & mask
        i += 1
    return checksum

def bench_integer():
    var n = UInt64(200000000)
    _ = integer50(n // 20 + 1)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt64(0)
    for r in range(7):
        var start = now_s()
        checksum = integer50(n)
        times[r] = now_s() - start
    var sec = median7(times)
    emit("integer50", n, sec, Float64(n) / sec / 1.0e6, checksum)

comptime pattern_len = 23

@inline(.always)
def pattern_at(i: Int) -> UInt8:
    var j = i % pattern_len
    if j == 0: return 97
    if j == 1: return 108
    if j == 2: return 112
    if j == 3: return 104
    if j == 4: return 97
    if j == 5: return 34
    if j == 6: return 98
    if j == 7: return 101
    if j == 8: return 116
    if j == 9: return 97
    if j == 10: return 92
    if j == 11: return 103
    if j == 12: return 97
    if j == 13: return 109
    if j == 14: return 109
    if j == 15: return 97
    if j == 16: return 10
    if j == 17: return 9
    if j == 18: return 1
    if j == 19: return 120
    if j == 20: return 121
    if j == 21: return 122
    return 47

@inline(.always)
def hex_at(i: UInt8) -> UInt8:
    if i < 10:
        return i + 48
    return i - 10 + 97

def json_escape(input: List[UInt8], mut output: List[UInt8]) -> Int:
    var j = 0
    output[j] = 34
    j += 1
    for i in range(len(input)):
        var c = input[i]
        if c == 34:
            output[j] = 92; output[j + 1] = 34; j += 2
        elif c == 92:
            output[j] = 92; output[j + 1] = 92; j += 2
        elif c == 8:
            output[j] = 92; output[j + 1] = 98; j += 2
        elif c == 12:
            output[j] = 92; output[j + 1] = 102; j += 2
        elif c == 10:
            output[j] = 92; output[j + 1] = 110; j += 2
        elif c == 13:
            output[j] = 92; output[j + 1] = 114; j += 2
        elif c == 9:
            output[j] = 92; output[j + 1] = 116; j += 2
        elif c < 32:
            output[j] = 92; output[j + 1] = 117; output[j + 2] = 48; output[j + 3] = 48
            output[j + 4] = hex_at(c >> 4); output[j + 5] = hex_at(c & 15); j += 6
        else:
            output[j] = c; j += 1
    output[j] = 34
    return j + 1

def bench_json():
    var n = 16000000
    var input = List[UInt8](length=n, fill=0)
    var output = List[UInt8](length=n * 6 + 2, fill=0)
    for i in range(n):
        input[i] = pattern_at(i)
    var outn = json_escape(input, output)
    var times = List[Float64](length=7, fill=0.0)
    for r in range(7):
        var start = now_s()
        outn = json_escape(input, output)
        times[r] = now_s() - start
    var checksum = UInt64(outn)
    for i in range(outn):
        checksum += UInt64(output[i])
    var sec = median7(times)
    emit("json_escape", UInt64(n), sec, Float64(n) / sec / 1.0e9, checksum)

def merge_pass(src: List[UInt32], mut dst: List[UInt32], width: Int):
    var n = len(src)
    var lo = 0
    while lo < n:
        var mid = min(lo + width, n)
        var hi = min(lo + 2 * width, n)
        var i = lo
        var j = mid
        var k = lo
        while i < mid and j < hi:
            if src[i] <= src[j]:
                dst[k] = src[i]; i += 1
            else:
                dst[k] = src[j]; j += 1
            k += 1
        while i < mid:
            dst[k] = src[i]; i += 1; k += 1
        while j < hi:
            dst[k] = src[j]; j += 1; k += 1
        lo += 2 * width

def merge_sort(mut a: List[UInt32], mut tmp: List[UInt32]):
    var n = len(a)
    var width = 1
    var flip = False
    while width < n:
        if flip:
            merge_pass(tmp, a, width)
        else:
            merge_pass(a, tmp, width)
        flip = not flip
        if width > n // 2:
            break
        width *= 2
    if flip:
        for i in range(n):
            a[i] = tmp[i]

def bench_merge():
    var n = 1000000
    var base = List[UInt32](length=n, fill=0)
    var a = List[UInt32](length=n, fill=0)
    var tmp = List[UInt32](length=n, fill=0)
    for i in range(n):
        base[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    for r in range(7):
        for i in range(n):
            a[i] = base[i]
        var start = now_s()
        merge_sort(a, tmp)
        times[r] = now_s() - start
    var sec = median7(times)
    emit("merge_sort", UInt64(n), sec, Float64(n) / sec / 1.0e6, UInt64(ck32(a)))

def lower_search(a: List[UInt32], x: UInt32) -> Int:
    var lo = 0
    var hi = len(a)
    while lo < hi:
        var m = lo + (hi - lo) // 2
        if a[m] < x:
            lo = m + 1
        else:
            hi = m
    if lo < len(a) and a[lo] == x:
        return lo
    return -1

def bench_bs():
    var n = 1000000
    var nq = n * 4
    var a = List[UInt32](length=n, fill=0)
    var q = List[UInt32](length=nq, fill=0)
    for i in range(n):
        a[i] = UInt32(i * 2)
    for i in range(nq):
        q[i] = mix32(UInt32(i)) % UInt32(2 * n)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt64(0)
    for r in range(7):
        var start = now_s()
        checksum = 0
        for i in range(nq):
            var p = lower_search(a, q[i])
            if p >= 0:
                checksum += UInt64(p + 1)
        times[r] = now_s() - start
    var sec = median7(times)
    emit("binary_search", UInt64(nq), sec, Float64(nq) / sec / 1.0e6, checksum)

def bench_prefix():
    var n = 8000000
    var input = List[UInt32](length=n, fill=0)
    var output = List[UInt64](length=n, fill=0)
    for i in range(n):
        input[i] = mix32(UInt32(i)) & UInt32(1023)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt64(0)
    for r in range(7):
        var start = now_s()
        checksum = 0
        for p in range(16):
            var s = UInt64(p)
            for i in range(n):
                s += UInt64(input[i])
                output[i] = s
            checksum ^= s
        times[r] = now_s() - start
    checksum ^= UInt64(ck64(output))
    var sec = median7(times)
    emit("prefix_sum", UInt64(n * 16), sec, Float64(n * 16) / sec / 1.0e6, checksum)

def bench_matrix():
    var n = 320
    var nn = n * n
    var a = List[UInt32](length=nn, fill=0)
    var b = List[UInt32](length=nn, fill=0)
    var output = List[UInt64](length=nn, fill=0)
    for i in range(nn):
        a[i] = mix32(UInt32(i)) & UInt32(15)
        b[i] = mix32(UInt32(i + nn)) & UInt32(15)
    var times = List[Float64](length=7, fill=0.0)
    for r in range(7):
        var start = now_s()
        for i in range(n):
            for j in range(n):
                var s = UInt64(0)
                for k in range(n):
                    s += UInt64(a[i * n + k]) * UInt64(b[k * n + j])
                output[i * n + j] = s
        times[r] = now_s() - start
    var sec = median7(times)
    emit("matrix_mul", UInt64(n), sec, Float64(n * n * n) / sec / 1.0e6, UInt64(ck64(output)))

def fill_graph(n: Int, mut a: List[UInt32], mut w: List[UInt32], weighted: Bool):
    var d = 4
    for i in range(n):
        for e in range(d):
            var p = i * d + e
            if e == 0:
                a[p] = UInt32((i + 1) % n)
            elif e == 1:
                a[p] = UInt32((i + n - 1) % n)
            else:
                a[p] = mix32(UInt32(p)) % UInt32(n)
            if weighted:
                w[p] = UInt32(1) + (mix32(UInt32(0xabc00000) + UInt32(p)) & UInt32(15))

def bench_bfs():
    var n = 200000
    var d = 4
    var passes = 16
    var a = List[UInt32](length=n * d, fill=0)
    var unused_w = List[UInt32](length=1, fill=0)
    fill_graph(n, a, unused_w, False)
    var dist = List[Int](length=n, fill=-1)
    var q = List[UInt32](length=n, fill=0)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        var seen = UInt32(0)
        for p in range(passes):
            for i in range(n):
                dist[i] = -1
            dist[0] = 0
            q[0] = 0
            var head = 0
            var tail = 1
            while head < tail:
                var u = Int(q[head])
                head += 1
                var nd = dist[u] + 1
                for e in range(d):
                    var v = Int(a[u * d + e])
                    if dist[v] < 0:
                        dist[v] = nd
                        q[tail] = UInt32(v)
                        tail += 1
            seen ^= UInt32(tail + p)
        var h = UInt32(2166136261)
        for i in range(n):
            h = (h ^ UInt32(dist[i])) * UInt32(16777619)
        checksum = h ^ seen
        times[r] = now_s() - start
    var sec = median7(times)
    emit("bfs", UInt64(n * passes), sec, Float64(n * d * passes) / sec / 1.0e6, UInt64(checksum))

struct HeapPop:
    var d: UInt64
    var v: UInt32
    var size: Int
    def __init__(out self, d: UInt64, v: UInt32, size: Int):
        self.d = d
        self.v = v
        self.size = size

def hp_push(mut hd: List[UInt64], mut hv: List[UInt32], size: Int, dd: UInt64, vv: UInt32) -> Int:
    var i = size
    while i > 0:
        var p = (i - 1) // 2
        if hd[p] <= dd:
            break
        hd[i] = hd[p]
        hv[i] = hv[p]
        i = p
    hd[i] = dd
    hv[i] = vv
    return size + 1

def hp_pop(mut hd: List[UInt64], mut hv: List[UInt32], size: Int) -> HeapPop:
    var od = hd[0]
    var ov = hv[0]
    var ns = size - 1
    var xd = hd[ns]
    var xv = hv[ns]
    var i = 0
    while True:
        var l = i * 2 + 1
        if l >= ns:
            break
        var rr = l + 1
        var c = l
        if rr < ns and hd[rr] < hd[l]:
            c = rr
        if hd[c] >= xd:
            break
        hd[i] = hd[c]
        hv[i] = hv[c]
        i = c
    if ns > 0:
        hd[i] = xd
        hv[i] = xv
    return HeapPop(od, ov, ns)

def bench_dijkstra():
    var n = 100000
    var d = 4
    var a = List[UInt32](length=n * d, fill=0)
    var w = List[UInt32](length=n * d, fill=0)
    fill_graph(n, a, w, True)
    var dist = List[UInt64](length=n, fill=0)
    var hd = List[UInt64](length=n * d * 4, fill=0)
    var hv = List[UInt32](length=n * d * 4, fill=0)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    var inf = UInt64(4611686018427387903)
    for r in range(7):
        var start = now_s()
        for i in range(n):
            dist[i] = inf
        dist[0] = 0
        var size = hp_push(hd, hv, 0, 0, 0)
        while size > 0:
            var x = hp_pop(hd, hv, size)
            size = x.size
            var u = Int(x.v)
            if x.d != dist[u]:
                continue
            for e in range(d):
                var p = u * d + e
                var v = Int(a[p])
                var nd = x.d + UInt64(w[p])
                if nd < dist[v]:
                    dist[v] = nd
                    size = hp_push(hd, hv, size, nd, UInt32(v))
        checksum = ck64(dist)
        times[r] = now_s() - start
    var sec = median7(times)
    emit("dijkstra", UInt64(n), sec, Float64(n * d) / sec / 1.0e6, UInt64(checksum))

def uf_find(mut parent: List[UInt32], x0: UInt32) -> UInt32:
    var x = x0
    while parent[Int(x)] != x:
        parent[Int(x)] = parent[Int(parent[Int(x)])]
        x = parent[Int(x)]
    return x

def bench_uf():
    var n = 1000000
    var ops = n * 4
    var parent = List[UInt32](length=n, fill=0)
    var rank = List[UInt8](length=n, fill=0)
    var aa = List[UInt32](length=ops, fill=0)
    var bb = List[UInt32](length=ops, fill=0)
    for i in range(ops):
        aa[i] = mix32(UInt32(i)) % UInt32(n)
        bb[i] = mix32(UInt32(i + ops)) % UInt32(n)
    var times = List[Float64](length=7, fill=0.0)
    for r in range(7):
        var start = now_s()
        for i in range(n):
            parent[i] = UInt32(i)
            rank[i] = 0
        for i in range(ops):
            var ra = uf_find(parent, aa[i])
            var rb = uf_find(parent, bb[i])
            if ra != rb:
                if rank[Int(ra)] < rank[Int(rb)]:
                    var z = ra; ra = rb; rb = z
                parent[Int(rb)] = ra
                if rank[Int(ra)] == rank[Int(rb)]:
                    rank[Int(ra)] += 1
        times[r] = now_s() - start
    for i in range(n):
        parent[i] = uf_find(parent, UInt32(i))
    var sec = median7(times)
    emit("union_find", UInt64(ops), sec, Float64(ops) / sec / 1.0e6, UInt64(ck32(parent)))

def mandelbrot(width: Int, max_iter: Int) -> UInt64:
    var checksum = UInt64(0)
    for y in range(width):
        var ci = -1.5 + 3.0 * Float64(y) / Float64(width - 1)
        for x in range(width):
            var cr = -2.0 + 3.0 * Float64(x) / Float64(width - 1)
            var zr = 0.0
            var zi = 0.0
            var it = 0
            while it < max_iter:
                var zr2 = zr * zr
                var zi2 = zi * zi
                if zr2 + zi2 > 4.0:
                    break
                var next_zr = zr2 - zi2 + cr
                zi = 2.0 * zr * zi + ci
                zr = next_zr
                it += 1
            checksum += UInt64(it)
    return checksum

def bench_mandel():
    var width = 1600
    _ = mandelbrot(128, 20)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt64(0)
    for r in range(7):
        var start = now_s()
        checksum = mandelbrot(width, 50)
        times[r] = now_s() - start
    var sec = median7(times)
    var pixels = UInt64(width * width)
    emit("mandelbrot", pixels, sec, Float64(pixels) / sec / 1.0e6, checksum)

def bench_array():
    var n = 5000000
    var input = List[UInt32](length=n, fill=0)
    for i in range(n):
        input[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        var v = List[UInt32](capacity=8)
        for i in range(n):
            v.append(input[i])
        var h = UInt32(2166136261)
        for i in range(n):
            v[i] ^= UInt32(i)
            h = (h ^ v[i]) * UInt32(16777619)
        while len(v) > 0:
            var nn = len(v) - 1
            var x = v.pop()
            h = (h ^ (x + UInt32(nn))) * UInt32(16777619)
        checksum = h
        times[r] = now_s() - start
    var sec = median7(times)
    emit("dynamic_array", UInt64(n), sec, Float64(n) / sec / 1.0e6, UInt64(checksum))

def bench_list():
    var n = 4000000
    var passes = 16
    var nilv = UInt32(0xffffffff)
    var block = 64
    var nxt = List[UInt32](length=n, fill=0)
    var val = List[UInt32](length=n, fill=0)
    var base = List[UInt32](length=n, fill=0)
    for i in range(n):
        base[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        for i in range(n):
            val[i] = base[i]
            if i + 1 < n:
                nxt[i] = UInt32(i + 1)
            else:
                nxt[i] = nilv
        var b = 0
        while b < n:
            var hi = min(b + block, n) - 1
            var i = b
            while i <= hi:
                if i == b:
                    if hi + 1 < n:
                        nxt[i] = UInt32(hi + 1)
                    else:
                        nxt[i] = nilv
                else:
                    nxt[i] = UInt32(i - 1)
                i += 1
            b += block
        var h = UInt32(2166136261)
        for p in range(passes):
            var cur = UInt32(block - 1 if block < n else n - 1)
            var seen = 0
            while cur != nilv and seen < n:
                var u = Int(cur)
                val[u] ^= UInt32(seen + p)
                h = (h ^ (val[u] + cur + UInt32(p))) * UInt32(16777619)
                cur = nxt[u]
                seen += 1
            h = (h ^ UInt32(seen)) * UInt32(16777619)
        checksum = h
        times[r] = now_s() - start
    var sec = median7(times)
    emit("linked_list", UInt64(n * passes), sec, Float64(n * passes) / sec / 1.0e6, UInt64(checksum))

def bench_queue():
    var ops = 10000000
    var cap = ops // 2 + 1024
    var buf = List[UInt32](length=cap, fill=0)
    var input = List[UInt32](length=ops, fill=0)
    for i in range(ops):
        input[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        var h = 0
        var t = 0
        var cnt = 0
        var z = UInt32(0)
        for i in range(ops):
            if (i & 3) != 3:
                if cnt == cap:
                    z ^= buf[h]
                    h = (h + 1) % cap
                    cnt -= 1
                buf[t] = input[i]
                t = (t + 1) % cap
                cnt += 1
            elif cnt > 0:
                z ^= buf[h]
                h = (h + 1) % cap
                cnt -= 1
        while cnt > 0:
            z ^= buf[h]
            h = (h + 1) % cap
            cnt -= 1
        checksum = z
        times[r] = now_s() - start
    var sec = median7(times)
    emit("queue_ring", UInt64(ops), sec, Float64(ops) / sec / 1.0e6, UInt64(checksum))

def next_pow2(x: Int) -> Int:
    var p = 1
    while p < x:
        p <<= 1
    return p

def bench_hash():
    var n = 1000000
    var cap = next_pow2(n * 2)
    var mask = cap - 1
    var keys = List[UInt32](length=cap, fill=0)
    var vals = List[UInt32](length=cap, fill=0)
    var ik = List[UInt32](length=n, fill=0)
    var iv = List[UInt32](length=n, fill=0)
    for i in range(n):
        ik[i] = mix32(UInt32(i)) | UInt32(1)
        iv[i] = mix32(UInt32(i) + UInt32(0x55555555))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        for i in range(cap):
            keys[i] = 0
        for i in range(n):
            var key = ik[i]
            var p = Int(hash32(key)) & mask
            while keys[p] != 0 and keys[p] != key:
                p = (p + 1) & mask
            keys[p] = key
            vals[p] = iv[i]
        var h = UInt32(0)
        for i in range(n):
            var key = ik[i]
            var p = Int(hash32(key)) & mask
            while keys[p] != key:
                p = (p + 1) & mask
            vals[p] ^= UInt32(i)
            h ^= vals[p]
        checksum = h
        times[r] = now_s() - start
    var sec = median7(times)
    emit("hash_table", UInt64(n), sec, Float64(n * 2) / sec / 1.0e6, UInt64(checksum))

def heap_push(mut h: List[UInt32], size: Int, x: UInt32) -> Int:
    var i = size
    while i > 0:
        var p = (i - 1) // 2
        if h[p] <= x:
            break
        h[i] = h[p]
        i = p
    h[i] = x
    return size + 1

struct Heap32Pop:
    var x: UInt32
    var size: Int
    def __init__(out self, x: UInt32, size: Int):
        self.x = x
        self.size = size

def heap_pop(mut h: List[UInt32], size: Int) -> Heap32Pop:
    var out = h[0]
    var ns = size - 1
    var x = h[ns]
    var i = 0
    while True:
        var l = i * 2 + 1
        if l >= ns:
            break
        var rr = l + 1
        var c = l
        if rr < ns and h[rr] < h[l]:
            c = rr
        if h[c] >= x:
            break
        h[i] = h[c]
        i = c
    if ns > 0:
        h[i] = x
    return Heap32Pop(out, ns)

def bench_heap():
    var n = 1000000
    var h = List[UInt32](length=n, fill=0)
    var input = List[UInt32](length=n, fill=0)
    for i in range(n):
        input[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        var size = 0
        for i in range(n):
            size = heap_push(h, size, input[i])
        var z = UInt32(0)
        for i in range(n):
            var p = heap_pop(h, size)
            size = p.size
            z ^= p.x + UInt32(i)
        checksum = z
        times[r] = now_s() - start
    var sec = median7(times)
    emit("binary_heap", UInt64(n), sec, Float64(n * 2) / sec / 1.0e6, UInt64(checksum))

def bench_bst():
    var n = 300000
    var keys = List[UInt32](length=n, fill=0)
    var left = List[Int](length=n, fill=-1)
    var right = List[Int](length=n, fill=-1)
    var input = List[UInt32](length=n, fill=0)
    for i in range(n):
        input[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        var root = -1
        for i in range(n):
            var key = input[i]
            keys[i] = key
            left[i] = -1
            right[i] = -1
            if root < 0:
                root = i
            else:
                var cur = root
                while True:
                    if key < keys[cur]:
                        if left[cur] < 0:
                            left[cur] = i
                            break
                        cur = left[cur]
                    else:
                        if right[cur] < 0:
                            right[cur] = i
                            break
                        cur = right[cur]
        var h = UInt32(0)
        var i = 0
        while i < n:
            var key = input[i]
            var cur = root
            while cur >= 0 and keys[cur] != key:
                if key < keys[cur]:
                    cur = left[cur]
                else:
                    cur = right[cur]
            if cur >= 0:
                h ^= UInt32(cur + 1)
            i += 3
        checksum = h
        times[r] = now_s() - start
    var sec = median7(times)
    emit("bst", UInt64(n), sec, Float64(n) / sec / 1.0e6, UInt64(checksum))

def bench_trie():
    var n = 100000
    var passes = 32
    var mx = 1 + n * 8
    var ch = List[Int](length=mx * 16, fill=-1)
    var term = List[UInt8](length=mx, fill=0)
    var words = List[UInt32](length=n, fill=0)
    for i in range(n):
        words[i] = mix32(UInt32(i))
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt32(0)
    for r in range(7):
        var start = now_s()
        for i in range(mx * 16):
            ch[i] = -1
        for i in range(mx):
            term[i] = 0
        var used = 1
        for i in range(n):
            var w = words[i]
            var node = 0
            var sh = 28
            while sh >= 0:
                var cc = Int((w >> sh) & UInt32(15))
                var p = node * 16 + cc
                if ch[p] < 0:
                    ch[p] = used
                    used += 1
                node = ch[p]
                sh -= 4
            term[node] = 1
        var h = UInt32(used)
        for p in range(passes):
            var i = 0
            while i < n:
                var w = words[i]
                var node = 0
                var sh = 28
                while sh >= 0 and node >= 0:
                    node = ch[node * 16 + Int((w >> sh) & UInt32(15))]
                    sh -= 4
                if node >= 0 and term[node] != 0:
                    h ^= UInt32(node + 1 + p)
                i += 2
        checksum = h
        times[r] = now_s() - start
    var sec = median7(times)
    emit("trie", UInt64(n * passes), sec, Float64(n * passes) / sec / 1.0e6, UInt64(checksum))

def main() raises:
    var args = argv()
    var kernel: String = "integer50"
    if len(args) > 1:
        kernel = args[1]

    if kernel == "integer50":
        bench_integer()
    elif kernel == "json_escape":
        bench_json()
    elif kernel == "merge_sort":
        bench_merge()
    elif kernel == "binary_search":
        bench_bs()
    elif kernel == "prefix_sum":
        bench_prefix()
    elif kernel == "matrix_mul":
        bench_matrix()
    elif kernel == "bfs":
        bench_bfs()
    elif kernel == "dijkstra":
        bench_dijkstra()
    elif kernel == "union_find":
        bench_uf()
    elif kernel == "mandelbrot":
        bench_mandel()
    elif kernel == "dynamic_array":
        bench_array()
    elif kernel == "linked_list":
        bench_list()
    elif kernel == "queue_ring":
        bench_queue()
    elif kernel == "hash_table":
        bench_hash()
    elif kernel == "binary_heap":
        bench_heap()
    elif kernel == "bst":
        bench_bst()
    elif kernel == "trie":
        bench_trie()
    else:
        raise Error("unknown kernel")
