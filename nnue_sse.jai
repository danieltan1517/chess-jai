#run {
  nnue_default :: "resources/nn-04cf2b4ed1da.nnue";
  if nnue_init(nnue_default) {
    print("NNUE % initialized\n", nnue_default);
  } else {
    assert(false, "Error. Neural Network is not initialized.\n"); 
  }
}

nnue_startup :: () #expand {} // initialization is done at compile time.

nnue_init :: (file_name: string) -> bool {
  verify_file :: (buffer: [] u8) -> bool {
    if buffer.count != 21022697 then
      return false;
    d := buffer.data;
    if (cast(*u32)d).* != NnueVersion then
      return false;
    if (cast(*u32)(d+4)).* != 0x3e5aa6ee then
      return false;
    if (cast(*u32)(d+8)).* != 177 then
      return false;
    if (cast(*u32)(d + TransformerStart)).* != 0x5d69d7b8 then
      return false;
    if (cast(*u32)(d + NetworkStart)).* != 0x63337156 then
      return false;
    return true;
  }

  read_hidden_weights :: (weight: []s8, dims: int, d: *s8) -> *s8 {

    wt_idx :: (r: int, c: int, dims: int) -> int {
      return c * 32 + r;
    }

    i := 0;
    for r: 0..31 {
      for c: 0..dims-1 {
        index := wt_idx(r, c, dims);
        weight[index] = d.*;
        d += 1;
      }
    }

    return d;
  }

  read_output_weights :: (weight: []s8, data: *s8) {
    for i: 0..31 {
      weight[i] = data.*;
      data += 1;
    }
  }

  init_weights :: (buffer: [] u8) {
    data := cast(*s8) (buffer.data + TransformerStart + 4);

    // Read transformer
    for i: 0..(kHalfDimensions-1) {
      ft_biases[i] = (cast, no_check (*s16)(data)).*;
      data += 2;
    }

    for i: 0..(kHalfDimensions*FtInDims)-1 {
      ft_weights[i] = (cast, no_check(*s16)(data)).*;
      data += 2;
    }

    // Read network
    data += 4;
    for i: 0..31 {
      hidden1_biases[i] = (cast, no_check(*s32)(data)).*;
      data += 4;
    }

    data = read_hidden_weights(hidden1_weights, 512, data);

    for i: 0..31 {
      hidden2_biases[i] = (cast, no_check(*s32)(data)).*;
      data += 4;
    }

    data = read_hidden_weights(hidden2_weights, 32, data);
    
    for i: 0..0 {
      output_biases[i] = (cast(*s32)(data)).*;
      data += 4;
    }

    read_output_weights(output_weights, data);

  }

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

}

nnue_evaluate :: (chess: *ChessGame) -> int {
  a_nnue: [3] *NNUEdata;
  a_nnue[0] = null;
  a_nnue[1] = null;
  a_nnue[2] = null;

  i := 0;
  while i<3 && chess.ply >= i {
    a_nnue[i] = *chess.nnue[chess.ply - i];
    i += 1;
  }

  using chess.chess;
  return nnue_evaluate_pos(chess, a_nnue);
}

nnue_evaluate_board :: (chess: Chess) -> int {
  nnue: NNUEdata #align 32;
  nnue.accumulator.computedAccumulation = 0;
  nnue_data: [3] *NNUEdata;
  nnue_data[0] = *nnue;
  nnue_data[1] = null;
  nnue_data[2] = null;
  return nnue_evaluate_pos(*chess, nnue_data);
}

DirtyPiece :: struct {
  dirtyNum: s32;
  pc      : [3] s32;
  from    : [3] s32;
  to      : [3] s32;
}

Accumulator :: struct {
  accumulation: [2][256] s16 #align 64;
  computedAccumulation: s32;
} 

NNUEdata :: struct {
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

nnue_evaluate_pos :: (chess: *Chess, nnue: [3] *NNUEdata) -> s32 {
  input_mask:   [FtOutDims / (8 * size_of(u32)) ] u32 #align 8;
  hidden1_mask: [8 / size_of(u32)] u32 #align 8;
  FV_SCALE :: 16;
  input: [FtOutDims] s8 #align 16;
  hidden1_out: [32] s8  #align 16;
  hidden2_out: [32] s8  #align 16; 
  transform(chess, nnue, *input[0], *input_mask[0]);
  affine_txfm(*input[0], *hidden1_out[0], FtOutDims, 32, *hidden1_biases[0], *hidden1_weights[0], *input_mask[0], *hidden1_mask[0], true);
  affine_txfm(*hidden1_out[0], *hidden2_out[0], 32, 32, *hidden2_biases[0], *hidden2_weights[0], *hidden1_mask[0], null, false);
  out_value := inline affine_propagate(*hidden2_out[0], output_biases[0], *output_weights[0]);
  return out_value / FV_SCALE;
}

update_accumulator :: (chess: *Chess, nnue: [3] *NNUEdata) -> bool {

  acc_if :: inline (prevAcc: **Accumulator, nnue: *NNUEdata) -> bool {
    if !nnue then
      return true;
    prevAcc.* = *nnue.accumulator;
    return !prevAcc.*.computedAccumulation;
  }

  accumulator := *nnue[0].accumulator;
  if accumulator.computedAccumulation then
    return true;
  prevAcc: *Accumulator = null;
  if acc_if(*prevAcc, nnue[1]) && acc_if(*prevAcc, nnue[2]) then
    return false;
  removed_indices: [2] IndexList;
  added_indices: [2] IndexList;
  reset: [2] bool;
  removed_indices[0].size = 0;
  removed_indices[1].size = 0;
  added_indices[0].size = 0;
  added_indices[1].size = 0;
  append_changed_indices(chess, nnue, removed_indices, added_indices, reset);

  for c: 0..1 {
    accindex := 0;
    while accindex < 256 {
      acc_tile := *accumulator.accumulation[c][accindex];
      r := reset[c] == true;
      copy_tile := ifx r then *ft_biases[accindex] else *prevAcc.accumulation[c][accindex];
      #asm SSE {
        movdqa.x xmm0: vec,  [copy_tile + 0x00];
        movdqa.x xmm1: vec,  [copy_tile + 0x10];
        movdqa.x xmm2: vec,  [copy_tile + 0x20];
        movdqa.x xmm3: vec,  [copy_tile + 0x30];
        movdqa.x xmm4: vec,  [copy_tile + 0x40];
        movdqa.x xmm5: vec,  [copy_tile + 0x50];
        movdqa.x xmm6: vec,  [copy_tile + 0x60];
        movdqa.x xmm7: vec,  [copy_tile + 0x70];
        movdqa.x xmm8: vec,  [copy_tile + 0x80];
        movdqa.x xmm9: vec,  [copy_tile + 0x90];
        movdqa.x xmm10: vec, [copy_tile + 0xa0];
        movdqa.x xmm11: vec, [copy_tile + 0xb0];
        movdqa.x xmm12: vec, [copy_tile + 0xc0];
        movdqa.x xmm13: vec, [copy_tile + 0xd0];
        movdqa.x xmm14: vec, [copy_tile + 0xe0];
        movdqa.x xmm15: vec, [copy_tile + 0xf0];
      }

      if r == false then {
        // Difference calculation for the deactivated features
        for k: 0..removed_indices[c].size-1 {
          index := removed_indices[c].values[k] * kHalfDimensions;
          sub_tile := *ft_weights[index + accindex];
          #asm SSE {
            psubw.x xmm0,  [sub_tile + 0x00];
            psubw.x xmm1,  [sub_tile + 0x10];
            psubw.x xmm2,  [sub_tile + 0x20];
            psubw.x xmm3,  [sub_tile + 0x30];
            psubw.x xmm4,  [sub_tile + 0x40];
            psubw.x xmm5,  [sub_tile + 0x50];
            psubw.x xmm6,  [sub_tile + 0x60];
            psubw.x xmm7,  [sub_tile + 0x70];
            psubw.x xmm8,  [sub_tile + 0x80];
            psubw.x xmm9,  [sub_tile + 0x90];
            psubw.x xmm10, [sub_tile + 0xa0];
            psubw.x xmm11, [sub_tile + 0xb0];
            psubw.x xmm12, [sub_tile + 0xc0];
            psubw.x xmm13, [sub_tile + 0xd0];
            psubw.x xmm14, [sub_tile + 0xe0];
            psubw.x xmm15, [sub_tile + 0xf0];
          }
        }
      }
     
      // Difference calculation for the activated features
      for k: 0..added_indices[c].size-1 {
        index := added_indices[c].values[k] * kHalfDimensions;
        add_tile := *ft_weights[index + accindex];
        #asm SSE {
          paddw.x xmm0,  [add_tile + 0x00];
          paddw.x xmm1,  [add_tile + 0x10];
          paddw.x xmm2,  [add_tile + 0x20];
          paddw.x xmm3,  [add_tile + 0x30];
          paddw.x xmm4,  [add_tile + 0x40];
          paddw.x xmm5,  [add_tile + 0x50];
          paddw.x xmm6,  [add_tile + 0x60];
          paddw.x xmm7,  [add_tile + 0x70];
          paddw.x xmm8,  [add_tile + 0x80];
          paddw.x xmm9,  [add_tile + 0x90];
          paddw.x xmm10, [add_tile + 0xa0];
          paddw.x xmm11, [add_tile + 0xb0];
          paddw.x xmm12, [add_tile + 0xc0];
          paddw.x xmm13, [add_tile + 0xd0];
          paddw.x xmm14, [add_tile + 0xe0];
          paddw.x xmm15, [add_tile + 0xf0];
        }
      }
     
      #asm SSE {
        movdqa.x [acc_tile + 0x00], xmm0;
        movdqa.x [acc_tile + 0x10], xmm1;
        movdqa.x [acc_tile + 0x20], xmm2;
        movdqa.x [acc_tile + 0x30], xmm3;
        movdqa.x [acc_tile + 0x40], xmm4;
        movdqa.x [acc_tile + 0x50], xmm5;
        movdqa.x [acc_tile + 0x60], xmm6;
        movdqa.x [acc_tile + 0x70], xmm7;
        movdqa.x [acc_tile + 0x80], xmm8;
        movdqa.x [acc_tile + 0x90], xmm9;
        movdqa.x [acc_tile + 0xa0], xmm10;
        movdqa.x [acc_tile + 0xb0], xmm11;
        movdqa.x [acc_tile + 0xc0], xmm12;
        movdqa.x [acc_tile + 0xd0], xmm13;
        movdqa.x [acc_tile + 0xe0], xmm14;
        movdqa.x [acc_tile + 0xf0], xmm15; 
      }
      accindex += 128;
    }
  }
  accumulator.computedAccumulation = 1;
  return true;
}

refresh_accumulator :: (chess: *Chess, nnue: [3] *NNUEdata) {
  accumulator := *(nnue[0].accumulator);
  activeIndices: [2] IndexList;
  activeIndices[0].size = 0;
  activeIndices[1].size = 0;
  append_active_indices(chess, activeIndices);

  for c: 0..1 {
    accindex := 0;
    while accindex < 256 {
      tile := *ft_biases[accindex];
      acc_tile := *accumulator.accumulation[c][accindex];
      #asm SSE {
        movdqa.x xmm0: vec,  [tile + 0x00];
        movdqa.x xmm1: vec,  [tile + 0x10];
        movdqa.x xmm2: vec,  [tile + 0x20];
        movdqa.x xmm3: vec,  [tile + 0x30];
        movdqa.x xmm4: vec,  [tile + 0x40];
        movdqa.x xmm5: vec,  [tile + 0x50];
        movdqa.x xmm6: vec,  [tile + 0x60];
        movdqa.x xmm7: vec,  [tile + 0x70];
        movdqa.x xmm8: vec,  [tile + 0x80];
        movdqa.x xmm9: vec,  [tile + 0x90];
        movdqa.x xmm10: vec, [tile + 0xa0];
        movdqa.x xmm11: vec, [tile + 0xb0];
        movdqa.x xmm12: vec, [tile + 0xc0];
        movdqa.x xmm13: vec, [tile + 0xd0];
        movdqa.x xmm14: vec, [tile + 0xe0];
        movdqa.x xmm15: vec, [tile + 0xf0];
      }
      for k: 0..activeIndices[c].size-1 {
        index := activeIndices[c].values[k];
        offset := kHalfDimensions * index;
        add_tile := *ft_weights[offset + accindex];
        #asm SSE {
          paddw.x xmm0,  [add_tile + 0x00];
          paddw.x xmm1,  [add_tile + 0x10];
          paddw.x xmm2,  [add_tile + 0x20];
          paddw.x xmm3,  [add_tile + 0x30];
          paddw.x xmm4,  [add_tile + 0x40];
          paddw.x xmm5,  [add_tile + 0x50];
          paddw.x xmm6,  [add_tile + 0x60];
          paddw.x xmm7,  [add_tile + 0x70];
          paddw.x xmm8,  [add_tile + 0x80];
          paddw.x xmm9,  [add_tile + 0x90];
          paddw.x xmm10, [add_tile + 0xa0];
          paddw.x xmm11, [add_tile + 0xb0];
          paddw.x xmm12, [add_tile + 0xc0];
          paddw.x xmm13, [add_tile + 0xd0];
          paddw.x xmm14, [add_tile + 0xe0];
          paddw.x xmm15, [add_tile + 0xf0];
        }
      }
      #asm SSE {
        movdqa.x [acc_tile + 0x00], xmm0;
        movdqa.x [acc_tile + 0x10], xmm1;
        movdqa.x [acc_tile + 0x20], xmm2;
        movdqa.x [acc_tile + 0x30], xmm3;
        movdqa.x [acc_tile + 0x40], xmm4;
        movdqa.x [acc_tile + 0x50], xmm5;
        movdqa.x [acc_tile + 0x60], xmm6;
        movdqa.x [acc_tile + 0x70], xmm7;
        movdqa.x [acc_tile + 0x80], xmm8;
        movdqa.x [acc_tile + 0x90], xmm9;
        movdqa.x [acc_tile + 0xa0], xmm10;
        movdqa.x [acc_tile + 0xb0], xmm11;
        movdqa.x [acc_tile + 0xc0], xmm12;
        movdqa.x [acc_tile + 0xd0], xmm13;
        movdqa.x [acc_tile + 0xe0], xmm14;
        movdqa.x [acc_tile + 0xf0], xmm15; 
      }
      accindex += 128;
    }
  }
  accumulator.computedAccumulation = 1;
}

append_active_indices :: (chess: *Chess, active: []IndexList) {
  half_kp_append_active_indices(chess, chess.w_king, 0, *active[0]);
  half_kp_append_active_indices(chess, chess.b_king, 1, *active[1]);
}

append_changed_indices :: (chess: *Chess, nnue: [3] *NNUEdata, removed: [] IndexList, added:[] IndexList, reset: [] bool) {
  dp := *nnue[0].dirtyPiece;
  if nnue[1].accumulator.computedAccumulation then {
    {
      king := chess.w_king;
      ksq := cast(s32) bsf(king);
      reset[0] = dp.pc[0] == 1;
      if reset[0] then {
        half_kp_append_active_indices(chess, king, 0, *added[0]);
      } else {
        half_kp_append_changed_indices(ksq, 0, dp, *removed[0], *added[0]);
      }
    }
    {
      king := chess.b_king;
      ksq := cast(s32) bsf(king);
      reset[1] = dp.pc[0] == 7;
      if reset[1] then {
        half_kp_append_active_indices(chess, king, 1, *added[1]);
      } else {
        half_kp_append_changed_indices(ksq, 1, dp, *removed[1], *added[1]);
      }
    }
  } else {
    dp2 := *nnue[1].dirtyPiece;
    {
      king := chess.w_king;
      ksq := cast(s32) bsf(king);
      reset[0] = dp.pc[0] == 1 || dp2.pc[0] == 1;
      if reset[0] then {
        half_kp_append_active_indices(chess, king, 0, *added[0]);
      } else {
        half_kp_append_changed_indices(ksq, 0, dp, *removed[0], *added[0]);
        half_kp_append_changed_indices(ksq, 0, dp2, *removed[0], *added[0]);
      }
    }

    {
      king := chess.b_king;
      ksq := cast(s32) bsf(king);
      reset[1] = dp.pc[0] == 7 || dp2.pc[0] == 7;
      if reset[1] then {
        half_kp_append_active_indices(chess, king, 1, *added[1]);
      } else {
        half_kp_append_changed_indices(ksq, 1, dp, *removed[1], *added[1]);
        half_kp_append_changed_indices(ksq, 1, dp2, *removed[1], *added[1]);
      }
    }
  }
}

half_kp_append_active_indices :: (chess: *Chess, king: u64, c: s32, active: *IndexList) {
  ksq := cast(s32) bsf(king);
  ksq = orient(c, ksq) * PS_END;
  occupied := chess.occupied;
  kings := chess.w_king | chess.b_king;
  occupied ^= kings;
  while occupied {
    sq := cast(s32) bsf(occupied);
    occupied &= occupied - 1;
    pc := cast(s32) chess.pieces[sq];
    active.values[active.size] = make_index(xx c, sq, pc, ksq);
    active.size += 1;
  }
}

bsf :: (value: u64) -> int #expand {
  result: int = 0;
  #asm { bsf.q result, value; }
  return result;
}

half_kp_append_changed_indices :: (ksq: s32, c: s32, dp: DirtyPiece, removed: *IndexList, added: *IndexList) {
  ksq = orient(c, ksq) * PS_END;
  num := dp.dirtyNum - 1;
  for i: 0..num {
    pc := dp.pc[i];
    if pc == 1 || pc == 7 continue;
    from := dp.from[i];
    to := dp.to[i];
    if from != 64 then {
      removed.values[removed.size] = make_index(c, from, pc, ksq);
      removed.size += 1;
    }

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

transform :: (chess: *Chess, nnue: [3] *NNUEdata, output: *s8, out_mask: *u32) {
  if !update_accumulator(chess, nnue) then
    refresh_accumulator(chess, nnue);
  accumulation: [][256] s16 = nnue[0].accumulator.accumulation;

  // 128 bit xmm register
  // 8 bit data
  // 128 / 8 => 16 numbers at a time.
  // 256 numbers total / 16 numbers per SIMD = 16 times.
  data  := *output[0];
  turn := chess.turn;
  for p: 0..1 {
    accindex := 0;
    while accindex < 256 {
      accum := *accumulation[turn][accindex];
      #asm SSE, SSE2 {
        xmm0: vec; xmm1: vec; xmm2: vec; xmm3: vec;
        xmm4: vec; xmm5: vec; xmm6: vec; xmm7: vec;
        movaps.x   xmm0, [accum + 0x00];
        packsswb.x xmm0, [accum + 0x10];
        movaps.x   xmm1, [accum + 0x20];
        packsswb.x xmm1, [accum + 0x30];
        movaps.x   xmm2, [accum + 0x40];
        packsswb.x xmm2, [accum + 0x50];
        movaps.x   xmm3, [accum + 0x60];
        packsswb.x xmm3, [accum + 0x70];
        movaps.x   xmm4, [accum + 0x80];
        packsswb.x xmm4, [accum + 0x90];
        movaps.x   xmm5, [accum + 0xa0];
        packsswb.x xmm5, [accum + 0xb0];
        movaps.x   xmm6, [accum + 0xc0];
        packsswb.x xmm6, [accum + 0xd0];
        movaps.x   xmm7, [accum + 0xe0];
        packsswb.x xmm7, [accum + 0xf0];
        movups.x   [data + 0x00], xmm0;
        movups.x   [data + 0x10], xmm1;
        movups.x   [data + 0x20], xmm2;
        movups.x   [data + 0x30], xmm3;
        movups.x   [data + 0x40], xmm4;
        movups.x   [data + 0x50], xmm5;
        movups.x   [data + 0x60], xmm6;
        movups.x   [data + 0x70], xmm7;

        // Build the input mask: one bit per packed byte, set where the byte
        // is > 0. Each xmm covers 16 inputs -> a 16-bit mask, stored
        // contiguously so the bitstream is dense in input order (this is what
        // affine_txfm's next_idx walks).
        zeroes: vec;
        pxor.x     zeroes, zeroes;
        mval: gpr;
        pcmpgtb.x  xmm0, zeroes;
        pmovmskb   mval, xmm0;
        mov.w      [out_mask + 0x00], mval;
        pcmpgtb.x  xmm1, zeroes;
        pmovmskb   mval, xmm1;
        mov.w      [out_mask + 0x02], mval;
        pcmpgtb.x  xmm2, zeroes;
        pmovmskb   mval, xmm2;
        mov.w      [out_mask + 0x04], mval;
        pcmpgtb.x  xmm3, zeroes;
        pmovmskb   mval, xmm3;
        mov.w      [out_mask + 0x06], mval;
        pcmpgtb.x  xmm4, zeroes;
        pmovmskb   mval, xmm4;
        mov.w      [out_mask + 0x08], mval;
        pcmpgtb.x  xmm5, zeroes;
        pmovmskb   mval, xmm5;
        mov.w      [out_mask + 0x0a], mval;
        pcmpgtb.x  xmm6, zeroes;
        pmovmskb   mval, xmm6;
        mov.w      [out_mask + 0x0c], mval;
        pcmpgtb.x  xmm7, zeroes;
        pmovmskb   mval, xmm7;
        mov.w      [out_mask + 0x0e], mval;

        add data, 0x80;
        add out_mask, 0x10;
      }
      accindex += 128;
    }

    turn ^= 1;
  }
}

affine_txfm :: (input: *s8, output: *s8, inDims: u32, outDims: u32, biases: *s32, weights: *s8, in_mask: *u32, out_mask: *u32, pack8_and_calc_mask: bool) #expand {
  // Masked 128-bit port of the AVX2 affine transform.
  //
  // The clipped inputs coming out of `transform` are SIGNED s8 (packsswb can
  // produce negatives). pmaddubsw treats its input operand as UNSIGNED, so we
  // must not feed negatives through it. The mask is the ReLU: in_mask has a bit
  // set for every input byte that is > 0, and next_idx visits only those. Any
  // non-positive input is skipped (it would contribute 0 anyway).
  //
  // Weights are 8-bit (like AVX2) and outDims == 32, so the 32 int32 partial
  // sums live in eight 128-bit accumulators (out_0..out_7). A weight row is
  // outDims == 32 bytes == two xmm registers. Because a 128-bit lane never
  // crosses (unlike AVX2's 256-bit unpacks) the channels stay in natural
  // order, so neither the weights nor the biases need the AVX2 permutation.
  //
  // mask2_t == u64 (IS_64BIT). SHIFT == 6.

  // Identical to the AVX2 next_idx: it walks the dense input-bitstream and is
  // independent of SIMD width.
  next_idx :: () -> bool #expand {
    #if pack8_and_calc_mask {
      while v == 0 {
        offset += 8 * size_of(u64);
        if offset >= inDims then
          return false;
        v = (cast(*u64)((cast(*s8)in_mask) + (offset/8))).*;
      }
      idx = offset + bsf(v);
      v &= v - 1;
      return true;
    } else {
      if v == 0 then {
        return false;
      }
      idx = bsf(v);
      v &= v - 1;
      return true;
    }
  }

  #asm SSE, SSE2, SSE3 {
    movdqa.x out_0: vec, [biases + 0x00];   // channels  0.. 3
    movdqa.x out_1: vec, [biases + 0x10];   // channels  4.. 7
    movdqa.x out_2: vec, [biases + 0x20];   // channels  8..11
    movdqa.x out_3: vec, [biases + 0x30];   // channels 12..15
    movdqa.x out_4: vec, [biases + 0x40];   // channels 16..19
    movdqa.x out_5: vec, [biases + 0x50];   // channels 20..23
    movdqa.x out_6: vec, [biases + 0x60];   // channels 24..27
    movdqa.x out_7: vec, [biases + 0x70];   // channels 28..31
    kZero: vec;
    pxor.x   kZero, kZero;
  }

  // memcpy(&v, in_mask, sizeof(mask2_t));
  v := (cast(*u64)in_mask).*;
  idx: int = 0;
  offset: int = 0;
  while offset < inDims {
    if !next_idx() break;

    // First active input of the pair.
    w0 := weights + 32 * idx;                       // weight row, outDims == 32 bytes
    factor: s16 = input[idx];

    // Optional second active input: its weights pair up with the first via
    // the interleaved (punpck) layout, and its value occupies the high byte
    // of factor. If there is no second input, `second` is zero.
    has_second := next_idx();
    w1: *s8 = ---;
    if has_second {
      w1 = weights + 32 * idx;
      val: s16 = input[idx];
      factor |= val << 8;
    }

    f32: u32 = cast(u32) (cast(u16) factor);
    f32 |= f32 << 16;                               // replicate for pshufd broadcast

    // ---- low 16 weights -> channels 0..15 ----
    #asm SSE, SSE2, SSE3 {
      movd        mul: vec, f32;
      pshufd      mul, mul, 0x0;                     // _mm_set1_epi16(factor)
      movdqa.x    a: vec, [w0 + 0x00];               // first_lo
      movdqa.x    b: vec, kZero;                     // second_lo defaults to 0
    }
    if has_second { #asm SSE, SSE2 { movdqa.x b, [w1 + 0x00]; } }
    #asm SSE, SSE2, SSE3 {
      // channels 0..7
      movdqa.x    prod: vec, mul;
      movdqa.x    t: vec, a;
      punpcklbw.x t, b;                              // interleave first/second weights
      pmaddubsw.x prod, t;                           // in0*w_first + in1*w_second, s16 x8
      movdqa.x    signs: vec, kZero;
      pcmpgtw.x   signs, prod;                       // signs = (0 > prod)
      movdqa.x    t, prod;
      punpcklwd.x t, signs;                          // sign-extend s16 -> s32
      paddd.x     out_0, t;
      movdqa.x    t, prod;
      punpckhwd.x t, signs;
      paddd.x     out_1, t;
      // channels 8..15
      movdqa.x    prod, mul;
      movdqa.x    t, a;
      punpckhbw.x t, b;
      pmaddubsw.x prod, t;
      movdqa.x    signs, kZero;
      pcmpgtw.x   signs, prod;
      movdqa.x    t, prod;
      punpcklwd.x t, signs;
      paddd.x     out_2, t;
      movdqa.x    t, prod;
      punpckhwd.x t, signs;
      paddd.x     out_3, t;
    }

    // ---- high 16 weights -> channels 16..31 ----
    #asm SSE, SSE2 {
      movdqa.x    a, [w0 + 0x10];                    // first_hi
      movdqa.x    b, kZero;                          // second_hi defaults to 0
    }
    if has_second { #asm SSE, SSE2 { movdqa.x b, [w1 + 0x10]; } }
    #asm SSE, SSE2, SSE3 {
      // channels 16..23
      movdqa.x    prod, mul;
      movdqa.x    t, a;
      punpcklbw.x t, b;
      pmaddubsw.x prod, t;
      movdqa.x    signs, kZero;
      pcmpgtw.x   signs, prod;
      movdqa.x    t, prod;
      punpcklwd.x t, signs;
      paddd.x     out_4, t;
      movdqa.x    t, prod;
      punpckhwd.x t, signs;
      paddd.x     out_5, t;
      // channels 24..31
      movdqa.x    prod, mul;
      movdqa.x    t, a;
      punpckhbw.x t, b;
      pmaddubsw.x prod, t;
      movdqa.x    signs, kZero;
      pcmpgtw.x   signs, prod;
      movdqa.x    t, prod;
      punpcklwd.x t, signs;
      paddd.x     out_6, t;
      movdqa.x    t, prod;
      punpckhwd.x t, signs;
      paddd.x     out_7, t;
    }
  }

  // pack int32 -> int16 (saturating) and shift down by SHIFT.
  #asm SSE, SSE2 {
    packssdw.x out_0, out_1;                         // s16: channels  0.. 7
    packssdw.x out_2, out_3;                         // s16: channels  8..15
    packssdw.x out_4, out_5;                         // s16: channels 16..23
    packssdw.x out_6, out_7;                         // s16: channels 24..31
    psraw.x    out_0, 6;
    psraw.x    out_2, 6;
    psraw.x    out_4, 6;
    psraw.x    out_6, 6;
  }

  #if pack8_and_calc_mask {
    // Store the raw clipped bytes (still signed) and emit the next layer's
    // mask: one bit per output, set where the byte is > 0.
    #asm SSE, SSE2 {
      packsswb.x out_0, out_2;                       // s8: channels  0..15
      packsswb.x out_4, out_6;                       // s8: channels 16..31
      movdqu.x   [output + 0x00], out_0;
      movdqu.x   [output + 0x10], out_4;
      mreg: gpr;
      pcmpgtb.x  out_0, kZero;
      pmovmskb   mreg, out_0;
      mov.w      [out_mask + 0x00], mreg;
      pcmpgtb.x  out_4, kZero;
      pmovmskb   mreg, out_4;
      mov.w      [out_mask + 0x02], mreg;
    }
  } else {
    // Final hidden layer: apply the ReLU clamp to [0,127] here (no mask). The
    // clamp is done in 16-bit with pmaxsw so this stays pure SSE2 (no pmaxsb /
    // SSE4.1); packsswb then saturates anything above 127 down to 127.
    #asm SSE, SSE2 {
      pmaxsw.x   out_0, kZero;
      pmaxsw.x   out_2, kZero;
      pmaxsw.x   out_4, kZero;
      pmaxsw.x   out_6, kZero;
      packsswb.x out_0, out_2;                       // s8: channels  0..15 in [0,127]
      packsswb.x out_4, out_6;                       // s8: channels 16..31 in [0,127]
      movdqu.x   [output + 0x00], out_0;
      movdqu.x   [output + 0x10], out_4;
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

