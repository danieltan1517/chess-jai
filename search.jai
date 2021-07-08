#import "Math";

// performance test
// walks the move generation tree of strictly legal moves to count all the leaf nodes

// TODO: perft from startpos =
// perft startpos 1 => 20
// perft startpos 2 => 400
// perft startpos 3 => 8_902
// perft startpos 4 => 197_281
// perft startpos 5 => 4_865_609
// perft startpos 6 => 119_060_324

perft :: (p: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, depth: int) -> int {
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
    num_nodes = num_nodes + perft(p, c_copy, ep_copy, !whose_turn, depth-1);
    unmake_move(p, capture, move, whose_turn);
  }
  return num_nodes;
}

perft_start_pos :: () {
  pieces := chess_start_pos();

  perft_run(1, 20);
  perft_run(2, 400); 
  perft_run(3, 8_902);
  perft_run(4, 197_281);
  perft_run(5, 4_865_609);
  perft_run(6, 119_060_324);

  perft_run :: (depth: int, expected: int) #expand {
    nodes := perft(*pieces, Castling.All, 0, true, depth);
    if nodes == expected {
      print("perft successful at the depth of: %, % nodes found.\n", depth, nodes);
    } else {
      print("FAILED at the depth of: %, expected: %, actual: %\n", depth, expected, nodes);
    }
  }
}

// TODO: eventually, replace this with principled variation search..
negamax :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, depth: int, whose_turn: bool, alpha := -FLOAT32_INFINITY, beta := FLOAT32_INFINITY) -> Move16, float {

  color := ifx whose_turn 1 else -1;
  if depth <= 0 then {
    eval := evaluate_position(pieces) * color;
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

// TODO: this is pseudocode
// TODO: this evaluate function is a mockup
evaluate_position :: (using pieces: *Piece_Bitboards) -> float {

  white := get_white_pieces(pieces);
  black := get_black_pieces(pieces);
  occ   := white|black;

  w_attacks := generate_attacks(occ, w_king, w_queen, w_rook, w_bishop, w_knight, w_pawn, true);
  b_attacks := generate_attacks(occ, b_king, b_queen, b_rook, b_bishop, b_knight, b_pawn, false);

  q := popcount(w_queen) - popcount(b_queen);
  r := popcount(w_rook)  - popcount(b_rook);
  b := popcount(w_bishop) - popcount(b_bishop);
  n := popcount(w_knight) - popcount(b_knight);
  p := popcount(w_pawn) - popcount(b_pawn);
  eval := (0.25 * popcount(w_attacks)) - (0.25 * popcount(b_attacks));
  material := (9.0 * q) + (5.0 * r) + 3.0 * (b+n) + 1.0 * p;

  ret := material*0.60 + eval*0.40;
  return ret;
}

/*
    if !equal(<<p, p2) {
      type, x, y := decode_move(move);
      print("w_king: %\n", cast(bboard)p2.w_king|p2.w_queen|p2.w_rook|p2.w_bishop|p2.w_knight);
      print("b_king: %\n", cast(bboard)p2.b_king|p2.b_queen|p2.b_rook|p2.b_bishop|p2.b_knight);
      print("w_pawn: %\n", cast(bboard)p2.w_pawn);
      print("b_pawn: %\n", cast(bboard)p2.b_pawn);

      assert(false, "Problem with undo, depth=%, %, %, %\n", depth, type, cast(serialized_bb)x, cast(serialized_bb)y);
    }
*/



