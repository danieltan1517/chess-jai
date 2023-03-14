nnue_init :: (file_name: string) -> bool {
  file, success :=  file_open(file_name);
  if !success {
    return false;
  }
  length :=  file_length(file);
  buffer := NewArray(length, u8);
  defer {
    array_free(buffer);
    file_close(*file);
  }

  if !file_read(file, buffer.data, length) {
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
      ft_weights[i] = <<cast, no_check(*s16)(data);
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
  }

  read_hidden_weights :: (weight:[] s16, dims: int, d: *s8) -> *s8 {
    i := 0;
    for r: 0..cast(u32)31 {
      for c: 0..cast(u32)(dims-1) {
        index := wt_idx(r, c, dims);
        weight[index] = <<d;
        d += 1;
      }
    }

    return d;

    wt_idx :: (r: u32, c: u32, dims: int) -> u32 #expand {
      return c * 32 + r;
    }
  }

  read_output_weights :: (weight:[] s16, data: *s8) {
    for i: 0..31 {
      weight[i] = << data;
      data += 1;
    }
  }
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

nnue_evaluate_incremental :: (player: s32, pieces: *s32, squares: *s32, nnue: **NNUEdata) -> s32 {
  assert(nnue[0] && cast(int)(*nnue[0].accumulator) % 64 == 0);
  pos: Position;
  pos.nnue[0] = nnue[0];
  pos.nnue[1] = nnue[1];
  pos.nnue[2] = nnue[2];
  pos.player = player;
  pos.pieces = pieces;
  pos.squares = squares;
  return nnue_evaluate_pos(*pos);
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

#scope_file
NNUE_Model :: struct {
  // features:
  ft_biases:  [kHalfDimensions] s16 #align 64;
  ft_weights: [kHalfDimensions*FtInDims] s16 #align 64;

  // weights:
  hidden1_weights: [64*512] s16 #align 64;
  hidden2_weights: [64*32]  s16 #align 64;
  output_weights:  [1*32]   s16 #align 64;

  // biases:
  hidden1_biases: [32] s32 #align 64;
  hidden2_biases: [32] s32 #align 64;
  output_biases : [1]  s32 #align 64;
}

#no_reset nnue_model: NNUE_Model #align 64;
using nnue_model;

// dimensions
kHalfDimensions :: 256;
FtInDims :: 64*PS_END; // 63 * 641
FtOutDims :: kHalfDimensions*2;
NnueVersion : u32 : 0x7AF32F16;
TransformerStart :: 3*4 + 177;
NetworkStart :: TransformerStart+4 + 2*256 + 2*256*64*641;

NetData :: struct {
  input: [FtOutDims] s8 #align 64;
  hidden1_out: [32] s8;

  // if using SSE2 w/o AVX2, then 's16'
  hidden2_out: [32] s16; 
}

Position :: struct {
  player: s32;
  pieces: *s32;
  squares: *s32;
  nnue: [3] *NNUEdata;
}

IndexList :: struct {
  size: s32;
  values: [30] s32;
}

nnue_evaluate_pos :: (pos: *Position) -> s32 {
  input_mask:   [FtOutDims / (8 * size_of(u32)) ] u32 #align 8;
  hidden1_mask: [8 / size_of(u32)] u32 #align 8;
  buf: NetData;
  FV_SCALE :: 16;

  transform(pos, *buf.input[0], *input_mask[0]);
  affine_txfm(*buf.input[0], *buf.hidden1_out[0], FtOutDims, 32, *hidden1_biases[0], *hidden1_weights[0], *input_mask[0], *hidden1_mask[0], true);
  affine_txfm(*buf.hidden1_out[0], *buf.hidden2_out[0], 32, 32, *hidden2_biases[0], *hidden2_weights[0], *hidden1_mask[0], null, false);
  out_value := affine_propagate(cast(*s8)*buf.hidden2_out[0], *output_biases[0], *output_weights[0]);
  return out_value / FV_SCALE;
}

TILE_HEIGHT :: (NUM_REGS * SIMD_WIDTH / 16);
NUM_REGS :: 16;
SIMD_WIDTH :: 128;

m128 :: union {
  i8x16: [16] s8;
  i16x8: [8] s16;
  i32x4: [4] s32;
  i64x2: [2] s64;
}

update_accumulator :: (pos: *Position) -> bool {
  accumulator := *pos.nnue[0].accumulator;
  if accumulator.computedAccumulation then
    return true;
  prevAcc: *Accumulator = null;
  if acc(1) && acc(2) then
    return false;
  removed_indices: [2] IndexList;
  added_indices: [2] IndexList;
  reset: [2] bool;
  removed_indices[0].size = 0;
  removed_indices[1].size = 0;
  added_indices[0].size = 0;
  added_indices[1].size = 0;
  append_changed_indices(pos, removed_indices.data, added_indices.data, reset.data);

  assert(false, "TODO: Not Implemented! Incremental Update.\n");
  accumulator.computedAccumulation = 1;
  return true;

  /*for i: 0..kHalfDimensions / TILE_HEIGHT - 1 {
    for c: 0..1 {
      accTile := cast(*m256) (*accumulator.accumulation[c][i*TILE_HEIGHT]);
      acc: [NUM_REGS] m256;

      if reset[c] then {
        ft_b_tile := cast(*m256) (*ft_biases[i*TILE_HEIGHT]);
        memcpy(acc.data, ft_b_tile, size_of(m256) * NUM_REGS);
      } else {
        prevAccTile := cast(*m256) *prevAcc.accumulation[c][i*TILE_HEIGHT];
        memcpy(acc.data, prevAccTile, size_of(m256) * NUM_REGS);
        // Difference calculation for the deactivated features
        for k: 0..removed_indices[c].size-1 {
          index := removed_indices[c].values[k];
          offset := kHalfDimensions*index + i*TILE_HEIGHT;
          column := cast(*m256) *ft_weights[offset];
          acc_data := acc.data;
          for j: 0..NUM_REGS-1 {
            #asm AVX, AVX2 {
              //acc[j] = vec_sub_16(acc[j], column[j]);
              movdqu.y xmm0: vec, [acc_data];
              movdqu.y xmm1: vec, [column];
              psubw.y  xmm0, xmm0, xmm1;
              movdqu.y [acc_data], xmm0;
              add      acc_data, 32;
              add      column, 32;
            }
          }
        }
      }

      // Difference calculation for the activated features
      for k: 0..added_indices[c].size-1 {
        index := added_indices[c].values[k];
        offset := kHalfDimensions*index + i*TILE_HEIGHT;
        column := cast(*m256) *ft_weights[offset];
        acc_data := acc.data;
        for j: 0..NUM_REGS-1 {
          #asm {
            // acc[j] = vec_add_16(acc[j], column[j]);
            movdqu.y xmm0: vec, [acc_data];
            movdqu.y xmm1: vec, [column];
            paddw.y  xmm0, xmm0, xmm1;
            movdqu.y [acc_data], xmm0;
            add acc_data, 32;
            add column, 32;
          }
        }
      }

      memcpy(accTile, acc.data, size_of(m256) * NUM_REGS);
    }
  }*/

  acc :: (i: int) -> bool #expand {
    if !pos.nnue[i] then
      return true;
    prevAcc = *pos.nnue[i].accumulator;
    return !prevAcc.computedAccumulation;
  }
}

refresh_accumulator :: (pos: *Position) {
  accumulator := *pos.nnue[0].accumulator;
  activeIndices: [2] IndexList;
  activeIndices[0].size = 0;
  activeIndices[1].size = 0;
  append_active_indices(pos, activeIndices.data);

  for c: 0..1 {
    for i: 0..(kHalfDimensions/TILE_HEIGHT) - 1 {
      ft_biases_tile := cast(*m128)*ft_biases[i*TILE_HEIGHT];
      accTile := cast(*m128)*accumulator.accumulation[c][i*TILE_HEIGHT];
      acc: [NUM_REGS] m128;

      memcpy(acc.data, ft_biases_tile, size_of(m128) * NUM_REGS);

      for k: 0..activeIndices[c].size-1 {
        index  := activeIndices[c].values[k];
        offset := kHalfDimensions * index + i * TILE_HEIGHT;
        acc_j  := acc.data;
        column := cast(*m128) *ft_weights[offset];
        for j: 0..NUM_REGS-1 {
          // acc[j] = vec_add_16(acc[j], column[j]);
          #asm SSE2 {
            movdqu.x xmm0: vec, [acc_j];
            movdqu.x xmm1: vec, [column];
            paddw.x xmm0, xmm1;
            movdqu.x [acc_j], xmm0;
            add acc_j, 16;
            add column, 16;
          }
        }
      }

      memcpy(accTile, acc.data, size_of(m128) * NUM_REGS);
    }
  }

  accumulator.computedAccumulation = 1;
}

append_active_indices :: (pos: *Position, active: *IndexList) {
  half_kp_append_active_indices(pos, 0, *active[0]);
  half_kp_append_active_indices(pos, 1, *active[1]);
}

append_changed_indices :: (pos: *Position, removed: *IndexList, added: *IndexList, reset: *bool) {
  dp := *pos.nnue[0].dirtyPiece;
  if pos.nnue[1].accumulator.computedAccumulation then {
    for c: 0..cast(s32)1 {
      reset[c] = dp.pc[0] == KING(c);
      if reset[c] then {
        half_kp_append_active_indices(pos, c, *added[c]);
      } else {
        half_kp_append_changed_indices(pos, c, dp, *removed[c], *added[c]);
      }
    }
  } else {
    dp2 := *pos.nnue[1].dirtyPiece;
    for c: 0..cast(s32)1 {
      reset[c] = dp.pc[0] == KING(c) || dp2.pc[0] == KING(c);
      if reset[c] then {
        half_kp_append_active_indices(pos, c, *added[c]);
      } else {
        half_kp_append_changed_indices(pos, c, dp, *removed[c], *added[c]);
        half_kp_append_changed_indices(pos, c, dp2, *removed[c], *added[c]);
      }
    }
  }

  KING :: (c: int) -> s32 #expand {
    return ifx c then bking else wking;
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
    active.values[active.size] = make_index(c, sq, pc, ksq);
    active.size += 1;
    i += 1;
  }
}

half_kp_append_changed_indices :: (pos: *Position, c: s32, dp: *DirtyPiece, removed: *IndexList, added: *IndexList) {
  ksq := pos.squares[c];
  ksq = orient(c, ksq);
  for i: 0..dp.dirtyNum-1 {
    pc := dp.pc[i];
    if pc == 1 || pc == 7 continue;
    from := dp.from[i];
    if from != 64 then {
      removed.values[removed.size] = make_index(c, from, pc, ksq);
      removed.size += 1;
    }

    to := dp.to[i];
    if to != 64 then {
      added.values[added.size] = make_index(c, to, pc, ksq);
      added.size += 1;
    }
  }
}

make_index :: (c: s32, s: s32, pc: s32, ksq: s32) -> s32 #expand {
  return orient(c, s) + PieceToIndex[c][pc] + PS_END * ksq;
}

orient :: (c: s32, s: s32) -> s32 #expand {
  x : s32 = cast(s32) ifx c == 0 0x00 else 0x3f;
  return s ^ x;
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

transform :: (pos: *Position, output: *s8, out_mask: *u32) {
  if !update_accumulator(pos) then
    refresh_accumulator(pos);
  accumulation := *pos.nnue[0].accumulator.accumulation;
  perspectives: [2] int;
  perspectives[0] = pos.player;
  perspectives[1] = pos.player ^ 1;

  numChunks :: (16*kHalfDimensions) / SIMD_WIDTH;
  for p: 0..1 {
    offset := kHalfDimensions*p;
    out := cast(*void) (output + offset);
    for i: 0..(numChunks/2) - 1 {
      pers := perspectives[p];
      s0 := *((cast(*m128) *(<<accumulation)[pers])[i*2]);
      s1 := *((cast(*m128) *(<<accumulation)[pers])[i*2 + 1]);

      // COMPILER BUG: packsswb requires SSE2, not AVX.
      // TODO: actually this is NOT a bug. Just me failing to remember packsswb xmm0, xmm1,
      // not packsswb xmm0, xmm0, xmm1;

      #asm SSE2 {
        // out[i] = vec_packs(s0, s1); => out[i] = _mm_packs_epi16(s0, s1);
        movdqu.x   xmm0: vec, [s0];
        packsswb.x xmm0, [s1];
        movdqu.x   [out], xmm0;

        // *outMask++ = _mm_movemask_epi8(_mm_cmpgt_epi8(out[i], _mm_setzero_si128()))
        pxor.x     xmm2: vec, xmm2;
        movdqu.x   xmm3: vec, xmm0;
        pcmpgtb.x  xmm3, xmm2;
        pmovmskb.x val: gpr, xmm3;
        mov.d      [out_mask], val;
        add        out, 16;
        add        out_mask, 4;
      }
    }
  }
}

affine_txfm :: (input: *s8, output: *void, inDims: u32, outDims: u32, biases: *s32, weights: *s16, in_mask: *u32, out_mask: *u32, pack8_and_calc_mask: bool) {
  assert(outDims == 32);
  // const __m128i kZeros[4] = { 0 };
  kZeros: [4] m128;
  first: *m128;
  second: *m128 = kZeros.data;

  #asm SSE2 {
    movdqu.x out_0: vec, [biases +  0];
    movdqu.x out_1: vec, [biases + 16];
    movdqu.x out_2: vec, [biases + 32];
    movdqu.x out_3: vec, [biases + 48];
    movdqu.x out_4: vec, [biases + 64];
    movdqu.x out_5: vec, [biases + 80];
    movdqu.x out_6: vec, [biases + 96];
    movdqu.x out_7: vec, [biases + 112];
  }

  // translated from => memcpy(&v, inMask, sizeof(mask2_t));
  v := << cast(*u64)in_mask;
  idx: int = 0;
  offset: int = 0;
  while offset < inDims {
    if !next_idx() then
      break;
    first = cast(*m128) *weights[outDims * idx];
    factor: u32 = cast(u32) <<(input + idx);
    if next_idx() {
      second = cast(*m128) *weights[outDims * idx];
      val: u32 = cast(u32) <<(input + idx);
      factor |= val << 16;
    } else {
      second = *kZeros[0];
    }

    // TODO: perhaps there is a less verbose way of doing this? but maybe for next time...
    #asm SSE2 {
      // __m128i mul = _mm_set1_epi32(factor);
      movd        xmm0: vec, factor;
      pshufd.x    mul:  vec, xmm0, 0;

      // out_0 = _mm_add_epi32(out_0, _mm_madd_epi16(mul, _mm_unpacklo_epi16(first[0],second[0])));
      movdqu.x    xmm1: vec, [first  + 0]; // xmm1 = first[0]
      movdqu.x    xmm2: vec, [second + 0]; // xmm2 = second[0]
      movdqu.x    xmm3: vec, xmm1;
      punpcklwd.x xmm3, xmm2;              // xmm3 = _mm_unpacklo_epi16(first[0], second[0])
      movdqu.x    xmm4: vec, mul;
      pmaddwd.x   xmm4, xmm3;              // _mm_add_epi16(mul, xmm3)
      paddd.x     out_0, xmm4;

      // out_1 = _mm_add_epi32(out_1, _mm_madd_epi16(mul, _mm_unpackhi_epi16(first[0],second[0])));
      movdqu.x    xmm5: vec, xmm1;
      punpckhwd.x xmm5, xmm2;              // xmm5 = _mm_unpackhi_epi16(first[0], second[0])
      movdqu.x    xmm6: vec, mul;
      pmaddwd.x   xmm6, xmm5;              // _mm_madd_epi16(mul, xmm5)
      paddd.x     out_1, xmm6;

      // out_2 = _mm_add_epi32(out_2, _mm_madd_epi16(mul, _mm_unpacklo_epi16(first[1],second[1])));
      movdqu.x    xmm7: vec, [first  + 16]; // xmm7 = first[1]
      movdqu.x    xmm8: vec, [second + 16]; // xmm8 = second[1]
      movdqu.x    xmm9: vec, xmm7;
      punpcklwd.x xmm9, xmm8;               // xmm9 = _mm_unpacklo_epi16(first[1], second[1])
      movdqu.x    xmm10: vec, mul;
      pmaddwd.x   xmm10, xmm9;              // _mm_madd_epi16(mul, xmm9)
      paddd.x     out_2, xmm10;

      // out_3 = _mm_add_epi32(out_3, _mm_madd_epi16(mul, _mm_unpackhi_epi16(first[1],second[1])));
      movdqu.x    xmm11: vec, xmm7;
      punpckhwd.x xmm11, xmm8;              // _mm_unpackhi_epi16(first[1],second[1])
      movdqu.x    xmm12: vec, mul;
      pmaddwd.x   xmm12, xmm11;             // _mm_madd_epi16(mul, xmm11);
      paddd.x     out_3, xmm12;

      // out_4 = _mm_add_epi32(out_4, _mm_madd_epi16(mul, _mm_unpacklo_epi16(first[2],second[2])));
      movdqu.x    xmm13: vec, [first  + 32]; // xmm13 = first[2]
      movdqu.x    xmm14: vec, [second + 32]; // xmm14 = second[2]
      movdqu.x    xmm15: vec, xmm13;
      punpcklwd.x xmm15, xmm14;              // _mm_unpacklo_epi16(first[2],second[2])
      movdqu.x    xmm16: vec, mul;
      pmaddwd.x   xmm16, xmm15;              // _mm_madd_epi16(mul, xmm15)
      paddd.x     out_4, xmm16;              // _mm_add_epi32(out_4, xmm16)

      // out_5 = _mm_add_epi32(out_5, _mm_madd_epi16(mul, _mm_unpackhi_epi16(first[2],second[2])));
      movdqu.x    xmm17: vec, xmm13;
      punpckhwd.x xmm17, xmm14;              // xmm17 = _mm_unpackhi_epi16(first[2],second[2])
      movdqu.x    xmm18: vec, mul;
      pmaddwd.x   xmm18, xmm17;              // xmm18 = _mm_madd_epi16(mul, xmm17)
      paddd.x     out_5, xmm18;

      // out_6 = _mm_add_epi32(out_6, _mm_madd_epi16(mul, _mm_unpacklo_epi16(first[3],second[3])));
      movdqu.x    xmm19: vec, [first  + 48];
      movdqu.x    xmm20: vec, [second + 48];
      movdqu.x    xmm21: vec, xmm19;
      punpcklwd.x xmm21, xmm20;               // xmm21 = _mm_unpacklo_epi16(first[3], second[3])
      movdqu.x    xmm22: vec, mul;
      pmaddwd.x   xmm22, xmm21;               // _mm_madd_epi16(mul, xmm21)
      paddd.x     out_6, xmm22;

      // out_7 = _mm_add_epi32(out_7, _mm_madd_epi16(mul, _mm_unpackhi_epi16(first[3],second[3])));
      movdqu.x    xmm23: vec, xmm19;
      punpckhwd.x xmm23, xmm20;               // _mm_unpackhi_epi16(first[3], second[3])
      movdqu.x    xmm24: vec, mul;
      pmaddwd     xmm24, xmm23;               // _mm_madd_epi16(mul, xmm23)
      paddd.x     out_7, xmm24;
    }
  }

  SHIFT :: 6;
  #asm SSE2 {
    // __m128i out16_0 = _mm_srai_epi16(_mm_packs_epi32(out_0, out_1), SHIFT);
    movdqu.x   out16_0: vec, out_0;
    packssdw.x out16_0, out_1;      //_mm_packs_epi32(out_0, out_1)
    psraw.x    out16_0, SHIFT;

    // __m128i out16_1 = _mm_srai_epi16(_mm_packs_epi32(out_2, out_3), SHIFT);
    movdqu.x   out16_1: vec, out_2;
    packssdw.x out16_1, out_3;      //_mm_packs_epi32(out_2, out_3)
    psraw.x    out16_1, SHIFT;

    // __m128i out16_2 = _mm_srai_epi16(_mm_packs_epi32(out_4, out_5), SHIFT);
    movdqu.x   out16_2: vec, out_4;
    packssdw.x out16_2, out_5;
    psraw.x    out16_2, SHIFT;

    // __m128i out16_3 = _mm_srai_epi16(_mm_packs_epi32(out_6, out_7), SHIFT);
    movdqu.x   out16_3: vec, out_6;
    packssdw.x out16_3, out_7;
    psraw.x    out16_3, SHIFT;
  }

  outVec: *m128 = cast(*m128) output;
  if pack8_and_calc_mask then {
    #asm SSE2 {
      //outVec[0] = _mm_packs_epi16(out16_0, out16_1);
      movdqu.x   xmm0: vec, out16_0;
      packsswb.x xmm0, out16_1;
      movdqu.x   [outVec + 0], xmm0;

      //outMask[0] = _mm_movemask_epi8(_mm_cmpgt_epi8(outVec[0], kZeros[0]));
      pxor.x     kZeros0: vec, kZeros0;
      pcmpgtb.x  xmm0, kZeros0;
      pmovmskb.x outMask0: gpr, xmm0;
      mov.d      [out_mask], outMask0;

      //outVec[1] = _mm_packs_epi16(out16_2, out16_3);
      movdqu.x   xmm1: vec, out16_2;
      packsswb.x xmm1, out16_3;
      movdqu.x   [outVec + 16], xmm1;

      //outMask[1] = _mm_movemask_epi8(_mm_cmpgt_epi8(outVec[1], kZeros[0]));
      pcmpgtb.x  xmm1, kZeros0;
      pmovmskb.x outMask1: gpr, xmm1;
      mov.d      [out_mask + 4], outMask1;
    }
  } else {
    #asm SSE2 {
      //const __m128i kx07f = _mm_set1_epi16(127);
      mov.d    reg: gpr, 127;
      movd     xmm0: vec, reg;
      pshufd.x kx07f: vec, xmm0, 0;

      pxor.x kZeros0: vec, kZeros0;

      //outVec[0] = _mm_min_epi16(_mm_max_epi16(out16_0, kZeros[0]), kx07f);
      movdqu.x outVec0: vec, out16_0;
      pmaxsw.x outVec0, kZeros0;
      pminsw.x outVec0, kx07f;
      movdqu.x [outVec + 0], outVec0;

      //outVec[1] = _mm_min_epi16(_mm_max_epi16(out16_1, kZeros[0]), kx07f);
      movdqu.x outVec1: vec, out16_1;
      pmaxsw.x outVec1, kZeros0;
      pminsw.x outVec1, kx07f;
      movdqu.x [outVec + 16], outVec1;

      //outVec[2] = _mm_min_epi16(_mm_max_epi16(out16_2, kZeros[0]), kx07f);
      movdqu.x outVec2: vec, out16_2;
      pmaxsw.x outVec2, kZeros0;
      pminsw.x outVec2, kx07f;
      movdqu.x [outVec + 32], outVec2;

      //outVec[3] = _mm_min_epi16(_mm_max_epi16(out16_3, kZeros[0]), kx07f);
      movdqu.x outVec3: vec, out16_3;
      pmaxsw.x outVec3, kZeros0;
      pminsw.x outVec3, kx07f;
      movdqu.x [outVec + 48], outVec3;
    }
  }

  // mask2_t = u64
  next_idx :: () -> bool #expand {
    while v == 0 {
      offset += 8 * size_of(u64);
      if offset >= inDims then
        return false;
      memcpy(*v, (cast(*s8)in_mask) + (offset/8), size_of(u64));
    }
    idx = offset + bsf(v);
    v &= v - 1;
    return true;
  }

  bsf :: (value: u64) -> int #expand {
    assert(value != 0);
    result: int = 0;
    #asm { bsf.q result, value; }
    return result;
  }
}

affine_propagate :: (input: *s8, biases: *s32, weights: *s16) -> s32 {

/*
  __m128i *iv = (__m128i *)input;
  __m128i *row = (__m128i *)weights;
  __m128i p0 = _mm_madd_epi16(iv[0], row[0]);
  __m128i p1 = _mm_madd_epi16(iv[1], row[1]);
  __m128i p2 = _mm_madd_epi16(iv[2], row[2]);
  __m128i p3 = _mm_madd_epi16(iv[3], row[3]);
  __m128i sum = _mm_add_epi32(_mm_add_epi32(p0, p1), _mm_add_epi32(p2, p3));
  sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, 0xb));
  sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, 0x1));
  return _mm_cvtsi128_si32(sum) + biases[0];
*/

  eax: s32 = ---;
  #asm SSE {
    movdqu.x   p0: vec, [input + 0];
    pmaddwd.x  p0, [weights + 0];

    movdqu.x   p1: vec, [input + 16];
    pmaddwd.x  p1, [weights + 16];

    movdqu.x   p2: vec, [input + 32];
    pmaddwd.x  p2, [weights + 32]; 

    movdqu.x   p3: vec, [input + 48];
    pmaddwd.x  p3, [weights + 48];

    movdqu.x   sum: vec, p0;
    paddd.x    sum, p1;
    paddd.x    sum, p2;
    paddd.x    sum, p3;

    pshufd.x   xb_shuf: vec, sum, 0xb;
    paddd.x    sum, xb_shuf;

    pshufd.x   x1_shuf: vec, sum, 0x1;
    paddd.x    sum, x1_shuf;

    movd eax, sum;
  }

  return eax + biases[0];
}

#import "Basic";
#import "File";
