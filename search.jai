math :: #import "Math";
#import "Basic";

search :: (chess: *ChessGame, depth: int, fifty: int) -> Move16 {
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  time_begin = get_time();
  memset(pv_table.data, 0, size_of(type_of(pv_table)));
  memset(__history_moves.data, 0, size_of(type_of(__history_moves)));
  memset(__killer_moves.data,  0, size_of(type_of(__killer_moves)));
  memset(__counter_moves.data, 0, size_of(type_of(__counter_moves)));
  memset(__follow_up.data, 0, size_of(type_of(__follow_up)));
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
    chess.depth = cur_depth;
    score = negamax(chess, cur_depth, alpha=alpha, beta=beta, fifty=fifty);
    time_taken := get_time() - time_begin;
    if stop_signal_triggered() then 
      break;

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
    if score >= -5000 && score <= 5000 then {
      alpha = score - delta;
      beta  = score + delta;
    } else if score < -5000 {
      alpha = -INF;
      beta  = score + delta;
    } else {
      alpha = score - delta;
      beta  = INF;
    }
    best_move = pv_table[0][0];
    print_stats(cur_depth);
    cur_depth += 1;
  }

  search_age += 1;
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

#no_reset LateMovePruning: [64][2] int;
#run {
  for i: 0..63 {
    LateMovePruning[i][0] = (3 + i * i) / 2;
    LateMovePruning[i][1] = (3 + i * i);
  }
}

negamax :: (chess: *ChessGame, depth: int, $null_flag := true, $single_ext := true, alpha := -INF, beta := INF, fifty: int) -> int {
  ply := chess.ply;
  pv_node := alpha != beta-1;
  if (__nodes_searched & 1024) && stdin_stop_signal()
    return 0;
  //__nodes_searched += 1;

  defer memset(*pv_table[ply+1], 0, size_of(PV_Line));

  // transposition lookup.
  ttentry := transposition_table_lookup(chess.hash);
  ttmove  := Move16.Quiet;
  if pv_table[ply][0] then {
    ttmove = pv_table[ply][0];
  } else if ttentry != null then {
    ttmove = ttentry.ttmove;
  }

  if depth <= 0 then {
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
  if pv_node && depth > 4 && ttmove == Move16.Quiet { 
    depth -= 2;
  }

  // TODO: this is NOT good code. inefficient.
  status := check_for_repetition(chess, fifty);
  if status == {
  case ChessFlags.Fifty;
    if ply then
      return 0 + ply;
  case ChessFlags.Threefold_Repetition; 
    if !pv_node then 
      return 0 + ply; 
  }

  array_add(*chess.eval, cast(s16)INF);
  defer pop(*chess.eval);

  // do pruning here. TODO:
  if status == ChessFlags.Normal && !in_check(chess) {
    if ply>0 && !pv_node then {
      static_eval := evaluate(chess, fifty);
      chess.eval[chess.eval.count-1] = cast(s16) static_eval;
      improving := get_improving(chess);

      // reverse futility pruning. stockfish has margin at 214*depth
      margin := 150*(depth-improving);
      if depth < 12 && (static_eval-margin) >= beta then {
        return static_eval;
      }
 
      // null move pruning. check for zugzwang before searching.
      #if null_flag == true then {
        if depth > 3 then {
          R := min(max(-depth/3, (static_eval - beta)/205), 2) + depth / 3 + 3;
          ep, hash := make_null_move(chess);
          score := -negamax(chess, depth-R-1, false, single_ext, -beta, -beta + 1, fifty);
          unmake_null_move(chess, ep, hash);
       
          if score >= beta then {
            // null move w/ verification at higher depths.
            if depth>12 || zugzwang(chess) then {
              score = negamax(chess, depth-R-1, false, single_ext, beta-1, beta, fifty);
              if score >= beta then
                return beta;
            } else {
              return beta;
            }
          }
        }
      }
 
      // razoring.
      if depth < 3 then {
        score := static_eval + 175;
        if score < beta && depth == 1 {
          new_score := quiescene(chess, alpha, beta, fifty);
          return ifx new_score > score then new_score else score;
        }
        score += 250;
        if score < beta {
          new_score := quiescene(chess, alpha, beta, fifty);
          if new_score < beta {
            return ifx new_score > score then new_score else score;
          }
        }
      }

      // prob cut implement TODO: make this better...currently we copy twice.
      prob_beta := beta + 110;
      if depth > 4 && math.abs(beta) < 20_000 {
        prob_movegen := init_quiescene(pv_table[ply][0], ttmove);
        generate_moves(chess, *prob_movegen, fifty);
        ep := chess.en_passant;
        for move, move_count: prob_movegen {
          flags, from, to := decode_move16(move);
          pfrom := piece_at(chess, from);
         
          // make capture move.
          cap, castling, hash := make_move(chess, move);
          next_fifty := 0;

          score := -quiescene(chess, -prob_beta, -prob_beta+1, 0);
          if score >= prob_beta then
            score = -negamax(chess, depth-4, false, single_ext, -prob_beta, -prob_beta + 1, 0);

          unmake_move(chess, move, cap, castling, hash);
          chess.en_passant = ep;

          if score >= prob_beta then {
            return score;
          }
        }
      }
    }
  }

  counter  := get_counter_move(chess);
  followup1, followup2 := get_follow_up_move(chess);
  move_gen := init_negamax(ttmove, __killer_moves[ply][0], __killer_moves[ply][1], counter, followup1, followup2);
  status = generate_moves(chess, *move_gen, fifty);

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
  }

  ep := chess.en_passant;
  hash_flag := TFLAGS.ALPHA;

  quiet_moves: [64] Move16;
  num_quiets := 0;
  moves_searched := 0;

  // search extension: extend if only one move can be played.
  if move_gen.count == 1  then {
    depth += 1;
  }

  alpha_increase := 0;
  improving := get_improving(chess);
  for move, move_count : move_gen {
    #if single_ext == false {
      if ply == chess.exply && move == chess.excluded_move then {
        continue;
      }
    }

    flags, from, to := decode_move16(move);
    print_curr_move();

    // piece
    pfrom := piece_at(chess, from);
    att := piece_at(chess, from);
    vic := piece_at(chess, to);
    if ply>0 && move_count>0 {
      if flags == Move16.Capture && PVALUE[att] > PVALUE[vic] && see(chess,move) < -218*depth  then
        continue;
      if flags <= Move16.Double_Pawn_Push && see(chess,move) < -21*depth*depth - 21 then
        continue;

      if move_score < min(depth * -8192, -15_000) then
        break;

      // Late Move Pruning. Search the Root Plies Exhuastively
      if flags <= Move16.Double_Pawn_Push && moves_searched > LateMovePruning[depth][improving] then
        break;
    }

    // singular extension:
    // if one move is better than all the rest, then we consider this singular
    // "singular" is determined by checking all other moves at a shallow depth on a nullwindow
    ext := 0;
    #if single_ext == true {
      if ply>0 && depth>=7 && move == ttmove && ttentry != null && cast(int)ttentry.depth >= depth-3 
         && math.abs(ttentry.score) < 20_000 && ttentry.flag == TFLAGS.ALPHA {
     
         singular_beta := ttentry.score - 3*depth;
         chess.excluded_move = move;
         chess.exply = ply;
         score := negamax(chess, depth-(depth/2)-1, null_flag, false, singular_beta-1, singular_beta, fifty);
         chess.excluded_move = Move16.Quiet;
         chess.exply = INF;
         if score < singular_beta then {
           ext = 1;
         } else if singular_beta >= beta then {
           return singular_beta;
         } else if ttentry.score >= beta then {
           ext = -2;
         }
      }
    }
     
    moves_searched += 1;
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
      eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -beta, -alpha, next_fifty);
    } else {
      // captures. promotions. checks.
      if in_check(chess) {
        // do not reduce depth on check.
        eval = -negamax(chess, depth, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      }

      else if cap != Piece.NONE || flags > Move16.Double_Pawn_Push {
        eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      }

      // Late Move Reduction when not in check and not giving check.
      else if depth > 2 && status == ChessFlags.Normal && flags <= Move16.Double_Pawn_Push {

        R := LateMoveReduction[min(depth,63)][min(move_count,63)];
        if !pv_node then
          R += 1;
        if improving == 0 then
          R += 1;
        if move_score < 0 then {
          R += -move_score / 4096;
        }
        #if null_flag == false || single_ext == false {
          R += 2; 
        }
        eval = -negamax(chess, depth+ext-R-1, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      } 

      else {
        // do normal search.
        eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      }

      // search the move again that has failed to be proved to be bad with normal alpha beta score bounds
      if pv_node && eval > alpha then {
        eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -beta, -alpha, next_fifty);
      } 
    }

    unmake_move(chess, move, cap, castling, hash);
    chess.en_passant = ep;

    if eval > alpha {
      hash_flag = TFLAGS.EXACT;
      ttmove = move;
      pv_table[ply].argmove[0] = move;
      memcpy(*pv_table[ply].argmove[1], *pv_table[ply+1].argmove[0], pv_table[ply+1].move_count * size_of(Move16));
      pv_table[ply].move_count = pv_table[ply+1].move_count + 1;
      alpha = eval;
      alpha_increase += 1;
      if alpha_increase > 2 then {
        depth -= 1;
      }
    } 

    if eval >= beta then {
      hash_flag = TFLAGS.BETA;
      alpha = beta;
      piece_type := piece_at(chess, from);
      // non-captures == Quiet|Pawn Push Moves
      if flags <= Move16.Double_Pawn_Push {
        
        inc : s16 = min(cast(s16) (depth*depth), 576);
        // decrement all quiet moves which < alpha.
        for i: 0..num_quiets-1 {
          prev_move := quiet_moves[i];
          if prev_move != move {
            _, from_move, to_move := decode_move16(prev_move);
            piece_type := piece_at(chess, from_move);
            value : int = xx __history_moves[piece_type][to_move];
            value -= ((64*inc) - (value*inc / 1024));
            value = max(value, -25_000);
            __history_moves[piece_type][to_move] = xx value;
          }
        }

        // update history heuristic
        value : int = xx __history_moves[piece_type][to];
        value += ((64*inc)-(value*inc/1024));
        value %= 19225;
        __history_moves[piece_type][to] = xx value;

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

  print_curr_move :: () #expand {
    time := get_time();
    if ply==0 && (time-time_begin)>3 then {
      print("info depth %1 currmove %2%3 currmovenumber %4\n", chess.depth, cast(serialized_bb)`from, cast(serialized_bb)`to, `move_count+1);
    }
  }

  transposition_table_lookup :: (hash: u64) -> *ttable.TTEntry #expand {
    #if single_ext == false {
      if ply == chess.exply then
        return null;
    }
    key  := hash % TSIZE;
    prefetch(*ttable.entries[key], Prefetch_Hint.T0);
    entry := *ttable.entries[key];
    if entry.hash == hash then {
      entry.age = search_age;
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

      return entry;
    }

    return null;
  }

  transposition_table_store :: (hash: u64) #expand {
    #if single_ext == false {
      if ply == chess.exply then
        return;
    }
    key  := hash % TSIZE;
    prefetch(*ttable.entries[key], Prefetch_Hint.T0);
    entry := *ttable.entries[key];
    if depth >= entry.depth || entry.age != search_age then {
      entry.hash   = hash;
      entry.score  = xx alpha;
      entry.flag   = hash_flag;
      entry.depth  = xx depth;
      entry.ttmove = ttmove;
      entry.age    = search_age;
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

INF :: 0x7FFF; // Alias
      
#scope_file

#import "Machine_X64";
// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (chess: *ChessGame, alpha: int, beta: int, fifty: int = 0) -> int {
  if (__nodes_searched & 1024) && stdin_stop_signal()
    return 0;
  //__nodes_searched += 1;
  ply := chess.ply;
  pv_node := alpha != beta-1;
  entry := transposition_table_lookup(chess.hash);
  best_move := ifx entry != null then entry.ttmove else Move16.Quiet;

  auto_release_temp();
  moves := init_quiescene(pv_table[ply][0], best_move);
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
    if score > alpha then {
      hash_flag = TFLAGS.EXACT;
      best_move = move;
      alpha = score;
      pv_table[ply].argmove[0] = move;
      memcpy(*pv_table[ply].argmove[1], *pv_table[ply+1].argmove[0], pv_table[ply+1].move_count * size_of(Move16));
      pv_table[ply].move_count = pv_table[ply+1].move_count + 1;
    }

    if score >= beta then {
      hash_flag = TFLAGS.BETA;
      alpha = beta;
      break;
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

  transposition_table_lookup :: (hash: u64) -> *ttable.TTEntry #expand {
    key  := hash % TSIZE;
    prefetch(*ttable.entries[key], Prefetch_Hint.T0);
    entry := *ttable.entries[key];
    entry.age = search_age;
    if !pv_node && entry.hash == hash then {
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
      return entry;
    }

    return null;
  }

  // quiescene TT
  transposition_table_store :: (hash: u64) #expand {
    key  := hash % TSIZE;
    prefetch(*ttable.entries[key], Prefetch_Hint.T0);
    entry := *ttable.entries[key];
    if entry.depth <= 0 then {
      entry.hash   = hash;
      entry.score  = xx alpha;
      entry.flag   = hash_flag;
      entry.depth  = 0;
      entry.ttmove = best_move;
    }
  }
}

PV_Line :: struct {
  argmove: [100] Move16;
  move_count: u16;
}

operator [] :: (using p: PV_Line, index: int) -> Move16 {
  return argmove[index];
}

time_begin: float64;

pv_table: [64] PV_Line;

// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (chess: *Chess, depth: int) -> int {
  if depth == 0 then return 1;
  num_nodes := 0;
  movegen: Perft(80);
  generate_moves(chess, *movegen);

  if depth == 1 then return movegen.count;
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
  v := cast(int) victim;
  a := cast(int) attacker;
  vs := piece_score[v] - (piece_score[a]/100) + 20_000;
  return vs;

  piece_score :: #run -> [13] int {
    using Piece;
    array: [13] int;
    array[cast(int)NONE     ] = 0;
    array[cast(int)W_KING   ] = 9000;
    array[cast(int)W_QUEEN  ] = 9000;
    array[cast(int)W_ROOK   ] = 5000;
    array[cast(int)W_BISHOP ] = 3500;
    array[cast(int)W_KNIGHT ] = 3250;
    array[cast(int)W_PAWN   ] = 1000;

    array[cast(int)B_KING   ] = 9000;
    array[cast(int)B_QUEEN  ] = 9000;
    array[cast(int)B_ROOK   ] = 5000;
    array[cast(int)B_BISHOP ] = 3500;
    array[cast(int)B_KNIGHT ] = 1000;
    array[cast(int)B_PAWN   ] = 1000;
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

ttable: struct {
  entries:  [TSIZE] TTEntry;

  TTEntry :: struct {
    hash  :  u64;
    flag  : TFLAGS;
    depth : u8;
    ttmove: Move16;
    score : s16;
    age   : u8;
  }
}
search_age : u8 = 0;

TFLAGS :: enum u8 { EXACT; ALPHA; BETA; }

#scope_export
clear_hash_table :: () #expand {
  memset(*ttable, 0, size_of(type_of(ttable)));
}

Negamax :: struct {
  items: [80] Move16;
  score: [80] s16;
  count: int;

  pv        : Move16;
  //ttmove    : Move16;
  killer1   : Move16;
  killer2   : Move16;
  counter   : Move16;
  follow_up1: Move16;
  follow_up2: Move16;
}

init_negamax :: (pv: Move16, killer1: Move16, killer2: Move16, counter: Move16, follow_up1: Move16, follow_up2: Move16) -> Negamax {
  n: Negamax;
  //n.items = NewArray(80, Move16);
  //n.score = NewArray(80, s16);
  n.count = 0;
  n.pv      = pv;
  n.killer1 = killer1;
  n.killer2 = killer2;
  n.counter = counter;
  n.follow_up1 = follow_up1;
  n.follow_up2 = follow_up2;
  return n;
}

init_quiescene :: (pv: Move16, ttmove: Move16) -> Quiescene {
  q: Quiescene;
  q.pv = pv;
  q.ttmove = ttmove;
  q.count = 0;
  return q;
}

Quiescene :: struct {
  items: [30] Move16;
  score: [30] s16;
  count: int;
  pv: Move16;
  ttmove: Move16;
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
  score[count] = xx num;
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
  score[count] = xx num;
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
  } else if move == heap.ttmove {
    score = INF - 1;
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
    score = 20000;
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
  /*if move == heap.ttmove then {
    score = INF-1;
    heap_add(heap, move, score);
    return;
  }*/

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
    score = 20000;
  }

  #if flags == Queen_Promotion_Capture || flags == Bishop_Promotion_Capture 
    || flags == Knight_Promotion_Capture || flags == Rook_Promotion_Capture {
    score = 20000;
  } 
  #if flags == King_Castle || flags == Queen_Castle {
    score = 19500;
  }

  #if flags == Quiet || flags == Double_Pawn_Push {
    if move == heap.killer1 {
      score = 19250;
    } else if move == heap.killer2 {
      score = 19225;
    } else {
      piece := cast(int) piece_at(chess, from);
      score = __history_moves[piece][to];

      if move == heap.counter then {
        COUNTER_BONUS :: 576;
        score += COUNTER_BONUS;
      }

      if move == heap.follow_up1 then {
        CONTINUE_BONUS :: 200;
        score += CONTINUE_BONUS;
      }

      if move == heap.follow_up2 then {
        CONTINUE_BONUS :: 200;
        score += CONTINUE_BONUS;
      }
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
    `move_score := score;
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

see :: (chess: *Chess, move: Move16) -> eval: int {
  _, from, to := decode_move16(move);
  target := cast(int) piece_at(chess, to);
  apiece := cast(int) piece_at(chess, from);

  gain: [16] int;
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
  nnue: [] NNUEdata;
  ply: int;
  maxply: int;
  depth: int;
  excluded_move: Move16;
  exply: int;
  moves: [..] Move32;
  rtable: [..] u64;
  eval: [..] s16;
} 

Move32 :: struct {
  mov16: Move16;
  piece: Piece;
}

clear :: (using c: *ChessGame) {
  array_reset(*moves);
  array_reset(*rtable);
  array_reset(*eval);
}

// init chess game
initialize_chess_game_memory :: (using c: *ChessGame) {
  array_reserve(*moves, MAX);
  array_reserve(*rtable, MAX);
  array_reserve(*eval, MAX);

  // NOTE: We need to alignment=64 so that
  // NNUE-probe library does not crash.
  nnue = NewArray(MAX, NNUEdata, alignment=64);
  assert((cast(s64)nnue.data % 64) == 0);

  MAX :: 500;
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
  count := 0;
  repeating := 0;
  for < repeat : c.rtable {
    if hash_val == repeat then {
      repeating += 1;
      if repeating > 1 then {
        return ChessFlags.Threefold_Repetition;
      }
    }

    count += 1;
    if count > fifty
      break;
  }

  return status;
}

check_for_repetition :: (using c: *ChessGame, fifty: int) -> ChessFlags {
  if fifty >= 100 {
    return ChessFlags.Fifty;
  }

  hash_val := c.hash;
  count := 0;
  for < repeat : c.rtable {
    if hash_val == repeat then {
      return ChessFlags.Threefold_Repetition;
    }

    count += 1;
    if count > fifty
      break;
  }

  return ChessFlags.Normal;
}

make_move :: (c: *ChessGame, move: Move16) -> Piece, Castling, u64 {
  __nodes_searched += 1;
  from := get_move16_from(move);
  piece := c.pieces[from];
  move32: Move32;
  move32.mov16 = move;
  move32.piece = piece;
  make_move_nnue(c, move);

  cap, castling, hash := make_move(*c.chess, move);
  array_add(*c.moves, move32);
  array_add(*c.rtable, hash);

  c.ply += 1;
  c.maxply = max(c.maxply, c.ply);
  return cap, castling, hash;

  make_move_nnue :: (using c: *ChessGame, move: Move16) #expand {
    flags, from, to := decode_move16(move);
    dp := *nnue[ply+1].dirtyPiece;
    nnue[ply+1].accumulator.computedAccumulation = 0;
    dp.dirtyNum = 1;
    // remove captured piece.
    if flags == Move16.Capture || flags >= Move16.Knight_Promotion_Capture {
      dp.dirtyNum = 2;
      dp.pc[1] = xx piece_at(c, to);
      dp.from[1] = xx to;
      dp.to[1] = 64;
    } else if flags == Move16.Ep_Capture {
      epto := bit_scan_forward(ifx c.turn==Turn.WHITE chess.en_passant>>8 else chess.en_passant<<8);
      dp.dirtyNum = 2;
      dp.pc[1] = xx piece_at(c, epto);
      dp.from[1] = xx epto;
      dp.to[1] = 64;
    }

    dp.pc[0] = xx piece_at(c, from);
    dp.from[0] = xx from;
    dp.to[0] = xx to;

    if flags >= Move16.Knight_Promotion then {
      pic : s32 = xx Piece.NONE;
      if flags == Move16.Knight_Promotion || flags == Move16.Knight_Promotion_Capture {
        pic = xx (ifx turn == Turn.WHITE Piece.W_KNIGHT else Piece.B_KNIGHT);
      } else if flags == Move16.Bishop_Promotion || flags == Move16.Bishop_Promotion_Capture {
        pic = xx (ifx turn == Turn.WHITE Piece.W_BISHOP else Piece.B_BISHOP);
      } else if flags == Move16.Rook_Promotion || flags == Move16.Rook_Promotion_Capture {
        pic = xx (ifx turn == Turn.WHITE Piece.W_ROOK else Piece.B_ROOK);
      } else if flags == Move16.Queen_Promotion || flags == Move16.Queen_Promotion_Capture {
        pic = xx (ifx turn == Turn.WHITE Piece.W_QUEEN else Piece.B_QUEEN);
      }

      dp.to[0] = 64;
      dp.pc[dp.dirtyNum] = pic;
      dp.from[dp.dirtyNum] = 64;
      dp.to[dp.dirtyNum] = xx to;
      dp.dirtyNum += 1;
    }

    if flags == Move16.King_Castle {
      pic: s32 = xx (ifx turn == Turn.WHITE Piece.W_ROOK else Piece.B_ROOK);
      from_castle: s32 = xx (ifx turn == Turn.WHITE serialized_bb.h1 else serialized_bb.h8);
      to_castle: s32 = xx (ifx turn == Turn.WHITE serialized_bb.f1 else serialized_bb.f8);
      dp.dirtyNum = 2;
      dp.pc[1] = pic;
      dp.from[1] = from_castle;
      dp.to[1] = to_castle;
    }

    if flags == Move16.Queen_Castle {
      pic : s32 = xx (ifx turn == Turn.WHITE Piece.W_ROOK else Piece.B_ROOK);
      from_castle: s32 = xx (ifx turn == Turn.WHITE serialized_bb.a1 else serialized_bb.a8);
      to_castle: s32 = xx (ifx turn == Turn.WHITE serialized_bb.d1 else serialized_bb.d8);
      dp.dirtyNum = 2;
      dp.pc[1] = pic;
      dp.from[1] = from_castle;
      dp.to[1] = to_castle;
    }
  }
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

  if c.ply >= 4 {
    prev2 := c.moves.count-4;
    piece1, to1 := piece_to(c.moves[prev2]);

    // previous 1 move.
    prev1 := c.moves.count-2;
    piece2, to2 := piece_to(c.moves[prev1]);
    __follow_up[piece1][to1][piece2][to2] = move;
  }

}

get_follow_up_move :: (c: *ChessGame) -> Move16, Move16 {
  follow1 := Move16.Quiet;
  follow2 := Move16.Quiet;
  if c.ply >= 2 {
    // previous 2 move.
    prev2 := c.moves.count-2;
    piece1, to1 := piece_to(c.moves[prev2]);

    // previous 1 move.
    prev1 := c.moves.count-1;
    piece2, to2 := piece_to(c.moves[prev1]);

    follow1 = __follow_up[piece1][to1][piece2][to2];
  }

  if c.ply >= 4 {
    prev2 := c.moves.count-4;
    piece1, to1 := piece_to(c.moves[prev2]);

    // previous 1 move.
    prev1 := c.moves.count-2;
    piece2, to2 := piece_to(c.moves[prev1]);
    follow2 = __follow_up[piece1][to1][piece2][to2];
  }

  return follow1, follow2;
}

get_improving :: (using c: *ChessGame) -> int {
  if ply>1 && eval[eval.count-1] > eval[eval.count-3] then 
    return 1;
  else
    return 0;
}

piece_to :: (mov: Move32) -> int, int #expand {
  to := get_move16_to(mov.mov16);
  return cast(int)mov.piece, to;
}

make_null_move :: (c: *ChessGame) -> ep: u64, hash: u64 {
  memcpy(*c.nnue[c.ply+1].accumulator, *c.nnue[c.ply].accumulator, size_of(Accumulator));

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


