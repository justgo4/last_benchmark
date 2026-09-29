{-# LANGUAGE BangPatterns #-}
import Data.Bits
import Data.Word
import Data.Int (Int32)
import Data.List (sort)
import GHC.Clock (getMonotonicTimeNSec)
import System.Environment (getArgs)
import Text.Printf
import Control.Monad (replicateM, when)
import Control.Exception (evaluate)
import Data.Array.IO
import Data.Array.MArray

now :: IO Double
now = do
  n <- getMonotonicTimeNSec
  pure (fromIntegral n * 1e-9)

median :: [Double] -> Double
median xs = sort xs !! 3

emit :: String -> Word64 -> Double -> Double -> Word64 -> IO ()
emit k u s rate c =
  printf "RESULT kernel=%s units=%d rounds=7 seconds=%.9f rate=%.6f checksum=%d\n" k u s rate c

measure7 :: IO Word64 -> IO (Double,Word64)
measure7 action = do
  xs <- replicateM 7 $ do
    a <- now
    c <- action
    b <- now
    pure (b-a,c)
  pure (median (map fst xs), snd (last xs))

mix32 :: Word32 -> Word32
mix32 x0 =
  let x1 = x0 + 0x9e3779b9
      x2 = (xor x1 (shiftR x1 16)) * 0x85ebca6b
      x3 = xor x2 (shiftR x2 13)
      x4 = x3 * 0xc2b2ae35
  in xor x4 (shiftR x4 16)

hash32 :: Word32 -> Word32
hash32 x0 =
  let x1 = xor x0 (shiftR x0 16)
      x2 = x1 * 0x7feb352d
      x3 = xor x2 (shiftR x2 15)
      x4 = x3 * 0x846ca68b
  in xor x4 (shiftR x4 16)

ck32 :: IOUArray Int Word32 -> Int -> IO Word32
ck32 a n = go 0 2166136261
  where
    go !i !h
      | i >= n = pure h
      | otherwise = do
          x <- readArray a i
          go (i+1) ((xor h x) * 16777619)

ckI32 :: IOUArray Int Int32 -> Int -> IO Word32
ckI32 a n = go 0 2166136261
  where
    go !i !h
      | i >= n = pure h
      | otherwise = do
          x <- readArray a i
          go (i+1) ((xor h (fromIntegral x :: Word32)) * 16777619)

ck64 :: IOUArray Int Word64 -> Int -> IO Word32
ck64 a n = go 0 2166136261
  where
    go !i !h
      | i >= n = pure h
      | otherwise = do
          x <- readArray a i
          let h1 = (xor h (fromIntegral x :: Word32)) * 16777619
              h2 = (xor h1 (fromIntegral (shiftR x 32) :: Word32)) * 16777619
          go (i+1) h2

copy32 :: IOUArray Int Word32 -> IOUArray Int Word32 -> Int -> IO ()
copy32 dst src n = go 0
  where
    go !i
      | i >= n = pure ()
      | otherwise = readArray src i >>= writeArray dst i >> go (i+1)

fillI32 :: IOUArray Int Int32 -> Int -> Int32 -> IO ()
fillI32 a n x = go 0
  where
    go !i | i>=n = pure ()
          | otherwise = writeArray a i x >> go (i+1)

fillW32 :: IOUArray Int Word32 -> Int -> Word32 -> IO ()
fillW32 a n x = go 0
  where
    go !i | i>=n = pure ()
          | otherwise = writeArray a i x >> go (i+1)

fillW64 :: IOUArray Int Word64 -> Int -> Word64 -> IO ()
fillW64 a n x = go 0
  where
    go !i | i>=n = pure ()
          | otherwise = writeArray a i x >> go (i+1)

fillW8 :: IOUArray Int Word8 -> Int -> Word8 -> IO ()
fillW8 a n x = go 0
  where
    go !i | i>=n = pure ()
          | otherwise = writeArray a i x >> go (i+1)

integer50 :: Word64 -> Word64
integer50 n = go n ((.&.) 88172645463325252 mask) 0
  where
    mask = (shiftL 1 50) - 1
    go 0 !_ !s = s
    go !i !x !s =
      let x1 = xor x (shiftR x 7)
          x2 = xor x1 ((.&.) (shiftL x1 8) mask)
          x3 = xor x2 (shiftR x2 9)
          x4 = (.&.) x3 mask
          s1 = (.&.) (s + xor x4 (shiftR x4 17)) mask
      in go (i-1) x4 s1

benchInteger :: Word64 -> IO ()
benchInteger n = do
  _ <- evaluate (integer50 (div n 20 + 1))
  (m,c) <- measure7 (evaluate (integer50 n))
  emit "integer50" n m (fromIntegral n/m/1e6) c

patternBytes :: [Word8]
patternBytes=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]

hexAt :: Word8 -> Word8
hexAt x | x < 10 = 48 + x
        | otherwise = 87 + x

jsonEscape :: IOUArray Int Word8 -> Int -> IOUArray Int Word8 -> IO Int
jsonEscape input n output = do
  writeArray output 0 34
  let go !i !j
        | i >= n = writeArray output j 34 >> pure (j+1)
        | otherwise = do
            c <- readArray input i
            case c of
              34 -> two i j 34
              92 -> two i j 92
              8  -> two i j 98
              12 -> two i j 102
              10 -> two i j 110
              13 -> two i j 114
              9  -> two i j 116
              _ | c < 32 -> do
                    writeArray output j 92
                    writeArray output (j+1) 117
                    writeArray output (j+2) 48
                    writeArray output (j+3) 48
                    writeArray output (j+4) (hexAt (shiftR c 4))
                    writeArray output (j+5) (hexAt ((.&.) c 15))
                    go (i+1) (j+6)
                | otherwise -> writeArray output j c >> go (i+1) (j+1)
      two i j x = do
        writeArray output j 92
        writeArray output (j+1) x
        go (i+1) (j+2)
  go 0 1

benchJson :: Int -> IO ()
benchJson n = do
  input <- newArray_ (0,n-1) :: IO (IOUArray Int Word8)
  output <- newArray_ (0,n*6+1) :: IO (IOUArray Int Word8)
  let fill !i
        | i>=n = pure ()
        | otherwise = writeArray input i (patternBytes !! mod i 23) >> fill (i+1)
  fill 0
  _ <- jsonEscape input n output
  xs <- replicateM 7 $ do
    a <- now
    outn <- jsonEscape input n output
    b <- now
    pure (b-a,outn)
  let m=median(map fst xs); outn=snd(last xs)
      sumOut !i !acc
        | i>=outn = pure acc
        | otherwise = do x<-readArray output i;sumOut(i+1)(acc+fromIntegral x)
  c <- sumOut 0 (fromIntegral outn)
  emit "json_escape" (fromIntegral n) m (fromIntegral n/m/1e9) c

mergeSort :: IOUArray Int Word32 -> IOUArray Int Word32 -> Int -> IO ()
mergeSort a tmp n = loop 1 a tmp False
  where
    loop !w !src !dst !flipv
      | w>=n = if flipv then copy32 a src n else pure ()
      | otherwise = do
          let blocks !lo
                | lo>=n = pure ()
                | otherwise = do
                    let mid=min (lo+w) n
                        hi=min (lo+2*w) n
                        merge !i !j !k
                          | i<mid && j<hi = do
                              x<-readArray src i
                              y<-readArray src j
                              if x<=y
                                then writeArray dst k x >> merge(i+1)j(k+1)
                                else writeArray dst k y >> merge i(j+1)(k+1)
                          | i<mid = readArray src i >>= writeArray dst k >> merge(i+1)j(k+1)
                          | j<hi = readArray src j >>= writeArray dst k >> merge i(j+1)(k+1)
                          | otherwise = pure ()
                    merge lo mid lo
                    blocks (lo+2*w)
          blocks 0
          if w > div n 2
            then loop n dst src (not flipv)
            else loop (w*2) dst src (not flipv)

benchMerge :: Int -> IO ()
benchMerge n = do
  base<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  a<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  tmp<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray base i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  ts<-replicateM 7$do
    copy32 a base n
    st<-now
    mergeSort a tmp n
    e<-now
    pure(e-st)
  c<-ck32 a n
  let m=median ts
  emit "merge_sort"(fromIntegral n)m(fromIntegral n/m/1e6)(fromIntegral c)

lowerSearch :: IOUArray Int Word32 -> Int -> Word32 -> IO Int
lowerSearch a n x=go 0 n
  where
    go !l !h
      | l>=h = if l<n then do v<-readArray a l;pure(if v==x then l else -1) else pure(-1)
      | otherwise=do
          let m=l+div(h-l)2
          v<-readArray a m
          if v<x then go(m+1)h else go l m

benchBS :: Int -> IO ()
benchBS n=do
  let nq=n*4
  a<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  q<-newArray_ (0,nq-1)::IO(IOUArray Int Word32)
  let fa !i|i>=n=pure ()
           |otherwise=writeArray a i(fromIntegral(i*2))>>fa(i+1)
      fq !i|i>=nq=pure ()
           |otherwise=writeArray q i(mod(mix32(fromIntegral i))(fromIntegral(2*n)))>>fq(i+1)
  fa 0;fq 0
  (m,c)<-measure7$do
    let go !i !s|i>=nq=pure s
                |otherwise=do
                    x<-readArray q i
                    p<-lowerSearch a n x
                    go(i+1)(if p>=0 then s+fromIntegral(p+1) else s)
    go 0 0
  emit "binary_search"(fromIntegral nq)m(fromIntegral nq/m/1e6)c

benchPrefix :: Int -> IO ()
benchPrefix n=do
  input<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  out<-newArray_ (0,n-1)::IO(IOUArray Int Word64)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray input i((.&.)(mix32(fromIntegral i))1023)>>gen(i+1)
  gen 0
  xs<-replicateM 7$do
    st<-now
    let pass !p !c
          |p>=16=pure c
          |otherwise=do
              let walk !i !s
                    |i>=n=pure s
                    |otherwise=do
                        x<-readArray input i
                        let s2=s+fromIntegral x
                        writeArray out i s2
                        walk(i+1)s2
              s<-walk 0(fromIntegral p)
              pass(p+1)(xor c s)
    c<-pass 0 0
    e<-now
    pure(e-st,c)
  k<-ck64 out n
  let m=median(map fst xs); c=xor(snd(last xs))(fromIntegral k)
  emit "prefix_sum"(fromIntegral(n*16))m(fromIntegral(n*16)/m/1e6)c

benchMatrix :: Int -> IO ()
benchMatrix n=do
  let nn=n*n
  a<-newArray_ (0,nn-1)::IO(IOUArray Int Word32)
  b<-newArray_ (0,nn-1)::IO(IOUArray Int Word32)
  out<-newArray_ (0,nn-1)::IO(IOUArray Int Word64)
  let gen !i|i>=nn=pure ()
            |otherwise=do
                writeArray a i((.&.)(mix32(fromIntegral i))15)
                writeArray b i((.&.)(mix32(fromIntegral(i+nn)))15)
                gen(i+1)
  gen 0
  ts<-replicateM 7$do
    st<-now
    let li !i|i>=n=pure ()
              |otherwise=lj i 0>>li(i+1)
        lj !i !j|j>=n=pure ()
                |otherwise=do
                    let lk !k !s
                          |k>=n=pure s
                          |otherwise=do
                              x<-readArray a(i*n+k)
                              y<-readArray b(k*n+j)
                              lk(k+1)(s+fromIntegral x*fromIntegral y)
                    s<-lk 0 0
                    writeArray out(i*n+j)s
                    lj i(j+1)
    li 0
    e<-now
    pure(e-st)
  c<-ck64 out nn
  let m=median ts
  emit "matrix_mul"(fromIntegral n)m(fromIntegral(n*n*n)/m/1e6)(fromIntegral c)

makeGraph :: Int -> Bool -> IO (IOUArray Int Word32,Maybe(IOUArray Int Word32))
makeGraph n weighted=do
  let d=4
  a<-newArray_ (0,n*d-1)::IO(IOUArray Int Word32)
  mw<-if weighted then do w<-newArray_ (0,n*d-1)::IO(IOUArray Int Word32);pure(Just w) else pure Nothing
  let li !i|i>=n=pure ()
            |otherwise=le i 0>>li(i+1)
      le !i !e|e>=d=pure ()
              |otherwise=do
                  let p=i*d+e
                      v=if e==0 then mod(i+1)n else if e==1 then mod(i+n-1)n else fromIntegral(mod(mix32(fromIntegral p))(fromIntegral n))
                  writeArray a p(fromIntegral v)
                  case mw of
                    Just w->writeArray w p(1+(.&.)(mix32(0xabc00000+fromIntegral p))15)
                    Nothing->pure()
                  le i(e+1)
  li 0
  pure(a,mw)

benchBFS :: Int -> IO ()
benchBFS n=do
  let d=4;passes=16
  (a,_)<-makeGraph n False
  dist<-newArray (0,n-1)(-1)::IO(IOUArray Int Int32)
  q<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  xs<-replicateM 7$do
    st<-now
    let pass !p !seen
          |p>=passes=do
              k<-ckI32 dist n
              pure(fromIntegral(xor k seen))
          |otherwise=do
              fillI32 dist n(-1)
              writeArray dist 0 0
              writeArray q 0 0
              let bfs !head !tail
                    |head>=tail=pure tail
                    |otherwise=do
                        u0<-readArray q head
                        let u=fromIntegral u0
                        du<-readArray dist u
                        let edges !e !t
                              |e>=d=bfs(head+1)t
                              |otherwise=do
                                  v0<-readArray a(u*d+e)
                                  let v=fromIntegral v0
                                  dv<-readArray dist v
                                  if dv<0
                                    then writeArray dist v(du+1)>>writeArray q t v0>>edges(e+1)(t+1)
                                    else edges(e+1)t
                        edges 0 tail
              t<-bfs 0 1
              pass(p+1)(xor seen(fromIntegral(t+p)))
    c<-pass 0 0
    e<-now
    pure(e-st,c)
  let m=median(map fst xs);c=snd(last xs)
  emit "bfs"(fromIntegral(n*passes))m(fromIntegral(n*d*passes)/m/1e6)c

hpPush :: IOUArray Int Word64 -> IOUArray Int Word32 -> Int -> Word64 -> Word32 -> IO Int
hpPush hd hv sz dd vv=go sz
  where
    go !i
      |i==0=writeArray hd 0 dd>>writeArray hv 0 vv>>pure(sz+1)
      |otherwise=do
          let p=div(i-1)2
          pd<-readArray hd p
          if pd<=dd
            then writeArray hd i dd>>writeArray hv i vv>>pure(sz+1)
            else do
              pv<-readArray hv p
              writeArray hd i pd
              writeArray hv i pv
              go p

hpPop :: IOUArray Int Word64 -> IOUArray Int Word32 -> Int -> IO(Word64,Word32,Int)
hpPop hd hv sz=do
  od<-readArray hd 0
  ov<-readArray hv 0
  let ns=sz-1
  xd<-readArray hd ns
  xv<-readArray hv ns
  let finish i=do
        when(ns>0)(writeArray hd i xd>>writeArray hv i xv)
        pure(od,ov,ns)
      go !i=do
        let l=i*2+1
        if l>=ns then finish i else do
          let rr=l+1
          c<-if rr<ns
             then do x<-readArray hd rr;y<-readArray hd l;pure(if x<y then rr else l)
             else pure l
          cd<-readArray hd c
          if cd>=xd
            then finish i
            else do
              cv<-readArray hv c
              writeArray hd i cd
              writeArray hv i cv
              go c
  go 0

benchDij :: Int -> IO ()
benchDij n=do
  let d=4;inf=4611686018427387903::Word64
  (a,mw)<-makeGraph n True
  let Just w=mw
  dist<-newArray_ (0,n-1)::IO(IOUArray Int Word64)
  hd<-newArray_ (0,n*d*4-1)::IO(IOUArray Int Word64)
  hv<-newArray_ (0,n*d*4-1)::IO(IOUArray Int Word32)
  xs<-replicateM 7$do
    st<-now
    fillW64 dist n inf
    writeArray dist 0 0
    sz0<-hpPush hd hv 0 0 0
    let loop !sz
          |sz<=0=fromIntegral <$> ck64 dist n
          |otherwise=do
              (dd,u0,ns)<-hpPop hd hv sz
              let u=fromIntegral u0
              cur<-readArray dist u
              if dd/=cur
                then loop ns
                else let edges !e !s
                           |e>=d=loop s
                           |otherwise=do
                               let p=u*d+e
                               v0<-readArray a p
                               ww<-readArray w p
                               let v=fromIntegral v0;nd=dd+fromIntegral ww
                               dv<-readArray dist v
                               if nd<dv
                                 then writeArray dist v nd>>hpPush hd hv s nd v0>>=edges(e+1)
                                 else edges(e+1)s
                     in edges 0 ns
    c<-loop sz0
    e<-now
    pure(e-st,c)
  let m=median(map fst xs);c=snd(last xs)
  emit "dijkstra"(fromIntegral n)m(fromIntegral(n*d)/m/1e6)c

ufFind :: IOUArray Int Word32 -> Word32 -> IO Word32
ufFind p x0=go x0
  where
    go !x=do
      px<-readArray p(fromIntegral x)
      if px==x
        then pure x
        else do
          pp<-readArray p(fromIntegral px)
          writeArray p(fromIntegral x)pp
          go pp

benchUF :: Int -> IO ()
benchUF n=do
  let ops=n*4
  p<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  rank<-newArray_ (0,n-1)::IO(IOUArray Int Word8)
  aa<-newArray_ (0,ops-1)::IO(IOUArray Int Word32)
  bb<-newArray_ (0,ops-1)::IO(IOUArray Int Word32)
  let gen !i|i>=ops=pure ()
            |otherwise=do
                writeArray aa i(mod(mix32(fromIntegral i))(fromIntegral n))
                writeArray bb i(mod(mix32(fromIntegral(i+ops)))(fromIntegral n))
                gen(i+1)
  gen 0
  ts<-replicateM 7$do
    st<-now
    let initp !i|i>=n=pure ()
                |otherwise=writeArray p i(fromIntegral i)>>writeArray rank i 0>>initp(i+1)
        runops !i|i>=ops=pure ()
                 |otherwise=do
                    a0<-readArray aa i;b0<-readArray bb i
                    ra0<-ufFind p a0;rb0<-ufFind p b0
                    if ra0==rb0 then runops(i+1) else do
                      rka<-readArray rank(fromIntegral ra0);rkb<-readArray rank(fromIntegral rb0)
                      let (ra,rb,ka,kb)=if rka<rkb then(rb0,ra0,rkb,rka)else(ra0,rb0,rka,rkb)
                      writeArray p(fromIntegral rb)ra
                      when(ka==kb)(writeArray rank(fromIntegral ra)(ka+1))
                      runops(i+1)
    initp 0;runops 0
    e<-now
    pure(e-st)
  let flatten !i|i>=n=pure ()
                 |otherwise=ufFind p(fromIntegral i)>>=writeArray p i>>flatten(i+1)
  flatten 0
  c<-ck32 p n
  let m=median ts
  emit "union_find"(fromIntegral ops)m(fromIntegral ops/m/1e6)(fromIntegral c)

mandelbrot :: Int -> Int -> Word64
mandelbrot w maxIter=goY 0 0
  where
    goY y !s
      |y>=w=s
      |otherwise=let ci=(-1.5)+3.0*fromIntegral y/fromIntegral(w-1)
                 in goY(y+1)(goX ci 0 s)
    goX _ x !s|x>=w=s
    goX ci x !s=
      let cr=(-2.0)+3.0*fromIntegral x/fromIntegral(w-1)
          it=iter cr ci 0 0 0
      in goX ci(x+1)(s+fromIntegral it)
    iter cr ci !zr !zi !it
      |it>=maxIter=it
      |zr*zr+zi*zi>4.0=it
      |otherwise=let nzr=zr*zr-zi*zi+cr;nzi=2*zr*zi+ci
                 in iter cr ci nzr nzi(it+1)

benchMandel :: Int -> IO ()
benchMandel w=do
  _<-evaluate(mandelbrot(min w 128)20)
  (m,c)<-measure7(evaluate(mandelbrot w 50))
  let pix=fromIntegral(w*w)
  emit "mandelbrot" pix m(fromIntegral pix/m/1e6)c

dynamicOnce :: IOUArray Int Word32 -> Int -> IO Word32
dynamicOnce input n=do
  a0<-newArray_ (0,7)::IO(IOUArray Int Word32)
  let copyGrow old cap=do
        new<-newArray_ (0,cap*2-1)::IO(IOUArray Int Word32)
        copy32 new old cap
        pure new
      push !i !cap !arr
        |i>=n=pure(cap,arr)
        |otherwise=do
            arr2<-if i==cap then copyGrow arr cap else pure arr
            let cap2=if i==cap then cap*2 else cap
            x<-readArray input i
            writeArray arr2 i x
            push(i+1)cap2 arr2
  (_,a)<-push 0 8 a0
  let mutate !i !h
        |i>=n=pure h
        |otherwise=do
            x<-readArray a i
            let y=xor x(fromIntegral i);h2=(xor h y)*16777619
            writeArray a i y
            mutate(i+1)h2
  h0<-mutate 0 2166136261
  let pop !i !h
        |i<=0=pure h
        |otherwise=do
            let j=i-1
            x<-readArray a j
            pop j((xor h(x+fromIntegral j))*16777619)
  pop n h0

benchArray :: Int -> IO ()
benchArray n=do
  input<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray input i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  (m,c)<-measure7(fromIntegral <$> dynamicOnce input n)
  emit "dynamic_array"(fromIntegral n)m(fromIntegral n/m/1e6)c

benchList :: Int -> IO ()
benchList n=do
  let passes=16;nilv=maxBound::Word32;block=64
  nxt<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  val<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  base<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray base i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  (m,c)<-measure7$do
    copy32 val base n
    let initn !i|i>=n=pure ()
                 |otherwise=writeArray nxt i(if i+1<n then fromIntegral(i+1)else nilv)>>initn(i+1)
        blocks !b|b>=n=pure ()
                 |otherwise=do
                    let hi=min(b+block)n-1
                        set !i|i>hi=pure ()
                              |otherwise=writeArray nxt i(if i==b then if hi+1<n then fromIntegral(hi+1)else nilv else fromIntegral(i-1))>>set(i+1)
                    set b;blocks(b+block)
    initn 0;blocks 0
    let pass !p !h
          |p>=passes=pure h
          |otherwise=do
              let walk !cur !seen !hh
                    |cur==nilv||seen>=n=pure(seen,hh)
                    |otherwise=do
                        let u=fromIntegral cur
                        x<-readArray val u
                        let y=xor x(fromIntegral(seen+p));h2=(xor hh(y+cur+fromIntegral p))*16777619
                        writeArray val u y
                        nx<-readArray nxt u
                        walk nx(seen+1)h2
              (seen,h2)<-walk(if block<n then fromIntegral(block-1)else fromIntegral(n-1))0 h
              pass(p+1)((xor h2(fromIntegral seen))*16777619)
    fromIntegral <$> pass 0 2166136261
  emit "linked_list"(fromIntegral(n*passes))m(fromIntegral(n*passes)/m/1e6)c

benchQueue :: Int -> IO ()
benchQueue ops=do
  let cap=div ops 2+1024
  buf<-newArray_ (0,cap-1)::IO(IOUArray Int Word32)
  input<-newArray_ (0,ops-1)::IO(IOUArray Int Word32)
  let gen !i|i>=ops=pure ()
            |otherwise=writeArray input i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  (m,c)<-measure7$do
    let drain !h !cnt !z
          |cnt<=0=pure(fromIntegral z)
          |otherwise=do x<-readArray buf h;drain(mod(h+1)cap)(cnt-1)(xor z x)
        go !i !h !t !cnt !z
          |i>=ops=drain h cnt z
          |otherwise=do
              x<-readArray input i
              if (.&.) i 3 /= 3
                then if cnt==cap
                     then do
                       old<-readArray buf h
                       writeArray buf t x
                       go(i+1)(mod(h+1)cap)(mod(t+1)cap)cnt(xor z old)
                     else writeArray buf t x>>go(i+1)h(mod(t+1)cap)(cnt+1)z
                else if cnt>0
                     then do old<-readArray buf h;go(i+1)(mod(h+1)cap)t(cnt-1)(xor z old)
                     else go(i+1)h t cnt z
    go 0 0 0 0 0
  emit "queue_ring"(fromIntegral ops)m(fromIntegral ops/m/1e6)c

nextPow2 :: Int -> Int
nextPow2 x=go 1 where go p|p>=x=p|otherwise=go(p*2)

benchHash :: Int -> IO ()
benchHash n=do
  let cap=nextPow2(n*2);mask=cap-1
  keys<-newArray (0,cap-1)0::IO(IOUArray Int Word32)
  vals<-newArray_ (0,cap-1)::IO(IOUArray Int Word32)
  ik<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  iv<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=do
                writeArray ik i((.|.)(mix32(fromIntegral i))1)
                writeArray iv i(mix32(fromIntegral i+0x55555555))
                gen(i+1)
  gen 0
  (m,c)<-measure7$do
    fillW32 keys cap 0
    let findSlot key !p=do k<-readArray keys p;if k==0||k==key then pure p else findSlot key((p+1).&.mask)
        ins !i|i>=n=pure ()
              |otherwise=do
                  key<-readArray ik i;v<-readArray iv i
                  p<-findSlot key(fromIntegral(hash32 key).&.mask)
                  writeArray keys p key;writeArray vals p v;ins(i+1)
        findKey key !p=do k<-readArray keys p;if k==key then pure p else findKey key((p+1).&.mask)
        look !i !h|i>=n=pure(fromIntegral h)
                  |otherwise=do
                      key<-readArray ik i
                      p<-findKey key(fromIntegral(hash32 key).&.mask)
                      v<-readArray vals p
                      let v2=xor v(fromIntegral i)
                      writeArray vals p v2
                      look(i+1)(xor h v2)
    ins 0;look 0 0
  emit "hash_table"(fromIntegral n)m(fromIntegral(n*2)/m/1e6)c

heapPush32 :: IOUArray Int Word32 -> Int -> Word32 -> IO Int
heapPush32 h sz x=go sz
  where
    go !i
      |i==0=writeArray h 0 x>>pure(sz+1)
      |otherwise=do
          let p=div(i-1)2
          v<-readArray h p
          if v<=x then writeArray h i x>>pure(sz+1)
                  else writeArray h i v>>go p

heapPop32 :: IOUArray Int Word32 -> Int -> IO(Word32,Int)
heapPop32 h sz=do
  o<-readArray h 0
  let ns=sz-1
  x<-readArray h ns
  let finish i=do when(ns>0)(writeArray h i x);pure(o,ns)
      go !i=do
        let l=i*2+1
        if l>=ns then finish i else do
          let rr=l+1
          c<-if rr<ns then do a<-readArray h rr;b<-readArray h l;pure(if a<b then rr else l) else pure l
          v<-readArray h c
          if v>=x then finish i else writeArray h i v>>go c
  go 0

benchHeap :: Int -> IO ()
benchHeap n=do
  h<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  input<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray input i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  (m,c)<-measure7$do
    let pushes !i !sz|i>=n=pure sz
                      |otherwise=readArray input i>>=heapPush32 h sz>>=pushes(i+1)
    sz0<-pushes 0 0
    let pops !i !sz !z|i>=n=pure(fromIntegral z)
                       |otherwise=do(x,ns)<-heapPop32 h sz;pops(i+1)ns(xor z(x+fromIntegral i))
    pops 0 sz0 0
  emit "binary_heap"(fromIntegral n)m(fromIntegral(n*2)/m/1e6)c

benchBST :: Int -> IO ()
benchBST n=do
  keys<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  left<-newArray_ (0,n-1)::IO(IOUArray Int Int32)
  right<-newArray_ (0,n-1)::IO(IOUArray Int Int32)
  input<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray input i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  (m,c)<-measure7$do
    let insertAll !i !root
          |i>=n=pure root
          |otherwise=do
              key<-readArray input i
              writeArray keys i key;writeArray left i(-1);writeArray right i(-1)
              if root<0 then insertAll(i+1)(fromIntegral i)
              else do
                let walk !cur=do
                      ck<-readArray keys(fromIntegral cur)
                      if key<ck
                        then do nx<-readArray left(fromIntegral cur);if nx<0 then writeArray left(fromIntegral cur)(fromIntegral i) else walk nx
                        else do nx<-readArray right(fromIntegral cur);if nx<0 then writeArray right(fromIntegral cur)(fromIntegral i) else walk nx
                walk root
                insertAll(i+1)root
    root<-insertAll 0(-1)
    let look !i !h
          |i>=n=pure(fromIntegral h)
          |otherwise=do
              key<-readArray input i
              let walk !cur
                    |cur<0=pure cur
                    |otherwise=do
                        ck<-readArray keys(fromIntegral cur)
                        if ck==key then pure cur
                        else if key<ck then readArray left(fromIntegral cur)>>=walk else readArray right(fromIntegral cur)>>=walk
              cur<-walk root
              look(i+3)(if cur>=0 then xor h(fromIntegral(cur+1))else h)
    look 0 0
  emit "bst"(fromIntegral n)m(fromIntegral n/m/1e6)c

benchTrie :: Int -> IO ()
benchTrie n=do
  let passes=32;mx=1+n*8
  ch<-newArray (0,mx*16-1)(-1)::IO(IOUArray Int Int32)
  term<-newArray (0,mx-1)0::IO(IOUArray Int Word8)
  wordsA<-newArray_ (0,n-1)::IO(IOUArray Int Word32)
  let gen !i|i>=n=pure ()
            |otherwise=writeArray wordsA i(mix32(fromIntegral i))>>gen(i+1)
  gen 0
  (m,c)<-measure7$do
    fillI32 ch(mx*16)(-1);fillW8 term mx 0
    let insert !i !used
          |i>=n=pure used
          |otherwise=do
              w<-readArray wordsA i
              let chars !sh !node !u
                    |sh<0=writeArray term node 1>>pure u
                    |otherwise=do
                        let cc=fromIntegral((.&.)(shiftR w sh)15);pos=node*16+cc
                        v<-readArray ch pos
                        if v<0
                          then writeArray ch pos(fromIntegral u)>>chars(sh-4)u(u+1)
                          else chars(sh-4)(fromIntegral v)u
              u2<-chars 28 0 used
              insert(i+1)u2
    used<-insert 0 1
    let passesLoop !p !h
          |p>=passes=pure(fromIntegral h)
          |otherwise=do
              let wordLoop !i !hh
                    |i>=n=pure hh
                    |otherwise=do
                        w<-readArray wordsA i
                        let chars !sh !node
                              |sh<0=pure node
                              |node<0=pure node
                              |otherwise=do
                                  let cc=fromIntegral((.&.)(shiftR w sh)15)
                                  v<-readArray ch(node*16+cc)
                                  chars(sh-4)(fromIntegral v)
                        node<-chars 28 0
                        if node>=0
                          then do t<-readArray term node;wordLoop(i+2)(if t/=0 then xor hh(fromIntegral(node+1+p))else hh)
                          else wordLoop(i+2)hh
              h2<-wordLoop 0 h
              passesLoop(p+1)h2
    passesLoop 0(fromIntegral used::Word32)
  emit "trie"(fromIntegral(n*passes))m(fromIntegral(n*passes)/m/1e6)c

defaultSize :: String -> Int
defaultSize k=case k of
  "integer50"->200000000
  "json_escape"->16000000
  "merge_sort"->1000000
  "binary_search"->1000000
  "prefix_sum"->8000000
  "matrix_mul"->320
  "bfs"->200000
  "dijkstra"->100000
  "union_find"->1000000
  "mandelbrot"->1600
  "dynamic_array"->5000000
  "linked_list"->4000000
  "queue_ring"->10000000
  "hash_table"->1000000
  "binary_heap"->1000000
  "bst"->300000
  "trie"->100000
  _->0

main :: IO ()
main=do
  args<-getArgs
  let k=if null args then "integer50" else head args
      n=if length args>1 then read(args!!1) else defaultSize k
  case k of
    "integer50"->benchInteger(fromIntegral n)
    "json_escape"->benchJson n
    "merge_sort"->benchMerge n
    "binary_search"->benchBS n
    "prefix_sum"->benchPrefix n
    "matrix_mul"->benchMatrix n
    "bfs"->benchBFS n
    "dijkstra"->benchDij n
    "union_find"->benchUF n
    "mandelbrot"->benchMandel n
    "dynamic_array"->benchArray n
    "linked_list"->benchList n
    "queue_ring"->benchQueue n
    "hash_table"->benchHash n
    "binary_heap"->benchHeap n
    "bst"->benchBST n
    "trie"->benchTrie n
    _->error "unknown kernel"
