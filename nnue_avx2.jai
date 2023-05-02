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

    // only for AVX2
    permute_biases(hidden1_biases.data);
    permute_biases(hidden2_biases.data);
  }

  read_hidden_weights :: (weight: []s8, dims: int, d: *s8) -> *s8 {
    i := 0;
    for r: 0..cast(u32)31 {
      for c: 0..cast(u32)(dims-1) {
        index := wt_idx(r, c, dims);
        weight[index] = <<d;
        d += 1;
      }
    }

    return d;

    wt_idx :: (r: u32, c: u32, dims: int) -> u32 {
      if dims > 32 {
        b: u32 = c & 0x18;
        b = (b << 1) | (b >> 1);
        c = xx ((c & ~0x18) | (b & 0x18));
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

  permute_biases :: (biases: *s32) #expand {
    rdi := biases;
    // translated from godbolt's clang -O3 assembly language output.
    #asm AVX {
      movdqa.x xmm0: vec, [rdi+16]; 
      movdqa.x xmm1: vec, [rdi+32];
      movdqa.x xmm2: vec, [rdi+48];
      movdqa.x xmm3: vec, [rdi+64];
      movdqa.x xmm4: vec, [rdi+80];
      movdqa.x xmm5: vec, [rdi+96];

      movdqa.x [rdi+16], xmm3; 
      movdqa.x [rdi+32], xmm0;
      movdqa.x [rdi+48], xmm4;
      movdqa.x [rdi+64], xmm1;
      movdqa.x [rdi+80], xmm5;
      movdqa.x [rdi+96], xmm2;
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
  //assert(nnue[0] && cast(int)(*nnue[0].accumulator) % 64 == 0);
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
  hidden1_weights: [64*512] s8 #align 64;
  hidden2_weights: [64*32]  s8 #align 64;
  output_weights:  [1*32]   s8 #align 64;

  // biases:
  hidden1_biases: [32] s32 #align 64;
  hidden2_biases: [32] s32 #align 64;
  output_biases : [1]  s32 #align 64;
}

using #no_reset nnue_model: NNUE_Model #align 64;

// dimensions
kHalfDimensions :: 256;
FtInDims :: 64*PS_END; // 63 * 641
FtOutDims :: kHalfDimensions*2;
NnueVersion : u32 : 0x7AF32F16;
TransformerStart :: 3*4 + 177;
NetworkStart :: TransformerStart+4 + 2*256 + 2*256*64*641;

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
  FV_SCALE :: 16;
  input: [FtOutDims] s8 #align 64;
  hidden1_out: [32] s8;
  hidden2_out: [32] s8; 
  transform(pos, *input[0], *input_mask[0]);
  affine_txfm(*input[0], *hidden1_out[0], FtOutDims, 32, *hidden1_biases[0], *hidden1_weights[0], *input_mask[0], *hidden1_mask[0], true);
  affine_txfm(*hidden1_out[0], *hidden2_out[0], 32, 32, *hidden2_biases[0], *hidden2_weights[0], *hidden1_mask[0], null, false);
  out_value := inline affine_propagate(*hidden2_out[0], output_biases[0], *output_weights[0]);
  return out_value / FV_SCALE;
}


TILE_HEIGHT :: (NUM_REGS * SIMD_WIDTH / 16);
NUM_REGS :: 16;
SIMD_WIDTH :: 256;

m256 :: union {
  i8x32 : [32] s8;
  i16x16: [16] s16;
  i32x8 : [8]  s32;
  i64x4 : [4]  s64;
}

update_accumulator :: (pos: *Position) -> bool {
  accumulator := *pos.nnue[0].accumulator;
  if accumulator.computedAccumulation then
    return true;
  prevAcc: *Accumulator = null;
  if acc_if(1) && acc_if(2) then
    return false;
  removed_indices: [2] IndexList;
  added_indices: [2] IndexList;
  reset: [2] bool;
  removed_indices[0].size = 0;
  removed_indices[1].size = 0;
  added_indices[0].size = 0;
  added_indices[1].size = 0;
  append_changed_indices(pos, removed_indices.data, added_indices.data, reset.data);
  for i: 0..kHalfDimensions / TILE_HEIGHT - 1 {
    for c: 0..1 {
      accTile := (*accumulator.accumulation[c][i*TILE_HEIGHT]);
      if reset[c] then {
        ft_b_tile := (*ft_biases[i*TILE_HEIGHT]);
        memcpy(accTile, ft_b_tile, size_of(s16) * kHalfDimensions);
      } else {
        prevAccTile := *prevAcc.accumulation[c][i*TILE_HEIGHT];
        memcpy(accTile, prevAccTile, size_of(s16) * kHalfDimensions);
        // Difference calculation for the deactivated features
        for k: 0..removed_indices[c].size-1 {
          index := removed_indices[c].values[k];
          offset := kHalfDimensions*index + i*TILE_HEIGHT;
          column := *ft_weights[offset];
          acc_data := accTile;
          for j: 0..NUM_REGS-1 {
            #asm AVX, AVX2 {
              //acc[j] = vec_sub_16(acc[j], column[j]);
              movdqa.y xmm0: vec, [acc_data];
              psubw.y  xmm0, xmm0, [column];
              movdqa.y [acc_data], xmm0;
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
        column := *ft_weights[offset];
        acc_data := accTile;
        for j: 0..NUM_REGS-1 {
          #asm AVX, AVX2 {
            // acc[j] = vec_add_16(acc[j], column[j]);
            movdqa.y xmm0: vec, [acc_data];
            paddw.y  xmm0, xmm0, [column];
            movdqa.y [acc_data], xmm0;
            add acc_data, 32;
            add column, 32;
          }
        }
      }
    }
  }

  accumulator.computedAccumulation = 1;
  return true;

  acc_if :: (i: int) -> bool #expand {
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
  numChunks :: (kHalfDimensions/TILE_HEIGHT) - 1;
  memcpy(*accumulator.accumulation[0], *ft_biases[0], size_of(s16) * kHalfDimensions);
  memcpy(*accumulator.accumulation[1], *ft_biases[0], size_of(s16) * kHalfDimensions);
  for c: 0..1 {
    accTile := *accumulator.accumulation[c][0];
    for k: 0..activeIndices[c].size-1 {
      index  := activeIndices[c].values[k];
      offset := kHalfDimensions * index;
      acc_j  := accTile;
      column := *ft_weights[offset];
      for j: 0..NUM_REGS-1 {
        #asm AVX, AVX2 {
          // acc[j] = vec_add_16(acc[j], column[j]);
          movdqa.y xmm0: vec, [acc_j];
          paddw.y xmm0, xmm0, [column];
          movdqa.y [acc_j], xmm0;
          add acc_j, 32;
          add column, 32;
        }
      }
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
  ksq = orient(c, ksq) * PS_END;
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
  ksq = orient(c, ksq) * PS_END;
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
  return orient(c, s) + PieceToIndex[c][pc] + ksq;
}

orient :: (c: s32, s: s32) -> s32 #expand {
  if c == 0 {
    return s;
  } else {
    return s ^ 0x3F;
  }
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
  accumulation: [][256] s16 = pos.nnue[0].accumulator.accumulation;
  pers := pos.player;
  numChunks :: (((16*kHalfDimensions) / SIMD_WIDTH) / 2) - 1;

  #asm AVX, AVX2 {
    // lift the xmm0 register out of the loop.
    pxor.y xmm3: vec, xmm3, xmm3;
  }

  for p: 0..1 {
    for i: 0..numChunks {
      s0 := *(cast(*m256) *accumulation[pers])[i * 2];
      #asm AVX, AVX2 {
        // out[i] = vec_packs(s0, s1); => out[i] = _mm256_packs_epi16(s0, s1);
        // *outMask++ = _mm256_movemask_epi8(_mm256_cmpgt_epi8(out[i],_mm256_setzero_si256()))
        movdqu.y   xmm0: vec, [s0];
        packsswb.y xmm0, xmm0, [s0 + 32];
        movdqu.y   [output], xmm0;
        pcmpgtb.y xmm0, xmm0, xmm3; 
        pmovmskb  val: gpr, xmm0;
        mov.d     [out_mask], val;
        add       output, 32;
        add       out_mask, 4;
      }
    }

    pers ^= 1;
  }
}

affine_txfm :: (input: *s8, output: *s8, inDims: u32, outDims: u32, biases: *s32, weights: *s8, in_mask: *u32, out_mask: *u32, pack8_and_calc_mask: bool) #expand {
  //assert(outDims == 32);
  #asm AVX, AVX2 {
    movdqa.y out_0: vec, [biases + 0];
    movdqa.y out_1: vec, [biases + 32];
    movdqa.y out_2: vec, [biases + 64];
    movdqa.y out_3: vec, [biases + 96];
    pxor.y   second: vec, second, second;
    pxor.y   kZero: vec, kZero, kZero;
  }

  // translated from => memcpy(&v, inMask, sizeof(mask2_t));
  v := << cast(*u64)in_mask;
  idx: int = 0;
  offset: int = 0;
  while offset < inDims {
    if !next_idx() break;
    weights_data := *(cast(*m256)weights)[idx];
    #asm AVX, AVX2 {
      // initialize first and second = 0.
      movdqa.y first: vec, [weights_data];
    }
    factor: s16 = input[idx];
    if next_idx() {
      weights_data := *(cast(*m256)weights)[idx];
      #asm AVX, AVX2 {
        movdqa.y second, [weights_data];
      }
      val: s16 = cast(s16) input[idx];
      factor |= val << 8;
    } else {
      #asm AVX, AVX2 {
        pxor.y second, second, second;
      }
    }

    #asm AVX, AVX2 {
      // __m256i mul = _mm256_set1_epi16(factor), prod, signs;
      // __m256i prod = _mm256_maddubs_epi16(mul, _mm256_unpacklo_epi8(first, second));
      // __m256i signs = _mm256_cmpgt_epi16(kZero, prod);
      // out_0 = _mm256_add_epi32(out_0, _mm256_unpacklo_epi16(prod, signs));
      // out_1 = _mm256_add_epi32(out_1, _mm256_unpackhi_epi16(prod, signs));
      // prod = _mm256_maddubs_epi16(mul, _mm256_unpackhi_epi8(first, second));
      // signs = _mm256_cmpgt_epi16(kZero, prod);
      // out_2 = _mm256_add_epi32(out_2, _mm256_unpacklo_epi16(prod, signs));
      // out_3 = _mm256_add_epi32(out_3, _mm256_unpackhi_epi16(prod, signs));

      movd mul: vec, factor;
      pbroadcastw.y mul, mul; 
      punpcklbw.y prod: vec, first, second;
      pmaddubsw.y prod, mul, prod;
      pcmpgtw.y signs: vec, kZero, prod;
      punpcklwd.y xmm1: vec, prod, signs;
      paddd.y out_0, out_0, xmm1;
      punpckhwd.y xmm1, prod, signs;
      paddd.y out_1, out_1, xmm1;
      punpckhbw.y xmm1, first, second;
      pmaddubsw.y prod, mul, xmm1;
      pcmpgtw.y signs, kZero, prod;
      punpcklwd.y xmm1, prod, signs;
      paddd.y out_2, out_2, xmm1;
      punpckhwd.y xmm1, prod, signs;
      paddd.y out_3, out_3, xmm1;
    }
  }

  //outVec: *m256 = cast(*m256)output;
  #asm AVX, AVX2 {
    // __m256i out16_0 = _mm256_srai_epi16(_mm256_packs_epi32(out_0, out_1), SHIFT);
    // __m256i out16_1 = _mm256_srai_epi16(_mm256_packs_epi32(out_2, out_3), SHIFT);
    // __m256i *outVec = (__m256i *)output;
    // outVec[0] = _mm256_packs_epi16(out16_0, out16_1);

    packssdw.y out_0, out_0, out_1;
    packssdw.y out_1, out_2, out_3;
    psraw.y    out_0, out_0, 6;
    psraw.y    out_1, out_1, 6;
    packsswb.y out_0, out_0, out_1;
    movdqu.y   [output], out_0;
  }

  #if pack8_and_calc_mask then {
    #asm AVX, AVX2 {
      // outMask[0] = _mm256_movemask_epi8(_mm256_cmpgt_epi8(outVec[0], kZero));
      pcmpgtb.y out_0, out_0, kZero;
      pmovmskb  reg: gpr, out_0;
      mov.d     [out_mask], reg;
    }
  } else {
    #asm AVX, AVX2 {
      // outVec[0] = _mm256_max_epi8(outVec[0], kZero);
      pmaxsb.y out_0, out_0, kZero;
      movdqu.y [output], out_0;
    }
  }

  // mask2_t = u64
  next_idx :: () -> bool #expand {
    while v == 0 {
      offset += 8 * size_of(u64);
      if offset >= inDims then
        return false;
      v = << cast(*u64)((cast(*s8)in_mask) + (offset/8));
    }
    idx = offset + bsf(v);
    v &= v - 1;
    return true;
  }

  bsf :: (value: u64) -> int #expand {
    result: int = 0;
    #asm { bsf.q result, value; }
    return result;
  }
}

affine_propagate :: (input: *s8, biases: s32, weights: *s8) -> s32 #expand {
  eax: s32 = ---;
  #asm AVX, AVX2 {
    // __m256i prod = _mm256_maddubs_epi16(iv[0], row[0]);
    // prod = _mm256_madd_epi16(prod, _mm256_set1_epi16(1));
    // __m128i sum = _mm_add_epi32(_mm256_castsi256_si128(prod), _mm256_extracti128_si256(prod, 1));
    // sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, 0x1b));
    // return _mm_cvtsi128_si32(sum) + _mm_extract_epi32(sum, 1) + biases[0];

    mov eax, 1;
    movdqu.y    prod: vec,  [input];
    pmaddubsw.y prod, prod, [weights];
    movd        xmm0: vec, eax;
    pbroadcastw xmm0, xmm0; 
    pmaddwd.y   prod, prod, xmm0;
    extracti128 xmm0, prod, 1;
    paddd.x     sum: vec, prod, xmm0;
    pshufd      xmm0, sum, 0x1b;
    paddd.x     sum, sum, xmm0;
    movd        eax, sum;
    pextrd      val: gpr, sum, 1;
    add         eax, val;
    add         eax, biases;
  }

  return eax;
}

#import "Basic";
#import "File";




