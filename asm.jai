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

// TODO: Eventually, we want to replace the clang intrinsic.
bit_reverse64  :: (x: u64)->u64 #c_call #foreign assm;

/*bit_reverse64  :: (x: u64) -> u64 {
  asm {
    rdi: gpr;
    rax: gpr;
    rcx: gpr;
    rdx: gpr;

   	bswap.q rdi;
   	mov.q   rax, 0xf0f0f0f0f0f0f0f;
  
   	and.q   rdi,rax;
   	shl.q   0x4,rax;
   	mov.q   rcx,0xf0f0f0f0f0f0f0f0;
  
   	and.q   rdi,rcx;
   	shr.q   rcx,0x4;
   	or.q    rax,rcx;
   	mov.q   rax,0x3333333333333333;
  
   	and.q   rcx,rax;
   	mov.q   rdx,0xcccccccccccccccc;
  
   	and.q   rcx,rdx;
   	shr.q   0x2,rdx;
   	lea.q   (rdx,rax,4),rax;
   	mov.q   rcx,0x5555555555555555;
  
   	and.q   rax,rcx;
   	mov.q   rdx,0xaaaaaaaaaaaaaaaa;
  
   	and.q   rax,rdx;
   	shr.q   rdx;
   	lea.q   (rdx,rcx,2),rax;
  }
}*/
