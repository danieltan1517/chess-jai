main :: () {
  nnue_startup();
  init_global_bitboards();
  initialize_move_randomness();
  init_ttable();
  initialize_chess_game_memory(*chess);
  chess.main_thread = true;
  chess_startpos(*chess);
  fifty := 0;

  for :getline input: os {
    reset_temporary_storage();
    if equal(input, "quit") {
      free_threads();
      return;
    }

    if equal(input, "uci") {
      print(uci_response);
      print("option name Clear Hash type button%1", NEWLINE);
      print("option name Hash type spin default 16 min 1 max 2000%1", NEWLINE);
      print("option name Threads type spin default 1 min 1 max 512%1", NEWLINE);
      print("option name MultiPV type spin default 1 min 1 max 100%1", NEWLINE);
      print("option name Difficulty type spin default 8 min 1 max 8%1", NEWLINE);
      print("uciok%1", NEWLINE);
    }
    
    if equal(input, "isready") {
      print("readyok%", NEWLINE);
    } 

    if equal(input, "ucinewgame") {
      Clear_Hash();
      chess_startpos(*chess);
    } 

    if equal(input, "perft_all") {
      perft_all();
    } 

    if equal(input, "eval") {
      eval := uci_evaluate(*chess);
      print_chess(*chess);
      push_allocator(temp);
      str := to_fen_string(*chess);
      print("FEN=[%1]%2", str, NEWLINE);
      print("Evaluate = %1 cp%2%2", eval, NEWLINE);
    }

    if begins_with(input, "position ") {
      fifty = parse_position(input, *chess);
    }

    if begins_with(input, "go") {
      go_search(input, *chess, fifty);
    }

    if begins_with(input, "setoption ") {
      set_option(input);
    }
  }

  chess_startpos :: (chessgame: *ChessGame) #expand {
    chess_startpos(*chessgame.chess);
    chessgame.nnue[chessgame.ply].accumulator.computedAccumulation = 0;
  }

  chess_fen :: (chessgame: *ChessGame, fen_string: string) -> bool #expand {
    chessgame.nnue[chessgame.ply].accumulator.computedAccumulation = 0;
    return chess_fen(*chessgame.chess, fen_string);
  }
}

#placeholder uci_response;

#scope_file
os: OS;

parse_position :: (line: string, chess: *ChessGame) -> fifty: int {
  clear(chess);
  // TODO: this does not guard against incoherent IO, this is just
  // to get it working... 
  fifty := 0;
  input := advance(line, 9);
  input = eat_spaces(input);
  if begins_with(input, "fen ") {
    input = advance(input, 4);
    input = eat_spaces(input);
    index :=  find_index_from_left(input, "moves");
    fen_string := ifx index != -1 then slice(input, 0, index) else input;
    if !chess_fen(chess, fen_string) {
      print("invalid fen %1%2", fen_string, NEWLINE);
      chess_startpos(chess);
      return 0;
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
    chess_startpos(chess);
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
    return 0;
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
    move_type := get_move16_flag(chess, from, to, promote);
    move := to_move16(from, to, move_type);
    make_move(chess, move);
    if (piece_at(chess,to) != Piece.W_PAWN && piece_at(chess,to) != Piece.B_PAWN) && move_type == Move16.Quiet {
      fifty += 1;
    } else {
      fifty = 0;
    }
  }

  return fifty;
}

go_search :: (line: string, chess: *ChessGame, fifty: int) {
  parse_token(*line);
  token := parse_token(*line);
  if equal(token, "perft") {
    depth, TF := parse_int(*line);
    if !TF return;
    perft_divide(chess, depth);
    return;
  }

  depth := -1;
  nodes := -1;
  movetime := -1;
  movestogo := -1;

  time := -1;
  incr := 0;

  while line {
    if token == {
    case "depth";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse depth%", NEWLINE);
        return;
      }
      depth = value;
    case "nodes";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse nodes%", NEWLINE);
        return;
      }
      nodes = value;
    case "movetime";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse movetime%", NEWLINE);
        return;
      }
      movetime = value;

    case "wtime";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse wtime%", NEWLINE);
        return;
      }
      if chess.turn == .WHITE {
        time = value;
      }

    case "btime";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse btime%", NEWLINE);
        return;
      }
      if chess.turn == .BLACK {
        time = value;
      }

    case "winc";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse winc%", NEWLINE);
        return;
      }
      if chess.turn == .WHITE {
        incr = value;
      }

    case "binc";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse binc%", NEWLINE);
        return;
      }
      if chess.turn == .BLACK {
        incr = value;
      }

    case "movestogo";
      value, TF := parse_int(*line);
      if TF == false {
        print("info string error unable to parse movestogo%", NEWLINE);
        return;
      }
      movestogo = value;

    case;
      print("info string error unable to parse [%1]%2", line, NEWLINE);
      return;
    }

    token = parse_token(*line);
    token = eat_spaces(token);
  }

  if time > -1 && movetime == -1 then {
    movetime = time_management(time, incr, movestogo, chess.ply);
  }

  chess.maxnodes = nodes;
  chess.movetime = movetime;
  chess.maxdepth = depth;
  chess.fifty = fifty;
  mov := uci_search(chess);

  push_allocator(temp);
  str := to_string(mov);
  print("bestmove %1%2", str, NEWLINE);
}

set_option :: (line: string) {
  parse_token(*line);
  token, TF := parse_token(*line);
  if TF == false || !equal(token, "name") {
    print("info string error. unable to parse setoption%", NEWLINE);
    return;
  }

  token = eat_spaces(line);
  found, left, right := split_from_left(token, " value ");
  if left == {
  case "Clear Hash";
    if right {
      print("info string error. Clear Hash cannot be assigned a value%", NEWLINE);
      return;
    }
      
    print("info string Transposition Table Cleared%", NEWLINE);
    Clear_Hash();
  case "Hash";
    num, tf := parse_int(*right);
    if !tf {
      print("info string error. Invalid Hash Value%", NEWLINE);
      return;
    }
    if num >= 1 && num <= 2000 {
      num *= 1_000_000;
      init_ttable(num);
    } else {
      print("info string error. Invalid Hash Value%", NEWLINE);
      return;
    }
  case "MultiPV";
    num, tf := parse_int(*right);
    if !tf {
      print("info string error. Invalid MultiPV Value%", NEWLINE);
      return;
    }
    if num >= 1 && num <= 100 {
      set_multi_pv(num);
    } else {
      print("info string error. Invalid MultiPV Value%", NEWLINE);
      return;
    }
  case "Threads";
    num, tf := parse_int(*right);
    if !tf {
      print("info string error. Invalid Thread Value%", NEWLINE);
      return;
    }
    if num >= 1 && num <= 512 {
      set_threads(num);
    } else {
      print("info string error. Invalid Thread Value%", NEWLINE);
      return;
    }
  case "Difficulty";
    num, tf := parse_int(*right);
    if !tf {
      print("info string error. Invalid Difficulty Value%", NEWLINE);
      return;
    }
    if num >= 1 && num <= 8 {
      set_difficulty(num);
    } else {
      print("info string error. Invalid Difficulty Value%", NEWLINE);
      return;
    }

  case;
    print("info string error. invalid name: [%1]%2", left, NEWLINE);

  }
}

// decides what the movetime is given the time/increment/other parameters in milliseconds
time_management :: (time: int, incr: int, movestogo: int, ply: int) -> movetime: int {
  div := 0;
  if movestogo != -1 then {
    div = movestogo;
  } else {
    div = max(60 - ply, 20);
  }
  movetime := (time / div) + incr - 50;
  if movetime < 0
    movetime = 0;
  return movetime;
}


chess: ChessGame;






