#import "Basic";
#import "File";
#import "String";
#load "asm.jai";
#load "bitboard.jai";

main :: () {
  text := read_entire_file("resources/openings.txt");
  lines := split(text, "\n");

  for line, i: lines {
    if i == 0 || !line continue;

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

    t2_start = t1_end + 2;
    t2_end   = line.count;

    opening_name := slice(line, t1_start, t1_end - t1_start);
    moves        := slice(line, t2_start, t2_end - t2_start);
    pieces, whose_turn, castling, ep := chess_start_pos();
    for move_string : split(moves, " ") {
      if !move_string continue;

      mov := parse_algebraic_notation(move_string, pieces, whose_turn, castling, ep);
      //capture := PieceType.None;
      //make_move(*pieces, *castling, *ep, *capture, mov, whose_turn);
      whose_turn = !whose_turn;
    }
  }

  parse_algebraic_notation :: (move_string: string, using pieces: Piece_Bitboards, whose_turn: bool, castling: Castling, ep: u64) -> Move16 {
    if equal(move_string, "O-O") {
      // castle kingside.
      return Move16.Quiet;
    } else if equal(move_string, "O-O-O") {
      // castle queenside.
      return Move16.Quiet;
    }

    original_move_string := move_string;
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
      bitboard &= rank_of(move_string[0] - #char "0");
      advance(*move_string, 1);
    }

    if !move_string {
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
      to_bitboard &= rank_of(move_string[0] - #char "0");
      advance(*move_string, 1);
    }

    print("move=[%], % => %\n", original_move_string, cast(bboard)from_bitboard, cast(bboard)to_bitboard);

    return Move16.Quiet;
  }

  file_of :: inline (i: int) -> u64 {
    file: u64 = (cast(u64) file_a) << i;
    return file;
  }

  rank_of :: inline (i: int) -> u64 {
    rank: u64 = (cast(u64) rank_1) << (8*(i-1));
    return rank;
  }
}
