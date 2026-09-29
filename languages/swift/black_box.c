#include <stdint.h>
uint64_t bench_black_box_u64(uint64_t x) {
    __asm__ __volatile__("" : "+r"(x) : : "memory");
    return x;
}
