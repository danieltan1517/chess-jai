#import "Basic";
#import "File";

main :: () {
  print("code\n");
  nnue_init("resources/nn-04cf2b4ed1da.nnue");
  print("actual\n");
  __nnue_init("resources/nn-04cf2b4ed1da.nnue");
  chess: Chess;
  chess_startpos(*chess);
  nnue_evaluate(*chess, true);
  nnue_evaluate(*chess, false);

bit_scan_forward :: (input: u64)->int #expand {
  result := -1;
  #asm { bsf.q result, input; }
  return result;
}

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
      ft_biases[i] = xx (<<cast(*u16)(data));
      data += 2;
    }

    for i: 0..(kHalfDimensions*FtInDims)-1 {
      ft_weights[i] = cast(s16) (<<cast(*u16)(data));
      data += 2;
    }

    // Read network
    data += 4;
    for i: 0..31 {
      hidden1_biases[i] = xx (<<cast(*u32)(data));
      data += 4;
    }

    data = read_hidden_weights(hidden1_weights, 512, data);

    for i: 0..31 {
      hidden2_biases[i] = xx (<<cast(*u32)(data));
      data += 4;
    }

    data = read_hidden_weights(hidden2_weights, 32, data);
    
    for i: 0..0 {
      output_biases[i] = xx (<<cast(*u32)(data));
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

  /*
      xmm0: vec;
      xmm1: vec;
      xmm2: vec;
      xmm3: vec;
      xmm4: vec;
      xmm5: vec;
  */

  permute_biases :: (biases: [] s32) #expand {
    rdi := biases.data;
    // translated from godbolt's clang -O3 assembly language output.
    #asm {
      movaps.x xmm0:, [rdi+16]; 
      movaps.x xmm1:, [rdi+32];
      movaps.x xmm2:, [rdi+48];
      movaps.x xmm3:, [rdi+64];
      movaps.x xmm4:, [rdi+80];
      movaps.x xmm5:, [rdi+96];

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
  input_mask:   [FtOutDims / (8 * size_of(u32)) ] u32; // #align 8
  hidden1_mask: [8 / size_of(u32)] u32; // #align 8

  buf: NetData;
  print("transform\n");
  transform(pos, buf.input, input_mask);

  /*affine_txfm(buf.input, buf.hidden1_out, FtOutDims, 32,
              hidden1_biases, hidden1_weights, input_mask, hidden1_mask, true);
  affine_txfm(buf.hidden1_out, buf.hidden2_out, 32, 32
              hidden2_biases, hidden2_weights, hidden1_mask, null, false);

  out_value = affine_propagate(buf.hidden2_out, output_biases, output_weights);*/

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
}


append_active_indices :: (pos: *Position, active: *[2] IndexList)
{
  for c: 0..1
    half_kp_append_active_indices(pos, xx c, *(<<active)[c]);
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

transform :: (pos: *Position, output: [] s8, out_mask: [] u32) {
  if (!update_accumulator(pos))
    refresh_accumulator(pos);

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

      #asm AVX, AVX2 {
        movups.y xmm0:, [s0];
        movups.y xmm1:, [s1];
        packsswb.y xmm2:, xmm0, xmm1;
        movups.y [out], xmm2;
      }

      //*outMask++ = vec_mask_pos(out[i]);
    }
  }
}

nnue :: #foreign_library "nnue-probe/src/libnnueprobe";
__nnue_init :: (eval_file: *u8) #foreign nnue "nnue_init"; 

__nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 #foreign nnue "nnue_evaluate";
