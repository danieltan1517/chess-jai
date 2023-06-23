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

  read_hidden_weights :: (weight: []s8, dims: int, d: *s8) -> *s8 {

    wt_idx :: (r: int, c: int, dims: int) -> int {
      return c * 32 + r;
    }
    i := 0;
    for r: 0..31 {
      for c: 0..dims-1 {
        index := wt_idx(r, c, dims);
        weight[index] = <<d;
        d += 1;
      }
    }

    return d;
  }

  read_output_weights :: (weight: []s8, data: *s8) {
    for i: 0..31 {
      weight[i] = << data;
      data += 1;
    }
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
  nnue: NNUEdata;
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
    if reset[c] then {
      memcpy(accumulator.accumulation[c].data, ft_biases.data, kHalfDimensions * size_of(s16));
    } else {
      memcpy(accumulator.accumulation[c].data, prevAcc.accumulation[c].data, kHalfDimensions * size_of(s16));
      // Difference calculation for the deactivated features
      for k: 0..removed_indices[c].size-1 {
        index  := removed_indices[c].values[k];
        offset := kHalfDimensions * index;
        for j: 0..kHalfDimensions-1 {
          accumulator.accumulation[c][j] -= ft_weights[offset + j];
        }
      }
    }

    // Difference calculation for the activated features
    for k: 0..added_indices[c].size-1 {
      index := added_indices[c].values[k];
      offset := kHalfDimensions * index;
      for j: 0..kHalfDimensions-1 {
        accumulator.accumulation[c][j] += ft_weights[offset + j];
      }
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
    memcpy(accumulator.accumulation[c].data, ft_biases.data, kHalfDimensions * size_of(s16));
    for k: 0..activeIndices[c].size-1 {
      index := activeIndices[c].values[k];
      offset := kHalfDimensions * index;
      for j: 0..kHalfDimensions-1 {
        accumulator.accumulation[c][j] += ft_weights[offset + j];
      }
    }
  }
  accumulator.computedAccumulation = 1;
}

append_active_indices :: (chess: *Chess, active: [] IndexList) {
  half_kp_append_active_indices(chess, chess.w_king, 0, *active[0]);
  half_kp_append_active_indices(chess, chess.b_king, 1, *active[1]);
}

append_changed_indices :: (chess: *Chess, nnue: [3] *NNUEdata, removed: [] IndexList, added: [] IndexList, reset: [] bool) {
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
  offset := 0;
  p := chess.turn;
  for 0..1 {
    for i: 0..kHalfDimensions-1 {
      sum: s16 = accumulation[p][i];
      output[offset + i] = cast(s8) clamp(sum, 0, 127);
    }
    offset += kHalfDimensions;
    p ^= 1;
  }
}

affine_txfm :: (input: *s8, output: *void, inDims: u32, $outDims: u32, biases: *s32, weights: *s8, in_mask: *u32, out_mask: *u32, pack8_and_calc_mask: bool) {

  tmp: [outDims] s32;
  for i: 0..outDims-1 {
    tmp[i] = biases[i];
  }

  for idx: 0..inDims-1 {
    factor: s32 = input[idx];
    if factor {
      for i: 0..outDims-1 {
        tmp[i] += factor * weights[outDims * idx + i];
      }
    }
  }

  outVec := cast(*s8)output;
  for i: 0..outDims-1 {
    outVec[i] = cast(s8) clamp(tmp[i] >> 6, 0, 127);
  }
}

affine_propagate :: (input: *s8, biases: s32, weights: *s8) -> s32 {
  sum := biases;
  for j: 0..31 {
    sum += cast(s32)weights[j] * cast(s32)input[j];
  }
  return sum;
}

#import "Basic";
#import "File";
