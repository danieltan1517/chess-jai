assm :: #foreign_library "asm";

trailing_zeros :: (input: u64)->int #expand {
  result := -1;
  asm { bsf.q result, input; }
  return result;
}

leading_zeros :: (input: u64) -> int #expand {
  result := -1;
  asm { bsr.q result, input; }
  return result;
}

popcount :: (value: u64) -> int #expand {
  result: int;
  asm { popcnt.q  result, value; }
  return result;
}

bit_reverse64  :: (x: u64)->u64 #c_call #foreign assm;
