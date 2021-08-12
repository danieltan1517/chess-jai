#import "Basic";
#import "File";
#import "String";
#load "asm.jai";
#load "bitboard.jai";

main :: () {
  load_opening_book("resources/openings.txt");
}

load_opening_book :: (file_path: string) {
  text := read_entire_file(file_path);
  lines := split(text, "\n");

  for line, i: lines {
    if i == 0 || !line continue;

    if line[0] == #char "#" continue; // TODO: Skip bugs for now...

    advance(*line, 4);

    t1_start := 0;
    t1_end   := 0;

    t2_start := 0;
    t2_end   := 0;

    j := 0;
    if line[j] == #char "\"" {
      j += 1;
      t1_start = 1;
      while line[j] != #char "\"" {
        j += 1;
      }
      t1_end = j;
    } else {
      t1_start = 0;
      while line[j] != #char "," {
        j += 1;
      }
      t1_end = j;
    }

    t2_start = t1_end + 1;
    t2_end   = line.count;
    opening_name := slice(line, t1_start, t1_end - t1_start); moves        := slice(line, t2_start, t2_end - t2_start);
    pieces, whose_turn, castling, ep := chess_start_pos();
    // TODO:
    for move_string : split(moves, " ") {
      if !move_string continue;
      capture := PieceType.None;
      mov := parse_algebraic_notation(move_string, pieces, whose_turn, castling, ep);
      make_move(*pieces, *castling, *ep, *capture, mov, whose_turn);
      whose_turn = !whose_turn;
    }
    print("\n\n");
  }

  parse_algebraic_notation :: (move_string: string, using pieces: Piece_Bitboards, whose_turn: bool, castling: Castling, ep: u64) -> Move16 {

    if move_string[0] == #char "," then    // TODO: parsing needs to be fixed!
      advance(*move_string, 1);

    print("opening move: %\n", move_string);
    if equal(move_string, "O-O") {
      // castle kingside.
      if whose_turn {
        return encode_move_bb(xx e1, xx g1, Move16.King_Castle);
      } else {
        return encode_move_bb(xx e8, xx g8, Move16.King_Castle);
      }
    } else if equal(move_string, "O-O-O") {
      if whose_turn {
        return encode_move_bb(xx e1, xx c1, Move16.Queen_Castle);
      } else {
        return encode_move_bb(xx e8, xx c8, Move16.Queen_Castle);
      }
    }

    from_bitboard : u64 = ~0;
    to_bitboard   : u64 = ~0;

    if move_string[0] == {
    case #char "K";
      from_bitboard &= ifx whose_turn w_king else b_king;
      advance(*move_string, 1);
    case #char "Q";
      from_bitboard &= ifx whose_turn w_queen else b_queen;
      advance(*move_string, 1);
    case #char "R";
      from_bitboard &= ifx whose_turn w_rook else b_rook;
      advance(*move_string, 1);
    case #char "B";
      from_bitboard &= ifx whose_turn w_bishop else b_bishop;
      advance(*move_string, 1);
    case #char "N";
      from_bitboard &= ifx whose_turn w_knight else b_knight;
      advance(*move_string, 1);
    case;
      from_bitboard &= ifx whose_turn w_pawn else b_pawn;
    }

    bitboard : u64 = ~0;
    if move_string[0] >= #char "a" && move_string[0] <= #char "h" {
      bitboard &= file_of(move_string[0] - #char "a");
      advance(*move_string, 1);
    }

    if move_string[0] >= #char "1" && move_string[0] <= #char "8" {
      bitboard &= rank_of(move_string[0] - #char "1");
      advance(*move_string, 1);
    }

    if !move_string || move_string[0] == #char "+" {
      to_bitboard &= bitboard;
    }

    if move_string && move_string[0] == #char "x" {
      from_bitboard &= bitboard;
      advance(*move_string, 1);
    }

    if move_string && move_string[0] >= #char "a" && move_string[0] <= #char "h" {
      from_bitboard &= bitboard;
      to_bitboard &= file_of(move_string[0] - #char "a");
      advance(*move_string, 1);
    }

    if move_string && move_string[0] >= #char "1" && move_string[0] <= #char "8" {
      from_bitboard &= bitboard;
      to_bitboard &= rank_of(move_string[0] - #char "1");
      advance(*move_string, 1);
    }

    //print("% => %\n", cast(bboard)from_bitboard, cast(bboard)to_bitboard);

    moves_arr: [..] Move16;
    defer array_free(moves_arr);
    array_reserve(*moves_arr, 50);

    generate_legal_moves(*pieces, castling, ep, *moves_arr, whose_turn);
    //print("legal moves = %, whose_turn=%, castling=%, ep=%\n", moves_arr.count, whose_turn, castling, cast(bboard)b_rook);

    // linear search through the legal moves
    for mov : moves_arr {
      f, from, to := decode_move(mov);
      from_mov_bb := cast(u64) (1 << from);
      to_mov_bb   := cast(u64) (1 << to);
      //print("%, % \n", cast(serialized_bb)from, cast(serialized_bb) to);
      if (from_mov_bb & from_bitboard) && (to_mov_bb == to_bitboard) {
        return mov;
      }
    }
    assert(false);
    return Move16.Quiet;
  }

  file_of :: inline (i: int) -> u64 {
    file: u64 = (cast(u64) file_a) << i;
    return file;
  }

  rank_of :: inline (i: int) -> u64 {
    rank: u64 = (cast(u64) rank_1) << (8*i);
    return rank;
  }
}
