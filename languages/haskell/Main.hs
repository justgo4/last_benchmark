{-# LANGUAGE BangPatterns #-}
import Data.Bits
import Data.Word
import Data.List (sort)
import qualified Data.ByteString as B
import qualified Data.ByteString.Builder as BB
import qualified Data.ByteString.Lazy as BL
import GHC.Clock (getMonotonicTimeNSec)
import System.Environment (getArgs)
import Text.Printf
import Control.Monad (replicateM)
import Control.Exception (evaluate)
import Data.IORef (newIORef, readIORef)

now :: IO Double
now = do n <- getMonotonicTimeNSec; pure (fromIntegral n * 1e-9)
median :: [Double] -> Double
median xs = sort xs !! 3
emit :: String -> Word64 -> Double -> Double -> Word64 -> IO ()
emit k u s rate c = printf "RESULT kernel=%s units=%d rounds=7 seconds=%.9f rate=%.6f checksum=%d\n" k u s rate c

integer50 :: Word64 -> Word64
integer50 n = go n (88172645463325252 .&. mask) 0
  where
    mask = (1 `shiftL` 50) - 1
    go 0 !_ !s = s
    go !i !x !s =
      let !x1 = x `xor` (x `shiftR` 7)
          !x2 = x1 `xor` ((x1 `shiftL` 8) .&. mask)
          !x3 = x2 `xor` (x2 `shiftR` 9)
          !x4 = x3 .&. mask
          !s1 = (s + (x4 `xor` (x4 `shiftR` 17))) .&. mask
      in go (i-1) x4 s1

benchInteger :: Word64 -> IO ()
benchInteger n = do
  ref <- newIORef n
  warmN <- readIORef ref
  _ <- evaluate (integer50 (warmN `div` 20 + 1))
  pairs <- replicateM 7 $ do
    n' <- readIORef ref
    a <- now
    c <- evaluate (integer50 n')
    b <- now
    pure (b-a,c)
  let m=median (map fst pairs); c=snd (last pairs)
  emit "integer50" n m (fromIntegral n/m/1e6) c

patternBytes :: [Word8]
patternBytes=[97,108,112,104,97,34,98,101,116,97,92,103,97,109,109,97,10,9,1,120,121,122,47]
esc :: Word8 -> BB.Builder
esc c = case c of
  34 -> BB.word8 92 <> BB.word8 34
  92 -> BB.word8 92 <> BB.word8 92
  8  -> BB.word8 92 <> BB.word8 98
  12 -> BB.word8 92 <> BB.word8 102
  10 -> BB.word8 92 <> BB.word8 110
  13 -> BB.word8 92 <> BB.word8 114
  9  -> BB.word8 92 <> BB.word8 116
  _ | c < 32 -> let hex="0123456789abcdef"
                    hi=fromIntegral (c `shiftR` 4)
                    lo=fromIntegral (c .&. 15)
                in BB.word8 92<>BB.word8 117<>BB.word8 48<>BB.word8 48<>BB.word8 (fromIntegral (fromEnum (hex!!hi)))<>BB.word8 (fromIntegral (fromEnum (hex!!lo)))
    | otherwise -> BB.word8 c
jsonEscape :: B.ByteString -> B.ByteString
jsonEscape bs = BL.toStrict $ BB.toLazyByteString $ BB.word8 34 <> B.foldl' (\acc c -> acc <> esc c) mempty bs <> BB.word8 34

benchJson :: Int -> IO ()
benchJson n = do
  let input=B.pack (take n (cycle patternBytes))
  ref <- newIORef input
  warmInput <- readIORef ref
  warm <- evaluate (jsonEscape warmInput)
  B.length warm `seq` pure ()
  pairs <- replicateM 7 $ do
    input' <- readIORef ref
    a <- now
    out <- evaluate (jsonEscape input')
    B.length out `seq` pure ()
    b <- now
    let !c = fromIntegral (B.length out) + B.foldl' (\z x -> z + fromIntegral x) 0 out
    pure (b-a,c)
  let m=median(map fst pairs); c=snd(last pairs)
  emit "json_escape" (fromIntegral n) m (fromIntegral n/m/1e9) c

data Node = Leaf | Node !Node !Node
makeTree :: Int -> Node
makeTree 0 = Leaf
makeTree d = Node (makeTree (d-1)) (makeTree (d-1))
checkTree :: Node -> Word64
checkTree Leaf = 1
checkTree (Node l r)=1+checkTree l+checkTree r
treesOnce :: Int -> Word64
treesOnce mx =
  let stretch=makeTree(mx+1)
      !base=checkTree stretch
      longl=makeTree mx
      loop d !tot | d>mx = tot
                  | otherwise =
                      let iters=1 `shiftL` (mx-d+4)
                          !s=sum [checkTree(makeTree d) | _<-[1..iters::Int]]
                      in loop (d+2) (tot+s)
  in loop 4 base + checkTree longl
benchTrees :: Int -> IO ()
benchTrees depth = do
  ref <- newIORef depth
  warmDepth <- readIORef ref
  _ <- evaluate (treesOnce (min warmDepth 6))
  pairs <- replicateM 7 $ do
    depth' <- readIORef ref
    a <- now
    c <- evaluate (treesOnce depth')
    b <- now
    pure (b-a,c)
  let m=median(map fst pairs);c=snd(last pairs)
  emit "binary_trees" (fromIntegral depth) m (1/m) c

mandelbrot :: Int -> Int -> Word64
mandelbrot w maxIter = goY 0 0
  where
    goY y !s | y>=w=s
             | otherwise = let ci=(-1.5)+3.0*fromIntegral y/fromIntegral(w-1)
                           in goY (y+1) (goX ci 0 s)
    goX _ x !s | x>=w=s
    goX ci x !s = let cr=(-2.0)+3.0*fromIntegral x/fromIntegral(w-1)
                      !it=iter cr ci 0 0 0
                  in goX ci (x+1) (s+fromIntegral it)
    iter cr ci !zr !zi !it
      | it>=maxIter=it
      | zr*zr+zi*zi>4.0=it
      | otherwise=let nzr=zr*zr-zi*zi+cr; nzi=2*zr*zi+ci in iter cr ci nzr nzi (it+1)
benchMandel :: Int -> IO ()
benchMandel w = do
  ref <- newIORef w
  warmW <- readIORef ref
  _ <- evaluate (mandelbrot (min warmW 128) 20)
  pairs <- replicateM 7 $ do
    w' <- readIORef ref
    a <- now
    c <- evaluate (mandelbrot w' 50)
    b <- now
    pure (b-a,c)
  let m=median(map fst pairs);c=snd(last pairs);pix=fromIntegral(w*w)::Word64
  emit "mandelbrot" pix m (fromIntegral pix/m/1e6) c

main :: IO ()
main = do
  a <- getArgs
  let k = if null a then "integer50" else head a
      size = if length a > 1 then read (a !! 1) else
        case k of
          "integer50" -> 200000000
          "json_escape" -> 16000000
          "binary_trees" -> 16
          "mandelbrot" -> 1600
          _ -> 0
  case k of
    "integer50" -> benchInteger (fromIntegral size)
    "json_escape" -> benchJson size
    "binary_trees" -> benchTrees size
    "mandelbrot" -> benchMandel size
    _ -> error "unknown kernel"
