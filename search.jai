#import "Math";

// TODO: eventually, replace this with principled variation search..
negamax :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, depth: int, whose_turn: bool, alpha := -FLOAT32_INFINITY, beta := FLOAT32_INFINITY) -> Move16, float {

  if depth <= 0 then {
    color := ifx whose_turn 1.0 else -1.0;
    eval := nnue_evaluate(pieces, whose_turn) * color;
    return Move16.Quiet, eval;
  }

  move_array: [..] Move16;
  generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);

  best_move, best_eval_value := Move16.Quiet, -FLOAT32_INFINITY;
  for move : move_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    make_move(pieces, *c_copy, *ep_copy, *capture, move, whose_turn);
    _, negamax_eval := negamax(pieces, c_copy, ep_copy, depth-1, whose_turn=!whose_turn, alpha=-beta, beta=-alpha);
    negamax_eval = -negamax_eval;

    if negamax_eval >= best_eval_value {
      best_move  = move;
      best_eval_value = negamax_eval;
    }
    unmake_move(pieces, capture, move, whose_turn);

    alpha = max(alpha, best_eval_value);
    if alpha >= beta then {
      break; 
    }
  }

  return best_move, best_eval_value;
}




// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (p: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, depth: int) -> int {
  if depth <= 0 then return 1;
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

divide :: (p: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, depth: int) -> int {
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


