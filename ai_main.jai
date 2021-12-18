#import "Basic";
#import "POSIX";
#import "String";

add_move :: (array: *[..] Move16, from: int, to: int, $flags: Move16) {
  assert(from != to, "%1%2 invalid move.\n", cast(serialized_bb)from, cast(serialized_bb)to);
  array_add(array, to_move16(from, to, flags));
}

main :: () {
  nnue_init();
  init_global_bitboards();
  initialize_ai_globals();
  chess: Chess;
  chess_startpos(*chess);
  repetitions: [..] u64;
  array_reserve(*repetitions, 200);
  fifty := 0;

  setup_stdin(); // set STDIN to non-blocking.
  while true {
    reset_stop_signal();
    input := getline();
    if equal(input, "quit") {
      print("Engine exit.\n");
      break;
    } else if equal(input, "uci") {
      print(uci_response);
    } else if equal(input, "isready") {
      print("readyok\n");
    } else if equal(input, "ucinewgame") {
      chess_startpos(*chess);

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
      print("fen = %\n", fen_string);
      if !chess_fen(*chess, fen_string) {
        chess_startpos(*chess);
        return;
      }

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
      chess_startpos(*chess);
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
      from := x2*8 + x1;
      to   := y2*8 + y1;

      promote := ifx token.count == 5 then token[4] else 0;
      move_type := get_move_type(*chess, xx 1<<from, xx 1<<to, promote);
      move := to_move16(from, to, move_type);

      before_pawn := chess.w_pawn | chess.b_pawn;
      make_move(*chess, move);
      after_pawn := chess.w_pawn | chess.b_pawn;
      hash : u64 = 0;
      array_add(*repetitions, hash);
    }
  }

  go_command :: (input: string) #expand {
    input = advance(input, 3);
    token := parse_token(*input);
    if token == {
    case "depth";
      depth, TF := parse_int(*input);
      if !TF || depth < 1 return;
      mov := search(*chess, *repetitions, depth, fifty);
      print_best_move(mov);

    case "infinite";
      depth := INF;   // make the depth arbitrarily high.
      mov := search(*chess, *repetitions, depth, fifty);
      print_best_move(mov);

    case "perft";
      depth, TF := parse_int(*input);
      if !TF return;
      perft_divide(*chess, depth);
    }

    print_best_move :: (mov: Move16) {

      if mov == 0 then {
        print("bestmove (none)\n");
        return;
      }

      using Move16;
      flags, from, to := decode_move(mov);
      // hopefully promote the piece functions correctly...
      if flags == Knight_Promotion || flags == Knight_Promotion_Capture {
        print("bestmove %1%2n\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else if flags == Bishop_Promotion || flags == Bishop_Promotion_Capture {
        print("bestmove %1%2b\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else if flags == Rook_Promotion || flags == Rook_Promotion_Capture {
        print("bestmove %1%2r\n", cast(serialized_bb) from, cast(serialized_bb) to);
      } else if flags == Queen_Promotion || flags == Queen_Promotion_Capture {
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
    for line: split(str, "\n") {
      if equal(line, "stop") {
        __stop_signal = true;
      } else {
        enqueue(line);
      }
    }
  }
  return __stop_signal;
}

stop_signal_triggered :: () -> bool {
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
  if has_elements_to_dequeue()
    return dequeue();
  reset_queue();
  bytes_read := 0;
  memset(__buffer.data, 0, __buffer.count);
  while true {
    bytes_read = read(STDIN_FILENO, __buffer.data, __buffer.count-1);
    if bytes_read > 0
      break;

    sleep_milliseconds(25);
  }
  str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
  for line: split(str, "\n") {
    enqueue(line);
  }
  return dequeue();
}

__stop_signal := false;
__buffer: [16384] u8;
__array: [100] string;
__mark  := 0;
__count := 0;

enqueue :: (s: string) #expand {
  assert(__count < __array.count);
  __array[__count] = s;
  __count += 1;
}

dequeue :: () -> string #expand {
  assert(__mark <= __count, "Error.\n");
  s := __array[__mark];
  __mark += 1;
  return s;
}

has_elements_to_dequeue :: () -> bool #expand {
  return __mark < __count;
}

reset_queue :: () #expand {
  __mark  = 0;
  __count = 0;
}

// TODO: this assumes the moves are valid
// TODO: this is a long function...
get_move_type :: (using chess: *Chess, from: u64, to: u64, promote: int)->Move16 {
  w_pieces := get_white_pieces(chess);
  b_pieces := get_black_pieces(chess);
  if chess.turn == Turn.WHITE {

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
        } else if to & en_passant {
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
        } else if to & en_passant {
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


