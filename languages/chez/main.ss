#!r6rs
(import (rnrs) (chezscheme))

(define rounds 7)
(define mask (- (bitwise-arithmetic-shift-left 1 50) 1))
(define (now-s) (/ (real-time) 1000.0))
(define (median7 v)
  (vector-sort! < v)
  (vector-ref v 3))
(define (emit k units sec rate checksum)
  (printf "RESULT kernel=~a units=~a rounds=7 seconds=~a rate=~a checksum=~a\n"
          k units sec rate checksum))

(define (integer50 n)
  (let loop ([i 0] [x (bitwise-and 88172645463325252 mask)] [s 0])
    (if (= i n) s
        (let* ([x1 (bitwise-xor x (bitwise-arithmetic-shift-right x 7))]
               [x2 (bitwise-xor x1 (bitwise-and (bitwise-arithmetic-shift-left x1 8) mask))]
               [x3 (bitwise-xor x2 (bitwise-arithmetic-shift-right x2 9))]
               [x4 (bitwise-and x3 mask)]
               [s1 (bitwise-and (+ s (bitwise-xor x4 (bitwise-arithmetic-shift-right x4 17))) mask)])
          (loop (+ i 1) x4 s1)))))

(define pattern '#vu8(97 108 112 104 97 34 98 101 116 97 92 103 97 109 109 97 10 9 1 120 121 122 47))
(define hex '#vu8(48 49 50 51 52 53 54 55 56 57 97 98 99 100 101 102))
(define (json-escape input out)
  (let ([n (bytevector-length input)])
    (let loop ([i 0] [j 1])
      (when (= i 0) (bytevector-u8-set! out 0 34))
      (if (= i n)
          (begin (bytevector-u8-set! out j 34) (+ j 1))
          (let ([c (bytevector-u8-ref input i)])
            (cond
              [(= c 34) (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 34)(loop (+ i 1) (+ j 2))]
              [(= c 92) (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 92)(loop (+ i 1) (+ j 2))]
              [(= c 8)  (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 98)(loop (+ i 1) (+ j 2))]
              [(= c 12) (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 102)(loop (+ i 1) (+ j 2))]
              [(= c 10) (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 110)(loop (+ i 1) (+ j 2))]
              [(= c 13) (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 114)(loop (+ i 1) (+ j 2))]
              [(= c 9)  (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 116)(loop (+ i 1) (+ j 2))]
              [(< c 32)
               (bytevector-u8-set! out j 92)(bytevector-u8-set! out (+ j 1) 117)
               (bytevector-u8-set! out (+ j 2) 48)(bytevector-u8-set! out (+ j 3) 48)
               (bytevector-u8-set! out (+ j 4) (bytevector-u8-ref hex (bitwise-arithmetic-shift-right c 4)))
               (bytevector-u8-set! out (+ j 5) (bytevector-u8-ref hex (bitwise-and c 15)))
               (loop (+ i 1) (+ j 6))]
              [else (bytevector-u8-set! out j c)(loop (+ i 1) (+ j 1))]))))))

(define-record-type node (fields l r))
(define (make-tree d)
  (if (= d 0) (make-node #f #f)
      (make-node (make-tree (- d 1)) (make-tree (- d 1)))))
(define (check-tree n)
  (if n (+ 1 (check-tree (node-l n)) (check-tree (node-r n))) 0))
(define (trees-once mx)
  (let ([total (check-tree (make-tree (+ mx 1)))]
        [long (make-tree mx)])
    (do ([d 4 (+ d 2)]) [(> d mx) (+ total (check-tree long))]
      (let* ([iters (bitwise-arithmetic-shift-left 1 (+ (- mx d) 4))]
             [s (let loop ([i 0] [z 0])
                  (if (= i iters) z
                      (loop (+ i 1) (+ z (check-tree (make-tree d))))))])
        (set! total (+ total s))))))

(define (mandelbrot w max-it)
  (let loopy ([y 0] [sum 0])
    (if (= y w) sum
        (let ([ci (+ -1.5 (/ (* 3.0 y) (- w 1.0)))])
          (let loopx ([x 0] [s sum])
            (if (= x w) (loopy (+ y 1) s)
                (let ([cr (+ -2.0 (/ (* 3.0 x) (- w 1.0)))])
                  (let iter ([zr 0.0] [zi 0.0] [it 0])
                    (if (or (= it max-it) (> (+ (* zr zr) (* zi zi)) 4.0))
                        (loopx (+ x 1) (+ s it))
                        (let ([nzr (+ (- (* zr zr) (* zi zi)) cr)])
                          (iter nzr (+ (* 2.0 zr zi) ci) (+ it 1))))))))))))

(define (bench k)
  (cond
    [(string=? k "integer50")
     (let* ([n 200000000] [_ (integer50 (+ 1 (quotient n 20)))] [ts (make-vector rounds)] [checksum 0])
       (do ([r 0 (+ r 1)]) [(= r rounds)]
         (let ([a (now-s)]) (set! checksum (integer50 n)) (vector-set! ts r (- (now-s) a))))
       (let ([m (median7 ts)]) (emit k n m (/ n m 1e6) checksum)))]
    [(string=? k "json_escape")
     (let* ([n 16000000] [input (make-bytevector n)] [out (make-bytevector (+ (* n 6) 2))] [ts (make-vector rounds)] [outn 0])
       (do ([i 0 (+ i 1)]) [(= i n)]
         (bytevector-u8-set! input i (bytevector-u8-ref pattern (mod i 23))))
       (json-escape input out)
       (do ([r 0 (+ r 1)]) [(= r rounds)]
         (let ([a (now-s)]) (set! outn (json-escape input out)) (vector-set! ts r (- (now-s) a))))
       (let loop ([i 0] [checksum outn])
         (if (= i outn)
             (let ([m (median7 ts)]) (emit k n m (/ n m 1e9) checksum))
             (loop (+ i 1) (+ checksum (bytevector-u8-ref out i))))))]
    [(string=? k "binary_trees")
     (let* ([d 16] [_ (trees-once 6)] [ts (make-vector rounds)] [checksum 0])
       (do ([r 0 (+ r 1)]) [(= r rounds)]
         (let ([a (now-s)]) (set! checksum (trees-once d)) (vector-set! ts r (- (now-s) a))))
       (let ([m (median7 ts)]) (emit k d m (/ 1.0 m) checksum)))]
    [(string=? k "mandelbrot")
     (let* ([w 1600] [_ (mandelbrot 128 20)] [ts (make-vector rounds)] [checksum 0])
       (do ([r 0 (+ r 1)]) [(= r rounds)]
         (let ([a (now-s)]) (set! checksum (mandelbrot w 50)) (vector-set! ts r (- (now-s) a))))
       (let ([m (median7 ts)] [pix (* w w)]) (emit k pix m (/ pix m 1e6) checksum)))]
    [else (error 'bench "unknown kernel" k)]))

(let* ([args (command-line-arguments)]
       [k (if (null? args) "integer50" (car args))])
  (bench k))
