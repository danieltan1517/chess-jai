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

nnue_evaluate_board :: (chess: *Chess) -> int {
  pieces, squares := initialize_piece_list(chess);
  return nnue_evaluate(xx chess.turn, *pieces[0], *squares[0]);
}

nnue_evaluate :: (chess: *ChessGame) -> int {
  pieces, squares := initialize_piece_list(chess);
  a_nnue: [3] *NNUEdata;
  a_nnue[0] = null;
  a_nnue[1] = null;
  a_nnue[2] = null;

  i := 0;
  while i<3 && chess.ply >= i {
    a_nnue[i] = chess.nnue.data + chess.ply - i;
    i += 1;
  }

  return nnue_evaluate_incremental(xx chess.turn, *pieces[0], *squares[0], *a_nnue[0]);
}

initialize_piece_list :: (chess: *Chess) -> [33] s32, [33] s32 {
  pieces : [33] s32;
  squares: [33] s32;
  pieces[0] = xx Piece.W_KING;
  squares[0] = xx bit_scan_forward(chess.w_king);
  pieces[1] = xx Piece.W_KING;
  squares[1] = xx bit_scan_forward(chess.b_king);

  index := 2;
  occupied := chess.occupied & ~(chess.w_king | chess.b_king);
  while occupied {
    sq := cast(s32) bit_scan_forward(occupied);
    piece := cast(s32) chess.pieces[sq];
    pieces[index] = piece;
    squares[index] = sq;
    index += 1;
    occupied &= occupied - 1;
  }

  pieces[index] = 0;
  squares[index] = 0;

  return pieces, squares;
}

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
