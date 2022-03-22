#import "Basic";
#import "File";

main :: () {
  nnue_init("resources/nn-04cf2b4ed1da.nnue");

}

nnue_init :: (file_name: string) -> bool {
  file, success :=  file_open(file_name);
  if !success {
    print("error. % cannot be loaded.\n", file_name);
    return false;
  }
  length :=  file_length(file);
  buffer := NewArray(length, u8);
  defer array_free(buffer);
  print("file % opened.\n", file_name);
  print("file % has % bytes.\n", file_name, length);
  if !file_read(file, buffer.data, length) {
    file_close(*file);
    print("Failed to read from file %\n", file_name);
    return false;
  }
  file_close(*file);

  // verify that the file is correct.
  if !verify_file(buffer) then
    return false;

  print("%\n", buffer);

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
    NnueVersion : u32 : 0x7AF32F16;
    TransformerStart :: 3 * 4 + 177;
    NetworkStart :: TransformerStart + 4 + 2 * 256 + 2 * 256 * 64 * 641;
  }

}

/*DLLExport void _CDECL nnue_init(const char* evalFile)
{
  printf("Loading NNUE : %s\n", evalFile);
  fflush(stdout);

  if (load_eval_file(evalFile)) {
    printf("NNUE loaded !\n");
    fflush(stdout);
    return;
  }

  printf("NNUE file not found!\n");
  fflush(stdout);

static void init_weights(const void *evalData)
{
  const char *d = (const char *)evalData + TransformerStart + 4;

  // Read transformer
  for (unsigned i = 0; i < kHalfDimensions; i++, d += 2)
    ft_biases[i] = readu_le_u16(d);
  for (unsigned i = 0; i < kHalfDimensions * FtInDims; i++, d += 2)
    ft_weights[i] = readu_le_u16(d);

  // Read network
  d += 4;
  for (unsigned i = 0; i < 32; i++, d += 4)
    hidden1_biases[i] = readu_le_u32(d);
  d = read_hidden_weights(hidden1_weights, 512, d);
  for (unsigned i = 0; i < 32; i++, d += 4)
    hidden2_biases[i] = readu_le_u32(d);
  d = read_hidden_weights(hidden2_weights, 32, d);
  for (unsigned i = 0; i < 1; i++, d += 4)
    output_biases[i] = readu_le_u32(d);
  read_output_weights(output_weights, d);

#ifdef USE_AVX2
  permute_biases(hidden1_biases);
  permute_biases(hidden2_biases);
#endif
}


}*/


