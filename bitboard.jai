#import "Basic";
#import "String";

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

king_side :: file_e | file_f | file_g | file_h;
queen_side :: (~king_side);

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

equal :: (p1: Piece_Bitboards, p2: Piece_Bitboards)->bool {
  if p1.w_king != p2.w_king return false;
  if p1.b_king != p2.b_king return false;

  if p1.w_queen != p2.w_queen return false;
  if p1.b_queen != p2.b_queen return false;

  if p1.w_bishop != p2.w_bishop return false;
  if p1.b_bishop != p2.b_bishop return false;

  if p1.w_knight != p2.w_knight return false;
  if p1.b_knight != p2.b_knight return false;

  if p1.w_pawn != p2.w_pawn return false;
  if p1.b_pawn != p2.b_pawn return false;
  return true;
}

is_capture :: inline (using m: Move16) -> bool {
  return m == Capture || m == Ep_Capture || (Knight_Promotion_Capture <= m && m <= Queen_Promotion_Capture);
}

PieceType :: enum u8 {
  None;
  King;
  Queen;
  Rook;
  Bishop;
  Knight;
  Pawn;
}

chess_start_pos :: () -> Piece_Bitboards, whose_turn: bool, Castling, ep: u64 {
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
  return start_pos, true, Castling.All, 0;
}

chess_start_from_fen :: (fen_string: string) -> Piece_Bitboards, whose_turn: bool, Castling, ep: u64 {
  // NOTE: not 100% correct parsing, just do something to get the FEN off the ground and
  // start using some basic stuff.
  pos: Piece_Bitboards;
  whose_turn: bool;
  castling: Castling = 0;
  en_paesant: u64 = 0;

  tok: [6] string;
  board: [8] string;

  start, n := 0;
  for i: 0.. fen_string.count-1 {
    if fen_string[i] == #char " " {
      tok[n] = slice(fen_string, start, i-start);
      start = i + 1;
      n += 1;
      if n == 5 then
        break;
    }
  }
  tok[n] = slice(fen_string, start, fen_string.count-start);
  //assert(n == 5); // TODO: do something when n=5, and when n<5

  start, n = 0;
  for i: 0.. tok[0].count-1 {
    if tok[0][i] == #char "/" {
      board[n] = slice(tok[0], start, i-start);
      start = i + 1;
      n += 1;
    }
  }

  assert(n == 7, "Parse error.\n");
  board[n] = slice(tok[0], start, tok[0].count-start);

  // put the pieces on the board according to the FEN string
  parse_board_row(*pos, a8, board[0]);
  parse_board_row(*pos, a7, board[1]);
  parse_board_row(*pos, a6, board[2]);
  parse_board_row(*pos, a5, board[3]);
  parse_board_row(*pos, a4, board[4]);
  parse_board_row(*pos, a3, board[5]);
  parse_board_row(*pos, a2, board[6]);
  parse_board_row(*pos, a1, board[7]);

  // handle whose turn it is
  if tok[1] == {
  case "w";
    whose_turn = true;
  case "b";
    whose_turn = false;
  case;
    assert(false, "Parse error.\n");
  }

  castling = parse_castling_flags(tok[2]);
  en_paesant = parse_en_paesant(tok[3]);

  return pos, whose_turn, castling, en_paesant;

  parse_en_paesant :: inline (tok: string) -> u64 {
    assert(tok.count >= 1 && tok.count <= 2);
    if tok.count == 1 {
      if tok[0] == #char "-"
        return 0;
      assert(false);
    }

    r := cast(int)(tok[0] - #char "a");
    c := cast(int)(tok[1] - #char "1");
    bb : u64 = cast(u64) (1 << (c*8 + r));
    bb = ifx bb & (xx rank_6) then (bb >> 8) else (bb << 8);
    return bb;
  }

  parse_board_row :: inline (using pos: *Piece_Bitboards, b: bboard, tok: string ) {
    start := cast(u64)b;
    for i: 0..tok.count-1 {
      if is_digit(tok[i]) {
        integer := tok[i] - #char "1";
        start = start << integer;
      } else if is_alpha(tok[i]) {
        if tok[i] == {
        case #char "P";
          w_pawn |= start;
        case #char "N";
          w_knight |= start;
        case #char "B";
          w_bishop |= start;
        case #char "R";
          w_rook   |= start;
        case #char "Q";
          w_queen |= start;
        case #char "K";
          w_king |= start;
        case #char "p";
          b_pawn |= start;
        case #char "n";
          b_knight |= start;
        case #char "b";
          b_bishop |= start;
        case #char "r";
          b_rook   |= start;
        case #char "q";
          b_queen |= start;
        case #char "k";
          b_king |= start;
        case;
          assert(false);
        }
      }
      start = start << 1;
    }
  }

  parse_castling_flags :: inline (tok: string) -> Castling {
    using Castling;
    c: Castling = 0;
    for i: 0..tok.count-1 {
      if tok[i] == {
      case #char "-";
        c = 0;
        break;
      case #char "K";
        c |= W_KS;
      case #char "Q";
        c |= W_QS;
      case #char "k";
        c |= B_KS;
      case #char "q";
        c |= B_QS;
      }
    }
    return c;
  }

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

// TODO: this is bad code...
make_move :: (using pieces: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, captured: *PieceType, move: Move16, whose_turn: bool) {
  type, from, to := decode_move(move);
  from_bit := cast(u64) (1 << from);
  to_bit   := cast(u64) (1 << to);
  << ep_sq = 0;

  using Move16;
  if whose_turn {
    if #complete type == {
    case Quiet;
      white_piece_move();
    case Double_Pawn_Push;
      w_pawn = (w_pawn & (~from_bit)) | to_bit;
      <<ep_sq = to_bit;
    case King_Castle;
      w_king = (w_king & (~from_bit)) | to_bit;
      w_rook = (w_rook & xx (~h1)) | xx f1;
      <<flags &= ~(Castling.W_KS | Castling.W_QS);
    case Queen_Castle;
      w_king = (w_king & (~from_bit)) | to_bit;
      w_rook = (w_rook & xx (~a1)) | xx d1;
      <<flags &= ~(Castling.W_KS | Castling.W_QS);
    case Capture;
      white_piece_move();
      black_piece_taken();
    case Ep_Capture;
      w_pawn = (w_pawn & (~from_bit)) | to_bit;
      b_pawn = b_pawn & (~(to_bit >> 8));
      <<captured = PieceType.Pawn;
    case Knight_Promotion_Capture;
      black_piece_taken();
      #through;
    case Knight_Promotion;
      w_pawn = w_pawn & (~from_bit);
      w_knight = w_knight | to_bit;
    case Bishop_Promotion_Capture;
      black_piece_taken();
      #through;
    case Bishop_Promotion;
      w_pawn = w_pawn & (~from_bit);
      w_bishop = w_bishop | to_bit;
    case Rook_Promotion_Capture;
      black_piece_taken();
      #through;
    case Rook_Promotion;
      w_pawn = w_pawn & (~from_bit);
      w_rook = w_rook | to_bit;
    case Queen_Promotion_Capture;
      black_piece_taken();
      #through;
    case Queen_Promotion;
      w_pawn = w_pawn & (~from_bit);
      w_queen = w_queen | to_bit;
    }
  } else {
    if #complete type == {
    case Quiet;
      black_piece_move();
    case Double_Pawn_Push;
      b_pawn = (b_pawn & (~from_bit)) | to_bit;
      <<ep_sq = to_bit;
    case King_Castle;
      b_king = (b_king & (~from_bit)) | to_bit;
      b_rook = (b_rook & xx (~h8)) | xx f8;
      <<flags &= ~(Castling.B_KS | Castling.B_QS);
    case Queen_Castle;
      b_king = (b_king & (~from_bit)) | to_bit;
      b_rook = (b_rook & xx (~a8)) | xx d8;
      <<flags &= ~(Castling.B_KS | Castling.B_QS);
    case Capture;
      black_piece_move();
      white_piece_taken();
    case Ep_Capture;
      b_pawn = (b_pawn & (~from_bit)) | to_bit;
      w_pawn = w_pawn & (~(to_bit << 8));
      <<captured = PieceType.Pawn;
    case Knight_Promotion_Capture;
      white_piece_taken();
      #through;
    case Knight_Promotion;
      b_pawn = b_pawn & (~from_bit);
      b_knight = b_knight | to_bit;
    case Bishop_Promotion_Capture;
      white_piece_taken();
      #through;
    case Bishop_Promotion;
      b_pawn = b_pawn & (~from_bit);
      b_bishop = b_bishop | to_bit;
    case Rook_Promotion_Capture;
      white_piece_taken();
      #through;
    case Rook_Promotion;
      b_pawn = b_pawn & (~from_bit);
      b_rook = b_rook | to_bit;
    case Queen_Promotion_Capture;
      white_piece_taken();
      #through;
    case Queen_Promotion;
      b_pawn = b_pawn & (~from_bit);
      b_queen = b_queen | to_bit;
    }
  }
  if !(w_rook & cast(u64)a1) {
    <<flags &= ~Castling.W_QS;
  }

  if !(w_rook & cast(u64)h1) {
    <<flags &= ~Castling.W_KS;
  }

  if !(b_rook & cast(u64)a8) {
    <<flags &= ~Castling.B_QS;
  }

  if !(b_rook & cast(u64)h8) {
    <<flags &= ~Castling.B_KS;
  }

  white_piece_move :: () #expand {
    if w_king & from_bit {
      w_king = (w_king & (~from_bit)) | to_bit;
      <<flags &= ~(Castling.W_KS | Castling.W_QS);
      return;
    }
    if w_queen & from_bit {
      w_queen = (w_queen & (~from_bit)) | to_bit;
      return;
    }
    if w_rook & from_bit {
      w_rook = (w_rook & (~from_bit)) | to_bit;
      return;
    }
    if w_bishop & from_bit {
      w_bishop = (w_bishop & (~from_bit)) | to_bit;
      return;
    }
    if w_knight & from_bit {
      w_knight = (w_knight & (~from_bit)) | to_bit;
      return;
    }

    if w_pawn & from_bit {
      w_pawn = (w_pawn & (~from_bit)) | to_bit;
      return;
    }
  }

  black_piece_move :: () #expand {
    if b_king & from_bit {
      b_king = (b_king & (~from_bit)) | to_bit;
      <<flags &= ~(Castling.B_KS | Castling.B_QS);
      return;
    }
    if b_queen & from_bit {
      b_queen = (b_queen & (~from_bit)) | to_bit;
      return;
    }
    if b_rook & from_bit {
      b_rook = (b_rook & (~from_bit)) | to_bit;
      return;
    }
    if b_bishop & from_bit {
      b_bishop = (b_bishop & (~from_bit)) | to_bit;
      return;
    }
    if b_knight & from_bit {
      b_knight = (b_knight & (~from_bit)) | to_bit;
      return;
    }

    if b_pawn & from_bit {
      b_pawn = (b_pawn & (~from_bit)) | to_bit;
      return;
    }
  }

  white_piece_taken :: () #expand {
    if w_pawn & to_bit {
      w_pawn &= ~to_bit;
      <<captured = PieceType.Pawn;
      return;
    }
    if w_queen & to_bit {
      w_queen &= ~to_bit;
      <<captured = PieceType.Queen;
      return;
    }
    if w_rook & to_bit {
      w_rook  &= ~to_bit;
      <<captured = PieceType.Rook;
      return;
    }
    if w_bishop & to_bit {
      w_bishop &= ~to_bit;
      <<captured = PieceType.Bishop;
      return;
    }
    if w_knight & to_bit {
      w_knight &= ~to_bit;
      <<captured = PieceType.Knight;
      return;
    }
  }

  black_piece_taken :: () #expand {
    if b_pawn & to_bit {
      b_pawn &= ~to_bit;
      <<captured = PieceType.Pawn;
      return;
    }
    if b_queen & to_bit {
      b_queen &= ~to_bit;
      <<captured = PieceType.Queen;
      return;
    }
    if b_rook & to_bit {
      b_rook  &= ~to_bit;
      <<captured = PieceType.Rook;
      return;
    }
    if b_bishop & to_bit {
      b_bishop &= ~to_bit;
      <<captured = PieceType.Bishop;
      return;
    }
    if b_knight & to_bit {
      b_knight &= ~to_bit;
      <<captured = PieceType.Knight;
      return;
    }
  }
}

unmake_move :: (using pieces: *Piece_Bitboards, captured: PieceType, move: Move16, whose_turn: bool) {
  type, from, to := decode_move(move);
  from_bb := cast(u64) (1 << from);
  to_bb   := cast(u64) (1 << to);
  using Move16;
  if whose_turn {
    if type == {
    case King_Castle;
      black_piece_undo_capture(); 
      w_king = xx e1;
      w_rook = (w_rook & xx (~f1)) | (xx h1);
    case Queen_Castle;
      black_piece_undo_capture(); 
      w_king = xx e1;
      w_rook = (w_rook & xx (~d1)) | (xx a1);
    case Knight_Promotion_Capture; #through;
    case Knight_Promotion;
      black_piece_undo_capture(); 
      w_knight &= xx ~to_bb;
      w_pawn = w_pawn | from_bb;
    case Bishop_Promotion_Capture; #through;
    case Bishop_Promotion;
      black_piece_undo_capture(); 
      w_bishop &= xx (~to_bb);
      w_pawn = w_pawn | from_bb;
    case Rook_Promotion_Capture; #through;
    case Rook_Promotion;
      black_piece_undo_capture(); 
      w_rook &= xx (~to_bb);
      w_pawn = w_pawn | from_bb;
    case Queen_Promotion_Capture; #through;
    case Queen_Promotion;
      black_piece_undo_capture(); 
      w_queen = (w_queen & (~to_bb));
      w_pawn = w_pawn | from_bb;
    case Ep_Capture;
      w_pawn = (w_pawn & (~to_bb)) | from_bb;
      b_pawn = b_pawn | (to_bb >> 8);
    case;
      black_piece_undo_capture(); 
      white_piece_undo_move();
    }
  } else {
    if type == {
    case King_Castle;
      b_king = xx e8;
      b_rook = (b_rook & xx (~f8)) | (xx h8);
    case Queen_Castle;
      b_king = xx e8;
      b_rook = (b_rook & xx (~d8)) | (xx a8);
    case Knight_Promotion_Capture; #through;
    case Knight_Promotion;
      white_piece_undo_capture();
      b_knight &= ~to_bb;
      b_pawn = b_pawn | from_bb;
    case Bishop_Promotion_Capture; #through;
    case Bishop_Promotion;
      white_piece_undo_capture();
      b_bishop &= ~to_bb;
      b_pawn = b_pawn | from_bb;
    case Rook_Promotion_Capture; #through;
    case Rook_Promotion;
      white_piece_undo_capture();
      b_rook &= ~to_bb;
      b_pawn = b_pawn | from_bb;
    case Queen_Promotion_Capture; #through;
    case Queen_Promotion;
      white_piece_undo_capture();
      b_queen &= ~to_bb;
      b_pawn = b_pawn | from_bb;
    case Ep_Capture;
      b_pawn = (b_pawn & (~to_bb)) | from_bb;
      w_pawn = w_pawn | (to_bb << 8);
    case;
      white_piece_undo_capture();
      black_piece_undo_move();
    }
  }

  white_piece_undo_capture :: () #expand {
    if captured == {
    case PieceType.Queen;
      w_queen |= to_bb;
    case PieceType.Rook;
      w_rook  |= to_bb;
    case PieceType.Bishop;
      w_bishop |= to_bb;
    case PieceType.Knight;
      w_knight |= to_bb;
    case PieceType.Pawn;
      w_pawn |= to_bb;
    }
  }

  black_piece_undo_capture :: () #expand {
    if captured == {
    case PieceType.Queen;
      b_queen |= to_bb;
    case PieceType.Rook;
      b_rook  |= to_bb;
    case PieceType.Bishop;
      b_bishop |= to_bb;
    case PieceType.Knight;
      b_knight |= to_bb;
    case PieceType.Pawn;
      b_pawn |= to_bb;
    }

  }

  white_piece_undo_move :: () #expand {
    if w_king & to_bb {
      w_king = (w_king & (~to_bb)) | from_bb;
      return;
    }
    if w_queen & to_bb {
      w_queen = (w_queen & (~to_bb)) | from_bb;
      return;
    }
    if w_rook & to_bb {
      w_rook = (w_rook & (~to_bb)) | from_bb;
      return;
    }
    if w_bishop & to_bb {
      w_bishop = (w_bishop & (~to_bb)) | from_bb;
      return;
    }
    if w_knight & to_bb {
      w_knight = (w_knight & (~to_bb)) | from_bb;
      return;
    }

    if w_pawn & to_bb {
      w_pawn = (w_pawn & (~to_bb)) | from_bb;
      return;
    }
  }

  black_piece_undo_move :: () #expand {
    if b_king & to_bb {
      b_king = (b_king & (~to_bb)) | from_bb;
      return;
    }
    if b_queen & to_bb {
      b_queen = (b_queen & (~to_bb)) | from_bb;
      return;
    }
    if b_rook & to_bb {
      b_rook = (b_rook & (~to_bb)) | from_bb;
      return;
    }
    if b_bishop & to_bb {
      b_bishop = (b_bishop & (~to_bb)) | from_bb;
      return;
    }
    if b_knight & to_bb {
      b_knight = (b_knight & (~to_bb)) | from_bb;
      return;
    }

    if b_pawn & to_bb {
      b_pawn = (b_pawn & (~to_bb)) | from_bb;
      return;
    }
  }
}


generate_legal_moves :: (p: *Piece_Bitboards, c_flags: Castling, ep_sq: u64, moves_arr: *[..] Move16, whose_turn: bool, $captures_only := false) -> u64 {
  w_pieces := get_white_pieces(p);
  b_pieces := get_black_pieces(p);
  occupied := w_pieces | b_pieces;
  if whose_turn {
     return generate_moves_for(moves_arr=moves_arr, c_flags=c_flags, ep_sq=ep_sq, occupied=occupied, pieces=w_pieces, opp_pieces=b_pieces,
       king=p.w_king,     queen=p.w_queen,     rook=p.w_rook,     bishop=p.w_bishop,     knight=p.w_knight,     pawn=p.w_pawn,
       opp_king=p.b_king, opp_queen=p.b_queen, opp_rook=p.b_rook, opp_bishop=p.b_bishop, opp_knight=p.b_knight, opp_pawn=p.b_pawn,
       whose_turn=whose_turn, captures_only=captures_only);
  } else {
     return generate_moves_for(moves_arr=moves_arr, c_flags=c_flags, ep_sq=ep_sq, occupied=occupied, pieces=b_pieces, opp_pieces=w_pieces,
       king=p.b_king,     queen=p.b_queen,     rook=p.b_rook,     bishop=p.b_bishop,     knight=p.b_knight,     pawn=p.b_pawn,
       opp_king=p.w_king, opp_queen=p.w_queen, opp_rook=p.w_rook, opp_bishop=p.w_bishop, opp_knight=p.w_knight, opp_pawn=p.w_pawn,
       whose_turn=whose_turn, captures_only=captures_only);
  }
}

generate_moves_for :: (moves_arr: *[..] Move16, c_flags: Castling, ep_sq: u64, occupied: u64, pieces: u64, opp_pieces: u64, 
                       king: u64,     queen: u64,     rook: u64,     bishop: u64,     knight: u64,     pawn: u64,
                       opp_king: u64, opp_queen: u64, opp_rook: u64, opp_bishop: u64, opp_knight: u64, opp_pawn: u64,
                       whose_turn: bool, $captures_only : bool) -> u64 {
  // NOTE: we do (occupied & (~king)) so that if    R - - - K - - -,
  // then the sliding will go through the king to cover other the unsafe squares
  attacks := generate_attacks(occ=occupied & ~king,
               king=opp_king, queen=opp_queen, rook=opp_rook, bishop=opp_bishop, knight=opp_knight, pawn=opp_pawn,
               whose_turn=!whose_turn);
  checks: u64 = 0;
  pins: u64 = 0;
  i := bit_scan_forward(king);
  k_file := file_of(i);
  k_rank := rank_of(i);
  k_diag := diag_of(i);
  k_adia := adiag_of(i);
  // pawn checks
  if whose_turn {
    checks = checks | (white_pawn_captures(king) & opp_pawn);
  } else {
    checks = checks | (black_pawn_captures(king) & opp_pawn);
  }

  // knight checks
  checks = checks | (knight_moves(king) & opp_knight);

  xray_rook, king_r_ray := xray_rook_attacks(occupied, pieces, i, king);
  xray_bishop, king_b_ray := xray_bishop_attacks(occupied, pieces, i, king);
  rook_pin := xray_rook & (opp_rook | opp_queen);
  bishop_pin := xray_bishop & (opp_bishop | opp_queen);

  checks = checks | (king_r_ray & (opp_rook | opp_queen));
  checks = checks | (king_b_ray & (opp_bishop | opp_queen));
  num_checks := popcount(checks);

  // handle double-check.
  if num_checks == 2 {
    // we only need to generate king moves during a double-check
    king_moves_bb := king_moves(king) & ~pieces & ~attacks;
    generate_normal_moves_from_bitboard(moves_arr, king, king_moves_bb, opp_pieces, captures_only);
    return checks;
  }

  while rook_pin {
    sq: u64 = xx  (1 << bit_scan_forward(rook_pin));
    between_sqs := between_squares(bit_scan_forward(rook_pin), i);
    pinned_piece := between_sqs & pieces;
    pins = pins | pinned_piece;
    rook_pin = rook_pin & (rook_pin - 1);
    if num_checks == 1 break;
    if (queen|rook) & pinned_piece {
      valid_moves : u64 = (between_sqs | sq) & (~pinned_piece);
      generate_normal_moves_from_bitboard(moves_arr, pinned_piece, valid_moves, opp_pieces, captures_only);
      continue;
    }

    // no knight/bishop
    // pawn vertical only, NO pawn horizontal, since pawns cannot move horizontally
    #if !captures_only {
      if (pawn & pinned_piece & k_file) {
        if whose_turn {
          move := (pinned_piece << 8) & (~occupied);
          move = move | ((move & xx rank_3) << 8) & (~occupied);
          generate_pawn_moves_from_bitboard(moves_arr, pinned_piece, move, opp_pieces, captures_only);
        } else {
          move := (pinned_piece >> 8) & (~occupied);
          move = move | ((move & xx rank_6) >> 8) & (~occupied);
          generate_pawn_moves_from_bitboard(moves_arr, pinned_piece, move, opp_pieces, captures_only);
        }
      }
    }
  }

  while bishop_pin {
    sq: u64 = xx  (1 << bit_scan_forward(bishop_pin));
    between_sqs := between_squares(bit_scan_forward(bishop_pin), i);
    pinned_piece := between_sqs & pieces;
    pins = pins | pinned_piece;
    bishop_pin = bishop_pin & (bishop_pin - 1);
    if num_checks == 1 break;
    // no rooks/knights

    // pinned queen/bishop
    if (queen|bishop) & pinned_piece {
      // make pinned piece moves.
      valid_moves := (between_sqs | sq) & (~pinned_piece);
      generate_normal_moves_from_bitboard(moves_arr, pinned_piece, valid_moves, opp_pieces, captures_only);
      continue;
    }

    // pawn diagonal moves only, if pawn is pinned, there is only one possible move.
    if pawn & pinned_piece {
      if whose_turn {
        wp_attacks := white_pawn_captures(pinned_piece & pawn);
        pawn_move := wp_attacks & opp_pieces & (between_sqs|sq);
        generate_pawn_moves_from_bitboard(moves_arr, pinned_piece, pawn_move, opp_pieces, captures_only);
        ep_bb : u64 = (ep_sq << 8);
        if wp_attacks & ep_bb & between_sqs {
          array_add(moves_arr, encode_move_bb(pinned_piece, ep_bb, Move16.Ep_Capture));
        }
      } else {
        bp_attacks := black_pawn_captures(pinned_piece & pawn);
        pawn_move := bp_attacks & opp_pieces & (between_sqs|sq);
        generate_pawn_moves_from_bitboard(moves_arr, pinned_piece, pawn_move, opp_pieces, captures_only);
        ep_bb : u64 = (ep_sq >> 8);
        if bp_attacks & ep_bb & between_sqs {
          array_add(moves_arr, encode_move_bb(pinned_piece, ep_bb, Move16.Ep_Capture));
        }
      }
    }
  }
  // eliminate pieces already handled by pins.
  queen  &= ~pins;
  rook   &= ~pins;
  bishop &= ~pins;
  knight &= ~pins;
  pawn   &= ~pins;
  check_sqs : u64 = 0;
  if num_checks == 1 {
    check_sqs = between_squares(bit_scan_forward(checks), i) | checks;
  } else {
    check_sqs = ~0;
    #if captures_only == false then {
      safe_sqs := cast(bboard) ~attacks;
      not_occu := cast(bboard) ~occupied;
      if whose_turn {
        handle_castling(Castling.W_KS, f1|g1, f1|g1, e1, g1, Move16.King_Castle);
        handle_castling(Castling.W_QS, c1|d1, b1|c1|d1, e1, c1, Move16.Queen_Castle);
      } else {
        handle_castling(Castling.B_KS, f8|g8, f8|g8, e8, g8, Move16.King_Castle);
        handle_castling(Castling.B_QS, c8|d8, b8|c8|d8, e8, c8, Move16.Queen_Castle);
      }
     
      handle_castling :: ($F: Castling, $castle_sqs: bboard, $check_occ: bboard, $from: bboard, $to: bboard, $flags: Move16) #expand {
        if c_flags & F {
          if (safe_sqs & castle_sqs) == castle_sqs && (not_occu & check_occ) == check_occ {
            array_add(moves_arr, encode_move_bb(xx from, xx to, flags));
          }
        }
      }
    }
  }

  while pawn {
    i := bit_scan_forward(pawn);
    from_bb := cast(u64)(1 << i);
    to_bb: u64 = 0;
    if whose_turn then {
      to_bb = white_pawn_moves(occupied, i, from_bb, pieces) & check_sqs;
    } else {
      to_bb = black_pawn_moves(occupied, i, from_bb, pieces) & check_sqs;
    }
    generate_pawn_moves_from_bitboard(moves_arr, from_bb, to_bb, opp_pieces, captures_only);

    // en paesant move. need to handle the strange special en_paesant pin...
    //    - - - - -  EP - - -
    //    K - - - WP BP - - R   -- WP cannot capture BP. need to check if there are multiple rooks on the same rank...
    //    - - - - -  -  - - -
    en_paesant_bb: u64 = 0;
    if whose_turn {
      ep_bb : u64 = ep_sq << 8;
      white_caps : u64 = white_pawn_captures(from_bb);

      if check_sqs & ep_sq {
        en_paesant_bb = white_caps & ep_bb;
      }
      opp_qr := (opp_queen | opp_rook) & (xx rank_5);
      if en_paesant_bb {
        // handle ugly corner case for en paesant pin...
        if (king & xx rank_5) && opp_qr {
          TF := true;
          while opp_qr {
            ooo := bit_scan_forward(opp_qr);
            btwn := between_squares(i, ooo);
            erase_both := occupied & (~(from_bb|ep_sq));
            if (btwn & erase_both) == 0 {
              // there is no blocker, doing the en paesant capture puts king in check.
              TF = false;
              break;
            }
            opp_qr &= opp_qr - 1;
          }
          if TF {
            array_add(moves_arr, encode_move_bb(from_bb, en_paesant_bb, Move16.Ep_Capture));
          }
        } else {
          array_add(moves_arr, encode_move_bb(from_bb, en_paesant_bb, Move16.Ep_Capture));
        }
      }
    } else {
      ep_bb : u64 = ep_sq >> 8;
      black_caps : u64 = black_pawn_captures(from_bb);
      if check_sqs & ep_sq {
        en_paesant_bb = black_caps & ep_bb;
      }
      opp_qr := (opp_queen | opp_rook) & (xx rank_4);
      if en_paesant_bb {
        // handle ugly corner case for en paesant pin...
        if (king & xx rank_4) && opp_qr {
          TF := true;
          while opp_qr {
            ooo := bit_scan_forward(opp_qr);
            btwn := between_squares(i, ooo);
            erase_both := occupied & (~(from_bb|ep_sq));
            if (btwn & erase_both) == 0 {
              // there is no blocker, doing the en paesant capture puts king in check.
              TF = false;
              break;
            }
            opp_qr &= opp_qr - 1;
          }
          if TF {
            array_add(moves_arr, encode_move_bb(from_bb, en_paesant_bb, Move16.Ep_Capture));
          }
        } else {
          array_add(moves_arr, encode_move_bb(from_bb, en_paesant_bb, Move16.Ep_Capture));
        }
      }
    }
    pawn ^= from_bb;
  }

  while knight {
    i := bit_scan_forward(knight);
    from_bb := cast(u64) (1 << i);
    to_bb := knight_moves(from_bb) & (~pieces) & check_sqs;
    generate_normal_moves_from_bitboard(moves_arr, from_bb, to_bb, opp_pieces, captures_only);
    knight ^= from_bb;
  }

  qb := queen|bishop;  // lump queen moves and bishop moves into 1 loop
  while qb {
    i := bit_scan_forward(qb);
    from_bb := cast(u64) (1 << i);
    to_bb   := (bishop_moves(i, occupied) & ~pieces) & check_sqs;
    generate_normal_moves_from_bitboard(moves_arr, from_bb, to_bb, opp_pieces, captures_only);
    qb ^= from_bb;
  }
 
  qr := queen|rook;   // lump queen moves and rook moves into 1 loop
  while qr {
    i := bit_scan_forward(qr);
    from_bb := cast(u64) (1 << i);
    to_bb   := (rook_moves(i, occupied) & ~pieces) & check_sqs;
    generate_normal_moves_from_bitboard(moves_arr, from_bb, to_bb, opp_pieces, captures_only);
    qr ^= from_bb;
  }

  king_moves_bb := king_moves(king) & (~pieces) & (~attacks);
  generate_normal_moves_from_bitboard(moves_arr, king, king_moves_bb, opp_pieces, captures_only);
  return checks;
}

// TODO: should we return the piece attacks separately or together?
// when whose_turn = true, 
//    return white attacks, 
// else 
//    return black attacks,
// generate attacks deals with king safe squares.

generate_attacks :: (occ: u64, king: u64, queen: u64, rook: u64, bishop: u64, knight: u64, pawn: u64, whose_turn: bool) -> u64 {
  attacks : u64 = 0;
  attacks |= king_moves(king);

  qr := queen|rook;
  while qr {
    sq := bit_scan_forward(qr);
    attacks |= rook_moves(sq, occ);
    qr &= qr-1;
  }

  qb := queen|bishop;
  while qb {
    sq := bit_scan_forward(qb);
    attacks |= bishop_moves(sq, occ);
    qb &= qb-1;
  }

  attacks |= knight_moves(knight);
  attacks |= ifx whose_turn white_pawn_captures(pawn) else black_pawn_captures(pawn);
  return attacks;
}

possible_moves_for :: (moves: [..] Move16, from: u64) -> u64 {
  ret: u64 = 0;
  for move: moves {
    type, i, j := decode_move(move);
    from_move := cast(u64) (1 << i);
    to_move   := cast(u64) (1 << j);
    if from == from_move {
      ret = ret | to_move;
    }
  }
  return ret;
}

xray_rook_attacks :: (occ: u64, blockers: u64, i: int, rook_sq: u64) -> u64, u64 {
  attacks := rook_moves(i, occ);
  blockers &= attacks;
  return attacks ^ rook_moves(i, occ ^ blockers), attacks;
}

xray_bishop_attacks :: (occ: u64, blockers: u64, i: int, bishop_sq: u64) -> u64, u64 {
  attacks := bishop_moves(i, occ);
  blockers &= attacks;
  return attacks ^ bishop_moves(i, occ ^ blockers), attacks;
}

white_pawn_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  up1 := (slider << 8) & (~occupied);
  captures := white_pawn_captures(slider) & (occupied & (~friends));
  pawn_power := ((up1 & (xx rank_3)) << 8) & (~occupied);
  return up1 | captures | pawn_power;
}

black_pawn_moves :: inline (occupied: u64, i: int, slider: u64, $$friends: u64 = 0) -> u64 {
  up1 := (slider >> 8) & (~occupied);
  captures := black_pawn_captures(slider) & (occupied & (~friends));
  pawn_power := ((up1 & (xx rank_6)) >> 8) & (~occupied);
  return up1 | captures | pawn_power;
}

white_pawn_captures :: inline (slider: u64) -> u64 {
  return ((slider << 9) & xx (~file_a)) | ((slider << 7) & xx (~file_h));
}

black_pawn_captures :: inline (slider: u64) -> u64 {
  return ((slider >> 7) & xx (~file_a)) | ((slider >> 9) & xx (~file_h));
}

file_of :: inline (i: int) -> u64 {
  //assert(0 <= i && i <= 63);
  f := i & 7;
  file: u64 = (cast(u64) file_a) << f;
  return file;
}

rank_of :: inline (i: int) -> u64 {
  //assert(0 <= i && i <= 63);
  r := i & (~7);
  rank: u64 = (cast(u64) rank_1) << r;
  return rank;
}

diag_of :: inline (i: int)->u64 {
  //assert(0 <= i && i <= 63);
  f := (i & (~7)) >> 3;
  r := i & 7;
  index := 7 + f - r;
  return xx diags[index];
}

adiag_of :: inline (i: int)->u64 {
  //assert(0 <= i && i <= 63);
  f := (i & (~7)) >> 3;
  r := i & 7;
  index := f + r;
  return xx a_diags[index];
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

encode_move_bb :: inline (f: u64, t: u64, flags: Move16) -> Move16 {
  from := bit_scan_forward(f);
  to   := bit_scan_forward(t);
  ret  := (from << 10) | (to << 4) | (xx flags);
  return cast, trunc(Move16) ret;
}


find_move :: (moves: [..]Move16, from: u64, to: u64, typ: Move16=Move16.Quiet) -> Move16 {
  if typ == Move16.Quiet {
    fr1 := bit_scan_forward(from);
    to1 := bit_scan_forward(to);
    for mov: moves {
      flags, fr2, to2 := decode_move(mov);
      if fr1 == fr2 && to1 == to2 {
        return mov;
      }
    }
  } else if Move16.Knight_Promotion <= typ && typ <= Move16.Queen_Promotion_Capture {
    fr1 := bit_scan_forward(from);
    to1 := bit_scan_forward(to);
    for mov: moves {
      flags, fr2, to2 := decode_move(mov);
      if fr1 == fr2 && to1 == to2 && ((flags == typ) || flags == (typ + xx 4)) {
        return mov;
      }
    }
  }
  return 0;
}

move_is_promotion :: inline (using m: Move16) -> bool {
  type, from, to := decode_move(m);
  return Knight_Promotion <= type && type <= Queen_Promotion_Capture;
}

zobrist_hash :: (using p: *Piece_Bitboards, c: Castling, ep: u64, whose_turn: bool) -> u64 {
  #import "Random";
  // calc zobrist hash
  hash : u64 = 0;
  hash ^= hash_pieces(w_king,   __zhash_wk);
  hash ^= hash_pieces(w_queen,  __zhash_wq);
  hash ^= hash_pieces(w_rook,   __zhash_wr);
  hash ^= hash_pieces(w_bishop, __zhash_wb);
  hash ^= hash_pieces(w_knight, __zhash_wn);
  hash ^= hash_pieces(w_pawn,   __zhash_wp);

  hash ^= hash_pieces(b_king,   __zhash_bk);
  hash ^= hash_pieces(b_queen,  __zhash_bq);
  hash ^= hash_pieces(b_rook,   __zhash_br);
  hash ^= hash_pieces(b_bishop, __zhash_bb);
  hash ^= hash_pieces(b_knight, __zhash_bn);
  hash ^= hash_pieces(b_pawn,   __zhash_bp);
  hash ^= hash_pieces(ep,       __zhash_EP);

  mask := ~(cast(u64)whose_turn) + 1;
  hash ^= (__zhash_turn) & mask;

  hash ^= __zhash_castling[cast(int)c];
  return hash;

  hash_pieces :: (p: u64, __zhash_values: [64] u64) -> u64 {
    ret : u64 = 0;
    while p {
      idx := cast(int)bit_scan_forward(p);
      ret = ret ^ __zhash_values[idx];
      p &= p-1;
    }
    return ret;
  }
}

zobrist_init_globals :: (s : s32 = 861097715) {
  // TODO: random generation?
  random_seed(s);
  for i: 0..63 {
    __zhash_wk[i] = rand64();
    __zhash_wq[i] = rand64();
    __zhash_wr[i] = rand64();
    __zhash_wb[i] = rand64();
    __zhash_wn[i] = rand64();
    __zhash_wr[i] = rand64();
 
    __zhash_bk[i] = rand64();
    __zhash_bq[i] = rand64();
    __zhash_br[i] = rand64();
    __zhash_bb[i] = rand64();
    __zhash_bn[i] = rand64();
    __zhash_br[i] = rand64();
    __zhash_EP[i] = rand64();
  }

  __zhash_turn = rand64();

  for i: 0..__zhash_castling.count-1 {
    __zhash_castling[i] = rand64();
  }
  print("info zobrist global initialization done.\n");

  rand64 :: () -> u64 {
    return (random_get() << 32) | random_get();
  }
}

bit_scan_forward :: (input: u64)->int #expand {
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

#scope_file

// magic bit boards for king/knight/pawn look up.
wpawn_cap_look_up_table: [64] u64;
bpawn_cap_look_up_table: [64] u64;

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

// generates normal moves. NOTE: does not handle special moves.
generate_normal_moves_from_bitboard :: (moves_arr: *[..]Move16, from: u64, to: u64, opp_pieces: u64, $captures_only: bool) {
  using Move16;
  #if captures_only then
    to &= opp_pieces;

  while to {
    to_bb := cast(u64)(1 << bit_scan_forward(to));
    flags := ifx (to_bb & opp_pieces) Capture else Quiet; 
    move := encode_move_bb(from, to_bb, flags);
    array_add(moves_arr, move);
    to ^= to_bb;
  }
}

// handle pawn moves except for en paesant
generate_pawn_moves_from_bitboard :: (moves_arr: *[..]Move16, from: u64, to: u64, opp_pieces: u64, $captures_only: bool) {
  using Move16;
  #if captures_only then
    to &= opp_pieces | (xx rank_1) | (xx rank_8);  // promotions are important too.

  while to {
    to_bb := cast(u64)(1 << bit_scan_forward(to));
    // promotion
    if to_bb & xx (rank_1|rank_8) {
      // add all promotion possibilities 
      if to_bb & opp_pieces {
        array_add(moves_arr, encode_move_bb(from, to_bb, Knight_Promotion_Capture));
        array_add(moves_arr, encode_move_bb(from, to_bb, Bishop_Promotion_Capture));
        array_add(moves_arr, encode_move_bb(from, to_bb, Rook_Promotion_Capture));
        array_add(moves_arr, encode_move_bb(from, to_bb, Queen_Promotion_Capture));
      } else {
        #if !captures_only {
          array_add(moves_arr, encode_move_bb(from, to_bb, Knight_Promotion));
          array_add(moves_arr, encode_move_bb(from, to_bb, Bishop_Promotion));
          array_add(moves_arr, encode_move_bb(from, to_bb, Rook_Promotion));
          array_add(moves_arr, encode_move_bb(from, to_bb, Queen_Promotion));
        }
      }
    } else {
      // non-promotion
      flags: Move16;
      ifx to_bb & opp_pieces {
        flags = Capture;
      } else if ((from & xx rank_2) && (to_bb & xx rank_4)) || ((from & xx rank_7) && (to_bb & xx rank_5)) {
        flags = Double_Pawn_Push;
      } else {
        flags = Quiet;
      }

      move := encode_move_bb(from, to_bb, flags);
      array_add(moves_arr, move);
    }
    to ^= to_bb;
  }
}

// zobrist hashing
__zhash_wk: [64] u64;
__zhash_wq: [64] u64;
__zhash_wr: [64] u64;
__zhash_wb: [64] u64;
__zhash_wn: [64] u64;
__zhash_wp: [64] u64;

__zhash_bk: [64] u64;
__zhash_bq: [64] u64;
__zhash_br: [64] u64;
__zhash_bb: [64] u64;
__zhash_bn: [64] u64;
__zhash_bp: [64] u64;

__zhash_EP: [64] u64;

__zhash_turn: u64;

__zhash_castling: [16]  u64;

