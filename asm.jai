assm :: #foreign_library "asm";

trailing_zeros :: (input: u64)->int #expand {
  result := -1;
  #asm { bsf.q result, input; }
  return result;
}

leading_zeros :: (input: u64) -> int #expand {
  result := -1;
  #asm { bsr.q result, input; }
  return result;
}

popcount :: (value: u64) -> int #expand {
  result: int;
  #asm { popcnt.q  result, value; }
  return result;
}

// TODO: Eventually, we want to replace the clang intrinsic.
bit_reverse64  :: (x: u64)->u64 #c_call #foreign assm;

/*bit_reverse64  :: (x: u64) -> u64 {
  CONST1 : u64 : -1085102592571150096;
  CONST2 : u64 : -3689348814741910324;
  CONST3 : u64 : -6148914691236517206;

  rdi: u64;
  rax: u64;
  rcx: u64;
  rdx: u64;
  #asm {
    bswap.q   rdi;
    mov.q     rax, 1085102592571150095;
    and.q     rax, rdi;
    shl.q     rax, 4;
    mov.q     rcx, CONST1;
    and.q     rcx, rdi;
    shr.q     rcx, 4;
    or.q      rcx, rax;
    mov.q     rax, 3689348814741910323;
    and.q     rax, rcx;
    mov.q     rdx, CONST2;
    and.q     rdx, rcx;
    shr.q     rdx, 2;
    lea.q     rax, [rdx + 4*rax];
    mov.q     rcx, 6148914691236517205;
    and.q     rcx, rax;
    mov.q     rdx, CONST3;
    and.q     rdx, rax;
    shr.q     rdx;
    lea.q     rax, [rdx + 2*rcx];
  }

  return rax;
}*/
