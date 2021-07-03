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

Piece_Bitboards :: struct {
  w_king :  u64;
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

serialized_bb :: enum s16 {
  a1; b1; c1; d1; e1; f1; g1; h1;
  a2; b2; c2; d2; e2; f2; g2; h2;
  a3; b3; c3; d3; e3; f3; g3; h3;
  a4; b4; c4; d4; e4; f4; g4; h4;
  a5; b5; c5; d5; e5; f5; g5; h5;
  a6; b6; c6; d6; e6; f6; g6; h6;
  a7; b7; c7; d7; e7; f7; g7; h7;
  a8; b8; c8; d8; e8; f8; g8; h8;
}

// from chess programming wiki:
Move16 :: enum s16 {
  Quiet :: 0;
  Double_Pawn_Push;
  King_Castle;
  Queen_Castle;
  Capture;
  Ep_Capture;
  Knight_Promotion;
  Bishop_Promotion;
  Rook_Promotion;
  Queen_Promotion;
  Knight_Promotion_Capture;
  Bishop_Promotion_Capture;
  Rook_Promotion_Capture;
  Queen_Promotion_Capture;
}

generate_move :: inline (x: u64, y: u64, flags: Move16) -> Move16 {
  from := serialize_bit(x);
  to   := serialize_bit(y);
  return xx ((from << 10) | (to << 4) | (xx flags));
}

// Type of move, From, To.
decode_move :: inline (mov: Move16) -> Move16, int, int {
  return  mov & (xx 0xF),  xx (mov & (xx 0xFC00) >> 10), xx (mov & (xx 0x03F0) >> 4);
}

chess_start_pos :: () -> Piece_Bitboards {
  start_pos: Piece_Bitboards;
  start_pos.w_king   = xx e1;
  start_pos.w_queen  = xx d1;
  start_pos.w_rook   = xx a1 | h1;
  start_pos.w_bishop = xx c1 | f1;
  start_pos.w_knight = xx b1 | g1;
  start_pos.w_pawn   = xx rank_2;

  start_pos.b_king   = xx e8;
  start_pos.b_queen  = xx d8;
  start_pos.b_rook   = xx a8 | h8;
  start_pos.b_bishop = xx c8 | f8;
  start_pos.b_knight = xx b8 | g8;
  start_pos.b_pawn   = xx rank_7;
  return start_pos;
}

get_white_pieces :: inline p => p.w_king | p.w_queen | p.w_rook | p.w_bishop | p.w_knight | p.w_pawn;
get_black_pieces :: inline p => p.b_king | p.b_queen | p.b_rook | p.b_bishop | p.b_knight | p.b_pawn;

can_move :: (using piece_bitboards: *Piece_Bitboards, sq: u64, whose_turn: bool) -> bool {
  if whose_turn == true {
    // white turn 
    w_pieces := get_white_pieces(piece_bitboards);
    return (w_pieces & sq) != 0;
  } else {
    // black turn
    b_pieces := get_black_pieces(piece_bitboards);
    return (b_pieces & sq) != 0;
  }
}

make_move_no_checking :: (using piece_bitboards: *Piece_Bitboards, from: u64, to: u64, whose_turn: bool) {

  mov := generate_move(from, to, Move16.Quiet);
  print("(type: %) (from: %) (to: %)\n", 
        mov & (xx 0xF), 
        cast(serialized_bb) (mov & (xx 0xFC00) >> 10),
        cast(serialized_bb) (mov & (xx 0x03F0) >> 4)
  );

  // TODO: this is very naive.
  if whose_turn == true {
    maybe_make_move(w_king);
    maybe_make_move(w_queen);
    maybe_make_move(w_rook);
    maybe_make_move(w_bishop);
    maybe_make_move(w_knight);
    maybe_make_move(w_pawn);
    b_king &= ~to;
    b_queen &= ~to;
    b_rook &= ~to;
    b_bishop &= ~to;
    b_knight &= ~to;
    b_pawn &= ~to;
  } else {
    maybe_make_move(b_king);
    maybe_make_move(b_queen);
    maybe_make_move(b_rook);
    maybe_make_move(b_bishop);
    maybe_make_move(b_knight);
    maybe_make_move(b_pawn);
    w_king &= ~to;
    w_queen &= ~to;
    w_rook &= ~to;
    w_bishop &= ~to;
    w_knight &= ~to;
    w_pawn &= ~to;
  }

  maybe_make_move :: (code: Code) #expand {
    if (#insert code) & from {
      (#insert code) &= ~from;
      (#insert code) |= to;
    }
  }
}

// TODO: figure out what to return.
// TODO: pins are a pain in the ass to figure out. i don't know if this is fully
// correct. but it works pretty robustly...

generate_legal_moves :: (p: *Piece_Bitboards, whose_turn: bool) -> u64 {
  w_pieces := get_white_pieces(p);
  b_pieces := get_black_pieces(p);
  all_pieces := w_pieces | b_pieces;
  if whose_turn {
    attacks := generate_black_attacks(p, all_pieces);
    // check for attacks around the white king
    checks: u64 = 0;
    pins: u64 = 0;
    
    king := p.w_king;
    i := serialize_bit(king);
    k_file := file_of(i);
    k_rank := rank_of(i);
    k_diag := diag_of(i);
    k_adia := adiag_of(i);

    // pawn checks
    checks = checks | (white_pawn_captures(king) & p.b_pawn);

    // knight checks
    checks = checks | (knight_moves(0, 0, king) & p.b_knight);

    xray_rook, king_r_ray := xray_rook_attacks(all_pieces, w_pieces, i, king);
    rook_pin := xray_rook & (p.b_rook | p.b_queen);
    while rook_pin {
      sq: u64 = xx  (1 << serialize_bit(rook_pin));
      pins = pins | between_bitboard(sq, king) & w_pieces;
      rook_pin = rook_pin & (rook_pin - 1);
    }

    xray_bishop, king_b_ray := xray_bishop_attacks(all_pieces, w_pieces, i, king);
    bishop_pin := xray_bishop & (p.b_bishop | p.b_queen);
    while bishop_pin {
      sq: u64 = xx  (1 << serialize_bit(bishop_pin));
      pins = pins | between_bitboard(sq, king) & w_pieces;
      bishop_pin = bishop_pin & (bishop_pin - 1);
    }

    checks = checks | (king_r_ray & (p.b_rook   | p.b_queen));
    checks = checks | (king_b_ray & (p.b_bishop | p.b_queen));

    return pins;
  } else {
    attacks := generate_white_attacks(p, all_pieces);
    // check for attacks around the black king
    checks: u64 = 0;
    pins: u64 = 0;

    king := p.b_king;
    i := serialize_bit(king);
    k_file := file_of(i);
    k_rank := rank_of(i);
    k_diag := diag_of(i);
    k_adia := adiag_of(i);

    // pawn checks
    checks = checks | (black_pawn_captures(king) & p.w_pawn);

    // knight checks
    checks = checks | (knight_moves(0, 0, king) & p.w_knight);

    xray_rook, king_r_ray := xray_rook_attacks(all_pieces, b_pieces, i, king); 
    rook_pin := xray_rook & (p.w_rook | p.w_queen);
    while rook_pin {
      sq: u64 = xx  (1 << serialize_bit(rook_pin));
      pins = pins | between_bitboard(sq, king) & b_pieces;
      rook_pin = rook_pin & (rook_pin - 1);
    }

    xray_bishop, king_b_ray := xray_bishop_attacks(all_pieces, b_pieces, i, king); 
    bishop_pin := xray_bishop & (p.w_bishop | p.w_queen);
    while bishop_pin {
      sq: u64 = xx  (1 << serialize_bit(bishop_pin));
      pins = pins | between_bitboard(sq, king) & b_pieces;
      bishop_pin = bishop_pin & (bishop_pin - 1);
    }

    checks = checks | (king_r_ray & (p.w_rook   | p.w_queen));
    checks = checks | (king_b_ray & (p.w_bishop | p.w_queen));
    return pins;
  }
}

// TODO: optimize attack generation...
generate_white_attacks :: (using p: *Piece_Bitboards, all_pieces: u64) -> u64 {
  // generate white attacks
  w_king_attacks := king_moves(0, 0, w_king); 
  w_queen_attacks: u64 = 0;
  {
    value := w_queen;
    while value {
      i := serialize_bit(value);
      bb: u64 = xx (1 << i);
      w_queen_attacks = w_queen_attacks | queen_moves(all_pieces, i, bb);
      value = value & (value - 1);
    }
  }
  w_rook_attacks: u64 = 0;
  {
    value := w_rook;
    while value {
      i := serialize_bit(value);
      bb: u64 = xx (1 << i);
      w_rook_attacks = w_rook_attacks | rook_moves(all_pieces, i, bb);
      value = value & (value - 1);
    }
  }
  w_bishop_attacks: u64 = 0;
  {
    value := w_bishop;
    while value {
      i := serialize_bit(value);
      bb: u64 = xx (1 << i);
      w_bishop_attacks = w_bishop_attacks | bishop_moves(all_pieces, i, bb);
      value = value & (value - 1);
    }
  }
  w_knight_attacks := knight_moves(all_pieces, 0, w_knight);
  w_pawn_attacks := white_pawn_captures(w_pawn);
  return w_king_attacks | w_queen_attacks | w_rook_attacks | w_bishop_attacks | w_knight_attacks | w_pawn_attacks;
}

// TODO: optimize attack generation...
generate_black_attacks :: (using p: *Piece_Bitboards, all_pieces: u64) -> u64 {
  // generate black attacks
  b_king_attacks := king_moves(0, 0, b_king); 
  b_queen_attacks: u64 = 0;
  {
    value := b_queen;
    while value {
      i := serialize_bit(value);
      bb: u64 = xx (1 << i);
      b_queen_attacks = b_queen_attacks | queen_moves(all_pieces, i, bb);
      value = value & (value - 1);
    }
  }
  b_rook_attacks: u64 = 0;
  {
    value := b_rook;
    while value {
      i := serialize_bit(value);
      bb: u64 = xx (1 << i);
      b_rook_attacks = b_rook_attacks | rook_moves(all_pieces, i, bb);
      value = value & (value - 1);
    }
  }
  b_bishop_attacks: u64 = 0;
  {
    value := b_bishop;
    while value {
      i := serialize_bit(value);
      bb: u64 = xx (1 << i);
      b_bishop_attacks = b_bishop_attacks | bishop_moves(all_pieces, i, bb);
      value = value & (value - 1);
    }
  }
  b_knight_attacks := knight_moves(all_pieces, 0, b_knight);
  b_pawn_attacks := black_pawn_captures(b_pawn);
  return b_king_attacks | b_queen_attacks | b_rook_attacks | b_bishop_attacks | b_knight_attacks | b_pawn_attacks;
}

possible_moves_for :: (using piece_bitboards: *Piece_Bitboards, b: u64, whose_turn: bool) -> u64 {
  w_pieces := get_white_pieces(piece_bitboards);
  b_pieces := get_black_pieces(piece_bitboards);
  all_pieces := w_pieces | b_pieces;
  i := serialize_bit(b);
  if whose_turn {
    do_piece(w_king, w_pieces, king_moves);
    do_piece(w_queen, w_pieces, queen_moves);
    do_piece(w_rook, w_pieces, rook_moves);
    do_piece(w_bishop, w_pieces, bishop_moves);
    do_piece(w_knight, w_pieces, knight_moves);
    do_piece(w_pawn, w_pieces, white_pawn_moves);
  } else {
    do_piece(b_king, b_pieces, king_moves);
    do_piece(b_queen, b_pieces, queen_moves);
    do_piece(b_rook, b_pieces, rook_moves);
    do_piece(b_bishop, b_pieces, bishop_moves);
    do_piece(b_knight, b_pieces, knight_moves);
    do_piece(b_pawn, b_pieces, black_pawn_moves);
  }

  return 0;

  do_piece :: (bboard: u64, friends: u64, $move_funct: #type (u64,int,u64,u64)->u64 ) #expand {
    if b & bboard {
      `return move_funct(all_pieces, i, b, friends);
    }
  }
}

xray_rook_attacks :: (occ: u64, blockers: u64, i: int, rook_sq: u64) -> u64, u64 {
  attacks := rook_moves(occ, i, rook_sq);
  blockers &= attacks;
  return attacks ^ rook_moves(occ ^ blockers, i, rook_sq), attacks;
}

xray_bishop_attacks :: (occ: u64, blockers: u64, i: int, bishop_sq: u64) -> u64, u64 {
  attacks := bishop_moves(occ, i, bishop_sq);
  blockers &= attacks;
  return attacks ^ bishop_moves(occ ^ blockers, i, bishop_sq), attacks;
}

white_pawn_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  up1 := (slider << 8) & ~occupied;
  captures := white_pawn_captures(slider) & (occupied & ~friends);
  pawn_power := ((up1 & (xx rank_3)) << 8) & ~occupied;
  return up1 | captures | pawn_power;
}

black_pawn_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  up1 := (slider >> 8) & ~occupied;
  captures := black_pawn_captures(slider) & (occupied & ~friends);
  pawn_power := ((up1 & (xx rank_6)) >> 8) & ~occupied;
  return up1 | captures | pawn_power;
}

bishop_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  diag_slide  := sliding(occupied, slider,  diag_of(i));
  adiag_slide := sliding(occupied, slider, adiag_of(i));
  return (diag_slide | adiag_slide) & ~friends;
}

knight_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  east1 := (slider << 1) & xx ~file_a;
  west1 := (slider >> 1) & xx ~file_h;
  east2 := (east1  << 1) & xx ~file_a;
  west2 := (west1  >> 1) & xx ~file_h;
  sqs1 := east1 | west1;
  sqs2 := east2 | west2;
  return ((sqs2 << 8) | (sqs2 >> 8) | (sqs1 << 16) | (sqs1 >> 16)) & ~friends;
}

rook_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  file_slide := sliding(occupied, slider, file_of(i));        
  rank_slide := sliding(occupied, slider, rank_of(i));        
  return (file_slide | rank_slide) & ~friends;
} 

queen_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  file_slide  := sliding(occupied, slider,  file_of(i));        
  rank_slide  := sliding(occupied, slider,  rank_of(i));        
  diag_slide  := sliding(occupied, slider,  diag_of(i));
  adiag_slide := sliding(occupied, slider, adiag_of(i));
  return (file_slide | rank_slide | diag_slide | adiag_slide) & ~friends;
}

king_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  k := slider | ((slider << 1) & xx ~file_a) | ((slider >> 1) & xx ~file_h);
  neighbors := (k | (k << 8) | (k >> 8)) & ~slider;
  return neighbors & ~friends;
}

white_pawn_captures :: inline (slider: u64) -> u64 {
  return ((slider << 9) & xx ~file_a) | ((slider << 7) & xx ~file_h);
}

black_pawn_captures :: inline (slider: u64) -> u64 {
  return ((slider >> 7) & xx ~file_a) | ((slider >> 9) & xx ~file_h);
}

file_of :: inline (i: int) -> u64 {
  assert(0 <= i && i <= 63);
  f := i & 7;
  file: u64 = (cast(u64) file_a) << f;
  return file;
}

rank_of :: inline (i: int) -> u64 {
  assert(0 <= i && i <= 63);
  r := i & ~7;
  rank: u64 = (cast(u64) rank_1) << r;
  return rank;
}

diag_of :: inline (i: int)->u64 {
  assert(0 <= i && i <= 63);
  f := (i & ~7) >> 3;
  r := i & 7;
  index := 7 + f - r;
  return xx diags[index];
}

adiag_of :: inline (i: int)->u64 {
  assert(0 <= i && i <= 63);
  f := (i & ~7) >> 3;
  r := i & 7;
  index := f + r;
  return xx a_diags[index];
}

serialize_bit :: trailing_zeros;

print_bitboard :: (b: u64) {
  #import "Basic";
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

// TODO: This function is WAY to slow...
// Actually, I don't know whether this is okay or too slow...can't tell....
init_global_bitboards :: () {
  for i: 0..63 {
    bb1: u64 = xx (1 << i);
    for j: (i+1)..63 {
      if between_look_up_table[i][j] != 0 continue;
      bb2: u64 = xx (1 << j);
      
      f := file_of(i);
      if f & bb2 {
        bb_file := sliding(bb1, bb2, f) & ~(bb1|bb2);
        between_look_up_table[i][j] = bb_file;
        between_look_up_table[j][i] = bb_file;
        continue;
      }

      r := rank_of(i);
      if r & bb2 {
        bb_rank := sliding(bb1, bb2, r) & ~(bb1|bb2);
        between_look_up_table[i][j] = bb_rank;
        between_look_up_table[j][i] = bb_rank;
        continue;
      }

      d := diag_of(i);
      if d & bb2 {
        bb_diag := sliding(bb1, bb2, d) & ~(bb1|bb2);
        between_look_up_table[i][j] = bb_diag;
        between_look_up_table[j][i] = bb_diag;
        continue;
      }

      a := adiag_of(i);
      if a & bb2 {
        bb_adia := sliding(bb1, bb2, a) & ~(bb1|bb2);
        between_look_up_table[i][j] = bb_adia;
        between_look_up_table[j][i] = bb_adia;
      } 
    } 
  }
}

#scope_file

// o = occupied, r = piece, m = mask
sliding :: inline (o: u64, r: u64, m: u64) -> u64 {
  o_bar := bit_reverse64(o & m);
  r_bar := bit_reverse64(r);
  return (((o & m) - (2*r)) ^ bit_reverse64(o_bar - (2*r_bar))) & m;
}

sliding_half_1 :: inline (o: u64, r: u64) -> u64 {
  return o - (2*r);
}

sliding_half_2 :: inline (o: u64, r: u64) -> u64 {
  o_bar := bit_reverse64(o);
  r_bar := bit_reverse64(r);
  return bit_reverse64(o_bar - (2*r_bar));
}

between_bitboard :: (i: u64, j: u64) -> u64 {
  ii := serialize_bit(i);
  jj := serialize_bit(j);
  ret := between_look_up_table[ii][jj];
  return ret;
}

// this look-up table can be found inside stockfish chess engine.
// I don't know whether it is correct... might be a bit slow...
between_look_up_table: [64][64] u64;

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

