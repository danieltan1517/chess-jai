#import "Basic";
#import "File";

main :: () {
  print("code\n");
  nnue_init("resources/nn-04cf2b4ed1da.nnue");
  print("actual\n");
  __nnue_init("resources/nn-04cf2b4ed1da.nnue");

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

  permute_biases :: (biases: [] s32) #expand {
    rdi := biases.data;
    // translated from godbolt's clang -O3 assembly language output.
    #asm {
      xmm0: vec;
      xmm1: vec;
      xmm2: vec;
      xmm3: vec;
      xmm4: vec;
      xmm5: vec;
   
      movaps.x xmm0, [rdi+16]; 
      movaps.x xmm1, [rdi+32];
      movaps.x xmm2, [rdi+48];
      movaps.x xmm3, [rdi+64];
      movaps.x xmm4, [rdi+80];
      movaps.x xmm5, [rdi+96];

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


PS_END :: 10*64 + 1;
kHalfDimensions :: 256;
FtInDims :: 64*PS_END; // 64 * 641
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

Position :: struct {
  player: s32;
  pieces: *s32;
  squares: *s32;
  nnue: [3] *NNUEdata;
}

nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 {
  nnue: NNUEdata;
  nnue.accumulator.computedAccumulation = 0;
  
  pos: Position;
  pos.nnue[0] = *nnue;
  pos.nnue[1] = null;
  pos.nnue[2] = null;
  pos.player  = player;
  pos.squares = squares;

  // TODO: return nnue_evaluate_pos(*pos);
  return 0;
}

nnue :: #foreign_library "nnue-probe/src/libnnueprobe";
__nnue_init :: (eval_file: *u8) #foreign nnue "nnue_init"; 

__nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 #foreign nnue "nnue_evaluate";
