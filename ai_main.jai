#import "Basic";
#import "POSIX";
#import "String";

main :: () {
  nnue_init();
  init_global_bitboards();
  initialize_ai_globals();
  pieces, whose_turn, castling, ep := chess_start_pos();
  repetitions: [..] u64;
  array_reserve(*repetitions, 200);
  fifty := 0;

  // I don't know whether or not random is being called behind
  // my back... so do this just in case.
  seed := cast(s32)(get_time() * 1.1350e14);
  random_seed(seed);

  setup_stdin(); // set STDIN to non-blocking.
  while true {
    reset_stop_signal();
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
      go_command(input);
    }
  }

  setup_position :: (input: string) #expand {
    // TODO: this does not guard against incoherent IO, this is just
    // to get it working... 
    array_reset(*repetitions);
    fifty = 0;
    input = advance(input, 9);
    input = eat_spaces(input);
    if begins_with(input, "fen ") {
      input = advance(input, 4);
      input = eat_spaces(input);
      index :=  find_index_from_left(input, "moves");
 
      // TODO: fen parsing may not work correctly against malicious inputs
      fen_string := ifx index != -1 then slice(input, 0, index) else input;
      pieces, whose_turn, castling, ep = chess_start_from_fen(fen_string);

      if index != -1 {
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
      index := find_index_from_left(input, "moves");
      if index != -1 {
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

      before_pawn := pieces.w_pawn | pieces.b_pawn;
      captured: PieceType;
      make_move(*pieces, *castling, *ep, *captured, move, whose_turn);
      whose_turn = !whose_turn;
      after_pawn := pieces.w_pawn | pieces.b_pawn;

      hash : u64 = 0;
      if move_type == Move16.Quiet && before_pawn == after_pawn {
        hash = zobrist_hash(*pieces, castling, ep, whose_turn);
        fifty += 1;
      } else {
        fifty = 0;
      }
      array_add(*repetitions, hash);
    }
  }

  go_command :: (input: string) #expand {
    input = advance(input, 3);
    token := parse_token(*input);
    if token == {
    case "depth";
      depth, TF := parse_int(*input);
      if !TF return;
      mov := search(*pieces, castling, ep, *repetitions, depth, whose_turn, fifty);
      print_best_move(mov);

    case "infinite";
      depth := INF;   // make the depth arbitrarily high.
      mov := search(*pieces, castling, ep, *repetitions, depth, whose_turn, fifty);
      print_best_move(mov);

    case "perft";
      depth, TF := parse_int(*input);
      if !TF return;
      perft_divide(*pieces, castling, ep, whose_turn, depth);

    }

    print_best_move :: (mov: Move16) {
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
    }
  }
}

stdin_stop_signal :: () -> bool {
  bytes_read := read(STDIN_FILENO, __buffer.data, __buffer.count-1);
  if bytes_read >= 0 then {
    str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
    for < line: split(str, "\n") {
      if equal(line, "stop") {
        __stop_signal = true;
      } else {
        array_add(*__array, line);
      }
    }
  }
  return __stop_signal;
}

reset_stop_signal :: () #expand {
  __stop_signal = false;
}

#scope_file

uci_response :: #string DONE
uciok
id name lion-tulip
id author Daniel Tan
DONE;

// TODO: does this actually do getline, or can
// it return "aaaa\nbbbb"?
getline :: () -> string {
  // TODO: create a queue. then pop from the queue. this way of doing it is unreliable
  // for "stop".
  if __array {
    return pop(*__array);
  }

  bytes_read := 0;
  while true {
    bytes_read = read(STDIN_FILENO, __buffer.data, __buffer.count-1);
    if bytes_read > 0
      break;

    sleep_milliseconds(25);
  }

  str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
  for < line: split(str, "\n") {
    array_add(*__array, line);
  }
  return pop(*__array);
}

__stop_signal := false;
__buffer: [16384] u8;
__array: [..] string;

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


setup_stdin :: () #expand {
  flags := fcntl(STDIN_FILENO, F_GETFL, 0) | O_NONBLOCK;
  fcntl(STDIN_FILENO, F_SETFL, flags);
}


