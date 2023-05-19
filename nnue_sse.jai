#run {
  nnue_default :: "resources/nn-04cf2b4ed1da.nnue";
  if nnue_init(nnue_default) {
    print("NNUE % initialized\n", nnue_default);
  } else {
    assert(false, "Error. Neural Network is not initialized.\n"); 
  }
}

init_nnue :: () #expand {} // initialization is done at compile time.

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

  read_hidden_weights :: (weight: []s8, dims: int, d: *s8) -> *s8 {
    i := 0;
    for r: 0..31 {
      for c: 0..dims-1 {
        index := wt_idx(r, c, dims);
        weight[index] = <<d;
        d += 1;
      }
    }

    return d;

    wt_idx :: (r: int, c: int, dims: int) -> int {
      return c * 32 + r;
    }
  }

  read_output_weights :: (weight: []s8, data: *s8) {
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
  hidden1_weights: [64*512] s8 #align 64;
  hidden2_weights: [64*32]  s8 #align 64;
  output_weights:  [1*32]   s8 #align 64;

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
  input: [FtOutDims] s8;
  hidden1_out: [32] s8;
  hidden2_out: [32] s8; 

  transform(pos, input, input_mask.data);
  affine_txfm(*input[0], *hidden1_out[0], FtOutDims, *hidden1_biases[0], *hidden1_weights[0]);
  affine_txfm(*hidden1_out[0], *hidden2_out[0], 32, *hidden2_biases[0], *hidden2_weights[0]);
  out_value := affine_propagate(*hidden2_out[0], output_biases[0], *output_weights[0]);

  return out_value / FV_SCALE;
  FV_SCALE :: 16;
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

  COUNT :: 31;
  for c: 0..1 {
    acc := accumulator.accumulation[c].data;
    if reset[c] then {
      memcpy(acc, ft_biases.data, kHalfDimensions * size_of(s16));
    } else {
      memcpy(acc, prevAcc.accumulation[c].data, kHalfDimensions * size_of(s16));
      // Difference calculation for the deactivated features
      for k: 0..removed_indices[c].size-1 {
        index  := removed_indices[c].values[k];
        offset := kHalfDimensions * index;
        acc_data := acc;
        features := *ft_weights[offset];
        for < COUNT..0 {
          #asm SSE2 {
            movdqa.x xmm0: vec, [acc_data];
            psubw.x  xmm0, [features];
            movdqa.x [acc_data], xmm0;
            add acc_data, 16;
            add features, 16;
          }
        }
      }
    }

    // Difference calculation for the activated features
    for k: 0..added_indices[c].size-1 {
      index := added_indices[c].values[k];
      offset := kHalfDimensions * index;
      acc_data := acc;
      features := *ft_weights[offset];
      for < COUNT..0 {
        #asm SSE2 {
          movdqa.x xmm0: vec, [acc_data];
          paddw.x  xmm0, [features];
          movdqa.x [acc_data], xmm0;
          add acc_data, 16;
          add features, 16;
        }
      }
    }
  }

  accumulator.computedAccumulation = 1;
  return true;

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
  COUNT :: 31;
  memcpy(*accumulator.accumulation[0][0], *ft_biases[0], kHalfDimensions * size_of(s16));
  memcpy(*accumulator.accumulation[1][0], *ft_biases[0], kHalfDimensions * size_of(s16));
  for c: 0..1 {
    for k: 0..activeIndices[c].size-1 {
      index := activeIndices[c].values[k];
      offset := kHalfDimensions * index;
      acc_data := *accumulator.accumulation[c][0];
      features := *ft_weights[offset];
      for 0..COUNT {
        #asm SSE2 {
          movdqa.x xmm0: vec, [acc_data];
          paddw.x  xmm0, [features];
          movdqa.x [acc_data], xmm0;
          add acc_data, 16;
          add features, 16;
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
  if c == 0 then {
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

transform :: (pos: *Position, output: [] s8, out_mask: *u32) {
  if !update_accumulator(pos) then
    refresh_accumulator(pos);
  accumulation: [][256] s16 = pos.nnue[0].accumulator.accumulation;
  pers := pos.player; 
  offset := 0;

  #asm SSE {
    mov.d  reg: gpr, 0x00_7f_00_7f;
    movd   xmm_127: vec, reg;
    pshufd xmm_127, xmm_127, 0;
    pxor.x xmm_000: vec, xmm_000;
  }

  // 128 bit xmm register
  // 8 bit data
  // 128 / 8 => 16 numbers at a time.
  // 256 numbers total / 16 numbers per SIMD = 16 times.
  COUNT :: 15;
  data := output.data;
  for p: 0..1 {
    accum := *accumulation[pers][0];
    for < COUNT..0 {
      #asm SSE, SSE4_1 {
        movaps.x   xmm0: vec, [accum];
        pmaxsw.x   xmm0, xmm_000;
        pminsw.x   xmm0, xmm_127;
        movaps.x   xmm1: vec, [accum + 0x10];
        pmaxsw.x   xmm1, xmm_000;
        pminsw.x   xmm1, xmm_127;
        
        packsswb.x xmm0, xmm1;
        movups.x   [data], xmm0;
        add        accum, 0x20;
        add        data,  0x10;
      }
    }

    pers ^= 1;
  }
}

affine_txfm :: (input: *s8, output: *void, inDims: u32, biases: *s32, weights: *s8) #expand {
  tmp: [32] s32;
  memcpy(*tmp[0], *biases[0], size_of(s32) * 32);

  offset := 0;
  mask: u32 = 0;
  input_pointer := input;
  #asm SSE {
    pxor.x zeroes: vec, zeroes;
  }

  while offset < inDims {
    // input 
    #asm SSE, SSE2 {
      movups.x   xmm0: vec, [input_pointer];
      pcmpgtb.x  xmm0, zeroes;
      pmovmskb.x mask, xmm0;
      add input_pointer, 16;
    }

    while mask {
      idx: int;
      #asm SSE {
        bsf idx, mask;
        add idx, offset;
      }
      factor: s32 = input[idx];
      index := idx << 5;  // idx * 32.
      sse_simd(factor, *tmp[0], *weights[index]);
      mask &= mask - 1;
    }

    offset += 16;
  }

  // GCC -O3 "optimized" output
  // terrible scrabbled eggs output, but faster than CPU w/o SIMD
  // the SSE code is a bit difficult to translate.
  sse_simd :: (factor: s32, tmp: *s32, weights: *s8) #expand {
    edx := factor;
    rsi := tmp;
    rdi := weights;
    #asm {
      movdqa.x    xmm1:, [rdi];
      pxor.x      xmm6:, xmm6;
      pxor.x      xmm7:, xmm7;
      movd        xmm5:,  edx;
      movdqa.x    xmm2:, xmm6;
      movdqa.x    xmm9:, xmm7;
      pshufd.x    xmm0:, xmm5, 0;
      pcmpgtb.x   xmm2, xmm1;
      movdqa.x    xmm3:, xmm1;
      movdqa.x    xmm5, xmm0;
      psrlq.x     xmm5, 32;
      movdqa.x    xmm10:, xmm7;
      punpcklbw.x xmm3, xmm2;
      punpckhbw.x xmm1, xmm2;
      pcmpgtw.x   xmm9, xmm3;
      pcmpgtw.x   xmm10, xmm1;
      movdqa.x    xmm2, xmm3;
      punpckhwd.x xmm2, xmm9;
      movdqa.x    xmm4:, xmm2;
      psrlq.x     xmm2, 32;
      pmuludq.x   xmm4, xmm0;
      pmuludq.x   xmm2, xmm5;
      pshufd.x    xmm4, xmm4, 8;
      pshufd.x    xmm2, xmm2, 8;
      punpckldq.x xmm4, xmm2;
      movdqu.x    xmm2, [rsi+16];
      paddd.x     xmm4, xmm2;
      movdqa.x    xmm2, xmm1;
      punpckhwd.x xmm1, xmm10;
      punpcklwd.x xmm2, xmm10;
      movdqa.x    xmm10, xmm1;
      movups.x    [rsi+16], xmm4;
      movdqa.x    xmm8:, xmm2;
      psrlq.x     xmm2, 32;
      pmuludq.x   xmm8, xmm0;
      pmuludq.x   xmm2, xmm5;
      pmuludq.x   xmm10, xmm0;
      pshufd      xmm2, xmm2, 8;
      pshufd      xmm8, xmm8, 8;
      punpckldq.x xmm8, xmm2;
      movdqu.x    xmm2, [rsi+32];
      paddd.x     xmm8, xmm2;
      movdqa.x    xmm2, xmm1;
      pshufd      xmm1, xmm10, 8;
      psrlq       xmm2, 32;
      movups.x    [rsi+32], xmm8;
      movdqa.x    xmm8, xmm7;
      pmuludq xmm2, xmm5;
      pshufd  xmm2, xmm2, 8;
      punpckldq       xmm1, xmm2;
      movdqu.x  xmm2, [rsi+48];
      paddd   xmm2, xmm1;
      movdqa  xmm1, xmm3;
      punpcklwd       xmm1, xmm9;
      movups.x [rsi+48], xmm2;
      movdqa  xmm3, xmm1;
      psrlq   xmm1, 32;
      pmuludq xmm3, xmm0;
      pmuludq xmm1, xmm5;
      pshufd  xmm3, xmm3, 8;
      pshufd  xmm1, xmm1, 8;
      punpckldq       xmm3, xmm1;
      movdqu.x  xmm1, [rsi];
      paddd.x   xmm1, xmm3;
      movdqu.x  xmm3, [rsi+80];
      movups.x  [rsi], xmm1;
      movdqa.x  xmm1, [rdi+16];
      pcmpgtb xmm6, xmm1;
      movdqa  xmm2, xmm6;
      movdqa  xmm6, xmm1;
      punpcklbw       xmm6, xmm2;
      punpckhbw       xmm1, xmm2;
      pcmpgtw xmm8, xmm6;
      pcmpgtw xmm7, xmm1;
      movdqa  xmm2, xmm6;
      punpckhwd       xmm2, xmm8;
      movdqa  xmm4, xmm2;
      psrlq   xmm2, 32;
      pmuludq xmm4, xmm0;
      pmuludq xmm2, xmm5;
      pshufd  xmm4, xmm4, 8;
      pshufd  xmm2, xmm2, 8;
      punpckldq       xmm4, xmm2;
      movdqa  xmm2, xmm1;
      punpckhwd       xmm1, xmm7;
      punpcklwd       xmm2, xmm7;
      paddd   xmm4, xmm3;
      movdqa  xmm7, xmm1;
      movdqa  xmm3, xmm2;
      psrlq   xmm2, 32;
      movups.x  [rsi+80], xmm4;
      pmuludq xmm3, xmm0;
      pmuludq xmm2, xmm5;
      pmuludq xmm7, xmm0;
      pshufd  xmm2, xmm2, 8;
      pshufd  xmm3, xmm3, 8;
      punpckldq       xmm3, xmm2;
      movdqu.x  xmm2, [rsi+96];
      paddd   xmm3, xmm2;
      movdqa  xmm2, xmm1;
      pshufd  xmm1, xmm7, 8;
      psrlq   xmm2, 32;
      movups.x  [rsi+96], xmm3;
      pmuludq xmm2, xmm5;
      pshufd  xmm2, xmm2, 8;
      punpckldq       xmm1, xmm2;
      movdqu.x  xmm2, [rsi+112];
      paddd   xmm2, xmm1;
      movdqa  xmm1, xmm6;
      movdqu.x  xmm6, [rsi+64];
      punpcklwd       xmm1, xmm8;
      movups  [rsi+112], xmm2;
      pmuludq xmm0, xmm1;
      psrlq   xmm1, 32;
      pmuludq xmm1, xmm5;
      pshufd  xmm0, xmm0, 8;
      pshufd  xmm1, xmm1, 8;
      punpckldq       xmm0, xmm1;
      paddd   xmm0, xmm6;
      movups  [rsi+64], xmm0;
    }
  }

  #asm SSE2 {
    mov.d    reg: gpr, 0x00_7f_00_7f;
    movd     xmm_127: vec, reg;
    pshufd.x xmm_127, xmm_127, 0;
    pxor.x   xmm_000: vec, xmm_000;
  }

  outVec := output;
  tmp_data := tmp.data;
  for < 7..0 {
    #asm SSE {
      movups.x   xmm_relu: vec, [tmp_data];
      packssdw.x xmm_relu, xmm_000;
      psraw.x    xmm_relu, 6;
      pmaxsw.x   xmm_relu, xmm_000;
      pminsw.x   xmm_relu, xmm_127;
      packsswb.x xmm_relu, xmm_000;
      movups.x   [outVec], xmm_relu;
      add        tmp_data, 0x10;
      add        outVec,   0x04;
    }
  }
}

affine_propagate :: (input: *s8, biases: s32, weights: *s8) -> s32 #expand {
  eax: s32 = 0x0001_0001;
  #asm SSE, SSE2, SSE3, SSE4_1 {
    movups.x    xmm0: vec, [input];
    movups.x    xmm1: vec, [input + 0x10];
    pmaddubsw.x xmm0, [weights];
    pmaddubsw.x xmm1, [weights + 0x10];
    movd        ones_xmm: vec, eax;
    pshufd      ones_xmm, ones_xmm, 0x0;
    pmaddwd.x   xmm0, ones_xmm;
    pmaddwd.x   xmm1, ones_xmm;
    paddd.x     xmm0, xmm1;
    pshufd      xmm1, xmm0, 0x1b;
    paddd.x     xmm0, xmm1;
    movd        eax, xmm0;
    pextrd      val: gpr, xmm0, 1;
    add         eax, val;
    add         eax, biases;
  }

  return eax;
}

#import "Basic";
#import "File";

