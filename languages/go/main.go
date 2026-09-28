package main

import (
    "fmt"
    "math"
    "os"
    "sort"
    "strconv"
    "time"
)

func now() float64 { return float64(time.Now().UnixNano()) * 1e-9 }
func median(v []float64) float64 {
    sort.Float64s(v)
    n := len(v)
    if n%2 == 1 { return v[n/2] }
    return .5 * (v[n/2-1] + v[n/2])
}
func result(k string, units uint64, rounds int, sec, rate float64, checksum uint64) {
    fmt.Printf("RESULT kernel=%s units=%d rounds=%d seconds=%.9f rate=%.6f checksum=%d\n",
        k, units, rounds, sec, rate, checksum)
}

func integer50(n uint64) uint64 {
    const mask uint64 = (1 << 50) - 1
    x := uint64(88172645463325252) & mask
    var sum uint64
    for i := uint64(0); i < n; i++ {
        x ^= x >> 7
        x ^= (x << 8) & mask
        x ^= x >> 9
        x &= mask
        sum = (sum + (x ^ (x >> 17))) & mask
    }
    return sum
}
func benchInteger(n uint64, rounds int) {
    _ = integer50(n/20 + 1)
    t := make([]float64, rounds)
    var c uint64
    for r := 0; r < rounds; r++ {
        a := now(); c = integer50(n); t[r] = now() - a
    }
    m := median(t)
    result("integer50", n, rounds, m, float64(n)/m/1e6, c)
}

func laneAt(i uint64, p uint32) uint16 {
    x := i*1103515245 + 12345
    return uint16((x >> 8) % uint64(p))
}
func stablePartition(lanes []uint16, p uint32, order, counts, cursor []uint64) bool {
    for i := range counts { counts[i] = 0 }
    for _, lv := range lanes {
        l := uint32(lv)
        if l >= p { return false }
        counts[l]++
    }
    var off uint64
    for l := uint32(0); l < p; l++ {
        cursor[l] = off
        off += counts[l]
    }
    for i, lv := range lanes {
        l := uint32(lv)
        order[cursor[l]] = uint64(i)
        cursor[l]++
    }
    return true
}
func checksumOrder(p []uint64) uint64 {
    var h uint64
    for i, v := range p {
        h += (v % 1000003) + ((uint64(i) * 17) % 1000003)
    }
    return h
}
func benchPartition(n uint64, rounds int) {
    const parts = 16
    lanes := make([]uint16, n)
    order := make([]uint64, n)
    counts := make([]uint64, parts)
    cursor := make([]uint64, parts)
    for i := uint64(0); i < n; i++ { lanes[i] = laneAt(i, parts) }
    stablePartition(lanes, parts, order, counts, cursor)
    t := make([]float64, rounds)
    for r := 0; r < rounds; r++ {
        a := now()
        if !stablePartition(lanes, parts, order, counts, cursor) { panic("partition") }
        t[r] = now() - a
    }
    var covered uint64
    for _, v := range counts { covered += v }
    if covered != n { panic("covered") }
    c := checksumOrder(order)
    m := median(t)
    result("stable_partition", n, rounds, m, float64(n)/m/1e6, c)
}

func u16le(p []byte) uint16 { return uint16(p[0]) | uint16(p[1])<<8 }
func u24le(p []byte) uint32 { return uint32(p[0]) | uint32(p[1])<<8 | uint32(p[2])<<16 }
func u32le(p []byte) uint32 { return uint32(p[0]) | uint32(p[1])<<8 | uint32(p[2])<<16 | uint32(p[3])<<24 }
func u64le(p []byte) uint64 { return uint64(u32le(p)) | uint64(u32le(p[4:]))<<32 }
func put16(p []byte, v uint16) { p[0] = byte(v); p[1] = byte(v >> 8) }
func put24(p []byte, v uint32) { p[0] = byte(v); p[1] = byte(v >> 8); p[2] = byte(v >> 16) }
func put32(p []byte, v uint32) { for i := 0; i < 4; i++ { p[i] = byte(v >> uint(8*i)) } }
func put64(p []byte, v uint64) { for i := 0; i < 8; i++ { p[i] = byte(v >> uint(8*i)) } }
const binRec = 35

func makeBin(p []byte, i uint64) {
    k := byte(i & 3)
    p[0] = k
    if k == 0 {
        p[1] = byte(i % 250)
        for j := 2; j < 10; j++ { p[j] = 0 }
    } else if k == 1 {
        p[1] = 0xfc
        put16(p[2:], uint16(i))
        for j := 4; j < 10; j++ { p[j] = 0 }
    } else if k == 2 {
        p[1] = 0xfd
        put24(p[2:], uint32(i))
        for j := 5; j < 10; j++ { p[j] = 0 }
    } else {
        p[1] = 0xfe
        put64(p[2:], i)
    }
    for j := 0; j < 8; j++ { p[10+j] = byte((i >> uint(j%6)) ^ uint64(0xA5+j)) }
    put16(p[18:], uint16(i*3))
    put24(p[20:], uint32(i*5))
    put32(p[23:], uint32(i*7))
    put64(p[27:], i*11+17)
}
func bitCount(b []byte) int {
    c := 0
    for i := 0; i < 64; i++ { c += int((b[i>>3] >> uint(i&7)) & 1) }
    return c
}
func decodeBin(buf []byte, rows uint64) uint64 {
    var h uint64
    for i := uint64(0); i < rows; i++ {
        p := buf[i*binRec:(i+1)*binRec]
        k := p[0]
        pos := 1
        var le uint64
        f := p[pos]; pos++
        if f < 0xfb {
            le = uint64(f)
        } else if f == 0xfc {
            le = uint64(u16le(p[pos:])); pos += 2
        } else if f == 0xfd {
            le = uint64(u24le(p[pos:])); pos += 3
        } else if f == 0xfe {
            le = u64le(p[pos:]); pos += 8
        } else { panic("lenenc") }
        pos = 10
        b := p[pos:pos+8]; pos += 8
        v16 := u16le(p[pos:]); pos += 2
        v24 := u24le(p[pos:]); pos += 3
        v32 := u32le(p[pos:]); pos += 4
        v64 := u64le(p[pos:])
        h += uint64(k) + le + uint64(bitCount(b)) + uint64(v16) + uint64(v24) + uint64(v32) + v64
    }
    return h
}
func benchBinary(rows uint64, rounds int) {
    buf := make([]byte, rows*binRec)
    for i := uint64(0); i < rows; i++ { makeBin(buf[i*binRec:], i) }
    _ = decodeBin(buf, rows)
    t := make([]float64, rounds)
    var c uint64
    for r := 0; r < rounds; r++ {
        a := now(); c = decodeBin(buf, rows); t[r] = now() - a
    }
    m := median(t)
    result("binary_decode", rows, rounds, m, float64(len(buf))/m/1e9, c)
}

func digits(p []byte) int {
    v := 0
    for _, c := range p {
        if c < '0' || c > '9' { panic("digit") }
        v = v*10 + int(c-'0')
    }
    return v
}
func parseInt19(p []byte) int64 {
    neg := p[0] == '-'
    v := uint64(0)
    for _, c := range p[1:19] { v = v*10 + uint64(c-'0') }
    if neg { return -int64(v) }
    return int64(v)
}
func daysFromCivil(y int, m, d uint) int64 {
    if m <= 2 { y-- }
    era := y / 400
    if y < 0 && y%400 != 0 { era-- }
    yoe := uint(y - era*400)
    mp := m + 9
    if m > 2 { mp = m - 3 }
    doy := (153*mp+2)/5 + d - 1
    doe := yoe*365 + yoe/4 - yoe/100 + doy
    return int64(era)*146097 + int64(doe) - 719468
}
func parseDT(p []byte) int64 {
    y := digits(p[0:4]); mo := digits(p[5:7]); d := digits(p[8:10])
    h := digits(p[11:13]); mi := digits(p[14:16]); s := digits(p[17:19]); us := digits(p[20:26])
    return ((daysFromCivil(y, uint(mo), uint(d))*86400 + int64(h*3600+mi*60+s))*1000000) + int64(us)
}
const textRec = 46
var dtPrefix = []byte("2026-09-28 19:39:12.")
func write18(p []byte, v uint64) { for j := 17; j >= 0; j-- { p[j] = byte('0'+v%10); v /= 10 } }
func write6(p []byte, v uint64) { for j := 5; j >= 0; j-- { p[j] = byte('0'+v%10); v /= 10 } }
func makeText(p []byte, i uint64) {
    if i&1 != 0 { p[0] = '-' } else { p[0] = '+' }
    v := uint64(100000000000000000) + i%800000000000000000
    write18(p[1:19], v)
    p[19] = '|'
    copy(p[20:40], dtPrefix)
    write6(p[40:46], i%1000000)
}
func parseTexts(buf []byte, rows uint64) uint64 {
    var h uint64
    for i := uint64(0); i < rows; i++ {
        p := buf[i*textRec:(i+1)*textRec]
        v := parseInt19(p)
        ts := parseDT(p[20:46])
        av := uint64(v)
        if v < 0 { av = uint64(-v) }
        h += (av % 1000003) + (uint64(ts) % 1000003)
    }
    return h
}
func benchText(rows uint64, rounds int) {
    buf := make([]byte, rows*textRec)
    for i := uint64(0); i < rows; i++ { makeText(buf[i*textRec:], i) }
    _ = parseTexts(buf, rows)
    t := make([]float64, rounds)
    var c uint64
    for r := 0; r < rounds; r++ {
        a := now(); c = parseTexts(buf, rows); t[r] = now() - a
    }
    m := median(t)
    result("text_parse", rows, rounds, m, float64(rows)/m/1e6, c)
}

var pattern = []byte{'a','l','p','h','a','"','b','e','t','a','\\','g','a','m','m','a','\n','\t',1,'x','y','z','/'}
func fillJSON(p []byte) { for i := range p { p[i] = pattern[i%len(pattern)] } }
func jsonEscape(in, out []byte) int {
    hex := "0123456789abcdef"
    j := 0
    out[j] = '"'; j++
    for _, c := range in {
        switch c {
        case '"': out[j]='\\'; out[j+1]='"'; j+=2
        case '\\': out[j]='\\'; out[j+1]='\\'; j+=2
        case '\b': out[j]='\\'; out[j+1]='b'; j+=2
        case '\f': out[j]='\\'; out[j+1]='f'; j+=2
        case '\n': out[j]='\\'; out[j+1]='n'; j+=2
        case '\r': out[j]='\\'; out[j+1]='r'; j+=2
        case '\t': out[j]='\\'; out[j+1]='t'; j+=2
        default:
            if c < 0x20 {
                out[j]='\\'; out[j+1]='u'; out[j+2]='0'; out[j+3]='0'
                out[j+4]=hex[c>>4]; out[j+5]=hex[c&15]; j+=6
            } else { out[j]=c; j++ }
        }
    }
    out[j] = '"'
    return j+1
}
func benchJSON(bytes uint64, rounds int) {
    in := make([]byte, bytes)
    out := make([]byte, bytes*6+2)
    fillJSON(in)
    outn := jsonEscape(in, out)
    _ = outn
    t := make([]float64, rounds)
    for r := 0; r < rounds; r++ {
        a := now(); outn = jsonEscape(in, out); t[r] = now() - a
    }
    c := uint64(outn)
    for _, v := range out[:outn] { c += uint64(v) }
    m := median(t)
    result("json_escape", bytes, rounds, m, float64(bytes)/m/1e9, c)
}

type Node struct{ l, r *Node }
func makeTree(depth int) *Node {
    n := &Node{}
    if depth > 0 { n.l = makeTree(depth-1); n.r = makeTree(depth-1) }
    return n
}
func checkTree(n *Node) uint64 {
    if n == nil { return 0 }
    return 1 + checkTree(n.l) + checkTree(n.r)
}
func binaryTreesOnce(maxDepth int) uint64 {
    const minDepth = 4
    stretch := makeTree(maxDepth+1)
    total := checkTree(stretch)
    stretch = nil
    _ = stretch
    for depth := minDepth; depth <= maxDepth; depth += 2 {
        iters := uint64(1) << uint(maxDepth-depth+minDepth)
        var s uint64
        for i := uint64(0); i < iters; i++ {
            n := makeTree(depth)
            s += checkTree(n)
        }
        total += s
    }
    long := makeTree(maxDepth)
    total += checkTree(long)
    _ = long
    return total
}
func benchTrees(depth uint64, rounds int) {
    _ = binaryTreesOnce(int(math.Min(float64(depth), 6)))
    t := make([]float64, rounds)
    var c uint64
    for r := 0; r < rounds; r++ {
        a := now(); c = binaryTreesOnce(int(depth)); t[r] = now() - a
    }
    m := median(t)
    result("binary_trees", depth, rounds, m, 1/m, c)
}

func mandelbrot(width, maxIter int) uint64 {
    var sum uint64
    for y := 0; y < width; y++ {
        ci := -1.5 + 3.0*float64(y)/float64(width-1)
        for x := 0; x < width; x++ {
            cr := -2.0 + 3.0*float64(x)/float64(width-1)
            zr, zi := 0.0, 0.0
            it := 0
            for it < maxIter {
                zr2, zi2 := zr*zr, zi*zi
                if zr2+zi2 > 4 { break }
                nzr := zr2 - zi2 + cr
                zi = 2*zr*zi + ci
                zr = nzr
                it++
            }
            sum += uint64(it)
        }
    }
    return sum
}
func benchMandel(width uint64, rounds int) {
    w := int(width)
    ww := w
    if ww > 128 { ww = 128 }
    _ = mandelbrot(ww, 20)
    t := make([]float64, rounds)
    var c uint64
    for r := 0; r < rounds; r++ {
        a := now(); c = mandelbrot(w, 50); t[r] = now() - a
    }
    m := median(t)
    pix := width*width
    result("mandelbrot", pix, rounds, m, float64(pix)/m/1e6, c)
}

func defaultSize(k string) uint64 {
    switch k {
    case "integer50": return 200000000
    case "stable_partition": return 5000000
    case "binary_decode": return 5000000
    case "text_parse": return 5000000
    case "json_escape": return 16000000
    case "binary_trees": return 16
    case "mandelbrot": return 1600
    }
    return 0
}
func runOne(k string, size uint64, rounds int) {
    switch k {
    case "integer50": benchInteger(size, rounds)
    case "stable_partition": benchPartition(size, rounds)
    case "binary_decode": benchBinary(size, rounds)
    case "text_parse": benchText(size, rounds)
    case "json_escape": benchJSON(size, rounds)
    case "binary_trees": benchTrees(size, rounds)
    case "mandelbrot": benchMandel(size, rounds)
    default: panic("unknown kernel")
    }
}
func main() {
    k := "all"
    if len(os.Args) > 1 { k = os.Args[1] }
    rounds := 7
    if len(os.Args) > 3 { rounds, _ = strconv.Atoi(os.Args[3]) }
    if k == "all" {
        for _, q := range []string{"integer50","stable_partition","binary_decode","text_parse","json_escape","binary_trees","mandelbrot"} {
            runOne(q, defaultSize(q), rounds)
        }
        return
    }
    size := defaultSize(k)
    if len(os.Args) > 2 { size, _ = strconv.ParseUint(os.Args[2], 10, 64) }
    runOne(k, size, rounds)
}
