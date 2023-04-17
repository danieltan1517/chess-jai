Move16 :: enum s16 {
  Quiet;
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

// fen string parsing with error checking.
chess_fen :: (chess: *Chess, fen_string: string) -> bool {
  memset(chess, 0, size_of(Chess));
  tokens := split(fen_string, " ");
  rows   := split(tokens[0], "/");
  for tokens {
    if !it remove it;
  }
  for rows {
    if !it remove it;
  }
  // handle whose turn it is
  if tokens.count < 4 || tokens.count > 6 then {
    print("Unidentifiable fen string: %\n", tokens);
    return false;
  }
  if rows.count != 8 then {
    print("Unidentifiable board string: %\n", rows);
    return false;
  }

  for token, i: rows {
    sq := (7-i)*8;
    for j: 0..token.count-1 {
      char := token[j];
      if char >= #char "1" && char <= #char "8" then {
        sq += char - #char "1" + 1;
      } else if char == #char "P" then {
        chess.pieces[sq] = Piece.W_PAWN;
        chess.w_pawn |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "p" then {
        chess.pieces[sq] = Piece.B_PAWN;
        chess.b_pawn |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "Q" then {
        chess.pieces[sq] = Piece.W_QUEEN;
        chess.w_queen |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "q" then {
        chess.pieces[sq] = Piece.B_QUEEN;
        chess.b_queen |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "K" then {
        chess.pieces[sq] = Piece.W_KING;
        chess.w_king |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "k" then {
        chess.pieces[sq] = Piece.B_KING;
        chess.b_king |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "N" then {
        chess.pieces[sq] = Piece.W_KNIGHT;
        chess.w_knight |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "n" then {
        chess.pieces[sq] = Piece.B_KNIGHT;
        chess.b_knight |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "R" then {
        chess.pieces[sq] = Piece.W_ROOK;
        chess.w_rook |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "r" then {
        chess.pieces[sq] = Piece.B_ROOK;
        chess.b_rook |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "B" then {
        chess.pieces[sq] = Piece.W_BISHOP;
        chess.w_bishop |= cast(u64)(1 << sq);
        sq += 1;
      } else if char == #char "b" then {
        chess.pieces[sq] = Piece.B_BISHOP;
        chess.b_bishop |= cast(u64)(1 << sq);
        sq += 1;
      } else {
        print("Invalid fen character: %\n", char);
        memset(chess, 0, size_of(Chess));
        return false;
      }
    }
  }
  chess.occupied |= get_pieces(chess);

  side := tokens[1];
  if equal(side, "w") then {
    chess.turn = Turn.WHITE;
  } else if equal(side, "b") then {
    chess.turn = Turn.BLACK;
  } else {
    print("Invalid FEN turn notation\n");
    memset(chess, 0, size_of(Chess));
    return false;
  }

  castling_string := tokens[2];
  if equal(castling_string, "-") {
    chess.castling = 0;
  } else {
    for i: 0..castling_string.count-1 {
      letter := castling_string[i];
      if letter == #char "K" then {
        chess.castling |= Castling.W_KS;
      } else if letter == #char "Q" then {
        chess.castling |= Castling.W_QS;
      } else if letter == #char "k" then {
        chess.castling |= Castling.B_KS;
      } else if letter == #char "q" then {
        chess.castling |= Castling.B_QS;
      } else {
        print("Invalid FEN castling flags\n");
        memset(chess, 0, size_of(Chess));
        return false;
      }
    }
  }

  en_passant_string := tokens[3];
  if equal(en_passant_string, "-") {
    chess.en_passant = 0;
  } else {
    if en_passant_string.count != 2 {
      print("Invalid En Passant Square\n");
      memset(chess, 0, size_of(Chess));
      return false;
    }
    r := cast(int)(en_passant_string[0] - #char "a");
    c := cast(int)(en_passant_string[1] - #char "1");
    bitboard := cast(u64) (1 << (c*8 + r));
    if chess.turn == Turn.WHITE && bitboard & (xx ~rank_6) then {
      print("Invalid En Passant Square\n");
      memset(chess, 0, size_of(Chess));
      return false;
    } else if chess.turn == Turn.BLACK && bitboard & (xx ~rank_3) then {
      print("Invalid En Passant Square\n");
      memset(chess, 0, size_of(Chess));
      return false;
    } else {
      chess.en_passant = bitboard;
    }
  }
  chess.hash = zobrist_hash(chess);
  return true;

}

to_fen_string :: (chess: *Chess) -> string {
  builder: String_Builder;
  i := 56;
  while i >= 0 {

    spaces := 0;

    for j: 0..7 {
      index := i + j;
      piece := chess.pieces[index];
      if piece == {
      case .NONE;
        spaces += 1;
      case .W_KING;
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "K");

      case .W_QUEEN; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "Q");

      case .W_ROOK; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "R");

      case .W_BISHOP; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "B");

      case .W_KNIGHT; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "N");

      case .W_PAWN; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "P");

      case .B_KING; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "k");

      case .B_QUEEN; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "q");

      case .B_ROOK; 
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "r");

      case .B_BISHOP;
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "b");

      case .B_KNIGHT;
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "n");

      case .B_PAWN;
        if spaces > 0 {
          print_to_builder(*builder, "%", spaces);
          spaces = 0;
        }
        append(*builder, #char "p");
      }
    }

    if spaces > 0 {
      print_to_builder(*builder, "%", spaces);
      spaces = 0;
    }

    if i > 0 then {
      append(*builder, #char "/");
    }

    i -= 8;
  }

  if chess.turn == .WHITE {
    append(*builder, " w");
  } else {
    append(*builder, " b");
  }

  append(*builder, #char " ");

  if chess.castling & .W_KS {
    append(*builder, #char "K");
  }

  if chess.castling & .W_QS {
    append(*builder, #char "Q");
  }

  if chess.castling & .B_KS {
    append(*builder, #char "k");
  }

  if chess.castling & .B_QS {
    append(*builder, #char "q");
  }

  if chess.castling == 0 {
    append(*builder, "-");
  }

  if chess.en_passant == 0 then 
    append(*builder, " -");
  else 
    print_to_builder(*builder, " %", cast(Bitboard)chess.en_passant);

  return builder_to_string(*builder);
}

get_pieces :: (using chess: *Chess) -> u64 #expand { 
  return w_pawn|w_bishop|w_knight|w_rook|w_queen|w_king|
         b_pawn|b_bishop|b_knight|b_rook|b_queen|b_king;
}

move_is_promotion :: inline (using m: Move16) -> bool {
  type, from, to := decode_move16(m);
  return Knight_Promotion <= type && type <= Queen_Promotion_Capture;
}

chess_startpos :: (chess: *Chess) {
  memset(chess, 0, size_of(Chess));

  chess.occupied = xx (rank_1|rank_2|rank_7|rank_8);
  add_piece(Piece.W_KING, xx e1);
  add_piece(Piece.W_QUEEN, xx d1);
  add_piece(Piece.W_ROOK, xx a1|h1);
  add_piece(Piece.W_BISHOP, xx c1|f1);
  add_piece(Piece.W_KNIGHT, xx b1|g1);
  add_piece(Piece.W_PAWN, xx rank_2);

  add_piece(Piece.B_KING, xx e8);
  add_piece(Piece.B_QUEEN, xx d8);
  add_piece(Piece.B_ROOK, xx a8|h8);
  add_piece(Piece.B_BISHOP, xx c8|f8);
  add_piece(Piece.B_KNIGHT, xx b8|g8);
  add_piece(Piece.B_PAWN, xx rank_7);
  chess.en_passant = 0;
  chess.castling = Castling.All;
  chess.turn = Turn.WHITE;
  chess.hash = zobrist_hash(chess);
  add_piece :: (p: Piece, bitboard: u64) #expand {
    chess.bitboard[cast(int) p] = bitboard;
    bb := bitboard;
    while bb {
      idx := bit_scan_forward(bb); 
      chess.pieces[idx] = p;
      bb = popbit(bb);
    }
  }
}

make_null_move :: (chess: *Chess) -> ep: u64, hash: u64 #expand {
  hash := chess.hash;
  ep   := chess.en_passant;
  chess.turn ^= 1;
  chess.hash ^= zobrist_turn;
  chess.hash ^= zobrist_en_passant(chess.en_passant);
  chess.en_passant = 0;
  return ep, hash;
}

unmake_null_move :: (chess: *Chess, ep: u64, hash: u64) #expand {
  chess.hash = hash;
  chess.turn ^= 1;
  chess.en_passant = ep;
}

make_move :: (chess: *Chess, move: Move16) -> captured: Piece, Castling, hash: u64 {
  flags, sq, to_sq := decode_move16(move);
  hash := chess.hash;
  chess.hash ^= zobrist_en_passant(chess.en_passant);
  chess.en_passant = 0;
  from := cast(u64) (1 << sq);
  to   := cast(u64) (1 << to_sq);
  castling := chess.castling;
  chess.occupied ^= from;
  chess.occupied |= to;
  chess.castling &= castling_move_table[sq];
  chess.castling &= castling_move_table[to_sq];
  chess.hash ^= zobrist_castling_table[cast(int)castling];
  chess.hash ^= zobrist_castling_table[cast(int)chess.castling];

  captured := chess.pieces[to_sq];
  piece_moved := chess.pieces[sq];
  chess.pieces[to_sq] = chess.pieces[sq];
  chess.pieces[sq] = Piece.NONE;
  chess.bitboard[cast(int)captured] &= ~to;
  chess.bitboard[cast(int)piece_moved] ^= from ^ to;

  chess.hash ^= zobrist_piece_inc(captured, to_sq);
  chess.hash ^= zobrist_piece_inc(piece_moved, to_sq);
  chess.hash ^= zobrist_piece_inc(piece_moved, sq);

  if piece_moved == Piece.W_PAWN || piece_moved == Piece.B_PAWN {
    if flags == Move16.Double_Pawn_Push {
      chess.en_passant = (to | (to << 8) | (to >> 8)) & (cast(u64)(rank_3|rank_6));
      chess.hash ^= zobrist_en_passant(chess.en_passant);
    } else if flags == Move16.Ep_Capture {
      cap := (to | (to << 8) | (to >> 8)) & (cast(u64)(rank_4|rank_5));
      taken := bit_scan_forward(cap);
      captured = chess.pieces[taken];
      chess.pieces[taken] = Piece.NONE;
      chess.w_pawn &= ~cap;
      chess.b_pawn &= ~cap;
      chess.occupied &= ~cap; // get rid of the pawn.
      chess.hash ^= zobrist_piece_inc(captured, taken);
    } else if flags >= Move16.Knight_Promotion {
      piece_promoted := promotion_table[cast(int)chess.turn][cast(int)flags];
      chess.pieces[to_sq] = piece_promoted;
      chess.bitboard[cast(int)piece_moved] ^= to;
      chess.bitboard[cast(int)piece_promoted] ^= to;
      chess.hash ^= zobrist_piece_inc(piece_moved, to_sq);
      chess.hash ^= zobrist_piece_inc(piece_promoted, to_sq);
    }
  } else if piece_moved == Piece.W_KING || piece_moved == Piece.B_KING {
    // Castling.
    if flags == Move16.King_Castle || flags == Move16.Queen_Castle {
      turn := cast(int) chess.turn;
      index := cast(int) flags;
      rook_from := castle_from[turn][index];
      rook_to   := castle_to[turn][index];
      from_bitboard := cast(u64) (1 << rook_from);
      to_bitboard := cast(u64) (1 << rook_to);
      piece_type := chess.pieces[rook_from];
      chess.bitboard[cast(int) piece_type] ^= from_bitboard ^ to_bitboard;
      chess.pieces[rook_to] = piece_type;
      chess.pieces[rook_from] = Piece.NONE;
      chess.occupied |= to_bitboard;
      chess.occupied ^= from_bitboard;
      chess.hash ^= zobrist_piece_inc(piece_type, rook_from);
      chess.hash ^= zobrist_piece_inc(piece_type, rook_to);
    }
  }

  chess.turn ^= 1;
  chess.hash ^= zobrist_turn;
  return captured, castling, hash;
}

unmake_move :: (chess: *Chess, move: Move16, cap: Piece, castling: Castling, hash: u64) {
  NONE : int : cast(int) Piece.NONE;

  // we incremental update on make move, but in undo, just assign 
  // hash rather than do an incremental update calculation.
  chess.hash = hash;
  flags, sq, to_sq := decode_move16(move);
  from := cast(u64) (1 << sq);
  to   := cast(u64) (1 << to_sq);
  piece_moved := cast(int) chess.pieces[to_sq];
  chess.castling = castling;
  chess.occupied |= from;
  chess.occupied &= ~to;
  chess.en_passant = 0;

  if flags >= Move16.Knight_Promotion then {
    pawn := cast(int) PawnSide[cast(int) chess.turn ^ 1];
    chess.pieces[to_sq] = cap;
    chess.pieces[sq] = cast(Piece) pawn;
    chess.bitboard[cast(int)cap] |= to;
    chess.bitboard[NONE] = 0;
    chess.bitboard[piece_moved] ^= to;
    chess.bitboard[pawn] ^= from;
    chess.occupied |= chess.bitboard[cast(int)cap];
  } else if cast(Piece)piece_moved == Piece.W_PAWN || cast(Piece)piece_moved == Piece.B_PAWN {
    if flags == Move16.Ep_Capture then {
      chess.bitboard[piece_moved] ^= from ^ to;
      encap := (to | (to << 8) | (to >> 8)) & xx (rank_4|rank_5);
      victim_index := bit_scan_forward(encap);
      chess.bitboard[cast(int) cap] ^= encap;
      chess.pieces[victim_index] = cap;
      chess.pieces[sq] = chess.pieces[to_sq];
      chess.pieces[to_sq] = Piece.NONE;
      chess.en_passant = to;
      chess.occupied |= encap;
    } else {
      chess.bitboard[piece_moved] ^= from ^ to;
      chess.bitboard[cast(int) cap] |= to;
      chess.bitboard[NONE] = 0;
      chess.pieces[sq] = chess.pieces[to_sq];
      chess.pieces[to_sq] = cap;
      chess.occupied |= chess.bitboard[cast(int)cap];
    }
  } else if cast(Piece)piece_moved == Piece.W_KING || cast(Piece)piece_moved == Piece.B_KING {
    chess.bitboard[piece_moved] ^= from ^ to;
    chess.bitboard[cast(int) cap] |= to;
    chess.bitboard[NONE] = 0;
    chess.pieces[sq] = chess.pieces[to_sq];
    chess.pieces[to_sq] = cap;
    chess.occupied |= chess.bitboard[cast(int)cap];

    if flags == Move16.King_Castle || flags == Move16.Queen_Castle {
      turn := cast(int) chess.turn ^ 1;
      index := cast(int) flags;
      rook_from := castle_from[turn][index];
      rook_to   := castle_to[turn][index];
      from_bitboard := cast(u64) (1 << rook_from);
      to_bitboard := cast(u64) (1 << rook_to);
      piece_type := chess.pieces[rook_to];
      chess.bitboard[cast(int) piece_type] |= from_bitboard;
      chess.bitboard[cast(int) piece_type] &= ~to_bitboard;
      chess.pieces[rook_from] = piece_type;
      chess.pieces[rook_to] = Piece.NONE;
      chess.occupied |= from_bitboard;
      chess.occupied ^= to_bitboard;
    }
  } else {
    chess.pieces[sq] = chess.pieces[to_sq];
    chess.pieces[to_sq] = cap;
    chess.bitboard[piece_moved] |= from;
    chess.bitboard[piece_moved] ^= to;
    chess.bitboard[cast(int) cap] |= to;
    chess.bitboard[NONE] = 0;
    chess.occupied |= chess.bitboard[cast(int)cap];
  }

  chess.turn ^= 1;
  PawnSide :: Piece.[Piece.W_PAWN, Piece.B_PAWN];
}

#no_reset castle_from: [2][15] int;
#no_reset castle_to: [2][15] int;
#run {
  using Move16; using Turn; using serialized_bb;
  set_from(WHITE, King_Castle, h1);
  set_from(WHITE, Queen_Castle, a1);
  set_from(BLACK, King_Castle, h8);
  set_from(BLACK, Queen_Castle, a8);
  set_to(WHITE, King_Castle, f1);
  set_to(WHITE, Queen_Castle, d1);
  set_to(BLACK, King_Castle, f8);
  set_to(BLACK, Queen_Castle, d8);

  set_from :: (t: Turn, flags: Move16, index: serialized_bb) #expand {
    castle_from[cast(int)t][cast(int)flags] = cast(int)index;
  }

  set_to :: (t: Turn, flags: Move16, index: serialized_bb) #expand {
    castle_to[cast(int)t][cast(int)flags] = cast(int)index;
  }
}

#no_reset promotion_table : [2][15] Piece;
#run {
  using Move16; using Piece; using Turn;
  set_promotion_table(WHITE, Knight_Promotion, W_KNIGHT);
  set_promotion_table(WHITE, Bishop_Promotion, W_BISHOP);
  set_promotion_table(WHITE, Rook_Promotion, W_ROOK);
  set_promotion_table(WHITE, Queen_Promotion, W_QUEEN);
  set_promotion_table(WHITE, Knight_Promotion_Capture, W_KNIGHT);
  set_promotion_table(WHITE, Bishop_Promotion_Capture, W_BISHOP);
  set_promotion_table(WHITE, Rook_Promotion_Capture, W_ROOK);
  set_promotion_table(WHITE, Queen_Promotion_Capture, W_QUEEN);

  set_promotion_table(BLACK, Knight_Promotion, B_KNIGHT);
  set_promotion_table(BLACK, Bishop_Promotion, B_BISHOP);
  set_promotion_table(BLACK, Rook_Promotion, B_ROOK);
  set_promotion_table(BLACK, Queen_Promotion, B_QUEEN);
  set_promotion_table(BLACK, Knight_Promotion_Capture, B_KNIGHT);
  set_promotion_table(BLACK, Bishop_Promotion_Capture, B_BISHOP);
  set_promotion_table(BLACK, Rook_Promotion_Capture, B_ROOK);
  set_promotion_table(BLACK, Queen_Promotion_Capture, B_QUEEN);

  set_promotion_table :: (turn: Turn, flag: Move16, piece: Piece) #expand {
    promotion_table[cast(int)turn][cast(int)flag] = piece;
  }
}

castling_move_table :: #run -> [64] Castling { 
  using serialized_bb; using Castling;
  table: [64] Castling;
  for i: 0..63 {
    if cast(serialized_bb)i == {
    case a1;
      table[i] = ~W_QS;
    case e1;
      table[i] = ~(W_QS|W_KS);
    case h1;
      table[i] = ~W_KS;
    case a8;
      table[i] = ~B_QS;
    case e8;
      table[i] = ~(B_QS|B_KS);
    case h8;
      table[i] = ~B_KS;
    case;
      table[i] = All;
    }
  }
  return table;
};

to_move16 :: inline (from: int, to: int, flags: Move16) -> Move16 {
  ret  := (from << 10) | (to << 4) | (xx flags);
  return cast, trunc(Move16) ret;
}

get_move16_to :: (mov: Move16) -> to: int {
  cast_mov := cast(int) mov;
  return  xx (cast_mov & 0x03F0) >> 4;
}

get_move16_from :: (mov: Move16) -> from: int {
  cast_mov := cast(int) mov;
  return  xx (cast_mov & 0xFC00) >> 10;
}

get_move16_flag :: (mov: Move16) -> flag: Move16 {
  cast_mov := cast(int) mov;
  return  mov & (xx 0xF);
}

// Type of move, From, To.
decode_move16 :: inline (mov: Move16) -> flags: Move16, from: int, to: int {
  // NOTE: this cast is neccesssary to prevent the release build from doing something stupid...
  cast_mov := cast(int) mov;
  return  cast(Move16)(cast_mov & 0xF), xx (cast_mov & 0xFC00) >> 10, xx (cast_mov & 0x03F0) >> 4;
}

bishop_moves :: (sq: int, occ: u64) -> u64 #expand {
  using magic_bishop[sq];
  #if FANCY_MAGIC_BITBOARDS {
    return bishop_attacks[sq][pext(occ, mask)];
  } else {
    occ &= mask;
    occ *= magic;
    occ >>= 64 - relevant_bit;
    return bishop_attacks[sq][occ];
  }
}

rook_moves :: (sq: int, occ: u64) -> u64 #expand {
  using magic_rook[sq];
  #if FANCY_MAGIC_BITBOARDS {
    return rook_attacks[sq][pext(occ, mask)];
  } else {
    occ &= mask;
    occ *= magic;
    occ >>= 64 - relevant_bit;
    return rook_attacks[sq][occ];
  }
}

king_moves :: (bitboard: u64) -> u64 {
  l := (bitboard << 1) & xx ~file_a;
  r := (bitboard >> 1) & xx ~file_h;
  k := bitboard | l | r;
  return l | r | (k << 8) | (k >> 8);
}

knight_moves :: (bitboard: u64) -> u64 {
  l1 := (bitboard << 1) & xx (~file_a);
  r1 := (bitboard >> 1) & xx (~file_h);
  l2 := (l1 << 1) & xx (~file_a);
  r2 := (r1 >> 1) & xx (~file_h);
  s1 := l1 | r1;
  s2 := l2 | r2;
  return (s2 << 8) | (s2 >> 8) | (s1 << 16) | (s1 >> 16);
}

pawn_captures :: (bitboard: u64, $turn: Turn) -> u64 {
  using Turn;
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

pawn_advance :: (bitboard: u64, $t: Turn) -> u64 {
  using Turn;
  #if t == WHITE then {
    return bitboard << 8;
  }
  #if t == BLACK then {
    return bitboard >> 8;
  }
}

pawn_push :: (bitboard: u64, $t: Turn) -> u64 {
  using Turn;
  #if t == WHITE then {
    return bitboard << 16;
  }
  #if t == BLACK then {
    return bitboard >> 16;
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

do_en_passant_moves :: (chess: *Chess, pawn: u64, en_passant: u64, $turn: Turn, move_gen: *$T, $$filter: u64 = ~0) #expand {
  // en passant is such an ugly move.
  opp :: turn ^ 1;
  ep_rank := EP_RANK(turn);

  if !en_passant then
    return;
  victim := pawn_advance(en_passant, opp) & filter;
  if victim == 0 then
    return;
  ep_sq := bit_scan_forward(en_passant);
  pawn &= pawn_captures(en_passant, opp);
  if !pawn then
    return;
  
  ret : u64 = 0;
  occupied := chess.occupied & ~victim;
  king := get_king(chess, turn) & ep_rank;
  ksq := bit_scan_forward(king);
  queen_rook := get_queen(chess, opp) | get_rook(chess, opp) & ep_rank;

  while pawn {
    pawn_sq := bit_scan_forward(pawn);
    pawn_bitboard := cast(u64) (1 << pawn_sq);
    if king != 0 && queen_rook != 0 {
      while queen_rook {
        sq := bit_scan_forward(queen_rook);
        between := between_squares(sq, ksq);
        erase_both := occupied & ~pawn_bitboard;
        if (between & erase_both) == 0 
          return;
        queen_rook &= popbit(queen_rook);
      }
    }

    // do enpassant move.
    add_move(move_gen, pawn_sq, ep_sq, Move16.Ep_Capture);

    pawn = popbit(pawn);
  }

  EP_RANK :: ($turn: Turn) -> u64 #expand {
    #if turn == Turn.WHITE
      return xx rank_5;
    #if turn == Turn.BLACK
      return xx rank_4;
  }
}

PawnPushRank :: ($turn: Turn) -> u64 #expand {
  #if turn == Turn.WHITE
    return xx rank_3;
  #if turn == Turn.BLACK
    return xx rank_6;
}

generate_attacks :: (chess: *Chess) -> unsafe: u64, check: u64 {
  if chess.turn == Turn.WHITE {
    unsafe, check := generate_attacks(chess, Turn.BLACK);
    return unsafe, check;
  } else {
    unsafe, check := generate_attacks(chess, Turn.WHITE);
    return unsafe, check;
  }
}

generate_tactics :: (unsafe: u64, check: u64, chess: *Chess, movegen: *$T) {
  num_checks := popcount(check);
  if chess.turn == Turn.WHITE {
    generate_tactics(unsafe, check, chess, Turn.WHITE, movegen);
  } else {
    generate_tactics(unsafe, check, chess, Turn.BLACK, movegen);
  }

  generate_tactics :: (unsafe: u64, check: u64, chess: *Chess, $turn: Turn, move_gen: *$T) {
    //assert(chess.turn == turn);
    num_checks := popcount(check);
    if num_checks > 1 then {
      king    := get_king(chess, turn);
      king_sq := bit_scan_forward(king);
      occupied := chess.occupied;
      king_move_bits := king_moves(king) & ~unsafe;
      pieces : u64 = 0;
      #if turn == Turn.WHITE then {
        pieces = get_white_pieces(chess);
      } else {
        pieces = get_black_pieces(chess);
      }
      captures := king_move_bits & occupied & ~pieces;
      for :bitloop _, to: captures {
        add_move(move_gen, king_sq, to, Move16.Capture);
      }
    } else if num_checks == 1 then {
      generate_check_captures(unsafe, check, chess, turn, move_gen);
    } else {
      generate_tactics_for(unsafe, chess, turn, move_gen);
    }
  }
}

generate_quiets :: (unsafe: u64, check: u64, chess: *Chess, movegen: *$T) {
  if chess.turn == Turn.WHITE {
    generate_quiets(unsafe, check, chess, Turn.WHITE, movegen);
  } else {
    generate_quiets(unsafe, check, chess, Turn.BLACK, movegen);
  }

  generate_quiets :: (unsafe: u64, check: u64, chess: *Chess, $turn: Turn, move_gen: *$T) {
    num_checks := popcount(check);
    if num_checks > 1 then {
      king    := get_king(chess, turn);
      king_sq := bit_scan_forward(king);
      occupied := chess.occupied;
      king_move_bits := king_moves(king) & ~unsafe;
      quiets   := king_move_bits & ~occupied;
      for :bitloop _, to: quiets {
        add_move(move_gen, king_sq, to, Move16.Quiet);
      }
    } else if num_checks == 1 then {
      generate_check_quiets(unsafe, check, chess, turn, move_gen);
    } else {
      generate_quiets_for(unsafe, chess, turn, move_gen);
    }
  }
}

generate_moves :: (using chess: *Chess, movegen: *$T) {
  if chess.turn == Turn.WHITE {
    generate_moves_for(chess, Turn.WHITE, movegen);
  } else {
    generate_moves_for(chess, Turn.BLACK, movegen);
  }
}

ChessFlags :: enum {
  Normal;
  Check;
  Checkmate;
  Stalemate;
  Insufficent_Material;
  Threefold_Repetition;
  Fifty;
}

init_global_bitboards :: () {
  init_magic_bitboard();
  init_between_bitboards();
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

  en_passant: u64;
  castling: Castling;
  turn: Turn;
  hash: u64;
}

Castling :: enum_flags u8 {
  W_KS;
  W_QS;
  B_KS;
  B_QS;
  All :: W_KS|W_QS|B_KS|B_QS;
}

Turn :: enum s32 { WHITE :: 0; BLACK :: 1; };

get_move16_flag :: (chess: *Chess, from: int, to: int, p: u8) -> Move16 {
  using Move16;
  piece := chess.pieces[from];
  topiece := chess.pieces[to];

  if piece == {
  case  Piece.NONE;
    return Quiet;
  case  Piece.W_KING;
    if cast(serialized_bb)from == serialized_bb.e1 && cast(serialized_bb)to == serialized_bb.g1 then
      return King_Castle;
    if cast(serialized_bb)from == serialized_bb.e1 && cast(serialized_bb)to == serialized_bb.c1 then
      return Queen_Castle;

  case  Piece.W_PAWN;
    fbb := cast(Bitboard) (1 << from);
    tbb := cast(Bitboard) (1 << to);
    if (fbb & rank_2) && (tbb & rank_4) then
      return Double_Pawn_Push;
    if cast(u64)tbb == chess.en_passant then
      return Ep_Capture;
    if tbb & rank_8 then {
      if topiece == Piece.NONE
        return promote(p);
      return promote_cap(p);
    }
    
  case  Piece.B_KING;
    if cast(serialized_bb)from == serialized_bb.e8 && cast(serialized_bb)to == serialized_bb.g8 then
      return King_Castle;
    if cast(serialized_bb)from == serialized_bb.e8 && cast(serialized_bb)to == serialized_bb.c8 then
      return Queen_Castle;

  case  Piece.B_PAWN;
    fbb := cast(Bitboard) (1 << from);
    tbb := cast(Bitboard) (1 << to);
    if (fbb & rank_7) && (tbb & rank_5) then
      return Double_Pawn_Push;
    if cast(u64)tbb == chess.en_passant then
      return Ep_Capture;
    if tbb & rank_1 then {
      if topiece == Piece.NONE
        return promote(p);
      return promote_cap(p);
    }

  }

  if topiece == Piece.NONE then
    return Quiet;
  else
    return Capture;

  promote :: (p: u8) -> Move16 {
    if p == #char "q" return Queen_Promotion;
    if p == #char "r" return Rook_Promotion;
    if p == #char "b" return Bishop_Promotion;
    if p == #char "n" return Knight_Promotion;
    return Quiet;
  }

  promote_cap :: (p: u8) -> Move16 {
    if p == #char "q" return Queen_Promotion_Capture;
    if p == #char "r" return Rook_Promotion_Capture;
    if p == #char "b" return Bishop_Promotion_Capture;
    if p == #char "n" return Knight_Promotion_Capture;
    return Capture;
  }
}

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

// TODO: need to verify all the false positives.
is_legal :: (chess: *Chess, move: Move16) -> bool {
  if move == Move16.Quiet then
    return false;
  if chess.turn == Turn.WHITE then
    return is_legal(chess, Turn.WHITE, move);
  else
    return is_legal(chess, Turn.BLACK, move);

  is_legal :: (chess: *Chess, $turn: Turn, move: Move16) -> bool {
    opp :: turn ^ 1;
    flags, from, to := decode_move16(move);
    if from == to then
      return false;

    from_bit := cast(u64) (1<<from);
    to_bitboard := cast(u64) (1<<to);
    moves : u64 = 0;
    piece := piece_at(chess, from);
    pieces : u64 = 0;
    #if turn == Turn.WHITE then {
      pieces = get_white_pieces(chess);
    } else {
      pieces = get_black_pieces(chess);
    }
    
    occupied := chess.occupied;
    if (from_bit & pieces) == 0 || (to_bitboard & pieces) then
      return false;

    opp_piece := piece_at(chess, to);
    if flags == Move16.Ep_Capture then {
      if piece_at(chess, to) != Piece.NONE
        return false;
      if to_bitboard != chess.en_passant {
        return false;
      }
      ep_bb := pawn_advance(to_bitboard, opp);
      index := bit_scan_forward(ep_bb);
      opp_piece = piece_at(chess, index);
      #if turn == Turn.WHITE {
        if opp_piece != Piece.B_PAWN
          return false;
      } else {
        if opp_piece != Piece.W_PAWN
          return false;
      }
      occupied &= ~ep_bb;
    }

    // not a capture move.
    if (flags < Move16.Capture || (flags >= Move16.Knight_Promotion && flags <= Move16.Queen_Promotion)) && opp_piece != Piece.NONE then
      return false;
    if (flags == Move16.Double_Pawn_Push || flags >= Move16.Ep_Capture) && (piece != Piece.W_PAWN && piece != Piece.B_PAWN)
      return false;
    // capture
    if (flags == Move16.Capture || flags >= Move16.Knight_Promotion_Capture) then {
      if opp_piece == Piece.NONE then {
        return false;
      }
      #if turn == Turn.WHITE {
        if opp_piece >= Piece.W_KING && opp_piece <= Piece.W_PAWN
          return false;
      }
      #if turn == Turn.BLACK {
        if opp_piece >= Piece.B_KING && opp_piece <= Piece.B_PAWN
          return false;
      }
    }
    if (flags == Move16.King_Castle || flags == Move16.Queen_Castle) && (piece != Piece.W_KING && piece != Piece.B_KING)
      return false;

    king_bit := get_king(chess, turn);
    if piece == {
    case Piece.NONE;
      return false;
    case Piece.W_KING;
      #if turn == Turn.BLACK return false;
      king_bit = to_bitboard;
      moves = king_moves(chess.w_king) & ~pieces;
      if flags == Move16.King_Castle {
        if from != cast(int)serialized_bb.e1
          return false;
        if chess.castling & Castling.W_KS {
          att, check := generate_attacks(chess, opp);
          if check || (att & cast(u64) (e1|f1|g1)) || (occupied & cast(u64)(f1|g1))
            return false;
          return true;
        }
        return false;
      } else if flags == Move16.Queen_Castle {
        if from != cast(int)serialized_bb.e1
          return false;
        if chess.castling & Castling.W_QS {
          att, check := generate_attacks(chess, opp);
          if check || (att & cast(u64) (e1|d1|c1)) || (occupied & cast(u64)(b1|c1|d1)) then
            return false;
          return true;
        }
        return false;
      }
    case Piece.W_QUEEN;
      #if turn == Turn.BLACK return false;
      moves = rook_moves(from, occupied) | bishop_moves(from, occupied);
      moves &= ~pieces;

    case Piece.W_ROOK;
      #if turn == Turn.BLACK return false;
      moves = rook_moves(from, chess.occupied) & ~pieces;

    case Piece.W_BISHOP;
      #if turn == Turn.BLACK return false;
      moves = bishop_moves(from, chess.occupied) & ~pieces;

    case Piece.W_KNIGHT;
      #if turn == Turn.BLACK return false;
      moves = knight_moves(from_bit) & ~pieces;

    case Piece.W_PAWN;
      #if turn == Turn.BLACK return false;
      adv := pawn_advance(from_bit, turn) & ~occupied;
      adv2 := pawn_advance(adv & cast(u64)rank_3, turn) & ~occupied;
      cap  := pawn_captures(from_bit, turn) & (occupied|chess.en_passant) & ~pieces;
      moves = adv|adv2|cap;

      // TODO: handle bad case of pawn quiet moves on rank1/rank8
      if from_bit & cast(u64)(rank_1|rank_8)
        return false;
      if (flags == Move16.Quiet || flags == Move16.Capture) && (to_bitboard & cast(u64)(rank_1|rank_8))
        return false;
      if flags == Move16.Double_Pawn_Push && (to_bitboard != adv2 || (from_bit & cast(u64)rank_2) == 0)
        return false;
      if flags != Move16.Double_Pawn_Push && to_bitboard == adv2
        return false;
      if flags <= Move16.Ep_Capture && to_bitboard & cast(u64)(rank_1|rank_8)
        return false;
      if flags >= Move16.Knight_Promotion_Capture && (to_bitboard & (cast(u64)(rank_8)) & cap) == 0
        return false;
      if flags >= Move16.Knight_Promotion && flags <= Move16.Queen_Promotion && (to_bitboard & (cast(u64)(rank_8)) & adv) == 0
        return false;

    case Piece.B_KING;
      #if turn == Turn.WHITE return false;
      king_bit = to_bitboard;
      moves = king_moves(chess.b_king) & ~pieces;
      if flags == Move16.King_Castle {
        if from != cast(int)serialized_bb.e8
          return false;
        if chess.castling & Castling.B_KS {
          att, check := generate_attacks(chess, opp);
          if check || (att & cast(u64) (e8|f8|g8)) || (occupied & cast(u64)(f8|g8))
            return false;
          return true;
        }
        return false;
      } else if flags == Move16.Queen_Castle {
        if from != cast(int)serialized_bb.e8
          return false;
        if chess.castling & Castling.B_QS {
          att, check := generate_attacks(chess, opp);
          if check || (att & cast(u64) (e8|d8|c8)) || (occupied & cast(u64)(b8|c8|d8)) then
            return false;
          return true;
        }
        return false;
      }
    case Piece.B_QUEEN;
      #if turn == Turn.WHITE return false;
      moves = rook_moves(from, occupied) | bishop_moves(from, occupied);
      moves &= ~pieces;

    case Piece.B_ROOK;
      #if turn == Turn.WHITE return false;
      moves = rook_moves(from, chess.occupied) & ~pieces;

    case Piece.B_BISHOP;
      #if turn == Turn.WHITE return false;
      moves = bishop_moves(from, chess.occupied) & ~pieces;

    case Piece.B_KNIGHT;
      #if turn == Turn.WHITE return false;
      moves = knight_moves(from_bit) & ~pieces;

    case Piece.B_PAWN;
      #if turn == Turn.WHITE return false;
      adv := pawn_advance(from_bit, turn) & ~occupied;
      adv2 := pawn_advance(adv & cast(u64)rank_6, turn) & ~occupied;
      cap  := pawn_captures(from_bit, turn) & (occupied|chess.en_passant) & ~pieces;
      moves = adv|adv2|cap;
      if from_bit & cast(u64)(rank_1|rank_8)
        return false;
      if (flags == Move16.Quiet || flags == Move16.Capture) && (to_bitboard & cast(u64)(rank_1|rank_8))
        return false;
      if flags == Move16.Double_Pawn_Push && (to_bitboard != adv2 || (from_bit & cast(u64)rank_7) == 0)
        return false;
      if flags != Move16.Double_Pawn_Push && to_bitboard == adv2
        return false;
      if flags <= Move16.Ep_Capture && to_bitboard & cast(u64)(rank_1|rank_8)
        return false;
      if flags >= Move16.Knight_Promotion_Capture && (to_bitboard & (cast(u64)(rank_1)) & cap) == 0
        return false;
      if flags >= Move16.Knight_Promotion && flags <= Move16.Queen_Promotion && (to_bitboard & (cast(u64)(rank_1)) & adv) == 0
        return false;
    }
    // illegal piece move.
    if (moves & to_bitboard) == 0 then {
      return false;
    }

    occupied &= ~from_bit;
    occupied |= to_bitboard;

    // if you made the move,
    // does it cause the king to enter check???
    return !in_check(chess, turn, king_bit, to_bitboard, occupied);
  }

  in_check :: (chess: *Chess, $turn: Turn, king_bit: u64, to_bitboard: u64, occupied: u64) -> bool {
    //assert(popcount(king_bit) == 1);
    opp :: turn ^ 1;
    // & occupied = ep capture.
    pawn := get_pawn(chess, opp) & ~to_bitboard & occupied;
    
    if king_bit & pawn_captures(pawn, opp) then {
      return true;
    }

    knight := get_knight(chess, opp) & ~to_bitboard;
    if king_bit & knight_moves(knight) then {
      return true;
    }

    king := get_king(chess, opp);
    if king_bit & king_moves(king) then {
      return true;
    }

    queen := get_queen(chess, opp) & ~to_bitboard; // & occupied;
    rook  := get_rook(chess, opp) & ~to_bitboard; // & occupied;
    bishop := get_bishop(chess, opp) & ~to_bitboard; // & occupied;
    sq := bit_scan_forward(king_bit);
    if rook_moves(sq, occupied) & (queen|rook) then {
      return true;
    }
     
    if bishop_moves(sq, occupied) & (queen|bishop) then {
      return true;
    }
    return false;
  }
}

// TODO: enpassant does not work on diagonal pins for esoteric
// reasons, hopefully we will be able to handle this case robustly,
// but for now, just get something off the ground.
generate_moves_for :: (chess: *Chess, $turn: Turn, move_gen: *$T) {
  //assert(chess.turn == turn);
  opp :: turn ^ 1; 
  unsafe, check := generate_attacks(chess, opp);
  num_checks := popcount(check);
  if num_checks > 1 then {
    king    := get_king(chess, turn);
    queen   := get_queen(chess, turn);
    rook    := get_rook(chess, turn);
    bishop  := get_bishop(chess, turn);
    knight  := get_knight(chess, turn); 
    pawn    := get_pawn(chess, turn);
    king_sq := bit_scan_forward(king);
    pieces := king|queen|rook|bishop|knight|pawn;
    occupied := chess.occupied;
    king_move_bits := king_moves(king) & ~unsafe;
    quiets   := king_move_bits & ~occupied;
    captures := king_move_bits & occupied & ~pieces;
    for :bitloop _, to: captures {
      add_move(move_gen, king_sq, to, Move16.Capture);
    }
    for :bitloop _, to: quiets {
      add_move(move_gen, king_sq, to, Move16.Quiet);
    }
  } else if num_checks == 1 then {
    generate_check_captures(unsafe, check, chess, turn, move_gen);
    generate_check_quiets(unsafe, check, chess, turn, move_gen);
  } else {
    generate_tactics_for(unsafe, chess, turn, move_gen);
    generate_quiets_for(unsafe, chess, turn, move_gen);
  }
}

promotion_rank :: (turn: $Turn) -> u64 #expand {
  #if turn == Turn.WHITE 
    return xx rank_7;
  else
    return xx rank_2;
}

generate_check_captures :: (unsafe: u64, check: u64, chess: *Chess, $turn: Turn, move_gen: *$T) {
  opp :: turn ^ 1; 
  occupied := chess.occupied;
  en_passant := chess.en_passant;
  king    := get_king(chess, turn);
  queen   := get_queen(chess, turn);
  rook    := get_rook(chess, turn);
  bishop  := get_bishop(chess, turn);
  knight  := get_knight(chess, turn); 
  pawn    := get_pawn(chess, turn);
  king_sq := bit_scan_forward(king);
  king_file := file_of(king_sq);
  pieces := king|queen|rook|bishop|knight|pawn;
  opponent_pieces := chess.occupied & ~pieces;

  pinned : u64 = 0; 
  opp_qr := get_queen(chess, opp) | get_rook(chess, opp);
  xray_rook := xray_rook_attacks(king_sq, occupied, pieces) & opp_qr;
  for :bitloop _, index: xray_rook {
    between := between_squares(index, king_sq);
    pinned |= between & occupied;
  }

  opp_qb := get_queen(chess, opp) | get_bishop(chess, opp);
  xray_bishop := xray_bishop_attacks(king_sq, occupied, pieces) & opp_qb;
  for :bitloop bitboard, index: xray_bishop {
    between := between_squares(index, king_sq);
    pinned |= between & occupied;
  }

  queen  &= ~pinned;
  rook   &= ~pinned;
  bishop &= ~pinned;
  knight &= ~pinned;
  pawn   &= ~pinned;

  check_sq := bit_scan_forward(check);
  // TODO: en passant capture!
  if pawn_advance(en_passant, opp) == check {
    do_en_passant_moves(chess, pawn, en_passant, turn, move_gen);
  }

  queen_rook := rook_moves(check_sq, occupied) & (queen|rook);
  for :bitloop _, from: queen_rook {
    add_move(move_gen, from, check_sq, Move16.Capture);
  }

  queen_bishop := bishop_moves(check_sq, occupied) & (queen|bishop);
  for :bitloop _, from: queen_bishop {
    add_move(move_gen, from, check_sq, Move16.Capture);
  }

  knight_bits := knight_moves(check) & knight;
  for :bitloop _, from: knight_bits {
    add_move(move_gen, from, check_sq, Move16.Capture);
  }

  pawn_bits := pawn_captures(check, opp) & pawn;
  if check & cast(u64)(rank_1|rank_8) {
    for :bitloop _, from: pawn_bits {
      add_move(move_gen, from, check_sq, Move16.Queen_Promotion_Capture);
      add_move(move_gen, from, check_sq, Move16.Rook_Promotion_Capture);
      add_move(move_gen, from, check_sq, Move16.Bishop_Promotion_Capture);
      add_move(move_gen, from, check_sq, Move16.Knight_Promotion_Capture);
    }
  } else {
    for :bitloop _, from: pawn_bits {
      add_move(move_gen, from, check_sq, Move16.Capture);
    }
  }
  between := between_squares(king_sq, check_sq) & cast(u64) (rank_1|rank_8);
  pawn_bits = pawn_advance(pawn, turn) & between;
  for :bitloop bit, to: pawn_bits {
    from := bit_scan_forward(pawn_advance(bit, opp));
    add_move(move_gen, from, to, Move16.Queen_Promotion);
    add_move(move_gen, from, to, Move16.Rook_Promotion);
    add_move(move_gen, from, to, Move16.Bishop_Promotion);
    add_move(move_gen, from, to, Move16.Knight_Promotion);
  }

  king_bits := king_moves(king) & opponent_pieces & ~unsafe;
  for :bitloop _, to: king_bits {
    add_move(move_gen, king_sq, to, Move16.Capture);
  }
}

generate_check_quiets :: (unsafe: u64, check: u64, chess: *Chess, $turn: Turn, move_gen: *$T) {
  //assert(chess.turn == turn);
  opp :: turn ^ 1; 
  occupied := chess.occupied;
  king    := get_king(chess, turn);
  queen   := get_queen(chess, turn);
  rook    := get_rook(chess, turn);
  bishop  := get_bishop(chess, turn);
  knight  := get_knight(chess, turn); 
  pawn    := get_pawn(chess, turn);
  king_sq := bit_scan_forward(king);
  pieces := king|queen|rook|bishop|knight|pawn;

  pinned : u64 = 0; 
  opp_qr := get_queen(chess, opp) | get_rook(chess, opp);
  xray_rook := xray_rook_attacks(king_sq, occupied, pieces) & opp_qr;
  for :bitloop _, index: xray_rook {
    between := between_squares(index, king_sq);
    pinned |= between & occupied;
  }

  opp_qb := get_queen(chess, opp) | get_bishop(chess, opp);
  xray_bishop := xray_bishop_attacks(king_sq, occupied, pieces) & opp_qb;
  for :bitloop bitboard, index: xray_bishop {
    between := between_squares(index, king_sq);
    pinned |= between & occupied;
  }

  queen  &= ~pinned;
  rook   &= ~pinned;
  bishop &= ~pinned;
  knight &= ~pinned;
  pawn   &= ~pinned;
  pawn   &= ~promotion_rank(turn);
  check_sq := bit_scan_forward(check);

  between := between_squares(king_sq, check_sq);
  for :bitloop _, from: (queen|rook) {
    moves := rook_moves(from, occupied) & between;
    for :bitloop _, to: moves {
      add_move(move_gen, from, to, Move16.Quiet);
    }
  }

  for :bitloop _, from: (queen|bishop) {
    moves := bishop_moves(from, occupied) & between;
    for :bitloop _, to: moves {
      add_move(move_gen, from, to, Move16.Quiet);
    }
  }

  knight &= knight_moves(between);
  for :bitloop knight_bit, from: knight {
    moves := knight_moves(knight_bit) & between;
    for :bitloop _, to: moves {
      add_move(move_gen, from, to, Move16.Quiet);
    }
  }
  // TODO: handle pawn advances.
  pawn_sqs  := pawn_advance(between, opp);
  pawn_bits := pawn_sqs & pawn;
  for :bitloop bit, from: pawn_bits {
    sq := bit_scan_forward(pawn_advance(bit, turn));
    add_move(move_gen, from, sq, Move16.Quiet);
  }
  pawn_sqs &= ~occupied;
  pawn_sqs = pawn_advance(pawn_sqs & pawn_push_rank(turn), opp);
  pawn_bits = pawn_sqs & pawn;
  for :bitloop bit, from: pawn_bits {
    sq := bit_scan_forward(pawn_push(bit, turn));
    add_move(move_gen, from, sq, Move16.Double_Pawn_Push);
  }

  king_bits := king_moves(king) & ~occupied & ~unsafe;
  for :bitloop _, to: king_bits {
    add_move(move_gen, king_sq, to, Move16.Quiet);
  }
}

generate_quiets_for :: (unsafe: u64, chess: *Chess, $turn: Turn, move_gen: *$T) {
  opp :: turn ^ 1; 
  occupied := chess.occupied;
  en_passant := chess.en_passant;
  king    := get_king(chess, turn);
  queen   := get_queen(chess, turn);
  rook    := get_rook(chess, turn);
  bishop  := get_bishop(chess, turn);
  knight  := get_knight(chess, turn); 
  pawn    := get_pawn(chess, turn);

  king_sq := bit_scan_forward(king);
  king_file := file_of(king_sq);
  pieces := king|queen|rook|bishop|knight|pawn;
  opponent_pieces := chess.occupied & ~pieces;

  pinned : u64 = 0;
  opp_qr := get_queen(chess, opp) | get_rook(chess, opp);
  xray_rook := xray_rook_attacks(king_sq, occupied, pieces) & opp_qr;
  for :bitloop _, index: xray_rook {
    between := between_squares(index, king_sq);
    pin := between & occupied;
    sq := bit_scan_forward(pin);
    pinned |= pin;

    // quiet pin moves.
    if (queen|rook) & pin {
      between_quiets := between & ~occupied;
      for :bitloop _, to: between_quiets {
        add_move(move_gen, sq, to, Move16.Quiet);
      }
    } else if pawn & pin & king_file {
      adv := pawn_advance(pin, turn) & ~occupied;
      if adv {
        to := bit_scan_forward(adv);
        add_move(move_gen, sq, to, Move16.Quiet);
        adv2 := pawn_advance(adv & pawn_push_rank(turn), turn) & ~occupied;
        if adv2 {
          to = bit_scan_forward(adv2);
          add_move(move_gen, sq, to, Move16.Double_Pawn_Push);
        }
      }
    }
  }

  opp_qb := get_queen(chess, opp) | get_bishop(chess, opp);
  xray_bishop := xray_bishop_attacks(king_sq, occupied, pieces) & opp_qb;
  for :bitloop bitboard, index: xray_bishop {
    between := between_squares(index, king_sq);
    between_quiets := between & ~occupied;
    pin := between & occupied;
    sq := bit_scan_forward(pin);
    pinned |= pin;
    if (queen|bishop) & pin {
      // capture move.
      for :bitloop _, to: between_quiets {
        add_move(move_gen, sq, to, Move16.Quiet);
      }
    }
  }

  queen  &= ~pinned;
  rook   &= ~pinned;
  bishop &= ~pinned;
  knight &= ~pinned;
  pawn   &= ~pinned;

  generate_king_quiet_moves(chess, king, ~occupied, ~unsafe, move_gen);
  generate_rook_quiet_moves(chess, queen|rook, occupied, move_gen);
  generate_bishop_quiet_moves(chess, queen|bishop, occupied, move_gen);
  generate_knight_move_moves(chess, knight, occupied, move_gen);
  pawn &= ~promotion_rank(turn);
  for :bitloop pawn_bit, from: pawn {
    quiet := pawn_advance(pawn_bit, turn) & ~occupied;
    if quiet {
      to := bit_scan_forward(quiet);
      add_move(move_gen, from, to, Move16.Quiet);
      quiet2 := pawn_advance(quiet & pawn_push_rank(turn), turn) & ~occupied;
      if quiet2 {
        to := bit_scan_forward(quiet2);
        add_move(move_gen, from, to, Move16.Double_Pawn_Push);
      }
    }
  }

  generate_king_quiet_moves :: (chess: *Chess, king: u64, not_occupied: u64, safe: u64, move_gen: *T) {
    king_sq := bit_scan_forward(king);
    king_move_bits := king_moves(king) & not_occupied & safe;
    for :bitloop _, to: king_move_bits {
      add_move(move_gen, king_sq, to, Move16.Quiet);
    }
  }

  generate_rook_quiet_moves :: (chess: *Chess, queen_rook: u64, occupied: u64, move_gen: *T) {
    for :bitloop _, from: queen_rook {
      quiets := rook_moves(from, occupied) & ~occupied;
      for :bitloop _, to: quiets {
        add_move(move_gen, from, to, Move16.Quiet);
      }
    }
  }

  generate_bishop_quiet_moves :: (chess: *Chess, queen_bishop: u64, occupied: u64, move_gen: *T) {
    for :bitloop _, from: queen_bishop {
      quiets := bishop_moves(from, occupied) & ~occupied;
      for :bitloop _, to: quiets {
        add_move(move_gen, from, to, Move16.Quiet);
      }
    }
  }

  generate_knight_move_moves :: (chess: *Chess, knight: u64, occupied: u64, move_gen: *T) {
    for :bitloop knight_bit, from: knight {
      quiets := knight_moves(knight_bit) & ~occupied;
      for :bitloop _, to: quiets {
        add_move(move_gen, from, to, Move16.Quiet);
      }
    }
  }
}

generate_tactics_for :: (unsafe: u64, chess: *Chess, $turn: Turn, move_gen: *$T) {
  //assert(chess.turn == turn);
  opp :: turn ^ 1; 
  occupied := chess.occupied;
  en_passant := chess.en_passant;
  king    := get_king(chess, turn);
  queen   := get_queen(chess, turn);
  rook    := get_rook(chess, turn);
  bishop  := get_bishop(chess, turn);
  knight  := get_knight(chess, turn); 
  pawn    := get_pawn(chess, turn);
  king_sq := bit_scan_forward(king);
  king_file := file_of(king_sq);
  pieces := king|queen|rook|bishop|knight|pawn;
  opponent_pieces := chess.occupied & ~pieces;
  pinned : u64 = 0;
  opp_qr := get_queen(chess, opp) | get_rook(chess, opp);
  xray_rook := xray_rook_attacks(king_sq, occupied, pieces) & opp_qr;
  for :bitloop _, index: xray_rook {
    between := between_squares(index, king_sq);
    pin := between & occupied;
    sq := bit_scan_forward(pin);
    pinned |= pin;
    if (queen|rook) & pin {
      // capture move.
      add_move(move_gen, sq, index, Move16.Capture);
    }
  }

  opp_qb := get_queen(chess, opp) | get_bishop(chess, opp);
  xray_bishop := xray_bishop_attacks(king_sq, occupied, pieces) & opp_qb;
  for :bitloop bitboard, index: xray_bishop {
    between := between_squares(index, king_sq);
    pin := between & occupied;
    sq := bit_scan_forward(pin);
    pinned |= pin;
    if (queen|bishop) & pin {
      // capture move.
      add_move(move_gen, sq, index, Move16.Capture);
    } else if pawn & pin {
      // diagonal pawn capture.
      from_bitboard := pin;
      to_bitboard := pawn_captures(from_bitboard, turn) & cast(u64)(1 << index);
      if to_bitboard {
        add_move(move_gen, sq, index, Move16.Capture);
      }
    }
  }

  queen  &= ~pinned;
  rook   &= ~pinned;
  bishop &= ~pinned;
  knight &= ~pinned;
  pawn   &= ~pinned;

  do_en_passant_moves(chess, pawn, en_passant, turn, move_gen);
  king_bitboard := king_moves(king) & opponent_pieces & ~unsafe;
  for :bitloop _, to: king_bitboard {
    add_move(move_gen, king_sq, to, Move16.Capture);
  }

  safe_sqs := cast(Bitboard) ~unsafe;
  not_occu := cast(Bitboard) ~occupied;
  #if turn == Turn.WHITE {
    handle_castling(Castling.W_KS, f1|g1, f1|g1, serialized_bb.e1, serialized_bb.g1, Move16.King_Castle);
    handle_castling(Castling.W_QS, c1|d1, b1|c1|d1, serialized_bb.e1, serialized_bb.c1, Move16.Queen_Castle);
  } else {
    handle_castling(Castling.B_KS, f8|g8, f8|g8, serialized_bb.e8, serialized_bb.g8, Move16.King_Castle);
    handle_castling(Castling.B_QS, c8|d8, b8|c8|d8, serialized_bb.e8, serialized_bb.c8, Move16.Queen_Castle);
  }

  handle_castling :: (F: Castling, castle_sqs: Bitboard, check_occ: Bitboard, from: serialized_bb, to: serialized_bb, flags: Move16) #expand {
    if chess.castling & F {
      if (safe_sqs & castle_sqs) == castle_sqs && (not_occu & check_occ) == check_occ {
        add_move(move_gen, xx from, xx to, flags);
      }
    }
  }

  generate_rook_moves(chess, queen|rook, occupied, opponent_pieces, move_gen);
  generate_bishop_moves(chess, queen|bishop, occupied, opponent_pieces, move_gen);
  generate_knight_moves(chess, knight & knight_moves(opponent_pieces), occupied, opponent_pieces, move_gen);

  generate_rook_moves :: (chess: *Chess, queen_rook: u64, occupied: u64, opponent_pieces: u64, move_gen: *T) {
    for :bitloop _, from: queen_rook {
      attacks := rook_moves(from, occupied) & opponent_pieces;
      for :bitloop _, to: attacks {
        add_move(move_gen, from, to, Move16.Capture);
      }
    }
  }

  generate_bishop_moves :: (chess: *Chess, queen_bishop: u64, occupied: u64, opponent_pieces: u64, move_gen: *T) {
    for :bitloop _, from: queen_bishop {
      attacks := bishop_moves(from, occupied) & opponent_pieces;
      for :bitloop _, to: attacks {
        add_move(move_gen, from, to, Move16.Capture);
      }
    }
  }

  generate_knight_moves :: (chess: *Chess, knight: u64, occupied: u64, opponent_pieces: u64, move_gen: *T) {
    for :bitloop knight_bit, from: knight {
      attacks := knight_moves(knight_bit) & opponent_pieces;
      for :bitloop _, to: attacks {
        add_move(move_gen, from, to, Move16.Capture);
      }
    }
  }

  promotion := pawn & promotion_rank(turn);
  for :bitloop pawn, from: promotion {
    cap := pawn_captures(pawn, turn) & opponent_pieces;
    for :bitloop _, to: cap {
      add_move(move_gen, from, to, Move16.Queen_Promotion_Capture);
      add_move(move_gen, from, to, Move16.Rook_Promotion_Capture);
      add_move(move_gen, from, to, Move16.Bishop_Promotion_Capture);
      add_move(move_gen, from, to, Move16.Knight_Promotion_Capture);
    }
    adv := pawn_advance(pawn, turn) & ~occupied;
    if adv {
      to := bit_scan_forward(adv);
      add_move(move_gen, from, to, Move16.Queen_Promotion);
      add_move(move_gen, from, to, Move16.Rook_Promotion);
      add_move(move_gen, from, to, Move16.Bishop_Promotion);
      add_move(move_gen, from, to, Move16.Knight_Promotion);
    }
  }

  pawn &= ~promotion_rank(turn);
  pawn &= pawn_captures(opponent_pieces, opp);
  for :bitloop pawn_bit, from: pawn {
    attacks := pawn_captures(pawn_bit, turn) & opponent_pieces;
    for :bitloop _, to: attacks {
      add_move(move_gen, from, to, Move16.Capture);
    }
  }
}

file_of :: inline (i: int) -> u64 {
  f := i & 7;
  file: u64 = (cast(u64) file_a) << f;
  return file;
}

fifty_move :: (chess: *Chess, move: Move16, fifty: int) -> int {
  type := get_move16_flag(move);
  from := get_move16_from(move);
  piece_from := piece_at(chess, from);
  if piece_from != .W_PAWN && piece_from != .B_PAWN && type == .Quiet then {
    return fifty + 1;
  }

  return 0;
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

generate_attacks :: (chess: *Chess, $turn: Turn) -> att: u64, check: u64 {
  opp :: turn ^ 1;
  att:   u64 = 0;
  check: u64 = 0;
  opp_king := get_king(chess, opp);
  occupied := chess.occupied & ~opp_king;

  king   := get_king(chess, turn);
  queen  := get_queen(chess, turn);
  rook   := get_rook(chess, turn);
  bishop := get_bishop(chess, turn);
  knight := get_knight(chess, turn); 
  pawn   := get_pawn(chess, turn);

  att |= king_moves(king);

  knight_bitboard := knight_moves(knight);
  att |= knight_bitboard;
  check |= knight_moves(opp_king) & knight;

  pawn_bitboard := pawn_captures(pawn, turn);
  att |= pawn_bitboard;
  check |= pawn_captures(opp_king, opp) & pawn;

  queen_rook := queen | rook;
  for :bitloop bitboard, index: queen_rook {
    att |= rook_moves(index, occupied);
  }
  queen_bishop := queen | bishop;
  for :bitloop bitboard, index: queen_bishop {
    att |= bishop_moves(index, occupied);
  }

  k_sq := bit_scan_forward(opp_king);
  check |= rook_moves(k_sq, occupied) & queen_rook;
  check |= bishop_moves(k_sq, occupied) & queen_bishop;
  return att, check;
}

bitloop :: (bitboard: *u64, body: Code, flags: For_Flags) #expand {
  loop := << bitboard;
  while loop {
    `it_index := bit_scan_forward(loop);
    `it := loop & cast,no_check(u64)(-cast,no_check(int)loop);
    loop ^= it;
    #insert body;
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

Magics :: struct {
  mask: u64;
  #if FANCY_MAGIC_BITBOARDS == false {
    magic: u64;
    relevant_bit: u64;
  }
}

// magics
magic_bishop: [64] Magics #align 64;
magic_rook  : [64] Magics #align 64;

// attacks
bishop_attacks: [64][512]  u64 #align 64;
rook_attacks:   [64][4096] u64 #align 64;

init_magic_bitboard :: () {
  for i: 0..63 {
    sq := cast(u64) (1 << i);
    magic_bishop[i].mask         = bishop_mask(sq);
    #if FANCY_MAGIC_BITBOARDS == false {
      magic_bishop[i].relevant_bit = bishop_relevant_bits[i];
      magic_bishop[i].magic        = bishop_magic_array[i]; 
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
      bishop_magic_array :: u64.[
        0x40106000a1160020,
        0x20010250810120,
        0x2010010220280081,
        0x2806004050c040,
        0x2021018000000,
        0x2001112010000400,
        0x881010120218080,
        0x1030820110010500,
        0x120222042400,
        0x2000020404040044,
        0x8000480094208000,
        0x3422a02000001,
        0xa220210100040,
        0x8004820202226000,
        0x18234854100800,
        0x100004042101040,
        0x4001004082820,
        0x10000810010048,
        0x1014004208081300,
        0x2080818802044202,
        0x40880c00a00100,
        0x80400200522010,
        0x1000188180b04,
        0x80249202020204,
        0x1004400004100410,
        0x13100a0022206,
        0x2148500001040080,
        0x4241080011004300,
        0x4020848004002000,
        0x10101380d1004100,
        0x8004422020284,
        0x1010a1041008080,
        0x808080400082121,
        0x808080400082121,
        0x91128200100c00,
        0x202200802010104,
        0x8c0a020200440085,
        0x1a0008080b10040,
        0x889520080122800,
        0x100902022202010a,
        0x4081a0816002000,
        0x681208005000,
        0x8170840041008802,
        0xa00004200810805,
        0x830404408210100,
        0x2602208106006102,
        0x1048300680802628,
        0x2602208106006102,
        0x602010120110040,
        0x941010801043000,
        0x40440a210428,
        0x8240020880021,
        0x400002012048200,
        0xac102001210220,
        0x220021002009900,
        0x84440c080a013080,
        0x1008044200440,
        0x4c04410841000,
        0x2000500104011130,
        0x1a0c010011c20229,
        0x44800112202200,
        0x434804908100424,
        0x300404822c08200,
        0x48081010008a2a80
      ];
    }

    magic_rook[i].mask           = rook_mask(sq);
    #if FANCY_MAGIC_BITBOARDS == false {
      magic_rook[i].relevant_bit   = rook_relevant_bits[i];
      magic_rook[i].magic          = rook_magic_array[i];
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
  
      rook_magic_array :: u64.[
        0xa80004000801220,
        0x8040004010002008,
        0x2080200010008008,
        0x1100100008210004,
        0xc200209084020008,
        0x2100010004000208,
        0x400081000822421,
        0x200010422048844,
        0x800800080400024,
        0x1402000401000,
        0x3000801000802001,
        0x4400800800100083,
        0x904802402480080,
        0x4040800400020080,
        0x18808042000100,
        0x4040800080004100,
        0x40048001458024,
        0xa0004000205000,
        0x3100808010002000,
        0x4825010010000820,
        0x5004808008000401,
        0x2024818004000a00,
        0x5808002000100,
        0x2100060004806104,
        0x80400880008421,
        0x4062220600410280,
        0x10a004a00108022,
        0x100080080080,
        0x21000500080010,
        0x44000202001008,
        0x100400080102,
        0xc020128200040545,
        0x80002000400040,
        0x804000802004,
        0x120022004080,
        0x10a386103001001,
        0x9010080080800400,
        0x8440020080800400,
        0x4228824001001,
        0x490a000084,
        0x80002000504000,
        0x200020005000c000,
        0x12088020420010,
        0x10010080080800,
        0x85001008010004,
        0x2000204008080,
        0x40413002040008,
        0x304081020004,
        0x80204000800080,
        0x3008804000290100,
        0x1010100080200080,
        0x2008100208028080,
        0x5000850800910100,
        0x8402019004680200,
        0x120911028020400,
        0x8044010200,
        0x20850200244012,
        0x20850200244012,
        0x102001040841,
        0x140900040a100021,
        0x200282410a102,
        0x200282410a102,
        0x200282410a102,
        0x4048240043802106
      ];
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
        index: u64 = ---;
        #if FANCY_MAGIC_BITBOARDS {
          index = pext(occ, mask);
        } else {
          index = (occ * magic) >> (64 - relevant_bit);
        }
        bishop_attacks[sq][index] = __bishop_moves(bitboard, occ);
      }
    }

    calc_rook_attacks :: (using m: *Magics) #expand {
      count := cast(u64) popcount(mask);
      occ_indices := 1 << count;
      for i: 0..occ_indices-1 {
        occ := set_occ(i, count, mask);
        index: u64 = ---;
        #if FANCY_MAGIC_BITBOARDS {
          index = pext(occ, mask);
        } else {
          index = (occ * magic) >> (64 - relevant_bit);
        }
        rook_attacks[sq][index] = __rook_moves(bitboard, occ);
      }
    }
  }

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

bit_scan_forward :: (value: u64)->int #expand {
  #assert(!is_constant(value));

  result := -1;
  #asm { bsf.q result, value; }
  return result;
}

pext :: (a: u64, b: u64) -> u64 #expand {
  c: u64 = ---;
  #asm BMI2 { 
    pext.q c, a, b;
  }
  return c;
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

rook_area :: (qr: u64, occ: u64) -> u64 {
  if qr == 0 return 0;
  NOT_A :: cast(u64) (~file_a);
  NOT_H :: cast(u64) (~file_h);

  n := smear_north(qr << 8, ~(occ<<8));
  s := smear_south(qr >> 8, ~(occ>>8));
  e := smear_east ((qr << 1) & NOT_A, ~((occ<<1) & NOT_A));
  w := smear_west ((qr >> 1) & NOT_H, ~((occ>>1) & NOT_H));
  return n | s | e | w;
}

bishop_area :: (qb: u64, occ: u64) -> u64 {
  if qb == 0 return 0;
  NOT_A :: cast(u64) (~file_a);
  NOT_H :: cast(u64) (~file_h);

  ne := smear_northeast((qb << 9) & NOT_A, ~((occ<<9) & NOT_A));
  se := smear_southeast((qb >> 7) & NOT_A, ~((occ>>7) & NOT_A));
  sw := smear_southwest((qb >> 9) & NOT_H, ~((occ>>9) & NOT_H));
  nw := smear_northwest((qb << 7) & NOT_H, ~((occ<<7) & NOT_H));
  return ne | se | sw | nw;
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
  init_lines :: (a: Bitboard, b: Bitboard, file: Bitboard, $num: int) {
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

// this look-up table can be found inside stockfish chess engine.
// I don't know whether it is correct... might be a bit slow...
between_look_up_table: [64][64] u64;

#scope_export 
between_squares :: inline (i: int, j: int) -> u64 #expand {
  return between_look_up_table[i][j];
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


get_white_pieces :: inline p => p.w_king | p.w_queen | p.w_rook | p.w_bishop | p.w_knight | p.w_pawn;
get_black_pieces :: inline p => p.b_king | p.b_queen | p.b_rook | p.b_bishop | p.b_knight | p.b_pawn;


piece_at :: (chess: *Chess, index: int) -> Piece #expand {
  //assert(0 <= index && index <= 63, "piece_at out of bounds: %\n", index);
  return chess.pieces[index];
}

// TODO: is this really what we want?
in_check :: (chess: *Chess) -> bool {
  if chess.turn == Turn.WHITE {
    return in_check_for(chess, Turn.WHITE);
  } else {
    return in_check_for(chess, Turn.BLACK);
  }

  in_check_for :: (chess: *Chess, $turn: Turn) -> bool {
    opp :: turn ^ 1;
    occupied := chess.occupied;
    king := get_king(chess, turn);
    sq := bit_scan_forward(king);

    pawn := get_pawn(chess, opp);
    if king & pawn_captures(pawn, opp) then {
      return true;
    }

    knight := get_knight(chess, opp); 
    if king & knight_moves(knight) then {
      return true;
    }

    queen := get_queen(chess, opp);
    rook  := get_rook(chess, opp);
    if rook_moves(sq, occupied) & (queen|rook) then
      return true;

    bishop := get_bishop(chess, opp);
    if bishop_moves(sq, occupied) & (queen|bishop) then
      return true;
 
    return false;
  }
}

// TODO: get rid of this.
can_move :: (using chess: *Chess, sq: u64) -> bool {
  if turn == Turn.WHITE {
    // white turn 
    w_pieces := get_white_pieces(chess);
    return (w_pieces & sq) != 0;
  } else {
    // black turn
    b_pieces := get_black_pieces(chess);
    return (b_pieces & sq) != 0;
  }
}

popcount :: (value: u64) -> int #expand {
  result: int;
  #asm { popcnt.q  result, value; }
  return result;
}

bit_reverse64  :: (x: u64) -> u64 #expand {
  // Modified from clang objdump
  rdi: u64 = x;
  rax, rcx, rdx: u64;
  #asm {
    bswap.q   rdi;
    mov.q     rax, 1085102592571150095;
    and.q     rax, rdi;
    shl.q     rax, 4;
    mov.q     rcx, -1085102592571150096;
    and.q     rcx, rdi;
    shr.q     rcx, 4;
    or.q      rcx, rax;
    mov.q     rax, 3689348814741910323;
    and.q     rax, rcx;
    mov.q     rdx, -3689348814741910324;
    and.q     rdx, rcx;
    shr.q     rdx, 2;
    lea.q     rax, [rdx + rax*4];
    mov.q     rcx, 6148914691236517205;
    and.q     rcx, rax;
    mov.q     rdx, -6148914691236517206;
    and.q     rdx, rax;
    shr.q     rdx;
    lea.q     rax, [rdx + rcx*2];
  }

  return rax;
}

popbit :: (a: u64) -> u64 #expand {
  // if we have the BSLR assembly instruction,
  // we run the assembly instruction, else fallback to a &= a-1.
  #if ENABLE_BLSR {
    #asm BMI1 { blsr.q a, a; }
    return a; 
  } else {
    a &= a - 1;
    return a;
  }
}


#import "Machine_X64";
#import "Basic";
#import "String";

// a boolean value set by the metaprogram enabling BLSR instruction.
#placeholder ENABLE_BLSR; 

// a boolean value set by the metaprogram enabling FANCY MAGIC BITBOARDS.
#placeholder FANCY_MAGIC_BITBOARDS;


#no_reset zobrist_piece_table : [13][64] u64 #align 64;
#no_reset zobrist_castling_table : [16] u64 #align 64;
#no_reset zobrist_ep: [64] u64 #align 64;
#no_reset zobrist_turn: u64 #align 64;

#run initialize_zobrist_hashing();

initialize_zobrist_hashing :: () {
  prng := PRNG.{1804289383};
  for i: 1..12 {
    for j: 0..63 {
      zobrist_piece_table[i][j] = random_u64(*prng);
    }
  }
  for i: 0..15 {
    zobrist_castling_table[i] = random_u64(*prng);
  }
  zobrist_ep[0] = 0;
  for i: 1..63 {
    bit := cast(u64)  (1<<i);
    epbits := cast(u64) (rank_3|rank_6);
    if bit & epbits then {
      zobrist_ep[i] = random_u64(*prng);
    }
  }
  zobrist_turn = random_u64(*prng);
}

zobrist_piece_inc :: (piece: Piece, index: int) -> hash: u64 #expand {
  hash := zobrist_piece_table[cast(int)piece][index];
  return hash;
}

zobrist_en_passant :: (ep: u64) -> u64 #expand {
  index := zobrist_bit_scan_forward(ep);
  return zobrist_ep[index];
}

zobrist_hash :: (chess: *Chess) -> hash: u64 {
  hash: u64 = 0;
  for i: 0..63 {
    piece_index := cast(int) chess.pieces[i];
    hash ^= zobrist_piece_table[piece_index][i];
  }
  hash ^= zobrist_castling_table[cast(int)chess.castling];
  hash ^= zobrist_en_passant(chess.en_passant);
  if chess.turn == Turn.BLACK then
    hash ^= zobrist_turn;
  return hash;
}

// default value of zero instead of -1
zobrist_bit_scan_forward :: (input: u64)->int #expand {
  result := 0;
  #asm { bsf.q result, input; }
  return result;
}

get_king :: (chess: *Chess, $turn: Turn) -> u64 #expand {
  #assert(turn == Turn.WHITE || turn == Turn.BLACK);
  #if turn == Turn.WHITE then 
    return chess.w_king;
  else
    return chess.b_king; 
}

get_queen :: (chess: *Chess, $turn: Turn) -> u64 #expand {
  #assert(turn == Turn.WHITE || turn == Turn.BLACK);
  #if turn == Turn.WHITE then 
    return chess.w_queen;
  else
    return chess.b_queen; 
}

get_rook :: (chess: *Chess, $turn: Turn) -> u64 #expand {
  #assert(turn == Turn.WHITE || turn == Turn.BLACK);
  #if turn == Turn.WHITE then 
    return chess.w_rook;
  else
    return chess.b_rook; 
}

get_bishop :: (chess: *Chess, $turn: Turn) -> u64 #expand {
  #assert(turn == Turn.WHITE || turn == Turn.BLACK);
  #if turn == Turn.WHITE then 
    return chess.w_bishop;
  else
    return chess.b_bishop; 
}

get_knight :: (chess: *Chess, $turn: Turn) -> u64 #expand {
  #assert(turn == Turn.WHITE || turn == Turn.BLACK);
  #if turn == Turn.WHITE then
    return chess.w_knight;
  else
    return chess.b_knight;
}

get_pawn :: (chess: *Chess, $turn: Turn) -> u64 #expand {
  #assert(turn == Turn.WHITE || turn == Turn.BLACK);
  #if turn == Turn.WHITE then
    return chess.w_pawn;
  else
    return chess.b_pawn;
}

zugzwang :: inline (using c: *Chess) -> bool {
  w_pieces := w_queen|w_rook|w_bishop|w_knight;
  b_pieces := b_queen|b_rook|b_bishop|b_knight;
  return w_pieces == 0 || b_pieces == 0;
}

to_string :: (move: Move16) -> string {
  if move == 0 {
    return "(none)";
  }

  type, from, to := decode_move16(move);
  p := get_promotion(type);
  if p.count == 0 {
    return sprint("%1%2", cast(serialized_bb) from, cast(serialized_bb) to);
  } else {
    return sprint("%1%2%3", cast(serialized_bb) from, cast(serialized_bb) to, p);
  }
}

append :: (builder: *String_Builder, move: Move16) {
  if move == 0 then {
    print_to_builder(builder, "(none)");
    return;
  }

  type, from, to := decode_move16(move);
  p := get_promotion(type);
  if p.count == 0 {
    print_to_builder(builder, "%1%2", cast(serialized_bb) from, cast(serialized_bb) to);
  } else {
    print_to_builder(builder, "%1%2%3", cast(serialized_bb) from, cast(serialized_bb) to, p);
  }
}

get_promotion :: (using type: Move16) -> string {
  if type == {
  case Knight_Promotion_Capture; #through;
  case Knight_Promotion;
    return "n";
  case Bishop_Promotion; #through;
  case Bishop_Promotion_Capture;
    return "b";
  case Rook_Promotion; #through;
  case Rook_Promotion_Capture;
    return "r";
  case Queen_Promotion; #through;
  case Queen_Promotion_Capture;
    return "q";
  case;
    return "";
  } 
}

print_move :: (move: Move16) {
  if move == 0 {
    print("(none)\n");
    return;
  }
  flags, from, to := decode_move16(move);
  print("%1%2 => %3\n", cast(serialized_bb)from, cast(serialized_bb)to, flags);
}

print_chess :: (chess: *Chess) {
  loop(xx serialized_bb.a8, "8 ");
  loop(xx serialized_bb.a7, "7 ");
  loop(xx serialized_bb.a6, "6 ");
  loop(xx serialized_bb.a5, "5 ");
  loop(xx serialized_bb.a4, "4 ");
  loop(xx serialized_bb.a3, "3 ");
  loop(xx serialized_bb.a2, "2 ");
  loop(xx serialized_bb.a1, "1 ");
  print("  a b c d e f g h\n");
  print("zobrist: 0x%\n", formatInt(chess.hash, 16));
  print("Castling: %\n", chess.castling);
  print("Turn: %\n\n", chess.turn);

  loop :: (x: int, s: string) #expand {
    print(s);
    for i: x..x+7 {
      p := chess.pieces[i];
      if #complete p == {
      case Piece.NONE;
        print(". ");
      case Piece.W_KING;
        print("K ");
      case Piece.W_QUEEN;
        print("Q ");
      case Piece.W_ROOK;
        print("R ");
      case Piece.W_BISHOP;
        print("B ");
      case Piece.W_KNIGHT;
        print("N ");
      case Piece.W_PAWN;
        print("P ");

      case Piece.B_KING;
        print("k ");
      case Piece.B_QUEEN;
        print("q ");
      case Piece.B_ROOK;
        print("r ");
      case Piece.B_BISHOP;
        print("b ");
      case Piece.B_KNIGHT;
        print("n ");
      case Piece.B_PAWN;
        print("p ");
      }
    }
    print("\n");
  }
}

