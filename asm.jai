assm :: #foreign_library "asm";

trailing_zeros :: (x: u64)->int #c_call #foreign assm;
leading_zeros  :: (x: u64)->int #c_call #foreign assm;
bit_reverse64  :: (x: u64)->u64 #c_call #foreign assm;







