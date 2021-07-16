#import "Basic";
#import "POSIX";
#import "String";

main :: () {
  init_global_bitboards();
  initialize_ai_globals();
  nnue_init();
  pieces, whose_turn, castling, ep := chess_start_pos();

  while true {
    input := getline();
    if equal(input, "quit") {
      break;
    } else if equal(input, "uci") {
      print(uci_response);
    } else if equal(input, "isready") {
      print("readyok\n");
    } else if equal(input, "ucinewgame") {
      pieces, whose_turn, castling, ep = chess_start_pos();

    } else if equal(input, "perft_all") {
      perft_all();
    } else if begins_with(input, "position ") {
      // set up the position
      setup_position(input);

    } else if begins_with(input, "go ") {
      eval := nnue_evaluate(*pieces, whose_turn);
      go_command(input);
    }
  }

  setup_position :: (input: string) #expand {
    // TODO: this does not guard against incoherent IO, this is just
    // to get it working... 

    input = advance(input, 9);
    input = eat_spaces(input);
    if begins_with(input, "fen ") {
      input = advance(input, 4);
      input = eat_spaces(input);
      index, found :=  index_of_string(input, "moves");
 
      // TODO: fen parsing may not work correctly against malicious inputs
      fen_string := ifx found then slice(input, 0, index) else input;
      pieces, whose_turn, castling, ep = chess_start_from_fen(fen_string);

      if found {
        input = advance(input, index);
        input = advance(input, 5);
        input = eat_spaces(input);
      } else {
        input = advance(input, input.count);
      }

    } else if begins_with(input, "startpos") {
      input = advance(input, 8);
      input = eat_spaces(input);
      pieces, whose_turn, castling, ep = chess_start_pos();
      index, found := index_of_string(input, "moves");
      if found {
        input = advance(input, index);
        input = advance(input, 5);
        input = eat_spaces(input);
      } else {
        input = advance(input, input.count);
      }
    } else {
      // we don't know what the input is, so return
      return;
    }

    // we setup the position, now just to parse the moves
    while input {
      token := parse_token(*input);
      x1 := cast(int)(token[0] - #char "a");
      x2 := cast(int)(token[1] - #char "1");
      y1 := cast(int)(token[2] - #char "a");
      y2 := cast(int)(token[3] - #char "1");
      from : u64 = cast(u64) (1 << (x2*8 + x1));
      to   : u64 = cast(u64) (1 << (y2*8 + y1));

      promote := ifx token.count == 5 then token[4] else 0;
      move_type := get_move_type(pieces, ep, from, to, promote, whose_turn);
      move := encode_move_bb(from, to, move_type);
      captured: PieceType;
      make_move(*pieces, *castling, *ep, *captured, move, whose_turn);
      whose_turn = !whose_turn;
    }
  }

  go_command :: (input: string) #expand {
    input = advance(input, 3);
    token := parse_token(*input);
    if token == {
    case "depth";
      depth, TF := parse_int(*input);
      if !TF return;

      mov, eval := search(*pieces, castling, ep, depth, whose_turn);

      flags, from, to := decode_move(mov);
      // hopefully promote the piece functions correctly...
      if flags == Move16.Knight_Promotion || flags == Move16.Knight_Promotion_Capture {
        print("bestmove %1%2n\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else if flags == Move16.Bishop_Promotion || flags == Move16.Bishop_Promotion_Capture {
        print("bestmove %1%2b\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else if flags == Move16.Rook_Promotion || flags == Move16.Rook_Promotion_Capture {
        print("bestmove %1%2r\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else if flags == Move16.Queen_Promotion || flags == Move16.Queen_Promotion_Capture {
        print("bestmove %1%2q\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else {
        print("bestmove %1%2\n", cast(serialized_bb) from, cast(serialized_bb) to);
      }

    case "perft";
      depth, TF := parse_int(*input);
      if !TF return;
      perft_divide(*pieces, castling, ep, whose_turn, depth);
    }
  }
}

#scope_file

uci_response :: #string DONE
uciok
id name Ai-Chess
id author Daniel Tan
DONE;

// TODO: does this actually do getline, or can
// it return "aaaa\nbbbb"?
getline :: () -> string {
  bytes_read := read(STDIN_FILENO, __buffer.data, __buffer.count-1);
  str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
  return str;
}

__buffer: [16384] u8;

// TODO: this assumes the moves are valid
// TODO: this is a long function...
get_move_type :: (using pieces: Piece_Bitboards, en_paesant: u64, from: u64, to: u64, promote: int, whose_turn: bool)->Move16 {
  w_pieces := get_white_pieces(pieces);
  b_pieces := get_black_pieces(pieces);
  if whose_turn {

    // pawn move
    if from & w_pawn {
      if promote != 0 {
        // promotion.
        if to & b_pieces {
          if promote == {
          case #char "q";
            return Move16.Queen_Promotion_Capture;
          case #char "r";
            return Move16.Rook_Promotion_Capture;
          case #char "b";
            return Move16.Bishop_Promotion_Capture;
          case #char "n";
            return Move16.Knight_Promotion_Capture;
          case;
            assert(false);
          }
        } else {
          if promote == {
          case #char "q";
            return Move16.Queen_Promotion;
          case #char "r";
            return Move16.Rook_Promotion;
          case #char "b";
            return Move16.Bishop_Promotion;
          case #char "n";
            return Move16.Knight_Promotion;
          case;
            assert(false);
          }
        }
      } else {
        if to & b_pieces {
          return Move16.Capture;
        } else if to & (en_paesant << 8) {
          return Move16.Ep_Capture;
        } else if (from & xx rank_2) && (to & xx rank_4) {
          return Move16.Double_Pawn_Push;
        } else {
          return Move16.Quiet;
        }
      }
    } else if w_king & from {
      if (from & cast(u64)e1) && (to & cast(u64)g1) {
        return Move16.King_Castle;
      } else if (from & cast(u64)e1) && (to & cast(u64)c1) {
        return Move16.Queen_Castle;
      } else if b_pieces & to {
        return Move16.Capture;
      } else {
        return Move16.Quiet;
      }
    } else if b_pieces & to {
      return Move16.Capture;
    } else {
      return Move16.Quiet;
    }


  } else {

    // pawn move
    if from & b_pawn {
      if promote != 0 {
        // promotion.
        if to & w_pieces {
          if promote == {
          case #char "q";
            return Move16.Queen_Promotion_Capture;
          case #char "r";
            return Move16.Rook_Promotion_Capture;
          case #char "b";
            return Move16.Bishop_Promotion_Capture;
          case #char "n";
            return Move16.Knight_Promotion_Capture;
          case;
            assert(false);
          }
        } else {
          if promote == {
          case #char "q";
            return Move16.Queen_Promotion;
          case #char "r";
            return Move16.Rook_Promotion;
          case #char "b";
            return Move16.Bishop_Promotion;
          case #char "n";
            return Move16.Knight_Promotion;
          case;
            assert(false);
          }
        }
      } else {
        if to & w_pieces {
          return Move16.Capture;
        } else if to & (en_paesant >> 8) {
          return Move16.Ep_Capture;
        } else if (from & xx rank_7) && (to & xx rank_5) {
          return Move16.Double_Pawn_Push;
        } else {
          return Move16.Quiet;
        }
      }
    } else if b_king & from {
      if (from & cast(u64)e8) && (to & cast(u64)g8) {
        return Move16.King_Castle;
      } else if (from & cast(u64)e8) && (to & cast(u64)c8) {
        return Move16.Queen_Castle;
      } else if w_pieces & to {
        return Move16.Capture;
      } else {
        return Move16.Quiet;
      }
    } else if w_pieces & to {
      return Move16.Capture;
    } else {
      return Move16.Quiet;
    }
  }

  return Move16.Quiet;
}






