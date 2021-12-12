#import "Basic";

main :: () {
  init_magic_bitboard();
  print("Chess: %\n", size_of(Chess));
  for i: 0..63 {
    print_bitboard(magic_rook[i].mask);
    print("square: %\n", cast(Bitboard) (1<<i));
    print("-----------\n");
  }

}

Chess :: struct {
  pieces: [64] Piece;

  occupied: u64;
  union {
    struct {
      none:     u64;
      w_king:   u64;
      w_queen:  u64;
      w_rook:   u64;
      w_bishop: u64;
      w_knight: u64;
      w_pawn:   u64; 
   
      b_king :  u64;
      b_queen:  u64;
      b_rook:   u64;
      b_bishop: u64;
      b_knight: u64;
      b_pawn:   u64; 
    }
    
    bitboard: [13] u64;
  }

  en_peasant: u64;
  castling: Castling;
  side: Side;

  Side :: enum s32 { white :: 0; black :: 1; };

  Castling :: enum_flags u8 {
    W_KS;
    W_QS;
    B_KS;
    B_QS;
    All :: W_KS|W_QS|B_KS|B_QS;
  }
}

#scope_file

using Bitboard :: enum_flags u64 {
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

  king_side :: file_e | file_f | file_g | file_h;
  queen_side :: ~king_side;
}

Piece :: enum u8 {
  NONE     :: 0;
  W_KING   :: 1;
  W_QUEEN  :: 2;
  W_ROOK   :: 3;
  W_BISHOP :: 4;
  W_KNIGHT :: 5;
  W_PAWN   :: 6;

  B_KING   :: 7;
  B_QUEEN  :: 8;
  B_ROOK   :: 9;
  B_BISHOP :: 10;
  B_KNIGHT :: 11;
  B_PAWN   :: 12;
}

Magics :: struct {
  mask: u64;
  magic: u64;
  relevant_bit: int;
}

#no_reset magic_bishop: [64] Magics;
#no_reset magic_rook  : [64] Magics;

init_magic_bitboard :: () {

  for i: 0..63 {
    sq := cast(u64) (1 << i);
    {
      using magic_bishop[i];
      mask         = bishop_mask(sq);
      relevant_bit = bishop_relevant_bits[i];
      magic        = find_bishop_magic_number(mask, i, relevant_bit);
    }

    {
      using magic_rook[i];
      mask           = rook_mask(sq);
      relevant_bit   = rook_relevant_bits[i];
      magic          = find_rook_magic_number(mask, i, relevant_bit);
    }
  }

  bishop_relevant_bits :: int.[
    6, 5, 5, 5, 5, 5, 5, 6, 
    5, 5, 5, 5, 5, 5, 5, 5, 
    5, 5, 7, 7, 7, 7, 5, 5, 
    5, 5, 7, 9, 9, 7, 5, 5, 
    5, 5, 7, 9, 9, 7, 5, 5, 
    5, 5, 7, 7, 7, 7, 5, 5, 
    5, 5, 5, 5, 5, 5, 5, 5, 
    6, 5, 5, 5, 5, 5, 5, 6
  ];

  rook_relevant_bits :: int.[
    12, 11, 11, 11, 11, 11, 11, 12, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    12, 11, 11, 11, 11, 11, 11, 12
  ];

}

find_bishop_magic_number :: (attack_mask: u64, sq: int, relevant_bits: int) -> u64 {
  occ:     [4096] u64;
  attacks: [4096] u64;
  used:    [4096] u64;
  occ_indices := 1 << relevant_bits;
  for i: 0..occ_indices-1 {
    bitboard := cast(u64) (1<<sq);
    occ[i] = set_occ(i, relevant_bits, attack_mask);
    attacks[i] = rook_moves(bitboard, occ[i]);
  }

  while true {


  }
  return 0;
}

find_rook_magic_number :: (attack_mask: u64, sq: int, relevant_bits: int) -> u64 {

  return 0;
}

set_occ :: (index: int, bits_in_mask: int, attack_mask: u64) -> u64 {
  occ : u64 = 0;
  for count: 0..bits_in_mask-1 {
    sq := bit_scan_forward(attack_mask);
    attack_mask &= attack_mask - 1;

    if index & (1 << count)
      occ |= xx (1 << sq);
  }
  return occ;
}

bit_scan_forward :: (input: u64)->int #expand {
  result := -1;
  #asm { bsf.q result, input; }
  return result;
}

bishop_mask :: (sq: u64) -> u64 {

  ne := smear_northeast(sq, xx ~(file_h|rank_8));
  se := smear_southeast(sq, xx ~(file_h|rank_1));
  sw := smear_southwest(sq, xx ~(file_a|rank_1));
  nw := smear_northwest(sq, xx ~(file_a|rank_8));

  return ne ^ se ^ sw ^ nw;
}

rook_mask :: (sq: u64) -> u64 {

  n := smear_north(sq, xx ~rank_8);
  s := smear_south(sq, xx ~rank_1);
  w := smear_west (sq, xx ~file_a);
  e := smear_east (sq, xx ~file_h);

  return n ^ s ^ e ^ w;
}

smear_north :: (g: u64, p: u64) -> u64 {
  g |= p & (g <<  8);
  p &=     (p <<  8);
  g |= p & (g << 16);
  p &=     (p << 16);
  g |= p & (g << 32);
  return g;
}

smear_south :: (g: u64, p: u64) -> u64 {
  g |= p & (g >>  8);
  p &=     (p >>  8);
  g |= p & (g >> 16);
  p &=     (p >> 16);
  g |= p & (g >> 32);
  return g;
}

smear_east :: (g: u64, p: u64) -> u64 {
  NOT_A :: cast(u64) ~ file_a;
  p &= NOT_A;
  g |= p & (g << 1);
  p &=     (p << 1);
  g |= p & (g << 2);
  p &=     (p << 2);
  g |= p & (g << 4);
  return g;
}

smear_west :: (g: u64, p: u64) -> u64 {
  NOT_H :: cast(u64) ~ file_h;
  p &= NOT_H;
  g |= p & (g >> 1);
  p &=     (p >> 1);
  g |= p & (g >> 2);
  p &=     (p >> 2);
  g |= p & (g >> 4);
  return g;
}

smear_northeast :: (g: u64, p: u64) -> u64 {
  NOT_A :: cast(u64) ~ file_a;
  p &= NOT_A;
  g |= p & (g << 9);
  p &=     (p << 9);
  g |= p & (g << 18);
  p &=     (p << 18);
  g |= p & (g << 36);
  return g;
}

smear_southeast :: (g: u64, p: u64) -> u64 {
  NOT_A :: cast(u64) ~ file_a;
  p &= NOT_A;
  g |= p & (g >> 7);
  p &=     (p >> 7);
  g |= p & (g >> 14);
  p &=     (p >> 14);
  g |= p & (g >> 28);
  return g;
}

smear_southwest :: (g: u64, p: u64) -> u64 {
  NOT_H :: cast(u64) ~ file_h;
  p &= NOT_H;
  g |= p & (g >> 9);
  p &=     (p >> 9);
  g |= p & (g >> 18);
  p &=     (p >> 18);
  g |= p & (g >> 36);
  return g;
}

smear_northwest :: (g: u64, p: u64) -> u64 {
  NOT_H :: cast(u64) ~ file_h;
  p &= NOT_H;
  g |= p & (g << 7);
  p &=     (p << 7);
  g |= p & (g << 14);
  p &=     (p << 14);
  g |= p & (g << 28);
  return g;
}

rook_moves :: (sq: u64, occ: u64) -> u64 {
  up    := smear_north(sq, ~(occ<<8));
  down  := smear_south(sq, ~(occ>>8));
  right := smear_east (sq, ~(occ<<1));
  left  := smear_west (sq, ~(occ>>1));
  return up ^ down ^ right ^ left;
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


