#import "Math";
#import "Basic";

search :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, depth: int, whose_turn: bool) -> Move16, float {
  time_taken := get_time();
  __nodes_searched = 0;
  move_array: [..] Move16;
  pv_line: PVLine;

  array_reserve(*move_array, 40);
  defer array_free(move_array);
  generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);
  move_ordering(pieces, move_array, whose_turn, *pv_line);

  best_move, best_eval := Move16.Quiet, -INF;
  for move: move_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    make_move(pieces, *c_copy, *ep_copy, *capture, move, whose_turn);
    eval := -negamax(pieces, c_copy, ep_copy, depth-1, !whose_turn, *pv_line);
    unmake_move(pieces, capture, move, whose_turn);
    if eval >= best_eval {
      // TODO: figure out whether to include pv line in here...
      best_move, best_eval = move, eval;
    }
  }

  time_taken = get_time() - time_taken;
  print_stats();
  return best_move, best_eval;

  print_stats :: () #expand {
    Push_Temporary();
    builder: String_Builder;

    print_to_builder(*builder, "info depth % nodes % time % score cp % nps % pv ", 
                                                                  depth, 
                                                       __nodes_searched, 
                                                      time_taken*1000.0,
                                                              best_eval, 
                                 cast(int)(__nodes_searched/time_taken));

    print_move_to_buffer(best_move);
    for mv: pv_line.argmove {
      if mv == 0 break;
      print_move_to_buffer(mv);
    }
    str := builder_to_string(*builder, allocator=__temporary_allocator);
    print("%\ninfo time taken: %\n", str, time_taken);
    reset_temporary_storage();

    print_move_to_buffer :: (mv: Move16) #expand {
      _, from, to := decode_move(mv);
      print_to_builder(*builder, "%1%2 ", cast(serialized_bb)from, cast(serialized_bb)to);
    }
  }
}

negamax :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, depth: int, whose_turn: bool, pv_line: *PVLine, alpha := -INF, beta := INF) -> float {
  line: PVLine;
  __nodes_searched += 1;
  if depth == 0 then {
    pv_line.cmove = 0;
    return quiescene(pieces, castling, ep, whose_turn, pv_line, alpha, beta);
  }

  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  defer array_free(move_array);
  generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);
  move_ordering(pieces, move_array, whose_turn, pv_line);

  eval := -INF;
  for move : move_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    make_move(pieces, *c_copy, *ep_copy, *capture, move, whose_turn);
    eval := max(eval, -negamax(pieces, c_copy, ep_copy, depth-1, !whose_turn, *line, -beta, -alpha));
    unmake_move(pieces, capture, move, whose_turn);
    alpha = max(alpha, eval);

    if eval >= alpha {
      alpha = eval;
      pv_line.argmove[0] = move;
      memcpy(*pv_line.argmove[1], *line.argmove[0], line.cmove * size_of(Move16));
      pv_line.cmove = line.cmove + 1;
    }

    if alpha >= beta then
      break; 
  }

  return eval;
}

// perft results are found here: https://www.chessprogramming.org/Perft_Results
// more perft results: http://www.rocechess.ch/perft.html

perft_all :: () {
  pieces: Piece_Bitboards;
  whose_turn: bool;
  castling: Castling;
  ep: u64;
  setup_perft_run("startpos", 
                  20, 
                  400, 
                  8_902, 
                  197_281, 
                  4_865_609,
                  119_060_324);
  // position 1: initial position
  setup_perft_run(fen="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                  20, 
                  400, 
                  8_902, 
                  197_281, 
                  4_865_609);

  // position 2: kiwipete by peter mckenzie
  setup_perft_run(fen="r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -",
                  48,
                  2_039,
                  97_862,
                  4_085_603,
                  193_690_690);

  // position 3: en paesant bugs
  setup_perft_run(fen="8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -",
                  14,
                  191,
                  2_812,
                  43_238,
                  674_624,
                  11_030_083,
                  178_633_661);
                  //8_031_647_685);  // <-- this takes way too long...

  // position 4: castling
  setup_perft_run("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
                  6,
                  264,
                  9_467,
                  422_333,
                  15_833_292);

  // position 4: castling (mirrored)
  setup_perft_run("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1",
                  6,
                  264,
                  9_467,
                  422_333,
                  15_833_292);
    
  // position 5: TalkChess discussed. rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8  
  setup_perft_run("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
                  44,
                  1_486,
                  62_379,
                  2_103_487,
                  89_941_194);

  // position 6: Steven Edwards weirdness
  setup_perft_run("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
                  46,
                  2_079,
                  89_890,
                  3_894_594);

  // position 7: promotion bugs
  setup_perft_run("n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1",
                  24,
                  496,
                  9_483,
                  182_838,
                  3_605_103);


  print("All perft tests complete!\n");

  setup_perft_run :: ($fen: string, expected: ..int) #expand {
    print("Testing FEN=[%]\n", fen);
    if equal(fen, "startpos") {
      pieces, whose_turn, castling, ep = chess_start_pos();
    } else {
      pieces, whose_turn, castling, ep = chess_start_from_fen(fen_string=fen);
    }

    for exp, depth: expected {
      perft_run(depth+1, exp);
    }
    print("------------------------------------\n\n", fen);
  }

  perft_run :: (depth: int, expected: int) #expand {
    if expected >= 250_000_000 {
      print("Skipping depth: %, too many nodes: %\n", depth, expected);
      return;
    }
    time_taken := get_time();
    nodes := perft(*pieces, castling, ep, whose_turn, depth);
    time_taken = get_time() - time_taken;
    if nodes == expected {
      print("perft successful at the depth of: %, % nodes found, time taken: %.\n", depth, nodes, time_taken);
    } else {
      print("FAILED at the depth of: %, expected: %, nodes found: %, time taken: %\n", depth, expected, nodes, time_taken);
    }
  }
}

perft_divide :: (p: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, depth: int) -> int {
  if depth <= 0 then return 1;
  num_nodes := 0;
  moves_array: [..] Move16;
  array_reserve(*moves_array, 40);
  defer { array_free(moves_array); }

  generate_legal_moves(p, castling, ep, *moves_array, whose_turn);
  print("legal moves from here: %\n", moves_array.count);
  for move : moves_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    make_move(p, *c_copy, *ep_copy, *capture, move, whose_turn);
    add := perft(p, c_copy, ep_copy, !whose_turn, depth-1);

    type, from, to := decode_move(move);
    print("%1%2: %3 nodes\n", cast(serialized_bb)from, cast(serialized_bb)to, add);

    num_nodes = num_nodes + add;
    unmake_move(p, capture, move, whose_turn);
  }
  return num_nodes;
}

#scope_file

INF :: FLOAT32_INFINITY; // Alias

// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, pv_line: *PVLine, alpha: float, beta: float) -> float {
  line: PVLine;
  eval := nnue_evaluate(pieces, whose_turn);
  if eval >= beta then
    return beta;
  if alpha < eval then
    alpha = eval; 

  //print("quiescene search: (%, %)\n", alpha, beta);
  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  defer array_free(move_array);
  generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);
  filter_captures(move_array);
  move_ordering(pieces, move_array, whose_turn, pv_line);

  // search captures only
  for cap_move: move_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    flags, from, to := decode_move(cap_move);
    make_move(pieces, *c_copy, *ep_copy, *capture, cap_move, whose_turn);
    score := -quiescene(pieces, c_copy, ep_copy, !whose_turn, *line, -beta, -alpha);
    unmake_move(pieces, capture, cap_move, whose_turn);

    if score >= beta then
      return beta;
    if score > alpha then {
      alpha = score;
      pv_line.argmove[0] = cap_move;
      memcpy(*pv_line.argmove[1], *line.argmove[0], line.cmove * size_of(Move16));
      pv_line.cmove = line.cmove + 1;
    }
  }

  return alpha;
}

filter_captures :: (move_array: [..] Move16) {
  for mov, i: move_array {
    flags := decode_move(mov);
    using Move16;
    if flags == Capture || flags == Ep_Capture
      continue;
    if Knight_Promotion_Capture <= flags && flags <= Queen_Promotion_Capture
      continue;
    remove mov;
  }
}

PVLine :: struct {
  cmove: int;
  argmove: [32] Move16;
}

// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (p: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, depth: int) -> int {
  if depth == 0 then return 1;
  num_nodes := 0;
  moves_array: [..] Move16;
  array_reserve(*moves_array, 40);
  defer { array_free(moves_array); }

  generate_legal_moves(p, castling, ep, *moves_array, whose_turn);
  for move : moves_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    make_move(p, *c_copy, *ep_copy, *capture, move, whose_turn);
    num_nodes = num_nodes + perft(p, c_copy, ep_copy, !whose_turn, depth-1);
    unmake_move(p, capture, move, whose_turn);
  }
  return num_nodes;
}

// Move Ordering consists of:
// MVV-LVA implementation  -- done
//
// TODO:
// -- principal variation search:
//    https://www.chessprogramming.org/Principal_Variation
// 
// -- history heuristic moves
//    https://www.chessprogramming.org/History_Heuristic
//
// -- killer moves

move_ordering :: (pieces: *Piece_Bitboards, move_array: [..] Move16, whose_turn: bool, pv_line: *PVLine) {
  // TODO: I don't know if some other function wants to use temporary storage.
  count := move_array.count;
  order := NewArray(count, float, allocator=__temporary_allocator);
  defer reset_temporary_storage();

  pawns := ifx whose_turn pieces.w_pawn else pieces.b_pawn;
  p_attacks := ifx whose_turn then black_pawn_captures(pieces.b_pawn) else white_pawn_captures(pieces.w_pawn);

  for i: 0..count-1 {
    if move_array[i] == pv_line.argmove[0] {
      // principle variation move. give highest priority, INF
      order[i] = INF; 
      continue;
    }

    flags, from_index, to_index := decode_move(move_array[i]);

    from := cast(u64) (1 << from_index);
    to   := cast(u64) (1 << to_index);
    using Move16;
    if flags == Capture {
      piece_from_type := piece_type_at(from, pieces, whose_turn);
      piece_to_type := piece_type_at(to, pieces, !whose_turn);
      order[i] = mvv_lva(piece_to_type, piece_from_type);

    } else if flags == Ep_Capture {
      order[i] = mvv_lva(PieceType.Pawn, PieceType.Pawn);

    } else if Knight_Promotion <= flags && flags <= Queen_Promotion_Capture {
      order[i] = 1000.0;
    } else if Knight_Promotion_Capture <= flags && flags <= Queen_Promotion_Capture {
      piece_to_type := piece_type_at(to, pieces, !whose_turn);
      order[i] = mvv_lva(piece_to_type, PieceType.Pawn);

    } else if flags == King_Castle || flags == Queen_Castle {
      order[i] = 75.0;

    } else {
      // quiet moves. don't step into attack range of enemy pawn
      if (from & ~pawns) && (to & p_attacks) { 
        order[i] = -250.0;
      } else {
        order[i] = 0.0;
      }
    }
  }

  // bubble sort the items from highest to lowest.
  // worst case is <64 items, so bubble sort should be optimal.
  while true {
    TF := false;
    for i: 0..count-2 {
      if order[i] < order[i+1] then {
        swap(order[i], order[i+1]);
        swap(move_array[i], move_array[i+1]);
        TF = true;
      }
    }
    if !TF then
      break;
  }

  // most valuable victim, least valuable attacker.
  // see: https://www.chessprogramming.org/MVV-LVA
  mvv_lva :: (victim: PieceType, attacker: PieceType) -> score: float {
    vs := piece_score(victim);
    as := piece_score(attacker);

    return vs + 10.0 - (as * 0.015);

    piece_score :: (using p: PieceType) -> score: float {
      if p == {
      case King;   return 1000.0;
      case Queen;  return  900.0;
      case Rook;   return  500.0;
      case Bishop; return  350.0;
      case Knight; return  325.0;
      case Pawn;   return  100.0;
      case;        return    0.0;
      }
    }
  }

  piece_type_at :: (bit: u64, using p: *Piece_Bitboards, whose_turn: bool) -> PieceType {
    if whose_turn {
      return search_pieces(bit, w_king, w_queen, w_rook, w_bishop, w_knight, w_pawn);
    } else {
      return search_pieces(bit, b_king, b_queen, b_rook, b_bishop, b_knight, b_pawn);
    }

    search_pieces :: (bit: u64, king: u64, queen: u64, rook: u64, bishop: u64, knight: u64, pawn: u64) -> PieceType {
      using PieceType;
      if bit & pawn {
        return Pawn;
      } else if bit & knight {
        return Knight;
      } else if bit & bishop {
        return Bishop;
      } else if bit & rook {
        return Rook;
      } else if bit & queen {
        return Queen;
      } else if bit & king {
        return King;
      } else {
        return None;
      }
    }
  }

  // for sorting
  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

__nodes_searched := 0;


