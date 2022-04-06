#import "Basic";
#import "File";

bit_scan_forward :: (input: u64)->int #expand {
  result := -1;
  #asm { bsf.q result, input; }
  return result;
}

main :: () {
  print("code\n");
  nnue_init("resources/nn-04cf2b4ed1da.nnue");
  print("actual\n");
  __nnue_init("resources/nn-04cf2b4ed1da.nnue");
  chess: Chess;
  chess_startpos(*chess);
  ret1 := nnue_evaluate(*chess, true);
  ret2 := nnue_evaluate(*chess, false);
  print("ret1=% ret2=%\n", ret1, ret2);

using Bitboard :: enum_flags u64 {
  a1; b1; c1; d1; e1; f1; g1; h1;
  a2; b2; c2; d2; e2; f2; g2; h2;
  a3; b3; c3; d3; e3; f3; g3; h3;
  a4; b4; c4; d4; e4; f4; g4; h4;
  a5; b5; c5; d5; e5; f5; g5; h5;
  a6; b6; c6; d6; e6; f6; g6; h6;
  a7; b7; c7; d7; e7; f7; g7; h7;
  a8; b8; c8; d8; e8; f8; g8; h8;

  // files
  file_a :: a1 | a2 | a3 | a4 | a5 | a6 | a7 | a8;
  file_b :: b1 | b2 | b3 | b4 | b5 | b6 | b7 | b8;
  file_c :: c1 | c2 | c3 | c4 | c5 | c6 | c7 | c8;
  file_d :: d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8;
  file_e :: e1 | e2 | e3 | e4 | e5 | e6 | e7 | e8;
  file_f :: f1 | f2 | f3 | f4 | f5 | f6 | f7 | f8;
  file_g :: g1 | g2 | g3 | g4 | g5 | g6 | g7 | g8;
  file_h :: h1 | h2 | h3 | h4 | h5 | h6 | h7 | h8;

  // ranks
  rank_1 :: a1 | b1 | c1 | d1 | e1 | f1 | g1 | h1;
  rank_2 :: a2 | b2 | c2 | d2 | e2 | f2 | g2 | h2;
  rank_3 :: a3 | b3 | c3 | d3 | e3 | f3 | g3 | h3;
  rank_4 :: a4 | b4 | c4 | d4 | e4 | f4 | g4 | h4;
  rank_5 :: a5 | b5 | c5 | d5 | e5 | f5 | g5 | h5;
  rank_6 :: a6 | b6 | c6 | d6 | e6 | f6 | g6 | h6;
  rank_7 :: a7 | b7 | c7 | d7 | e7 | f7 | g7 | h7;
  rank_8 :: a8 | b8 | c8 | d8 | e8 | f8 | g8 | h8;

  king_side :: file_e | file_f | file_g | file_h;
  queen_side :: ~king_side;
}

Turn :: enum s32 { WHITE :: 0; BLACK :: 1; };

Castling :: enum_flags u8 {
  W_KS;
  W_QS;
  B_KS;
  B_QS;
  All :: W_KS|W_QS|B_KS|B_QS;
}

Piece :: enum u8 {
  NONE     :: 0;
  W_KING   :: 1;
  W_QUEEN  :: 2;
  W_ROOK   :: 3;
  W_BISHOP :: 4;
  W_KNIGHT :: 5;
  W_PAWN   :: 6;

  B_KING   :: 7;
  B_QUEEN  :: 8;
  B_ROOK   :: 9;
  B_BISHOP :: 10;
  B_KNIGHT :: 11;
  B_PAWN   :: 12;
}

chess_startpos :: (chess: *Chess) {
  memset(chess, 0, size_of(Chess));

  chess.occupied = xx (rank_1|rank_2|rank_7|rank_8);
  add_piece(Piece.W_KING, xx e1);
  add_piece(Piece.W_QUEEN, xx d1);
  add_piece(Piece.W_ROOK, xx a1|h1);
  add_piece(Piece.W_BISHOP, xx c1|f1);
  add_piece(Piece.W_KNIGHT, xx b1|g1);
  add_piece(Piece.W_PAWN, xx rank_2);

  add_piece(Piece.B_KING, xx e8);
  add_piece(Piece.B_QUEEN, xx d8);
  add_piece(Piece.B_ROOK, xx a8|h8);
  add_piece(Piece.B_BISHOP, xx c8|f8);
  add_piece(Piece.B_KNIGHT, xx b8|g8);
  add_piece(Piece.B_PAWN, xx rank_7);
  chess.en_passant = 0;
  chess.castling = Castling.All;
  chess.turn = Turn.WHITE;
  chess.hash = 0; 

  add_piece :: (p: Piece, bitboard: u64) #expand {
    chess.bitboard[cast(int) p] = bitboard;
    bb := bitboard;
    while bb {
      idx := bit_scan_forward(bb); 
      chess.pieces[idx] = p;
      bb = popbit(bb);
    }
  }
}

Chess :: struct {
  pieces: [64] Piece;

  occupied: u64;
  union {
    struct {
      none:     u64;
      w_king:   u64;
      w_queen:  u64;
      w_rook:   u64;
      w_bishop: u64;
      w_knight: u64;
      w_pawn:   u64; 
   
      b_king :  u64;
      b_queen:  u64;
      b_rook:   u64;
      b_bishop: u64;
      b_knight: u64;
      b_pawn:   u64; 
    }
    
    bitboard: [13] u64;
  }

  en_passant: u64;
  castling: Castling;
  turn: Turn;
  hash: u64;
}

nnue_evaluate :: (chess: *Chess, TF: bool = true) -> int {
  pieces : [40] s32;
  squares: [40] s32;
  pieces[0] = xx Piece.W_KING;
  squares[0] = xx bit_scan_forward(chess.w_king);
  pieces[1] = xx Piece.W_KING;
  squares[1] = xx bit_scan_forward(chess.b_king);
  index := 2;
  piece := chess.occupied & ~(chess.w_king|chess.b_king);
  for i: 0..63 {
    bitboard := cast(u64) (1<<i);
    if bitboard & piece {
      pieces[index] = xx chess.pieces[i];
      squares[index] = xx i;
      index += 1;
    }
  }
  pieces[index] = 0;
  squares[index] = 0;
  if TF == true
    return __nnue_evaluate(xx chess.turn, pieces.data, squares.data);
  else 
    return nnue_evaluate(xx chess.turn, pieces.data, squares.data); 
}

popbit :: (a: u64) -> u64 #expand {
  #asm { blsr.q a, a; }
  return a; 
}


}

nnue_init :: (file_name: string) -> bool {
  file, success :=  file_open(file_name);
  if !success {
    print("error. % cannot be loaded.\n", file_name);
    return false;
  }
  length :=  file_length(file);
  buffer := NewArray(length, u8);
  defer {
    array_free(buffer);
    file_close(*file);
  }

  if !file_read(file, buffer.data, length) {
    print("Failed to read from file %\n", file_name);
    return false;
  }

  // verify that the file is correct.
  if !verify_file(buffer) then
    return false;

  init_weights(buffer);
  return true;

  verify_file :: (buffer: [] u8) -> bool {
    if buffer.count != 21022697 then
      return false;
    d := buffer.data;
    if <<cast(*u32)d != NnueVersion then
      return false;
    if <<cast(*u32)(d+4) != 0x3e5aa6ee then
      return false;
    if <<cast(*u32)(d+8) != 177 then
      return false;
    if <<cast(*u32)(d + TransformerStart) != 0x5d69d7b8 then
      return false;
    if <<cast(*u32)(d + NetworkStart) != 0x63337156 then
      return false;
    return true;
  }

  init_weights :: (buffer: [] u8) {
    data := cast(*s8) (buffer.data + TransformerStart + 4);

    // Read transformer
    for i: 0..(kHalfDimensions-1) {
      ft_biases[i] = <<cast, no_check (*s16)(data);
      data += 2;
    }

    for i: 0..(kHalfDimensions*FtInDims)-1 {
      ft_weights[i] = <<cast(*s16)(data);
      data += 2;
    }

    // Read network
    data += 4;
    for i: 0..31 {
      hidden1_biases[i] = <<cast, no_check(*s32)(data);
      data += 4;
    }

    data = read_hidden_weights(hidden1_weights, 512, data);

    for i: 0..31 {
      hidden2_biases[i] = <<cast, no_check(*s32)(data);
      data += 4;
    }

    data = read_hidden_weights(hidden2_weights, 32, data);
    
    for i: 0..0 {
      output_biases[i] = <<cast(*s32)(data);
      data += 4;
    }

    read_output_weights(output_weights, data);

    permute_biases(hidden1_biases);
    permute_biases(hidden2_biases);

  }

  read_hidden_weights :: (weight: []s8, dims: int, d: *s8) -> *s8 {
    i := 0;
    for r: 0..31 {
      for c: 0..dims-1 {
        index := weight_index(r, c, dims);
        weight[index] = <<d;
        i += 1;
        d += 1;
      }
    }

    return d;

    weight_index :: (r: int, c: int, dims: int) -> int {
      // TODO: what if there's an ifdef?
      if dims > 32 {
        b := c & 0x18;
        b = (b << 1) | (b >> 1);
        c = (c & ~0x18) | (b & 0x18);
      }
      return c * 32 + r;
    }
  }

  read_output_weights :: (weight: []s8, data: *s8) {
    for i: 0..31 {
      weight[i] = << data;
      data += 1;
    }
  }

  permute_biases :: (biases: [] s32) #expand {
    rdi := biases.data;
    // translated from godbolt's clang -O3 assembly language output.
    #asm {
      movaps.x xmm0: vec, [rdi+16]; 
      movaps.x xmm1: vec, [rdi+32];
      movaps.x xmm2: vec, [rdi+48];
      movaps.x xmm3: vec, [rdi+64];
      movaps.x xmm4: vec, [rdi+80];
      movaps.x xmm5: vec, [rdi+96];

      movaps.x [rdi+16], xmm3; 
      movaps.x [rdi+32], xmm0;
      movaps.x [rdi+48], xmm4;
      movaps.x [rdi+64], xmm1;
      movaps.x [rdi+80], xmm5;
      movaps.x [rdi+96], xmm2;
    }
  }
}

// features:
ft_biases:  [kHalfDimensions] s16 #align 64;
ft_weights: [kHalfDimensions*FtInDims] s16 #align 64;

// weights:
hidden1_weights: [64*512] s8 #align 64;
hidden2_weights: [64*32]  s8 #align 64;
output_weights:  [1*32]   s8 #align 64;

// biases:
hidden1_biases: [32] s32 #align 64;
hidden2_biases: [32] s32 #align 64;
output_biases : [1]  s32 #align 64;


kHalfDimensions :: 256;
FtInDims :: 64*PS_END; // 63 * 641
FtOutDims :: kHalfDimensions*2;
NnueVersion : u32 : 0x7AF32F16;
TransformerStart :: 3*4 + 177;
NetworkStart :: TransformerStart+4 + 2*256 + 2*256*64*641;

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

NetData :: struct {
  input: [FtOutDims] s8;
  hidden1_out: [32] s8;

  // if using SSE2|MMX w/o AVX2, then 's16'
  hidden2_out: [32] s8; 
}

Position :: struct {
  player: s32;
  pieces: *s32;
  squares: *s32;
  nnue: [3] *NNUEdata;
}

IndexList :: struct {
  size: s32;
  values: [30] u32;
} 

nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 {
  nnue: NNUEdata;
  nnue.accumulator.computedAccumulation = 0;
  pos: Position;
  pos.nnue[0] = *nnue;
  pos.nnue[1] = null;
  pos.nnue[2] = null;
  pos.player  = player;
  pos.pieces = pieces;
  pos.squares = squares;
  return nnue_evaluate_pos(*pos);
}

nnue_evaluate_pos :: (pos: *Position) -> s32 {
  //typedef uint32_t mask_t;
  out_value: s32;

  // TODO: maybe these need to be align 8? like the nnue-probe library?
  input_mask:   [FtOutDims / (8 * size_of(u32)) ] u32 #align 8;
  hidden1_mask: [8 / size_of(u32)] u32 #align 8;

  buf: NetData;
  print("transform\n");
  transform(pos, buf.input, input_mask.data);
  print("buf.input: %\n", buf.input);
  print("input: %\n", input_mask);

  affine_txfm(buf.input.data, buf.hidden1_out.data, FtOutDims, 32,
              hidden1_biases.data, hidden1_weights.data, input_mask.data, hidden1_mask.data, true);
  affine_txfm(buf.hidden1_out.data, buf.hidden2_out.data, 32, 32,
              hidden2_biases.data, hidden2_weights.data, hidden1_mask.data, null, false);

  out_value = affine_propagate(buf.hidden2_out.data, output_biases.data, output_weights.data);

  return out_value / FV_SCALE;

  FV_SCALE :: 16;
}


TILE_HEIGHT :: (NUM_REGS * SIMD_WIDTH / 16);
NUM_REGS :: 8; 
SIMD_WIDTH :: 256;

update_accumulator :: (pos: *Position) -> bool {
  accumulator := *pos.nnue[0].accumulator;
  if accumulator.computedAccumulation then
    return true;
  prev_acc: *Accumulator;
  if check_acc(*prev_acc, pos, 1) && check_acc(*prev_acc, pos, 2) then
    return false;

  removed_indices: [2] IndexList;
  added_indices:  [2] IndexList;
  reset: [2] bool;

  removed_indices[0].size = 0;
  removed_indices[1].size = 0;
  added_indices[0].size = 0;
  added_indices[1].size = 0;

  append_changed_indices(pos, removed_indices, added_indices, *reset);

  ITERS :: kHalfDimensions / TILE_HEIGHT;
  for i: 0..ITERS-1 {
    for c: 0..1 {
      acc: [NUM_REGS * (256/8)] u8;

      if reset[c] {
        ft_b_tile := cast(*void) *ft_biases[i*TILE_HEIGHT];
        acc_ptr   := cast(*void) acc.data;
        for j: 0..NUM_REGS-1 {
          // hopefully this is correct.
          //acc[j] = ft_b_tile[j]
          #asm AVX {
            xmm0: vec;
            movups.y xmm0, [ft_b_tile];
            movups.y [acc_ptr], xmm0;
            add.q ft_b_tile, 32;
            add.q acc_ptr, 32;
          }
        }
      } else {
        prevAccTile := cast(*void) *prev_acc.accumulation[c][i*TILE_HEIGHT];
        acc_ptr     := cast(*void) acc.data;
        for j : 0..NUM_REGS-1 {
          //acc[j] = prevAccTile[j];
          #asm AVX {
            xmm0: vec;
            movups.y xmm0, [prevAccTile];
            movups.y [acc_ptr], xmm0;
            add.q prevAccTile, 32;
            add.q acc_ptr, 32;
          }
        }
        for k: 0..removed_indices[c].size-1 {
          index := removed_indices[c].values[k];
          offset := kHalfDimensions * index + i * TILE_HEIGHT;
          column := cast(*void) *ft_weights[offset];
          acc_ptr := cast(*void) acc.data;
          for j: 0..NUM_REGS-1 {
            //acc[j] = vec_sub_16(acc[j], column[j]);
            #asm AVX {
              movups.x v1:, [acc_ptr];
              movups.x v2:, [column];
              psubd.x  v1, v1, v2;
              movups.x [acc_ptr], v1;
              add.q acc_ptr, 32;
              add.q column, 32;
            }
          }
        }
      }

      // Difference calculation for the activated features
      for k: 0..added_indices[c].size-1 {
        index := added_indices[c].values[k];
        offset := kHalfDimensions*index + i*TILE_HEIGHT;
        column := cast(*void) *ft_weights[offset];
        acc_ptr := cast(*void) acc.data;
        for j: 0..NUM_REGS-1 {
          //acc[j] = vec_add_16(acc[j], column[j]);
          #asm AVX {
            movups.x v1:, [acc_ptr];
            movups.x v2:, [column];
            psubd.x  v1, v1, v2;
            movups.x [acc_ptr], v1;
            add.q acc_ptr, 32;
            add.q column, 32;
          }
        }
      }
      
      accTile := cast(*void) *accumulator.accumulation[c][i*TILE_HEIGHT];
      acc_ptr := cast(*void) acc.data;
      for j: 0..NUM_REGS-1 {
        #asm AVX {
          xmm0: vec;
          movups.y xmm0, [acc_ptr];
          movups.y [accTile], xmm0;
          add.q accTile, 32;
          add.q acc_ptr, 32;
        }
      }
    }
  }

  return true;

  check_acc:: (prev_acc: **Accumulator, pos: *Position, i: int) -> bool #expand {
    if pos.nnue[1] == null then
      return true;
    <<prev_acc = *pos.nnue[i].accumulator;
    return ! (<<prev_acc).computedAccumulation;
  }

}

refresh_accumulator :: (pos: *Position) {
  accumulator := *pos.nnue[0].accumulator;
  activeIndices: [2] IndexList;
  activeIndices[0].size = 0;
  activeIndices[1].size = 0;
  append_active_indices(pos, *activeIndices);

  ITERS :: kHalfDimensions / TILE_HEIGHT;

  for c: 0..1 {
    /*

    for (unsigned i = 0; i < kHalfDimensions / TILE_HEIGHT; i++) {
      vec16_t *ft_biases_tile = (vec16_t *)&ft_biases[i * TILE_HEIGHT];
      vec16_t *accTile = (vec16_t *)&accumulator->accumulation[c][i * TILE_HEIGHT];
      vec16_t acc[NUM_REGS];

      for (unsigned j = 0; j < NUM_REGS; j++)
        acc[j] = ft_biases_tile[j];

      for (size_t k = 0; k < activeIndices[c].size; k++) {
        unsigned index = activeIndices[c].values[k];
        unsigned offset = kHalfDimensions * index + i * TILE_HEIGHT;
        vec16_t *column = (vec16_t *)&ft_weights[offset];

        for (unsigned j = 0; j < NUM_REGS; j++)
          acc[j] = vec_add_16(acc[j], column[j]);
      }

      for (unsigned j = 0; j < NUM_REGS; j++)
        accTile[j] = acc[j];
    }*/

    for i: 0..ITERS-1 {
      ft_biases_tile := cast(*void) *ft_biases[i*TILE_HEIGHT];
      acc: [NUM_REGS * (256/8)] u8;

      acc_ptr := acc.data;
      for j: 0..NUM_REGS-1 {
        // acc[j] = ft_biases_tile[j]
        #asm AVX {
          xmm0: vec;
          movups.y xmm0, [ft_biases_tile];
          movups.y [acc_ptr], xmm0;
          add.q acc_ptr, 32;
          add.q ft_biases_tile, 32;
        }
      }

      for k: 0..activeIndices[c].size-1 {
        // TODO: do not know where to put acc ptr.
        index := activeIndices[c].values[k];
        offset := kHalfDimensions * index + i * TILE_HEIGHT;
        column := cast(*void) *ft_weights[offset];
        acc_ptr := cast(*void) acc.data;
        for j: 0..NUM_REGS-1 {
          #asm AVX {
            movups.x v1:, [acc_ptr];
            movups.x v2:, [column];
            paddd.x  v1, v1, v2;
            movups.x [acc_ptr], v1;
            add.q column, 32;
            add.q acc_ptr, 32;
          }
        }
      }

      accTile := cast(*void) *accumulator.accumulation[c][i*TILE_HEIGHT];
      acc_ptr = cast(*void) acc.data;
      for j: 0..NUM_REGS-1 {
        #asm AVX {
          xmm0: vec;
          movups.y xmm0, [acc_ptr];
          movups.y [accTile], xmm0;
          add.q acc_ptr, 32;
          add.q accTile, 32;
        }
      }
    }
  }

  accumulator.computedAccumulation = 1;
  print("accumulator.accumulation: %\n", accumulator.accumulation);
}


append_active_indices :: (pos: *Position, active: *[2] IndexList)
{
  for c: 0..1 {
    half_kp_append_active_indices(pos, xx c, *(<<active)[c]);
  }
}

append_changed_indices :: (pos: *Position, removed: [2] IndexList, added: [2] IndexList, reset: *[2] bool) {
  dp := *pos.nnue[0].dirtyPiece;
  if pos.nnue[1].accumulator.computedAccumulation then {
    for c: 0..1 {
      (<<reset)[c] = dp.pc[0] == KING(c);
      if reset[c] then {
        half_kp_append_active_indices(pos, xx c, *added[c]);
      } else {
        half_kp_append_changed_indices(pos, xx c, dp, *removed[c], *added[c]);
      }
    }
  } else {
    dp2 := *pos.nnue[1].dirtyPiece;
    for c: 0..1 {
      (<<reset)[c] = dp.pc[0] == KING(c) || dp2.pc[0] == KING(c);
      if reset[c] then {
        half_kp_append_active_indices(pos, xx c, *added[c]);
      } else {
        half_kp_append_changed_indices(pos, xx c, dp, *removed[c], *added[c]);
        half_kp_append_changed_indices(pos, xx c, dp2, *removed[c], *added[c]);
      }
    }
  }

  KING :: (c: int) -> s32 #expand {
    return ifx c != 0 then bking else wking;

    wking : s32 : 1;
    bking : s32 : 7;
  }

  half_kp_append_changed_indices :: (pos: *Position, c: s32, dp: *DirtyPiece, removed: *IndexList, added: *IndexList) {
    ksq := pos.squares[c];
    ksq = orient(c, ksq);
    for i: 0..dp.dirtyNum-1 {
      pc := dp.pc[i];
      if IS_KING(pc) continue;
      if dp.from[i] != 64 then {
        removed.values[removed.size] = xx make_index(c, dp.from[i], pc, ksq);
        removed.size += 1;
      }

      if dp.to[i] != 64 then {
        added.values[added.size] = xx make_index(c, dp.to[i], pc, ksq);
        added.size += 1;
      }
    }

    IS_KING :: (p: s32) -> bool #expand {
      return p == wking || p == bking;
    }

    wking : s32 : 1;
    bking : s32 : 7;
  }
}

half_kp_append_active_indices :: (pos: *Position, c: s32, active: *IndexList) {
  ksq := pos.squares[c];
  ksq = orient(c, ksq);
  i := 2;
  while pos.pieces[i] {
    sq := pos.squares[i];
    pc := pos.pieces[i];
    active.values[active.size] = xx make_index(c, sq, pc, ksq);
    active.size += 1;
    i+=1;
  }
}


make_index :: (c: s32, s: s32, pc: s32, ksq: s32) -> s32 #expand {
  return orient(c, s) + PieceToIndex[c][pc] + PS_END * ksq;
}

orient :: (c: s32, s: s32) -> s32 #expand {
  if c == 0
    return s ^ 0x00;
  else
    return s ^ 0x3f;
}


PS_W_PAWN   ::  1;
PS_B_PAWN   ::  1*64 + 1;
PS_W_KNIGHT ::  2*64 + 1;
PS_B_KNIGHT ::  3*64 + 1;
PS_W_BISHOP ::  4*64 + 1;
PS_B_BISHOP ::  5*64 + 1;
PS_W_ROOK   ::  6*64 + 1;
PS_B_ROOK   ::  7*64 + 1;
PS_W_QUEEN  ::  8*64 + 1;
PS_B_QUEEN  ::  9*64 + 1;
PS_END      :: 10*64 + 1;

PieceToIndex: [2][14] s32 = .[ 
  s32.[0, 0, PS_W_QUEEN, PS_W_ROOK, PS_W_BISHOP, PS_W_KNIGHT, PS_W_PAWN,
       0, PS_B_QUEEN, PS_B_ROOK, PS_B_BISHOP, PS_B_KNIGHT, PS_B_PAWN, 0],
  s32.[ 0, 0, PS_B_QUEEN, PS_B_ROOK, PS_B_BISHOP, PS_B_KNIGHT, PS_B_PAWN,
       0, PS_W_QUEEN, PS_W_ROOK, PS_W_BISHOP, PS_W_KNIGHT, PS_W_PAWN, 0]
];

transform :: (pos: *Position, output: [] s8, out_mask: *u32) {
  if (!update_accumulator(pos))
    refresh_accumulator(pos);
  print("wukong transform!\n");
  accumulation := *pos.nnue[0].accumulator.accumulation;
  perspectives: [2] int;
  perspectives[0] = pos.player;
  perspectives[1] = pos.player^1;

  for p: 0..1 {
    offset := kHalfDimensions * p;
    numChunks := (16*kHalfDimensions) / SIMD_WIDTH;
    out := cast(*void) *output[offset];
    
    for i: 0..numChunks/2-1 {
      s0 := cast(*s8)*((<<accumulation)[perspectives[p]]) + 32*(i*2);
      s1 := cast(*s8)*((<<accumulation)[perspectives[p]]) + 32*(i*2 + 1);
      //print("%\n", s0-accumulation.data);
      //print("%\n", s1-accumulation.data);
      // TODO: I don't know if this is correct. I'm assuming it is
      // then come back later to fix it...
      // s0, s1 are fine. just need to figure out the correct assembly...
      #asm AVX, AVX2 {
        movups.y xmm0:, [s0];
        movups.y xmm1:, [s1];
        packsswb.y xmm2:, xmm0, xmm1;
        movups.y [out], xmm2;

        pxor.y xmm3:, xmm3, xmm3; // xmm3 = 0
        pcmpgtb.y xmm4:, xmm2, xmm3; // vec_mask_pos(out, 0)
        pmovmskb reg:, xmm4;
        mov.d [out_mask], reg;
        add.q out, 32;
        add.q out_mask, 4;
      }
    }
  }
}

affine_txfm :: (input: *s8, output: *void, inDims: u32, outDims: u32, biases: *s32, weights: *s8, in_mask: *u32, out_mask: *u32, pack8_and_calc_mask: bool) {

  assert(outDims == 32);

  #asm AVX, AVX2 {
     pxor.y   kZero:, kZero, kZero; // kZero = 0
     movups.y out0:, [biases];
     movups.y out1:, [biases + 32];
     movups.y out2:, [biases + 64];
     movups.y out3:, [biases + 96];
  }
  v: u64;
  idx : s32 = 0;

  v = << (cast(*u64)in_mask);
  offset := 0;
  while offset < inDims {
    if !next_idx(*idx, *offset, *v, in_mask, inDims)
      break;
    simd_index := idx * 32;
    #asm AVX, AVX2 {
      //first = ((__m256i *)weights)[idx];
      movups.y first:, [weights + simd_index];
      pxor.y second:, second, second;
    }
    factor: u16 = xx input[idx];

    if next_idx(*idx, *offset, *v, in_mask, inDims) {
      simd_index := idx * 32;
      #asm AVX, AVX2 {
        //second = ((__m256i *)weights)[idx];
        movups.y second, [weights + simd_index];
      }
      factor |= cast(u16)(input[idx]) << 8;
    } else {
      #asm AVX, AVX2 {
        movups.y second, kZero;
      }
    }

    //__m256i mul = _mm256_set1_epi16(factor), prod, signs;
    xmm_vec:  [16] u16;
    xmm_vec[0] = factor;
    xmm_vec[1] = factor;
    xmm_vec[2] = factor;
    xmm_vec[3] = factor;
    xmm_vec[4] = factor;
    xmm_vec[5] = factor;
    xmm_vec[6] = factor;
    xmm_vec[7] = factor;
    xmm_vec[8] = factor;
    xmm_vec[9] = factor;
    xmm_vec[10] = factor;
    xmm_vec[11] = factor;
    xmm_vec[12] = factor;
    xmm_vec[13] = factor;
    xmm_vec[14] = factor;
    xmm_vec[15] = factor;
    xmm_ptr := xmm_vec.data;
    #asm AVX, AVX2 {
      movups.y mul:, [xmm_ptr];

      // prod = _mm256_maddubs_epi16(mul, _mm256_unpacklo_epi8(first, second));
      punpcklbw.y xmm_reg:, first, second;
      pmaddubsw.y prod:, mul, prod;

      // signs = _mm256_cmpgt_epi16(kZero, prod); // <---
      pcmpgtw.y signs:, kZero, prod;

      // out_0 = _mm256_add_epi32(out_0, _mm256_unpacklo_epi16(prod, signs));
      punpcklwd.y xmm_reg, prod, signs;
      paddd.y out0, out0, xmm_reg;
      
      // out_1 = _mm256_add_epi32(out_1, _mm256_unpackhi_epi16(prod, signs));
      punpckhwd.y xmm_reg, prod, signs;
      paddd.y out1, out1, xmm_reg;

      // prod = _mm256_maddubs_epi16(mul, _mm256_unpackhi_epi8(first, second)); // <---
      punpckhbw.y xmm_reg, first, second;
      pmaddubsw.y prod, mul, xmm_reg;

      // signs = _mm256_cmpgt_epi16(kZero, prod);
      pcmpgtw.y signs, kZero, prod;

      // out_2 = _mm256_add_epi32(out_2, _mm256_unpacklo_epi16(prod, signs));
      punpcklwd.y xmm_reg, prod, signs;
      paddd.y out2, out2, xmm_reg;

      // out_3 = _mm256_add_epi32(out_3, _mm256_unpackhi_epi16(prod, signs));
      punpcklwd.y xmm_reg, prod, signs;
      paddd.y out3, out3, xmm_reg;
    }
  }

  #asm AVX, AVX2 {
    // __m256i out16_0 = _mm256_srai_epi16(_mm256_packs_epi32(out_0, out_1), SHIFT);
    packssdw.y sat01:, out0, out1;
    psraw.y out16_0:,  sat01, 6;

    // __m256i out16_1 = _mm256_srai_epi16(_mm256_packs_epi32(out_2, out_3), SHIFT);
    packssdw.y sat23:, out2, out3;
    psraw.y out16_1:,  sat23, 6;

    //__m256i *outVec = (__m256i *)output;
    //outVec[0] = _mm256_packs_epi16(out16_0, out16_1);
    packsswb.y outvec:, out16_0, out16_1;
    movups.y [output], outvec;
  }

  if pack8_and_calc_mask then {
    #asm AVX2 {
      //outMask[0] = _mm256_movemask_epi8(_mm256_cmpgt_epi8(outVec[0], kZero));
      pcmpgtb.y  temp:, outvec, kZero;
      pmovmskb eax:, temp;
      mov.d [out_mask], eax;
    }
  } else {
    #asm AVX, AVX2 {
      //outVec[0] = _mm256_max_epi8(outVec[0], kZero);
      pmaxsb.y outvec, outvec, kZero;
      movups.y [output], outvec;
    }
  }

  next_idx :: (idx: *s32, offset: *int, v: *u64, mask: *u32, inDims: int) -> bool {
    while <<v == 0 {
      <<offset += 8 * size_of(u32);
      if <<offset >= inDims then
        return false;
      memcpy(v, cast(*s8)mask + (<<offset / 8), size_of(u64));
    }
    <<idx = cast(s32) (<<offset + bit_scan_forward(<<v));
    <<v &= <<v - 1;
    return true;
  }

}

// TODO: Do this:
affine_propagate :: (input: *s8, biases: *s32, weights: *s8) -> s32 {
  #asm AVX, AVX2 {
     //__m256i *iv = (__m256i *)input;
     movups.y iv:, [input];
     //__m256i *row = (__m256i *)weights;
     movups.y row:, [weights];
     //__m256i prod = _mm256_maddubs_epi16(iv[0], row[0]);
     pmaddubsw.y prod:, iv, row;
  }
  
  //  prod = _mm256_madd_epi16(prod, _mm256_set1_epi16(1));
  xmm_vec:  [16] u16;
  xmm_vec[0] = 1;
  xmm_vec[1] = 1;
  xmm_vec[2] = 1;
  xmm_vec[3] = 1;
  xmm_vec[4] = 1;
  xmm_vec[5] = 1;
  xmm_vec[6] = 1;
  xmm_vec[7] = 1;
  xmm_vec[8] = 1;
  xmm_vec[9] = 1;
  xmm_vec[10] = 1;
  xmm_vec[11] = 1;
  xmm_vec[12] = 1;
  xmm_vec[13] = 1;
  xmm_vec[14] = 1;
  xmm_vec[15] = 1;
  xmm_ptr := xmm_vec.data;

  value: s32 = 0;
  #asm AVX, AVX2 {
    movups.y temp:, [xmm_ptr];
    pmaddwd.y prod, prod, temp;

    //__m128i sum = _mm_add_epi32(_mm256_castsi256_si128(prod), _mm256_extracti128_si256(prod, 1));
    extracti128 xmm0:, prod, 1;
    paddd.x sum:, prod, xmm0;


    //sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, 0x1b));
    pshufd.x xmm1:, sum, 0x1b;
    paddd.x sum, sum, xmm1;


    pextrd reg2:, sum, 1;
    movd reg1:, sum; 
    lea.d reg3:, [biases];
    add.q value, reg1;
    add.q value, reg2;
    add.q value, reg3;
  }

  return xx value;
}


nnue :: #foreign_library "nnue-probe/src/libnnueprobe";
__nnue_init :: (eval_file: *u8) #foreign nnue "nnue_init"; 

__nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 #foreign nnue "nnue_evaluate";










