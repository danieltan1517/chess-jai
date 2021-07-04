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

generate_move :: inline (f: u64, t: u64, flags: Move16) -> Move16 {
  from := serialize_bit(f);
  to   := serialize_bit(t);
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
     return generate_moves_for(occupied=all_pieces, pieces=w_pieces, opp_pieces=b_pieces,
       king=p.w_king,     queen=p.w_queen,     rook=p.w_rook,     bishop=p.w_bishop,     knight=p.w_knight,     pawn=p.w_pawn,
       opp_king=p.b_king, opp_queen=p.b_queen, opp_rook=p.b_rook, opp_bishop=p.b_bishop, opp_knight=p.b_knight, opp_pawn=p.b_pawn,
       whose_turn=whose_turn);
  } else {
     return generate_moves_for(occupied=all_pieces, pieces=b_pieces, opp_pieces=w_pieces,
       king=p.b_king,     queen=p.b_queen,     rook=p.b_rook,     bishop=p.b_bishop,     knight=p.b_knight,     pawn=p.b_pawn,
       opp_king=p.w_king, opp_queen=p.w_queen, opp_rook=p.w_rook, opp_bishop=p.w_bishop, opp_knight=p.w_knight, opp_pawn=p.w_pawn,
       whose_turn=whose_turn);
  }
}

generate_moves_for :: (occupied: u64, pieces: u64, opp_pieces: u64, 
                       king: u64,     queen: u64,     rook: u64,     bishop: u64,     knight: u64,     pawn: u64,
                       opp_king: u64, opp_queen: u64, opp_rook: u64, opp_bishop: u64, opp_knight: u64, opp_pawn: u64,
                       whose_turn: bool) -> u64 {
  // TODO: really need to fix this!!!!!
  attacks := generate_attacks(occ=occupied, 
               king=opp_king, queen=opp_queen, rook=opp_rook, bishop=opp_bishop, knight=opp_knight, pawn=opp_pawn, 
               whose_turn=!whose_turn);

  checks: u64 = 0;
  pins: u64 = 0;
  i := serialize_bit(king);
  k_file := file_of(i);
  k_rank := rank_of(i);
  k_diag := diag_of(i);
  k_adia := adiag_of(i);
  // pawn checks
  checks = checks | (white_pawn_captures(king) & opp_pawn);

  // knight checks
  checks = checks | (knight_moves(0, 0, king) & opp_knight);

  xray_rook, king_r_ray := xray_rook_attacks(occupied, pieces, i, king);
  rook_pin := xray_rook & (opp_rook | opp_queen);
  while rook_pin {
    sq: u64 = xx  (1 << serialize_bit(rook_pin));
    between_sqs := between_bitboard(sq, king);
    pinned_piece := between_sqs & pieces;

    // no knight/bishop
    // pawn vertical only, NO pawn horizontal, since pawns cannot move horizontally
    if (pawn & pinned_piece & k_file) {
      if whose_turn {
        // REMEMBER: There is double pawn push!
        move := (pinned_piece << 8) & ~occupied;
        move = move | ((move & xx rank_3) << 8) & ~occupied;
      } else {
        // REMEMBER: There is double pawn push!
        move := (pinned_piece >> 8) & ~occupied;
        move = move | ((move & xx rank_6) >> 8) & ~occupied;
      }
    }

    if (queen|rook) & pinned_piece {
      valid_moves := (between_sqs | sq) & ~pinned_piece;
      // make pinned piece moves.
    }

    pins = pins | pinned_piece;
    rook_pin = rook_pin & (rook_pin - 1);
  }

  xray_bishop, king_b_ray := xray_bishop_attacks(occupied, pieces, i, king);
  bishop_pin := xray_bishop & (opp_bishop | opp_queen);
  while bishop_pin {
    sq: u64 = xx  (1 << serialize_bit(bishop_pin));
    between_sqs := between_bitboard(sq, king);
    pinned_piece := between_sqs & pieces;

    // no rooks/knights

    // pawn diagonal moves only, if pawn is pinned, there is only one possible move.
    if whose_turn {
      pawn_moves := white_pawn_captures(pawn) & opp_pieces & between_sqs;
      if pawn_moves {
     
      }
    } else {
      pawn_moves := black_pawn_captures(pawn) & opp_pieces & between_sqs;
      if pawn_moves {
     
      }
    }

    if (queen|bishop) & pinned_piece {
      valid_moves := (between_sqs | sq) & ~pinned_piece;
      // make pinned piece moves.
    }

    pins = pins | pinned_piece;
    bishop_pin = bishop_pin & (bishop_pin - 1);
  }

  checks = checks | (king_r_ray & (opp_rook | opp_queen));
  checks = checks | (king_b_ray & (opp_bishop | opp_queen));

  // eliminate pieces already handled by pins.
  queen  &= ~pins;
  rook   &= ~pins;
  bishop &= ~pins;
  knight &= ~pins;
  pawn   &= ~pins;

  return attacks;
}

// TODO: should we return the piece attacks separately or together?
// when whose_turn = true, 
//    return white attacks, 
// else 
//    return black attacks,
// generate attacks deals with king safe squares.

generate_attacks :: (occ: u64, king: u64, queen: u64, rook: u64, bishop: u64, knight: u64, pawn: u64, whose_turn: bool) -> u64 {
  // generate white attacks
  king_attacks := king_moves(0, 0, king); 
  queen_attacks: u64 = 0;
  while queen {
    i := serialize_bit(queen);
    bb: u64 = xx (1 << i);
    queen_attacks = queen_attacks | queen_moves(occ, i, bb);
    queen = queen & (queen-1);
  }
  rook_attacks: u64 = 0;
  while rook {
    i := serialize_bit(rook);
    bb: u64 = xx (1 << i);
    rook_attacks = rook_attacks | rook_moves(occ, i, bb);
    rook = rook & (rook-1);
  }
  bishop_attacks: u64 = 0;
  while bishop {
    i := serialize_bit(bishop);
    bb: u64 = xx (1 << i);
    bishop_attacks = bishop_attacks | bishop_moves(occ, i, bb);
    bishop = bishop & (bishop - 1);
  }

  knight_attacks := knight_moves(occ, 0, knight);
  pawn_attacks := ifx whose_turn white_pawn_captures(pawn) else black_pawn_captures(pawn);
  return king_attacks | queen_attacks | rook_attacks | bishop_attacks | knight_attacks | pawn_attacks;
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

//bb_file := sliding(bb1, bb2, f) & ~(bb1|bb2);
// TODO: This function is WAY to slow...
// Actually, I don't know whether this is okay or too slow...can't tell....
init_global_bitboards :: () {
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
        i := serialize_bit(xx iii);
        j := serialize_bit(xx yy);
        entry := file_entry & ~(iii|yy);
        between_look_up_table[i][j] = xx entry;
        between_look_up_table[j][i] = xx entry;
        file_entry = file_entry & ~iii;
        iii = iii << num;
      }
      ff = ff & ~yy;
      yy = yy >> num;
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

between_bitboard :: inline (i: u64, j: u64) -> u64 {
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

