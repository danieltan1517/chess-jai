// This is handcrafted bindings for Daniel Shawul's NNUE-Probe Library.
// NNUE-Probe can be used to get an optimized SIMD Matrix Multiplication
// for computer architectures that the current Jai Chess Engine does not
// support with the inline assembly.
// e.g. AVX512, MMX, ARM NEON, etc.
// This library is completely optional, and is not a necessary component
// of the Chess Engine.

nnue_probe :: #library "libnnueprobe";

nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 #foreign nnue_probe;
nnue_evaluate_incremental :: (player: s32, pieces: *s32, squares: *s32, nnue: **NNUEdata) -> s32 #foreign nnue_probe;
nnue_init :: (file_name: *u8) -> bool #foreign nnue_probe;

nnue_startup :: () #expand { // initialization is done at compile time.
  #import "File_Utilities";

  nnue_default :: "resources/nn-04cf2b4ed1da.nnue";
  if !file_exists(nnue_default) {
    print("Error. % does not exist", nnue_default);
    `return;
  }
  nnue_init(nnue_default);
}

DirtyPiece :: struct {
  dirtyNum: s32;
  pc      : [3] s32;
  from    : [3] s32;
  to      : [3] s32;
}

Accumulator :: struct {
  padding: [1088] u8;
  #place padding;
  accumulation: [2][256] s16 #align 64;
  computedAccumulation: s32;
} 

NNUEdata :: struct {
  padding: [1152] u8;
  #place padding;
  accumulator: Accumulator;
  dirtyPiece: DirtyPiece;
} 
