from std.collections import List
from std.memory.alloc import alloc, dealloc, ThinAllocation, Layout
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
    print(
        t"RESULT kernel={k} units={units} rounds=7 seconds={sec} rate={rate} checksum={checksum}"
    )


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
            output[j] = 92
            output[j + 1] = 34
            j += 2
        elif c == 92:
            output[j] = 92
            output[j + 1] = 92
            j += 2
        elif c == 8:
            output[j] = 92
            output[j + 1] = 98
            j += 2
        elif c == 12:
            output[j] = 92
            output[j + 1] = 102
            j += 2
        elif c == 10:
            output[j] = 92
            output[j + 1] = 110
            j += 2
        elif c == 13:
            output[j] = 92
            output[j + 1] = 114
            j += 2
        elif c == 9:
            output[j] = 92
            output[j + 1] = 116
            j += 2
        elif c < 32:
            output[j] = 92
            output[j + 1] = 117
            output[j + 2] = 48
            output[j + 3] = 48
            output[j + 4] = hex_at(c >> 4)
            output[j + 5] = hex_at(c & 15)
            j += 6
        else:
            output[j] = c
            j += 1
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
    emit(
        "json_escape",
        UInt64(n),
        sec,
        Float64(n) / sec / 1.0e9,
        checksum,
    )


struct Node:
    comptime Ptr = Optional[Pointer[Self, MutUntrackedOrigin]]
    var left: Self.Ptr
    var right: Self.Ptr

    def __init__(out self):
        self.left = Self.Ptr()
        self.right = Self.Ptr()


def make_tree(depth: Int) -> Pointer[Node, MutUntrackedOrigin]:
    var p: Pointer[Node, MutUntrackedOrigin] = alloc(
        Layout[Node].single()
    ).unsafe_leak()
    p.unsafe_write(Node())
    if depth > 0:
        p[].left = make_tree(depth - 1)
        p[].right = make_tree(depth - 1)
    return p


def check_tree(p: Pointer[Node, MutUntrackedOrigin]) -> UInt64:
    var total = UInt64(1)
    if p[].left:
        total += check_tree(p[].left.value())
    if p[].right:
        total += check_tree(p[].right.value())
    return total


def free_tree(p: Pointer[Node, MutUntrackedOrigin]):
    var left = p[].left
    var right = p[].right
    if left:
        free_tree(left.value())
    if right:
        free_tree(right.value())
    p.unsafe_deinit_pointee()
    dealloc(
        ThinAllocation(unsafe_owned_ptr=p).unsafe_with_layout({count = 1})
    )


def trees_once(max_depth: Int) -> UInt64:
    var stretch = make_tree(max_depth + 1)
    var total = check_tree(stretch)
    free_tree(stretch)

    var long_lived = make_tree(max_depth)
    var depth = 4
    while depth <= max_depth:
        var iterations = UInt64(1) << (max_depth - depth + 4)
        var subtotal = UInt64(0)
        var i = UInt64(0)
        while i < iterations:
            var tree = make_tree(depth)
            subtotal += check_tree(tree)
            free_tree(tree)
            i += 1
        total += subtotal
        depth += 2

    total += check_tree(long_lived)
    free_tree(long_lived)
    return total


def bench_trees():
    var depth = 16
    _ = trees_once(6)
    var times = List[Float64](length=7, fill=0.0)
    var checksum = UInt64(0)
    for r in range(7):
        var start = now_s()
        checksum = trees_once(depth)
        times[r] = now_s() - start
    var sec = median7(times)
    emit("binary_trees", UInt64(depth), sec, 1.0 / sec, checksum)


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


def bench_mandelbrot():
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
    emit(
        "mandelbrot",
        pixels,
        sec,
        Float64(pixels) / sec / 1.0e6,
        checksum,
    )


def main() raises:
    var args = argv()
    var kernel: String = "integer50"
    if len(args) > 1:
        kernel = args[1]

    if kernel == "integer50":
        bench_integer()
    elif kernel == "json_escape":
        bench_json()
    elif kernel == "binary_trees":
        bench_trees()
    elif kernel == "mandelbrot":
        bench_mandelbrot()
    else:
        raise Error("unknown kernel")
