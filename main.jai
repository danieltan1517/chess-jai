#import "Basic";

main :: () {
  for < i: 63..0 {
    val := cast(bboard) (1 << i);
    o := sliding(xx d1|a4|f8|h6, xx val, file_of(i));        
    o |= sliding(xx d1|a4, xx val, rank_of(i));        
    print("------------------------------------\n");
    print("square: %\n", val);
    print("values: %\n", cast(bboard)(o));
    print_bitboard(o);
    print("------------------------------------\n");
  }

  //a := reverse(xx a1 | b1);
  //print("%\n", cast(bboard)a);
  //s := diagonals(serialize_bit(val));


}

using bboard :: enum_flags u64 {
  a1; b1; c1; d1; e1; f1; g1; h1;
  a2; b2; c2; d2; e2; f2; g2; h2;
  a3; b3; c3; d3; e3; f3; g3; h3;
  a4; b4; c4; d4; e4; f4; g4; h4;
  a5; b5; c5; d5; e5; f5; g5; h5;
  a6; b6; c6; d6; e6; f6; g6; h6;
  a7; b7; c7; d7; e7; f7; g7; h7;
  a8; b8; c8; d8; e8; f8; g8; h8;

  // files
  file_a :: a1 | a2 | a3 | a4 | a5 | a6 | a7 | a8;
  file_b :: b1 | b2 | b3 | b4 | b5 | b6 | b7 | b8;
  file_c :: c1 | c2 | c3 | c4 | c5 | c6 | c7 | c8;
  file_d :: d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8;
  file_e :: e1 | e2 | e3 | e4 | e5 | e6 | e7 | e8;
  file_f :: f1 | f2 | f3 | f4 | f5 | f6 | f7 | f8;
  file_g :: g1 | g2 | g3 | g4 | g5 | g6 | g7 | g8;
  file_h :: h1 | h2 | h3 | h4 | h5 | h6 | h7 | h8;

  // ranks
  rank_1 :: a1 | b1 | c1 | d1 | e1 | f1 | g1 | h1;
  rank_2 :: a2 | b2 | c2 | d2 | e2 | f2 | g2 | h2;
  rank_3 :: a3 | b3 | c3 | d3 | e3 | f3 | g3 | h3;
  rank_4 :: a4 | b4 | c4 | d4 | e4 | f4 | g4 | h4;
  rank_5 :: a5 | b5 | c5 | d5 | e5 | f5 | g5 | h5;
  rank_6 :: a6 | b6 | c6 | d6 | e6 | f6 | g6 | h6;
  rank_7 :: a7 | b7 | c7 | d7 | e7 | f7 | g7 | h7;
  rank_8 :: a8 | b8 | c8 | d8 | e8 | f8 | g8 | h8;
}

file_and_rank :: inline (i: int) -> u64 {
  assert(0 <= i && i <= 63);
  f := i & 7;
  r := i & ~7;

  file: u64 = (cast(u64) file_a) << f;
  rank: u64 = (cast(u64) rank_1) << r;
  return file | rank;
}

file_of :: inline (i: int) -> u64 {
  f := i & 7;
  file: u64 = (cast(u64) file_a) << f;
  return file;
}

rank_of :: inline (i: int) -> u64 {
  r := i & ~7;
  rank: u64 = (cast(u64) rank_1) << r;
  return rank;
}

diag_of :: inline (i: int)->u64 {
  diags :: bboard.[
    h1,
    g1 | h2,
    f1 | g2 | h3,
    e1 | f2 | g3 | h4,
    d1 | e2 | f3 | g4 | h5,
    c1 | d2 | e3 | f4 | g5 | h6,
    b1 | c2 | d3 | e4 | f5 | g6 | h7,
    a1 | b2 | c3 | d4 | e5 | f6 | g7 | h8,
    a2 | b3 | c4 | d5 | e6 | f7 | g8,
    a3 | b4 | c5 | d6 | e7 | f8,
    a4 | b5 | c6 | d7 | e8,
    a5 | b6 | c7 | d8,
    a6 | b7 | c8,
    a7 | b8,
    a8
  ];
  assert(0 <= i && i <= 63);
  f := (i & ~7) >> 3;
  r := i & 7;
  diag_i  := 7 + f - r;
  return xx diags[diag_i];
}

adiag_of :: inline (i: int)->u64 {
  a_diags :: bboard.[
    a1,
    a2 | b1,
    a3 | b2 | c1,
    a4 | b3 | c2 | d1,
    a5 | b4 | c3 | d2 | e1,
    a6 | b5 | c4 | d3 | e2 | f1,
    a7 | b6 | c5 | d4 | e3 | f2 | g1,
    a8 | b7 | c6 | d5 | e4 | f3 | g2 | h1,
    b8 | c7 | d6 | e5 | f4 | g3 | h2,
    c8 | d7 | e6 | f5 | g4 | h3,
    d8 | e7 | f6 | g5 | h4,
    e8 | f7 | g6 | h5,
    f8 | g7 | h6,
    g8 | h7,
    h8,
  ];
  assert(0 <= i && i <= 63);
  f := (i & ~7) >> 3;
  r := i & 7;
  adiag_i := f + r;
  return xx a_diags[adiag_i];
}


// TODO: if bit_scan_reverse gets a zero-based implementation, we'll use that...
// ... or assembly-language instruction...
// can also use de brujin's multiplication to do this too.
serialize_bit :: inline (x: u64)->int {
  return bit_scan_forward(x) - 1;
}

print_bitboard :: (b: u64) {
  loop(xx a8, "8 ");
  loop(xx a7, "7 ");
  loop(xx a6, "6 ");
  loop(xx a5, "5 ");
  loop(xx a4, "4 ");
  loop(xx a3, "3 ");
  loop(xx a2, "2 ");
  loop(xx a1, "1 ");
  print("  a b c d e f g h\n");

  loop :: (x: u64, s: string) #expand {
    print(s);
    z := x;
    for 0..7 {
      if b & z {
        print("O ");
      } else {
        print("- ");
      }
      z <<= 1;
    }
    print("\n");
  }
}

// o = occupied, r = piece, m = mask
sliding :: inline (o: u64, r: u64, m: u64)->u64 {
  o_bar := reverse(o & m);
  r_bar := reverse(r);
  return (((o & m) - (2*r)) ^ reverse(o_bar - (2*r_bar))) & m;
}

// TODO: most computers already have 64 assembly instruction just to do this.
reverse :: (x: u64)->u64 {
  ret: u64 = 0;
  while x {
    b := serialize_bit(x);
    bit: u64 = cast(u64) (1 << (63-b));
    ret = ret | bit;
    x = x & (x-1);
  }
  return ret;
}




