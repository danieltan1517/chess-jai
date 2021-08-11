#include <stdint.h>
uint64_t bit_reverse64(uint64_t x);

uint64_t bit_reverse64(uint64_t x) {
  return __builtin_bitreverse64(x);
}

