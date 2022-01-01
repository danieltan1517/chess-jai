math :: #import "Math";
#import "Basic";

search :: (chess: *ChessGame, depth: int, fifty: int) -> Move16 {
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  time_begin := get_time();
  memset(pv_table.data, 0, size_of(type_of(pv_table)));
  memset(__history_moves.data, 0, size_of(type_of(__history_moves)));
  memset(__killer_moves.data,  0, size_of(type_of(__killer_moves)));
  memset(__counter_moves.data, 0, size_of(type_of(__counter_moves)));
  memset(__follow_up.data, 0, size_of(type_of(__follow_up)));
  clear_hash_table();
  __nodes_searched = 0;
  score : int; 
  best_move : Move16;
  alpha: int = -INF;
  beta:  int =  INF;
  delta := 50;
  cur_depth := 1;
  push_allocator(temp);
  while cur_depth <= depth { 
    reset_temporary_storage();
    chess.ply = 0;
    chess.maxply =  0; 
    score = negamax(chess, cur_depth, alpha=alpha, beta=beta, fifty=fifty);

    if score <= alpha then {
      print("info depth % lowerbound %\n", cur_depth, score);
      beta = (alpha + beta) / 2;
      alpha = max(score - delta, -INF);
      delta += delta / 4 + 5;
      continue;
    }

    if score >= beta then {
      print("info depth % upperbound %\n", cur_depth, score);
      beta = min(score + delta, INF);
      delta += delta / 4 + 5;
      continue;
    }
    if score >= -50_000 && score <= 50_000 then {
      alpha = score - delta;
      beta  = score + delta;
    } else {
      alpha = -INF;
      beta  =  INF;
    }

    time_taken := get_time() - time_begin;
    if stop_signal_triggered() then 
      break;
    best_move = pv_table[0][0];
    print_stats(cur_depth);
    cur_depth += 1;
  }
  return best_move;

  print_stats :: (depth: int) #expand {
    builder: String_Builder;
    t_ms := cast(int)(`time_taken*1000.0); // convert secs to ms
    nps  := cast(int)(__nodes_searched/(`time_taken+0.0001));
    print_to_builder(*builder, "info depth % seldepth % ", depth, chess.maxply);
    if score >= -INF+20 && score <= INF-20 then {
      print_to_builder(*builder, "nodes % time % score cp % nps % pv ", __nodes_searched, t_ms, score, nps);
    } else {
      mate := INF - math.abs(score);
      print_to_builder(*builder, "nodes % time % score mate % nps % pv ", __nodes_searched, t_ms, mate, nps);
    }
    count := pv_table[0].move_count - 1;
    for i: 0..count {
      mv := pv_table[0][i];
      if mv == Move16.Quiet break;  // do not print out NULL moves.
      print_move_to_buffer(mv);
    }
    str := builder_to_string(*builder, allocator=__temporary_allocator);
    print("%\n", str);

    print_move_to_buffer :: (mv: Move16) #expand {
      _, from, to := decode_move16(mv);
      print_to_builder(*builder, "%1%2 ", cast(serialized_bb)from, cast(serialized_bb)to);
    }
  }

}

#no_reset LateMovePruning: [64] int;
#run {
  for i: 0..63 {
    LateMovePruning[i] = (3 + i * i) * 3 / 5;
  }
}

negamax :: (chess: *ChessGame, depth: int, $null_flag := true, alpha := -INF, beta := INF, fifty: int) -> int {
  ply := chess.ply;
  pv_node := alpha != beta-1;
  if (__nodes_searched & 1024) && stdin_stop_signal()
    return 0;
  __nodes_searched += 1;

  // transposition lookup.
  h_move := transposition_table_lookup(chess.hash);

  if depth <= 0 then {
    pv_table[ply].move_count = 0;
    return quiescene(chess, alpha, beta, fifty);
  }

  // mate distance pruning
  if ply > 0 then {
    alpha = max(alpha,-INF+ply);
    beta  = min(beta,  INF-ply);
    if alpha >= beta then {
      return alpha;
    }
  }

  // internal iterative deepening.
  if pv_node && h_move == Move16.Quiet && depth > 8 && pv_table[ply][0] == 0 { 
    for cur_depth: 1..depth-3 {
      negamax(chess, cur_depth, null_flag=null_flag, alpha=alpha, beta=beta, fifty=fifty);
      if stop_signal_triggered() then 
        return 0;
    }
  }

  counter  := get_counter_move(chess);
  followup := get_follow_up_move(chess);
  auto_release_temp();
  move_gen := init_negamax(pv_table[ply][0], h_move, __killer_moves[ply][0], __killer_moves[ply][1], counter, followup);
  status := generate_moves(chess, *move_gen, fifty);

  if status == {
  case ChessFlags.Checkmate;
    return -INF + ply;
  case ChessFlags.Stalemate;
    return 0 + ply;
  case ChessFlags.Fifty;
    if ply then
      return 0 + ply;
  case ChessFlags.Threefold_Repetition; 
    if !pv_node then 
      return 0 + ply; 

  case ChessFlags.Normal;
    if ply>0 && !pv_node then {
      static_eval := evaluate(chess, fifty);
      // reverse futility pruning.
      if depth < 7 && math.abs(beta-1) > -INF+100 then {
        futility_margin := 214 * depth; // stockfish has its futility_margin at 214 * depth.
        if static_eval - futility_margin >= beta then {
          return static_eval - futility_margin;
        }
      }
 
      // null move pruning. check for zugzwang before searching.
      if null_flag && depth > 3 && !zugzwang(chess) then {
        R := min(math.abs(static_eval - beta) / 205, 2) + depth / 3 + 3;
        ep, hash := make_null_move(chess);
        score := -negamax(chess, depth-R-1, false, -beta, -beta + 1, fifty);
        unmake_null_move(chess, ep, hash);
        if score >= beta then {
          return beta;
        }
      }
 
      // razoring.
      // taken from BBC chess engine...
      if depth <= 3 then {
        score := static_eval + 250;
        if score < beta && depth == 1 {
          new_score := quiescene(chess, alpha, beta, fifty);
          return ifx new_score > score then new_score else score;
        }
        score += 350;
        if score < beta && depth <= 2 {
          new_score := quiescene(chess, alpha, beta, fifty);
          if new_score < beta {
            return ifx new_score > score then new_score else score;
          }
        }
      }

      // prob cut implement TODO: make this better...currently we copy twice.
      prob_beta := beta + 110;
      if depth > 4 && math.abs(beta) < 20_000 {
        movegen_copy := copy_negamax(move_gen);
        ep := chess.en_passant;
        for move, move_count: movegen_copy {
          flags, from, to := decode_move16(move);
          pfrom := piece_at(chess, from);
         
          // make move.
          cap, castling, hash := make_move(chess, move);
          next_fifty := 0;
          // not a capture/pawn move.
          if pfrom != Piece.W_PAWN && pfrom != Piece.B_PAWN && flags == Move16.Quiet {
            next_fifty = fifty + 1;
          }

          score := -quiescene(chess, -prob_beta, -prob_beta+1, next_fifty);
          if score >= prob_beta then
            score = -negamax(chess, depth-4, false, -prob_beta, -prob_beta + 1, next_fifty);

          unmake_move(chess, move, cap, castling, hash);
          chess.en_passant = ep;

          if score >= prob_beta then {
            return score;
          }
        }
      }
    }
  }

  ep := chess.en_passant;
  hash_flag := TFLAGS.ALPHA;

  quiet_moves := NewArray(64, Move16);
  num_quiets := 0;
  moves_searched := 0;
  // simple search extension, extend if only one move can be played.
  if move_gen.count == 1  then 
    depth += 1;

  for move, move_count : move_gen {
    flags, from, to := decode_move16(move);
    // piece
    pfrom := piece_at(chess, from);
    att := piece_at(chess, from);
    vic := piece_at(chess, to);

    if ply > 3 {
      if move_count != 0 && depth < 5 && flags == Move16.Capture && PVALUE[att] > PVALUE[vic]
      && see(chess,move) < -218*depth  then
        continue;
      
      if move_count != 0 && depth < 5 && flags <= Move16.Double_Pawn_Push && see(chess,move) < -20*depth*depth then
        continue;
     
      moves_searched += 1;
      // Late Move Pruning. Search the Root Plies Exhuastively
      if moves_searched > LateMovePruning[depth] then {
        break;
      }
    }

    // make move.
    cap, castling, hash := make_move(chess, move);
    next_fifty := 0;
    // not a capture/pawn move.
    if pfrom != Piece.W_PAWN && pfrom != Piece.B_PAWN && flags == Move16.Quiet {
      next_fifty = fifty + 1;
    }

    if flags <= Move16.Double_Pawn_Push {
      quiet_moves[num_quiets] = move;
      num_quiets += 1;
    }

    eval := 0;
    if move_count == 0 {
      eval = -negamax(chess, depth-1, null_flag, -beta, -alpha, next_fifty);
    } else {
      // captures. promotions. checks.
      if in_check(chess) {
        // do not reduce depth on check.
        eval = -negamax(chess, depth, null_flag, -alpha-1, -alpha, next_fifty);
      }

      else if cap != Piece.NONE || flags > Move16.Double_Pawn_Push {
        eval = -negamax(chess, depth-1, null_flag, -alpha-1, -alpha, next_fifty);
      }

      // Late Move Reduction when not in check and not giving check.
      else if ply && move_count > 3 && depth > 3 
         && status == ChessFlags.Normal && flags <= Move16.Double_Pawn_Push {

        // do late move reduction when not in check and making "quiet moves" 
        R := LateMoveReduction[min(depth,63)][min(move_count,63)];
        eval = -negamax(chess, depth-R-1, null_flag, -alpha-1, -alpha, next_fifty);
      } 

      else {
        // do normal search.
        eval = -negamax(chess, depth-1, null_flag, -alpha-1, -alpha, next_fifty);
      }

      // re-search the move that has failed to be proved to be bad with normal alpha beta score bounds
      if eval > alpha then {
        eval = -negamax(chess, depth-1, null_flag, -beta, -alpha, next_fifty);
        //print("re-searching... depth %\n", depth);
      } 
    }

    unmake_move(chess, move, cap, castling, hash);
    chess.en_passant = ep;

    if eval > alpha {
      hash_flag = TFLAGS.EXACT;
      pv_table[ply].argmove[0] = move;
      memcpy(*pv_table[ply].argmove[1], *pv_table[ply+1].argmove[0], pv_table[ply+1].move_count * size_of(Move16));
      pv_table[ply].move_count = pv_table[ply+1].move_count + 1;
      alpha = eval;
    } 

    if eval >= beta then {
      hash_flag = TFLAGS.BETA;
      alpha = ifx (eval>(INF-20)) then eval else  beta;
      piece_type := piece_at(chess, from);
      // non-captures == Quiet|Pawn Push Moves
      if flags <= Move16.Double_Pawn_Push {

        // decrement all quiet moves which < alpha.
        for i: 0..num_quiets-1 {
          prev_move := quiet_moves[i];
          if prev_move != move {
            _, from_move, to_move := decode_move16(prev_move);
            piece_type := piece_at(chess, from_move);
            __history_moves[piece_type][to_move] -= xx (depth * depth);
          }
        }
        // update history heuristic
        __history_moves[piece_type][to] += xx (depth * depth);

        // update countermove heuristic
        update_countermove(chess, move);

        // update follow up heuristic
        update_followup(chess, move);

        if move != __killer_moves[ply][0] then {
          __killer_moves[ply][1] = __killer_moves[ply][0];
          __killer_moves[ply][0] = move;
        }
      } 
      break;
    } 
  }

  if status == ChessFlags.Threefold_Repetition || status == ChessFlags.Fifty then {
    alpha = 0 + ply;
    depth = 100;
  }

  transposition_table_store(chess.hash);
  return alpha;

  transposition_table_lookup :: (hash: u64) -> h_move: Move16 #expand {
    key  := hash % TSIZE;
    if ttable.hash[key] == hash then {
      entry := *ttable.entries[key];
      if !pv_node && ply>0 && entry.depth >= depth {
        value := entry.score;
        flag  := entry.flag;
        if flag == {
        case TFLAGS.EXACT;
        `return value;
        
        case TFLAGS.ALPHA;
        if value <= alpha then
          `return alpha; 
        
        case TFLAGS.BETA;
        if value >= beta then
          `return beta; 
        }
      }
      
      return entry.bmove;
    }

    return Move16.Quiet;
  }

  transposition_table_store :: (hash: u64) #expand {
    key  := hash % TSIZE;
    entry := *ttable.entries[key];
    if depth >= entry.depth then {
      ttable.hash[key] = hash;
      entry.score = xx alpha;
      entry.flag = hash_flag;
      entry.depth = xx depth;
      entry.bmove = h_move;
    }
  }

}

// perft results are found here: https://www.chessprogramming.org/Perft_Results
// more perft results: http://www.rocechess.ch/perft.html
perft_all :: () {
  chess: Chess;
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
      chess_startpos(*chess);
    } else {
      chess_fen(*chess, fen);
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
    nodes := perft(*chess, depth);
    time_taken = get_time() - time_taken;
    if nodes == expected {
      print("perft successful at the depth of: %, % nodes found, time taken: %.\n", depth, nodes, time_taken);
    } else {
      print("FAILED at the depth of: %, expected: %, nodes found: %, time taken: %\n", depth, expected, nodes, time_taken);
    }
  }
}

perft_divide :: (chess: *Chess, depth: int) -> int {
  taken := get_time();
  if depth <= 0 then return 1;
  num_nodes := 0;
  movegen: Perft(80);
  generate_moves(chess, *movegen);
  ep := chess.en_passant;
  print("moves from here: %\n\n", movegen.count);
  for move : movegen {
    cap, flags, hash := make_move(chess, move);
    move_count := perft(chess, depth-1);
    _, from, to := decode_move16(move);
    print("%1%2: %3 nodes\n", cast(serialized_bb)from, cast(serialized_bb)to, move_count);

    num_nodes += move_count;
    unmake_move(chess, move, cap, flags, hash);
    chess.en_passant = ep;
  }

  taken = get_time() - taken;
  print("Total: % nodes, Time taken: %\n\n", num_nodes, taken);
  return num_nodes;
}

initialize_ai_globals :: () {
  //zobrist_init_globals();
}

INF :: 0x7FF_FFFF; // Alias

#scope_file
// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (chess: *ChessGame, alpha: int, beta: int, fifty: int = 0) -> int {
  if (__nodes_searched & 1024) && stdin_stop_signal()
    return 0;
  __nodes_searched += 1;
  ply := chess.ply;
  pv_node := alpha != beta-1;
  transposition_table_lookup(chess.hash);

  auto_release_temp();
  moves := init_quiescene(pv_table[ply][0]);
  status := generate_moves(chess, *moves, fifty);
  hash_flag := TFLAGS.ALPHA;
  using ChessFlags;
  if status == {
  case Threefold_Repetition; #through;
  case Stalemate;
    return 0 + ply;

  case Checkmate;
    return -INF + ply;

  case Normal;
    // no standing pat while in check, only when position is normal
    eval := evaluate(chess, fifty);
    if eval >= beta then
      return beta;
  
    // delta pruning:
    if can_delta_prune(chess) {
      delta := 975;
      if is_promoting_pawn(chess) then {
        delta += 775;
      }
      if eval < (alpha - delta) then {
        return alpha; 
      }
    }
    if alpha < eval then {
      hash_flag = TFLAGS.EXACT;
      alpha = eval; 
    }
  }
  // search captures only, captures negate the fifty move rule
  ep := chess.en_passant;
  for move: moves {
    type, from, to := decode_move16(move);

    // piece
    pfrom := piece_at(chess, from);

    // skip bap captures. SEE algorithm.
    if is_bad_capture(move, status) then {
      continue;
    }

    cap, flags, hash := make_move(chess, move);
    next_fifty := 0;
    if pfrom != Piece.W_PAWN && pfrom != Piece.B_PAWN && type==Move16.Quiet {
      next_fifty = fifty + 1;
    }

    score := -quiescene(chess, -beta, -alpha, fifty=next_fifty);
    unmake_move(chess, move, cap, flags, hash);
    chess.en_passant = ep;

    if score >= beta then {
      hash_flag = TFLAGS.BETA;
      transposition_table_store(chess.hash);
      return beta;
    }
    if score > alpha then {
      hash_flag = TFLAGS.EXACT;
      alpha = score;
      pv_table[ply].argmove[0] = move;
      memcpy(*pv_table[ply].argmove[1], *pv_table[ply+1].argmove[0], pv_table[ply+1].move_count * size_of(Move16));
      pv_table[ply].move_count = pv_table[ply+1].move_count + 1;
    }
  }

  transposition_table_store(chess.hash);
  return alpha;

  can_delta_prune :: (using chess: *Chess) -> bool #expand {
    w := w_queen | w_rook | w_bishop | w_knight;
    b := b_queen | b_rook | b_bishop | b_knight;
    return w != 0 || b != 0;
  }

  is_promoting_pawn :: inline (using chess: *Chess) -> bool {
    return (w_pawn & cast(u64)rank_7) != 0 || (b_pawn & cast(u64)rank_2) != 0; 
  }

  // a bad capture => true, a good capture => false
  is_bad_capture :: (move: Move16, status: ChessFlags) -> bool #expand {
    if status != ChessFlags.Normal then
      return false;

    _, from, to := decode_move16(move);
    pfrom := cast(int) piece_at(chess, from);
    pto   := cast(int) piece_at(chess, to);
    if PVALUE[pfrom] > PVALUE[pto] then {
      return see(chess, move) < 0;
    }
    return false;
  }

  transposition_table_lookup :: (hash: u64) #expand {
    key  := hash % TSIZE;
    if !pv_node && ttable.hash[key] == hash then {
      entry := *ttable.entries[key];
      value := entry.score;
      flag  := entry.flag;
      if flag == {
      case TFLAGS.EXACT;
      `return value;
      
      case TFLAGS.ALPHA;
      if value <= alpha then
        `return alpha; 
      
      case TFLAGS.BETA;
      if value >= beta then
        `return beta; 
      }
    }
  }

  // quiescene TT
  transposition_table_store :: (hash: u64) #expand {
    key  := hash % TSIZE;
    entry := *ttable.entries[key];
    if entry.depth <= 0 then {
      ttable.hash[key] = hash;
      entry.score = xx alpha;
      entry.flag = hash_flag;
      entry.depth = 0;
      entry.bmove = Move16.Quiet;
    }
  }
}

PV_Line :: struct {
  argmove: [64] Move16;
  move_count: u16;
}

operator [] :: (using p: PV_Line, index: int) -> Move16 {
  return argmove[index];
}

pv_table: [64] PV_Line;

// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (chess: *Chess, depth: int) -> int {
  if depth == 0 then return 1;
  num_nodes := 0;
  movegen: Perft(80);
  generate_moves(chess, *movegen);
  ep := chess.en_passant;
  for move : movegen {
    piece, flags, hash := make_move(chess, move);
    num_nodes += perft(chess, depth-1);
    unmake_move(chess, move, piece, flags, hash);
    chess.en_passant = ep;
  }
  return num_nodes;
}

#no_reset LateMoveReduction: [64][64] int;
#run {
  for i: 1..63
    for j: 1..63 {
      LMR := math.log(cast(float)i) * math.log(cast(float)j) * 0.5;
      LateMoveReduction[i][j] = cast (int) LMR;
    }
}

// most valuable victim, least valuable attacker.
// see: https://www.chessprogramming.org/MVV-LVA
mvv_lva :: (victim: Piece, attacker: Piece) -> score: int {
  vs := piece_score[cast(int) victim] - piece_score[cast(int) attacker]/100;
  return vs;

  piece_score :: #run -> [13] int {
    using Piece;
    array: [13] int;
    array[cast(int)NONE     ] = 0;
    array[cast(int)W_KING   ] = 100_000;
    array[cast(int)W_QUEEN  ] =  90_000;
    array[cast(int)W_ROOK   ] =  50_000;
    array[cast(int)W_BISHOP ] =  30_000;
    array[cast(int)W_KNIGHT ] =  30_000;
    array[cast(int)W_PAWN   ] =  10_000;

    array[cast(int)B_KING   ] = 100_000;
    array[cast(int)B_QUEEN  ] =  90_000;
    array[cast(int)B_ROOK   ] =  50_000;
    array[cast(int)B_BISHOP ] =  30_000;
    array[cast(int)B_KNIGHT ] =  30_000;
    array[cast(int)B_PAWN   ] =  10_000;
    return array;
  }
}

__nodes_searched := 0;
__history_moves:   [13][64] s16;
__killer_moves:    [64][2] Move16;
__counter_moves:   [13][64] Move16;
__follow_up:       [13][64][13][64] Move16;

// get something off the ground.
TSIZE :: 0x20000;

ttable : struct {
  hash:     [TSIZE] u64;
  entries:  [TSIZE] TTEntry;

  TTEntry :: struct {
    flag : TFLAGS;
    depth: u8;
    bmove: Move16;
    score: s32;
  }
}

TFLAGS :: enum u8 { EXACT; ALPHA; BETA; }

clear_hash_table :: () #expand {
  memset(*ttable, 0, size_of(type_of(ttable)));
}

#scope_export
Negamax :: struct {
  items: [] Move16;
  score: [] int;
  count: int;

  pv       : Move16;
  hmove    : Move16;
  killer1  : Move16;
  killer2  : Move16;
  counter  : Move16;
  follow_up: Move16;
}

init_negamax :: (pv: Move16, hmove: Move16, killer1: Move16, killer2: Move16, counter: Move16, follow_up: Move16) -> Negamax {
  n: Negamax;
  n.items = NewArray(80, Move16);
  n.score = NewArray(80, int);
  n.count = 0;
  n.pv      = pv;
  n.hmove   = hmove;
  n.killer1 = killer1;
  n.killer2 = killer2;
  n.counter = counter;
  n.follow_up = follow_up;
  return n;
}

copy_negamax :: (neg: Negamax) -> Negamax {
  ret: Negamax;
  ret.items     = array_copy(neg.items);
  ret.score     = array_copy(neg.score);
  ret.count     = neg.count;
  ret.pv        = neg.pv;
  ret.hmove     = neg.hmove;
  ret.killer1   = neg.killer1;
  ret.killer2   = neg.killer2;
  ret.counter   = neg.counter;
  ret.follow_up = neg.follow_up;
  return ret;
}

init_quiescene :: (pv: Move16) -> Quiescene {
  q: Quiescene;
  q.pv = pv;
  q.items = NewArray(30, Move16);
  q.score = NewArray(30, int);
  q.count = 0;
  return q;
}

Quiescene :: struct {
  items: [] Move16;
  score: [] int;
  count: int;
  pv: Move16;
}

heap_pop :: (using heap: *Quiescene) -> Move16, int {
  it := items[0];
  sc := score[0];

  items[0] = items[count-1];
  score[0] = score[count-1];
  i := 0;
  back := count-1;
  while i < back {
    l := (i*2)+1;
    r := (i*2)+2;
    largest := i;
    if l < back && score[l] > score[largest] then
      largest = l;
    if r < back && score[r] > score[largest] then
      largest = r;
    if largest == i then {
      break;
    }

    swap(score[i], score[largest]);
    swap(items[i], items[largest]);
    i = largest;
  }
  count-=1;
  return it, sc;

  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

heap_add :: (using heap: *Quiescene, item: Move16, num: int) {
  child  := count;
  parent := (child-1) / 2;
  items[count] = item;
  score[count] = num;
  count += 1;
  while child > 0 && score[parent] < score[child] {
    swap(score[parent], score[child]);
    swap(items[parent], items[child]);
    child = parent;
    parent = (child-1) / 2;
  }

  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

heap_pop :: (using heap: *Negamax) -> Move16, int {
  it := items[0];
  sc := score[0];

  items[0] = items[count-1];
  score[0] = score[count-1];
  i := 0;
  back := count-1;
  while i < back {
    l := (i*2)+1;
    r := (i*2)+2;
    largest := i;
    if l < back && score[l] > score[largest] then
      largest = l;
    if r < back && score[r] > score[largest] then
      largest = r;
    if largest == i then {
      break;
    }

    swap(score[i], score[largest]);
    swap(items[i], items[largest]);
    i = largest;
  }
  count-=1;
  return it, sc;

  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

heap_add :: (using heap: *Negamax, item: Move16, num: int) {
  child  := count;
  parent := (child-1) / 2;
  items[count] = item;
  score[count] = num;
  count += 1;
  while child > 0 && score[parent] < score[child] {
    swap(score[parent], score[child]);
    swap(items[parent], items[child]);
    child = parent;
    parent = (child-1) / 2;
  }

  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

add_move :: (chess: *Chess, heap: *Quiescene, from: int, to: int, $flags: Move16, $in_check: bool) {
  using Move16;

  score := 0;
  move := to_move16(from, to, flags);
  if move == heap.pv {
    score = INF;
    heap_add(heap, move, score);
    return;
  }

  #if flags == Capture {
    att := piece_at(chess, from);
    vic := piece_at(chess, to);
    score = mvv_lva(vic, att);
    heap_add(heap, move, score);
  }
  #if flags == Ep_Capture {
    score = mvv_lva(Piece.W_PAWN, Piece.W_PAWN);
    heap_add(heap, move, score);
  }
  #if flags == Queen_Promotion || flags == Queen_Promotion_Capture {
    score = 90000;
    heap_add(heap, move, score);
  }

  #if in_check && (flags == Quiet || flags == Double_Pawn_Push || flags == King_Castle || flags == Queen_Castle) {
    piece := cast(int) piece_at(chess, from);
    score = __history_moves[piece][to];
    heap_add(heap, move, score); // TODO: evasion history maybe?
  }

  #if !in_check && (flags == Quiet || flags == Double_Pawn_Push || flags == King_Castle || flags == Queen_Castle) {
    #assert(false);
  }
}

add_move :: (chess: *Chess, heap: *Negamax, from: int, to: int, $flags: Move16, $in_check: bool) {
  using Move16;

  move := to_move16(from, to, flags);
  score := 0;

  // move is part of principle variation. store it.
  if move == heap.pv then {
    score = INF;
    heap_add(heap, move, score);
    return;
  }
  if move == heap.hmove then {
    score = INF-1;
    heap_add(heap, move, score);
    return;
  }

  #if flags == Capture {
    // TODO: try different capture move scoring techniques.
    vic := piece_at(chess, to);
    att := piece_at(chess, from);
    score = mvv_lva(vic, att);
  }

  #if flags == Ep_Capture {
    score = mvv_lva(Piece.W_PAWN, Piece.W_PAWN);
  }

  #if flags == Knight_Promotion || flags == Bishop_Promotion || flags == Rook_Promotion {
    score = 8000;
  }

  #if flags == Queen_Promotion {
    score = 90000;
  }

  #if flags == Queen_Promotion_Capture || flags == Bishop_Promotion_Capture 
    || flags == Knight_Promotion_Capture || flags == Rook_Promotion_Capture {
    score = 90000;
  } 
  #if flags == King_Castle || flags == Queen_Castle {
    score = 10000;
  }

  #if flags == Quiet || flags == Double_Pawn_Push {
    if move == heap.killer1 {
      score = 9500;
    } else if move == heap.killer2 {
      score = 9250;
    } else {
      piece := cast(int) piece_at(chess, from);
      score = __history_moves[piece][to];

      if move == heap.counter then {
        COUNTER_BONUS :: 100;
        score += COUNTER_BONUS;
      }

      if move == heap.follow_up then {
        CONTINUE_BONUS :: 100;
        score += CONTINUE_BONUS;
      }
      // a hack to prevent history from overpowering killer moves.
      score = min(score, 9150);
    }
  }

  heap_add(heap, move, score);
}

Perft :: struct($N: int) {
  count: int;
  array: [N] Move16;
}

for_expansion :: (using heap: *$Q/Quiescene, code: Code, f: For_Flags) #expand {
  i := 0;
  while heap.count > 0 {
    mov, score := heap_pop(heap);
    `it, `it_index := mov, i;
    #insert code;
    i += 1;
  }
}

for_expansion :: (using heap: *Negamax, code: Code, f: For_Flags) #expand {
  i := 0;
  while heap.count > 0 {
    mov, score := heap_pop(heap);
    `it, `it_index := mov, i;
    #insert code;
    i += 1;
  }
}

for_expansion :: (perft: *$P/Perft, code: Code, f: For_Flags) #expand {
  i := 0;
  while i < perft.count {
    `it, `it_index := perft.array[i], i;
    #insert code;
    i += 1;
  }
}

add_move :: (chess: *Chess, using perft: *$P/Perft, from: int, to: int, $flags: Move16, $in_check: bool) {
  move := to_move16(from, to, flags);
  array[count] = move;
  count += 1;
}

// TODO: handle pins for more accurate SEE values.
see :: (chess: *Chess, move: Move16) -> eval: int {
  _, from, to := decode_move16(move);
  target := cast(int) piece_at(chess, to);
  apiece := cast(int) piece_at(chess, from);

  gain: [32] int;
  d := 0;
  may_x_ray: u64 = chess.w_pawn | chess.w_bishop | chess.w_rook | chess.w_queen
                 | chess.b_pawn | chess.b_bishop | chess.b_rook | chess.b_queen;
  from_set := cast(u64) 1 << from;
  occupied := chess.occupied;
  attadef  := attacks_to(occupied, to);
  gain[d] = PVALUE[target];
  turn := chess.turn;

  while from_set != 0 {
    d += 1; // next depth and side
    turn ^= 1;
    gain[d] = PVALUE[apiece] - gain[d-1]; // speculative store, if defended

    // prune.
    if max(-gain[d-1], gain[d]) < 0 then
      break; 

    attadef  ^= from_set; // reset bit in set to traverse
    occupied ^= from_set; // reset bit in temporary occupancy (for x-Rays)
    if from_set & may_x_ray then
      attadef |= consider_x_rays(occupied, to, from_set);

    from_set, apiece = get_least_valuable_piece(attadef, turn);
  }

  for < i: d-1..1 {
    gain[i-1]= -max(-gain[i-1], gain[i]);
  }

  return gain[0];

  attacks_to :: (occ: u64, sq: int) -> u64 #expand {
    to := cast(u64) (1 << sq);
    atts : u64 = 0;
    atts |= pawn_captures(to, Turn.BLACK) & chess.w_pawn;
    atts |= pawn_captures(to, Turn.WHITE) & chess.b_pawn;
    atts |= knight_moves(to) & (chess.w_knight|chess.b_knight);
    atts |= bishop_moves(sq, occ) & (chess.w_bishop|chess.b_bishop|chess.w_queen|chess.b_queen);
    atts |= rook_moves(sq, occ) & (chess.w_rook|chess.b_rook|chess.w_queen|chess.b_queen);
    atts |= king_moves(to) & (chess.w_king|chess.b_king);
    return atts;
  }

  consider_x_rays :: (occ: u64, to: int, from_set: u64) -> u64 #expand {
    atts : u64 = 0;
    atts |= bishop_moves(to, occ) & (chess.w_bishop|chess.b_bishop|chess.w_queen|chess.b_queen);
    atts |= rook_moves(to, occ) & (chess.w_rook|chess.b_rook|chess.w_queen|chess.b_queen);
    return atts & occ;
  }

  get_least_valuable_piece :: (attadef: u64, turn: Turn)-> bitboard: u64, piece: int #expand {
    if turn == Turn.WHITE {
      bitboard, piece := least_valuable_piece(attadef, Turn.WHITE);
      return bitboard, piece;
    } else {
      bitboard, piece := least_valuable_piece(attadef, Turn.BLACK);
      return bitboard, piece;
    }

    least_valuable_piece :: (attadef: u64, $turn: Turn) -> bitboard: u64, piece: int #expand {
      subset: u64 = 0;
      pawns := get_pawn(chess, turn);
      subset = attadef & pawns;
      if subset then
        return get_bit(subset), xx Piece.W_PAWN;

      knights := get_knight(chess, turn);
      subset = attadef & knights;
      if subset then
        return get_bit(subset), xx Piece.W_KNIGHT;

      bishops := get_bishop(chess, turn);
      subset = attadef & bishops;
      if subset then
        return get_bit(subset), xx Piece.W_BISHOP;

      rooks := get_rook(chess, turn);
      subset = attadef & rooks;
      if subset then
        return get_bit(subset), xx Piece.W_ROOK;

      queens := get_queen(chess, turn);
      subset = attadef & queens;
      if subset then
        return get_bit(subset), xx Piece.W_QUEEN;

      kings := get_king(chess, turn);
      subset = attadef & kings;
      if subset then
        return get_bit(subset), xx Piece.W_KING;

      return 0, xx Piece.NONE;
    }
  }

  get_bit :: (bits: u64) -> u64 {
    return bits & cast(u64)(-cast(int)bits);
  }

}

PVALUE :: #run -> [13] int {
  using Piece;
  array: [13] int;
  array[cast(int)NONE     ] = 0;
  array[cast(int)W_KING   ] = 100000;
  array[cast(int)W_QUEEN  ] =   1000;
  array[cast(int)W_ROOK   ] =    500;
  array[cast(int)W_BISHOP ] =    300;
  array[cast(int)W_KNIGHT ] =    300;
  array[cast(int)W_PAWN   ] =    100;

  array[cast(int)B_KING   ] = 100000;
  array[cast(int)B_QUEEN  ] =   1000;
  array[cast(int)B_ROOK   ] =    500;
  array[cast(int)B_BISHOP ] =    300;
  array[cast(int)B_KNIGHT ] =    300;
  array[cast(int)B_PAWN   ] =    100;
  return array;
}

ChessGame :: struct {
  using chess: Chess;
  ply: int;
  maxply: int;
  moves: [..] Move32;
  rtable: [..] u64;
}

Move32 :: struct {
  mov16: Move16;
  piece: Piece;
}

clear :: (using c: *ChessGame) {
  array_reset(*moves);
  array_reset(*rtable);
}

// init chess game
initialize_chess_game_memory :: (using c: *ChessGame) {
  array_reserve(*moves, MAX);
  array_reserve(*rtable, MAX);
  MAX :: 1000;
}

generate_moves :: (using c: *ChessGame, movegen: *$T, fifty: int) -> ChessFlags {
  status := generate_moves(*chess, movegen);
  if status == ChessFlags.Checkmate || status == ChessFlags.Stalemate {
    return status;
  }

  if fifty >= 100 {
    return ChessFlags.Fifty;
  }

  hash_val := c.hash;
  for < repeat : c.rtable {
    if hash_val == repeat then {
      return ChessFlags.Threefold_Repetition;
    }
  }

  return status;
}

make_move :: (c: *ChessGame, move: Move16) -> Piece, Castling, u64 {
  from := get_move16_from(move);
  piece := c.pieces[from];
  move32: Move32;
  move32.mov16 = move;
  move32.piece = piece;

  cap, castling, hash := make_move(*c.chess, move);
  array_add(*c.moves, move32);
  array_add(*c.rtable, hash);
  c.ply += 1;
  return cap, castling, hash;
}

unmake_move :: (c: *ChessGame, move: Move16, cap: Piece, castling: Castling, hash: u64) {
  unmake_move(*c.chess, move, cap, castling, hash);
  pop(*c.moves);
  pop(*c.rtable);
  c.ply -= 1;
}

// used for countermove heuristic.
get_counter_move :: (c: *ChessGame) -> Move16 {
  if c.ply > 0 {
    prev := c.moves.count-1;
    prev_move := c.moves[prev];
    piece, to := piece_to(prev_move);
    return __counter_moves[piece][to];
  }
  return Move16.Quiet;
}

update_countermove :: (c: *ChessGame, move: Move16) #expand {
  if c.ply > 0 {
    prev := c.moves.count-1;
    prev_move := c.moves[prev];
    piece, to := piece_to(prev_move);
    __counter_moves[piece][to] = move;
  }
}

update_followup :: (c: *ChessGame, move: Move16) #expand {
  if c.ply >= 2 {
    prev2 := c.moves.count-2;
    piece1, to1 := piece_to(c.moves[prev2]);

    // previous 1 move.
    prev1 := c.moves.count-1;
    piece2, to2 := piece_to(c.moves[prev1]);

    __follow_up[piece1][to1][piece2][to2] = move;
  }
}

get_follow_up_move :: (c: *ChessGame) -> Move16 {
  if c.ply >= 2 {
    // previous 2 move.
    prev2 := c.moves.count-2;
    piece1, to1 := piece_to(c.moves[prev2]);

    // previous 1 move.
    prev1 := c.moves.count-1;
    piece2, to2 := piece_to(c.moves[prev1]);

    return __follow_up[piece1][to1][piece2][to2];
  }
  return Move16.Quiet;

}

piece_to :: (mov: Move32) -> int, int #expand {
  to := get_move16_to(mov.mov16);
  return cast(int)mov.piece, to;
}

make_null_move :: (c: *ChessGame) -> ep: u64, hash: u64 {
  c.ply += 1;
  c.maxply = max(c.maxply, c.ply);
  ep, hash := make_null_move(*c.chess);
  array_add(*c.moves, NULL);
  array_add(*c.rtable, hash);
  return ep, hash;

  NULL :: Move32.{Move16.Quiet, Piece.NONE};
}

unmake_null_move :: (c: *ChessGame, ep: u64, hash: u64) {
  unmake_null_move(*c.chess, ep, hash);
  pop(*c.moves);
  pop(*c.rtable);
  c.ply -= 1;
}


