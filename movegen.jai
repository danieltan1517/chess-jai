bishop_moves :: (sq: int, occ: u64) -> u64 #expand {
  using magic_bishop[sq];
  occ &= mask;
  occ *= magic;
  occ >>= 64 - relevant_bit;
  return bishop_attacks[sq][occ];
}

rook_moves :: (sq: int, occ: u64) -> u64 #expand {
  using magic_rook[sq];
  occ &= mask;
  occ *= magic;
  occ >>= 64 - relevant_bit;
  return rook_attacks[sq][occ];
}

king_moves :: (bitboard: u64) -> u64 #expand {
  l := (bitboard << 1) & xx ~file_a;
  r := (bitboard >> 1) & xx ~file_h;
  k := bitboard | l | r;
  return l | r | (k << 8) | (k >> 8);
}

knight_moves :: (bitboard: u64) -> u64 #expand {
  l1 := (bitboard << 1) & xx (~file_a);
  r1 := (bitboard >> 1) & xx (~file_h);
  l2 := (l1 << 1) & xx (~file_a);
  r2 := (r1 >> 1) & xx (~file_h);
  s1 := l1 | r1;
  s2 := l2 | r2;
  return (s2 << 8) | (s2 >> 8) | (s1 << 16) | (s1 >> 16);
}

pawn_captures :: (bitboard: u64, $turn: Turn) -> u64 #expand {
  using Side;
  #if turn == WHITE then {
    l := (bitboard << 7) & xx ~file_h;
    r := (bitboard << 9) & xx ~file_a;
    return l | r;
  }

  #if turn == BLACK then {
    l := (bitboard >> 9) & xx ~file_h;
    r := (bitboard >> 7) & xx ~file_a;
    return l | r;
  }
}

pawn_advance :: (bitboard: u64, $t: Turn) -> u64 #expand {
  using Turn;
  #if t == WHITE then {
    return bitboard << 8;
  }

  #if t == BLACK then {
    return bitboard >> 8;
  }
}

pawn_push_rank :: ($t: Turn) -> u64 #expand {
  using Turn;
  #if t == WHITE then {
    return xx rank_3;
  }

  #if t == BLACK then {
    return xx rank_6;
  }
}

init_magic_bitboards :: () {
  print("initializing magic bitboards.\n");
  init_magic_bitboard();
  print("magic bitboards initialized :)\n");
}

generate_moves :: (using chess: *Chess, $T: Type) -> T, ChessFlags {
  if #complete chess.side == {
  case Side.WHITE;
    moves, flags := generate_moves_for(chess, Side.WHITE, T);
    return moves, flags;

  case Side.BLACK;
    moves, flags := generate_moves_for(chess, Side.BLACK, T);
    return moves, flags;

  }
}

ChessFlags :: enum {
  Normal;
  Check;
  Checkmate;
  Stalemate;
  Insufficent_Material;
}

init_global_bitboards :: () {
  init_magic_bitboards();
  init_between_bitboards();
}

#scope_file

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

  en_passant: u64;
  castling: Castling;
  turn: Turn;

  Castling :: enum_flags u8 {
    W_KS;
    W_QS;
    B_KS;
    B_QS;
    All :: W_KS|W_QS|B_KS|B_QS;
  }
}

Turn :: enum s32 { WHITE :: 0; BLACK :: 1; };

Bitboard :: enum_flags u64 {
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

generate_moves_for :: (chess: *Chess, $turn: Turn, $T: Type) -> T, ChessFlags {
  opp :: turn ^ 1; 

  move_gen: T;

  unsafe, check, block := generate_attacks(chess, opp);
  king    := get_bitboard(chess, turn, "king");
  king_sq := bit_scan_forward(king);
  queen   := get_bitboard(chess, turn, "queen");
  rook    := get_bitboard(chess, turn, "rook");
  bishop  := get_bitboard(chess, turn, "bishop");
  knight  := get_bitboard(chess, turn, "knight"); 
  pawn    := get_bitboard(chess, turn, "pawn");

  pieces := king|queen|rook|bishop|knight|pawn;

  num_checks := popcount(check);

  if num_checks > 1 {
    // double check.
    to := king_moves(king) & ~unsafe & ~pieces;

    return move_gen;
  }

  if num_checks == 1 {
    // single check.
    pinned : u64 = 0;
    opp_qr := get_bitboard(chess, opp, "queen") | get_bitboard(chess, opp, "rook");
    xray_rook := xray_rook_attacks(king_sq, occupied, pieces) & opp_qr;

    while xray_rook {
      sq := bit_scan_forward(xray_rook);
      pinned |= between_squares(sq, king_sq) & occupied;
      xray_rook &= xray_rook - 1;
    }

    opp_qb := get_bitboard(chess, opp, "queen") | get_bitboard(chess, opp, "bishop");
    xray_bishop := xray_bishop_attacks(king_sq, occupied, pieces) & opp_qb;

    while xray_bishop {
      sq := bit_scan_forward(xray_bishop);
      pinned |= between_squares(sq, king_sq) & occupied;
      xray_bishop &= xray_bishop - 1;
    }

    queen  &= ~pinned;
    rook   &= ~pinned;
    bishop &= ~pinned;
    knight &= ~pinned;
    pawn   &= ~pinned;

    // pawn captures
    pawn_capture_move := pawn_captures(check, opp) & pawn;

    // pawn advances block
    pawn_forward_move := pawn_advance(block, opp) & pawn;

    // pawn push block
    pawn_push_move := pawn_advance(advance1 & ~pieces & pawn_push_rank(turn), opp) & pawn;

    // en passant
    enpassant_move := check & pawn_advace(en_passant, opp);



  } else {
    opp_qr := get_bitboard(chess, opp, "queen") | get_bitboard(chess, opp, "rook");
    xray_rook := xray_rook_attacks(king_sq, occupied, pieces) & opp_qr;




    opp_qb := get_bitboard(chess, opp, "queen") | get_bitboard(chess, opp, "bishop");
    xray_bishop := xray_bishop_attacks(king_sq, occupied, pieces) & opp_qb;


  }

}

xray_rook_attacks :: (sq: int, occ: u64, blockers: u64) -> u64 {
  attacks := rook_moves(sq, occ);
  blockers &= attacks;
  occ ^= blockers;
  attacks ^= rook_moves(sq, occ);
  return attacks;
}

xray_bishop_attacks :: (sq: int, occ: u64, blockers: u64) -> u64 {
  attacks := bishop_moves(sq, occ);
  blockers &= attacks;
  occ ^= blockers;
  attacks ^= bishop_moves(sq, occ);
  return attacks; 
}

generate_attacks :: (chess: *Chess, $turn: Turn) -> att: u64, check: u64, block: u64 {
  opp :: turn ^ 1;
  att:   u64 = 0;
  check: u64 = 0;
  block: u64 = 0;

  opp_king := get_bitboard(chess, opp, "king");
  occupied := chess.occupied & ~opp_king;

  king   := get_bitboard(chess, turn, "king");
  queen  := get_bitboard(chess, turn, "queen");
  rook   := get_bitboard(chess, turn, "rook");
  bishop := get_bitboard(chess, turn, "bishop");
  knight := get_bitboard(chess, turn, "knight"); 
  pawn   := get_bitboard(chess, turn, "pawn");

  king_index := bit_scan_forward(king);

  att |= king_moves(king);

  knight_bitboard := knight_moves(knight);
  att |= knight_bitboard;
  check |= knight_moves(opp_king) & knight;

  pawn_bitboard := pawn_captures(pawn, turn);
  att |= pawn_bitboard;
  check |= pawn_captures(opp_king, opp) & pawn;

  queen_rook := queen | rook;
  while queen_rook {
    sq := bit_scan_forward(queen_rook);
    bitboard := rook_moves(sq, occupied);
    att |= bitboard;
    if opp_king & bitboard then {
      check |= xx 1 << sq;
      block |= between_squares(sq, king_index);
    }
    queen_rook &= queen_rook - 1;
  }

  queen_bishop := queen | bishop;
  while queen_bishop {
    sq := bit_scan_forward(queen_bishop);
    bitboard := bishop_moves(sq, occupied);
    att |= bitboard;
    if opp_king & bitboard then {
      check |= xx 1 << sq;
      block |= between_squares(sq, king_index);
    }
    queen_bishop &= queen_bishop - 1;
  }

  return att, check, block;
}

get_bitboard :: (chess: *Chess, $turn: Turn, $piece_name: string) -> u64 #expand {
  #insert -> string {
    #if side == Turn.WHITE {
      return sprint("return chess.w_%;\n", piece_name);
    }

    #if side == Turn.BLACK {
      return sprint("return chess.b_%;\n", piece_name);
    }
  }
}

PRNG :: struct {
  seed: u64;
}

random_u64 :: (using p: *PRNG) -> u64 {
  seed ^= seed >> 12;
  seed ^= seed << 25;
  seed ^= seed >> 27;
  return seed * 2685821657736338717;
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
  relevant_bit: u64;
}

// magics
magic_bishop: [64] Magics;
magic_rook  : [64] Magics;

// attacks
bishop_attacks: [64][512]  u64;
rook_attacks:   [64][4096] u64;

init_magic_bitboard :: () {
  for i: 0..63 {
    sq := cast(u64) (1 << i);
    {
      using magic_bishop[i];
      mask         = bishop_mask(sq);
      relevant_bit = bishop_relevant_bits[i];
      magic        = find_magic_number(mask, i, relevant_bit, __bishop_moves);
    }

    {
      using magic_rook[i];
      mask           = rook_mask(sq);
      relevant_bit   = rook_relevant_bits[i];
      magic          = find_magic_number(mask, i, relevant_bit, __rook_moves);
    }
  }

  for sq: 0..63 {
    bitboard := cast(u64) (1 << sq);
    calc_bishop_attacks(*magic_bishop[sq]);
    calc_rook_attacks(*magic_rook[sq]);

    calc_bishop_attacks :: (using m: *Magics) #expand {
      count := cast(u64) popcount(mask);
      occ_indices := 1 << count;
      for i: 0..occ_indices-1 {
        occ := set_occ(i, count, mask);
        magic_index := (occ * magic) >> (64 - relevant_bit);
        bishop_attacks[sq][magic_index] = __bishop_moves(bitboard, occ);
      }
    }

    calc_rook_attacks :: (using m: *Magics) #expand {
      count := cast(u64) popcount(mask);
      occ_indices := 1 << count;
      for i: 0..occ_indices-1 {
        occ := set_occ(i, count, mask);
        magic_index := (occ * magic) >> (64 - relevant_bit);
        rook_attacks[sq][magic_index] = __rook_moves(bitboard, occ);
      }
    }
  }

  bishop_relevant_bits :: u64.[
    6, 5, 5, 5, 5, 5, 5, 6, 
    5, 5, 5, 5, 5, 5, 5, 5, 
    5, 5, 7, 7, 7, 7, 5, 5, 
    5, 5, 7, 9, 9, 7, 5, 5, 
    5, 5, 7, 9, 9, 7, 5, 5, 
    5, 5, 7, 7, 7, 7, 5, 5, 
    5, 5, 5, 5, 5, 5, 5, 5, 
    6, 5, 5, 5, 5, 5, 5, 6
  ];

  rook_relevant_bits :: u64.[
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

find_magic_number :: (attack_mask: u64, sq: int, relevant_bits: u64, $moves: (u64,u64)->u64) -> u64 {
  occ:     [4096] u64;
  attacks: [4096] u64;
  used:    [4096] u64;
  occ_indices := 1 << relevant_bits;
  seeds :: u64.[728, 10316, 55013, 32803, 12281, 15100,  16645, 255];
  rank := sq / 8;

  prng: PRNG;
  prng.seed = seeds[rank];

  for i: 0..occ_indices-1 {
    bitboard := cast(u64) (1<<sq);
    occ[i] = set_occ(i, relevant_bits, attack_mask);
    attacks[i] = moves(bitboard, occ[i]);
  }


  while true {
    magic_number := generate_magic_number(*prng);
    if popcount((attack_mask*magic_number) & 0xFF00000000000000) < 6 then
      continue;

    memset(used.data, 0, size_of(type_of(used)));
    fail := false;
    for i: 0..occ_indices-1 {
      magic_index := (occ[i] * magic_number) >> (64 - relevant_bits);
      // if magic index works.
      if used[magic_index] == 0 then {
        // magic index works.
        used[magic_index] = attacks[i];

      } else if used[magic_index] != attacks[i] then {
        // magic index fails.
        fail = true;
        break;
      }
    }

    if !fail then {
      return magic_number;
    }
  }

  print("magic_number generation failed.\n");
  return 0;

  // We need a sparse random number to generate magic bitboards fast
  generate_magic_number :: (p: *PRNG) -> u64 #expand {
    return random_u64(p) & random_u64(p) & random_u64(p);
  }
}

set_occ :: (index: int, bits_in_mask: u64, attack_mask: u64) -> u64 {
  occ : u64 = 0;
  for count: 0..bits_in_mask-1 {
    sq := bit_scan_forward(attack_mask);
    attack_mask &= cast(u64) (~(1 << sq));

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

popcount :: (value: u64) -> int #expand {
  result: int;
  #asm { popcnt.q  result, value; }
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

__rook_moves :: (sq: u64, occ: u64) -> u64 {
  n := smear_north(sq, ~(occ<<8));
  s := smear_south(sq, ~(occ>>8));
  e := smear_east (sq, ~((occ<<1) & (xx ~file_a)));
  w := smear_west (sq, ~((occ>>1) & (xx ~file_h)));
  return n ^ s ^ e ^ w;
} 

__bishop_moves :: (sq: u64, occ: u64) -> u64 {
  ne := smear_northeast(sq, ~((occ<<9) & (xx ~ file_a)));
  se := smear_southeast(sq, ~((occ>>7) & (xx ~ file_a)));
  sw := smear_southwest(sq, ~((occ>>9) & (xx ~ file_h)));
  nw := smear_northwest(sq, ~((occ<<7) & (xx ~ file_h)));
  return ne ^ se ^ sw ^ nw;
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

init_between_bitboards :: () {
  init_lines(a1, a8, file_a, 8);
  init_lines(b1, b8, file_b, 8);
  init_lines(c1, c8, file_c, 8);
  init_lines(d1, d8, file_d, 8);
  init_lines(e1, e8, file_e, 8);
  init_lines(f1, f8, file_f, 8);
  init_lines(g1, g8, file_g, 8);
  init_lines(h1, h8, file_h, 8);

  init_lines(a1, h1, rank_1, 1);
  init_lines(a2, h2, rank_2, 1);
  init_lines(a3, h3, rank_3, 1);
  init_lines(a4, h4, rank_4, 1);
  init_lines(a5, h5, rank_5, 1);
  init_lines(a6, h6, rank_6, 1);
  init_lines(a7, h7, rank_7, 1);
  init_lines(a8, h8, rank_8, 1);

  init_lines(f1, h3, f1|g2|h3, 9);
  init_lines(e1, h4, e1|f2|g3|h4, 9);
  init_lines(d1, h5, d1|e2|f3|g4|h5, 9);
  init_lines(c1, h6, c1|d2|e3|f4|g5|h6, 9);
  init_lines(b1, h7, b1|c2|d3|e4|f5|g6|h7, 9);
  init_lines(a1, h8, a1|b2|c3|d4|e5|f6|g7|h8, 9);
  init_lines(a2, g8, a2|b3|c4|d5|e6|f7|g8, 9);
  init_lines(a3, f8, a3|b4|c5|d6|e7|f8, 9);
  init_lines(a4, e8, a4|b5|c6|d7|e8, 9);
  init_lines(a5, d8, a5|b6|c7|d8, 9);
  init_lines(a6, c8, a6|b7|c8, 9);

  init_lines(c1, a3, a3|b2|c1, 7);
  init_lines(d1, a4, a4|b3|c2|d1, 7);
  init_lines(e1, a5, a5|b4|c3|d2|e1, 7);
  init_lines(f1, a6, a6|b5|c4|d3|e2|f1, 7);
  init_lines(g1, a7, a7|b6|c5|d4|e3|f2|g1, 7);
  init_lines(h1, a8, a8|b7|c6|d5|e4|f3|g2|h1, 7);
  init_lines(h2, b8, b8|c7|d6|e5|f4|g3|h2, 7);
  init_lines(h3, c8, c8|d7|e6|f5|g4|h3, 7);
  init_lines(h4, d8, d8|e7|f6|g5|h4, 7);
  init_lines(h5, e8, e8|f7|g6|h5, 7);
  init_lines(h6, f8, f8|g7|h6, 7);

  // this runs 2x faster in release mode when just a function rather than a macro.
  init_lines :: (a: bboard, b: bboard, file: bboard, $num: int) {
    ff := file;
    yy := b;
    while yy != a {
      iii := a;
      file_entry := ff;
      while iii != yy {
        i := bit_scan_forward(xx iii);
        j := bit_scan_forward(xx yy);
        entry := file_entry & (~(iii|yy));
        between_look_up_table[i][j] = xx entry;
        between_look_up_table[j][i] = xx entry;
        file_entry = file_entry & (~iii);
        iii = iii << num;
      }
      ff = ff & (~yy);
      yy = yy >> num;
    }
  }
}

#scope_export 
// this look-up table can be found inside stockfish chess engine.
// I don't know whether it is correct... might be a bit slow...
between_look_up_table: [64][64] u64;

between_squares :: inline (i: int, j: int) -> u64 #expand {
  return between_look_up_table[i][j];
}

#import "Basic";

