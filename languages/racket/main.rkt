#lang racket/base
(require racket/list racket/unsafe/ops)
(define rounds 7)
(define (now) (/ (current-inexact-milliseconds) 1000.0))
(define (median7 xs) (list-ref (sort xs <) 3))
(define mask (sub1 (arithmetic-shift 1 50)))
(define (integer50 n)
  (let loop ([i 0] [x (bitwise-and 88172645463325252 mask)] [s 0])
    (if (= i n) s
        (let* ([x1 (unsafe-fxxor x (unsafe-fxrshift x 7))]
               [x2 (unsafe-fxxor x1 (unsafe-fxand (unsafe-fxlshift x1 8) mask))]
               [x3 (unsafe-fxxor x2 (unsafe-fxrshift x2 9))]
               [x4 (unsafe-fxand x3 mask)]
               [s1 (unsafe-fxand (unsafe-fx+ s (unsafe-fxxor x4 (unsafe-fxrshift x4 17))) mask)])
          (loop (unsafe-fx+ i 1) x4 s1)))))
(define pattern (bytes 97 108 112 104 97 34 98 101 116 97 92 103 97 109 109 97 10 9 1 120 121 122 47))
(define hex #"0123456789abcdef")
(define (json-escape in out)
  (define j 0)
  (bytes-set! out j 34) (set! j (add1 j))
  (for ([i (in-range (bytes-length in))])
    (define c (bytes-ref in i))
    (cond
      [(= c 34) (bytes-set! out j 92)(bytes-set! out (+ j 1) 34)(set! j (+ j 2))]
      [(= c 92) (bytes-set! out j 92)(bytes-set! out (+ j 1) 92)(set! j (+ j 2))]
      [(= c 8) (bytes-set! out j 92)(bytes-set! out (+ j 1) 98)(set! j (+ j 2))]
      [(= c 12) (bytes-set! out j 92)(bytes-set! out (+ j 1) 102)(set! j (+ j 2))]
      [(= c 10) (bytes-set! out j 92)(bytes-set! out (+ j 1) 110)(set! j (+ j 2))]
      [(= c 13) (bytes-set! out j 92)(bytes-set! out (+ j 1) 114)(set! j (+ j 2))]
      [(= c 9) (bytes-set! out j 92)(bytes-set! out (+ j 1) 116)(set! j (+ j 2))]
      [(< c 32)
       (bytes-set! out j 92)(bytes-set! out (+ j 1) 117)(bytes-set! out (+ j 2) 48)(bytes-set! out (+ j 3) 48)
       (bytes-set! out (+ j 4) (bytes-ref hex (arithmetic-shift c -4)))
       (bytes-set! out (+ j 5) (bytes-ref hex (bitwise-and c 15)))(set! j (+ j 6))]
      [else (bytes-set! out j c)(set! j (add1 j))]))
  (bytes-set! out j 34)
  (add1 j))
(struct node (l r) #:transparent)
(define (make-tree d) (if (zero? d) (node #f #f) (node (make-tree (sub1 d)) (make-tree (sub1 d)))))
(define (check-tree n) (if n (+ 1 (check-tree (node-l n)) (check-tree (node-r n))) 0))
(define (trees-once mx)
  (define total (check-tree (make-tree (add1 mx))))
  (define long (make-tree mx))
  (for ([d (in-range 4 (add1 mx) 2)])
    (define iters (arithmetic-shift 1 (+ (- mx d) 4)))
    (define s 0)
    (for ([i (in-range iters)]) (set! s (+ s (check-tree (make-tree d)))))
    (set! total (+ total s)))
  (+ total (check-tree long)))
(define (mandelbrot w max-it)
  (define total 0)
  (for ([y (in-range w)])
    (define ci (+ -1.5 (/ (* 3.0 y) (- w 1))))
    (for ([x (in-range w)])
      (define cr (+ -2.0 (/ (* 3.0 x) (- w 1))))
      (let loop ([zr 0.0][zi 0.0][it 0])
        (cond [(>= it max-it) (set! total (+ total it))]
              [else
               (define zr2 (* zr zr))(define zi2 (* zi zi))
               (if (> (+ zr2 zi2) 4.0)
                   (set! total (+ total it))
                   (loop (+ (- zr2 zi2) cr) (+ (* 2.0 zr zi) ci) (add1 it)))]))))
  total)
(define (emit k units sec rate checksum)
  (printf "RESULT kernel=~a units=~a rounds=7 seconds=~a rate=~a checksum=~a\n"
          k units (~r sec #:precision '(= 9)) (~r rate #:precision '(= 6)) checksum))
(require racket/format)
(define (bench k)
  (cond
    [(equal? k "integer50")
     (define n 200000000)(integer50 (+ 1 (quotient n 20)))
     (define checksum 0)
     (define ts (for/list ([r (in-range rounds)]) (define a (now))(set! checksum (integer50 n))(- (now) a)))
     (define m (median7 ts))(emit k n m (/ n m 1e6) checksum)]
    [(equal? k "json_escape")
     (define n 16000000)(define in (make-bytes n))(define out (make-bytes (+ (* n 6) 2)))
     (for ([i (in-range n)]) (bytes-set! in i (bytes-ref pattern (remainder i 23))))
     (json-escape in out)(define outn 0)
     (define ts (for/list ([r (in-range rounds)]) (define a (now))(set! outn (json-escape in out))(- (now) a)))
     (define checksum (+ outn (for/sum ([i (in-range outn)]) (bytes-ref out i))))
     (define m (median7 ts))(emit k n m (/ n m 1e9) checksum)]
    [(equal? k "binary_trees")
     (define d 16)(trees-once 6)(define checksum 0)
     (define ts (for/list ([r (in-range rounds)]) (define a (now))(set! checksum (trees-once d))(- (now) a)))
     (define m (median7 ts))(emit k d m (/ 1.0 m) checksum)]
    [(equal? k "mandelbrot")
     (define w 1600)(mandelbrot 128 20)(define checksum 0)
     (define ts (for/list ([r (in-range rounds)]) (define a (now))(set! checksum (mandelbrot w 50))(- (now) a)))
     (define m (median7 ts))(define pix (* w w))(emit k pix m (/ pix m 1e6) checksum)]
    [else (error 'bench "unknown kernel")]))
(module+ main (define args (current-command-line-arguments))(bench (if (zero? (vector-length args)) "integer50" (vector-ref args 0))))
