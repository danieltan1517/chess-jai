#import "Math";
#import "Basic";
#import "Thread";

lazy_smp_threads: Thread_Group;
num_threads: int = 0;
chess_work: [] ChessGame;

free_threads :: () {
  if num_threads > 0
    shutdown(*lazy_smp_threads);
}

uci_search :: (chess: *ChessGame) -> bestmove: Move16 {
  time_begin = get_time();
  nodes_searched = 0;
  // copy the work. add to queue.
  // make sure we are on max difficulty before starting threads.
  if difficulty == 8 {
    for *chess_work {
      copy_chessgame(it, chess);
      add_work(*lazy_smp_threads, it);
    }
    start(*lazy_smp_threads);
  }

  // start the lazy SMP threads!
  bestmove := search(chess);

  // make sure work is finished before we report bestmove.
  work_remaining := num_threads;
  while work_remaining > 0 {
    results := get_completed_work(*lazy_smp_threads);
    work_remaining -= results.count;
    reset_temporary_storage();
  }

  return bestmove;
}

set_threads :: (num_wanted: int) {
  num_wanted -= 1;
  if num_threads == num_wanted then
    return;
  if num_threads > 0 {
    shutdown(*lazy_smp_threads);
  }

  // initialize the threads
  num_threads = num_wanted;
  init(*lazy_smp_threads, cast(s32)num_threads, search_thread, false);
  lazy_smp_threads.logging = false;

  // initialize the workers
  for *chess_work {
    free_chess_game(it);
  }
  if chess_work.count
    array_free(chess_work);

  chess_work = NewArray(num_threads, ChessGame);
  for *chess_work {
    it.main_thread = false;
    initialize_chess_game_memory(it);
  }
}

set_multi_pv :: (number: int) {
  multi_pv = number;
}

set_difficulty :: (number: int) {
  difficulty = number;
}

difficulty: int = 8;

search_thread :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
  chess := cast(*ChessGame) work;
  search(chess);
  return .CONTINUE;
}

// main search function. iterative deepening.
search :: (chess: *ChessGame) -> bestmove: Move16 {
  clear_history(chess);
  if chess.maxdepth == -1 then
    chess.maxdepth = S64_MAX; // set maxdepth arbitarily high to make it loop infinitely.
  if chess.maxnodes == -1 then
    chess.maxnodes = S64_MAX; // set maxnodes arbitarily high to make it loop infinitely.
  if chess.movetime == -1 then
    chess.movetime = S64_MAX; // set movetime arbitarily high to make it loop infinitely.
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  score : int; 
  alpha: int = -INF+1;
  beta:  int =  INF-1;
  delta := 50;
  cur_depth := 1;

  maxdepth := set_maxdepth(chess.maxdepth);
  maxnodes := chess.maxnodes;

  root_moves: MoveQueue;
  best_score := -INF;
  best_move  := Move16.Quiet;

  num_multi_pv := get_num_multipv(chess);

  while outer_loop := cur_depth <= maxdepth { 
    line := 1;
    root_moves.count = 0;
    while line <= num_multi_pv {
      if cur_depth <= 3 then {
        alpha = -INF;
        beta = INF;
      }
      reset_temporary_storage();
      chess.ply = 0;
      chess.node_state = NodeState.NULL | NodeState.SSE;
      chess.maxply = 0; 
      chess.depth = cur_depth;
      score = negamax_root(chess, *root_moves, line, cur_depth, alpha, beta, chess.fifty);
      time_taken := get_time() - time_begin;
      if stop() || nodes_searched >= maxnodes then 
        break outer_loop;
 
      if score <= alpha then {
        if chess.main_thread == true
          print("info depth %1 lowerbound %2%3", cur_depth, score, NEWLINE);
        alpha = max(score-delta, -INF);
        delta += delta + delta / 5;
        continue;
      }
 
      if score >= beta then {
        if chess.main_thread == true
          print("info depth %1 upperbound %2%3", cur_depth, score, NEWLINE);
        beta = min(score+delta, INF);
        delta += delta + delta / 5;
        continue;
      }
 
      alpha = max(score - delta, -INF);
      beta  = min(score + delta, INF);
 
      chess.score = cast, no_check(s16)score;

      if line == 1 {
        best_score = cast(s16) score;
        best_move  = get_bestmove(chess);
      } else {
        if score > best_score then {
          best_score = cast(s16) score;
          best_move  = get_bestmove(chess);
        }
      }

      print_stats(cur_depth, line);
      line += 1;
    }

    cur_depth += 1;
  }

  search_age += 1;
  return pick_move(best_move, best_score, num_multi_pv, *root_moves);

  print_stats :: (depth: int, line: int) #expand {
    if chess.main_thread == false return;

    builder: String_Builder;
    builder.allocator = temp;
    t_ms := cast(int)(`time_taken*1000.0); // convert secs to ms
    nps  := cast(int)(nodes_searched/(`time_taken+0.0001));
    print_to_builder(*builder, "info depth % seldepth % ", depth, chess.maxply);
    if score >= -INF+20 && score <= INF-20 then {
      print_to_builder(*builder, "nodes % time % score cp % nps % multipv % pv", nodes_searched, t_ms, score, nps, line);
    } else {
      mate := INF - abs(score);
      mate = (mate/2) + (mate & 1);
      print_to_builder(*builder, "nodes % time % score mate % nps % multipv % pv", nodes_searched, t_ms, mate, nps, line);
    }
    count := chess.history.pv_table[0].move_count - 1;
    for i: 0..count {
      move := chess.history.pv_table[0][i];
      if move == Move16.Quiet break;  // do not print out NULL moves.
      append(*builder, #char " ");
      append(*builder, move);
    }
    str := builder_to_string(*builder, allocator=__temporary_allocator);
    print("%1%2", str, NEWLINE);
  }
}

count_moves :: (chess: *Chess) -> int {
  moves: Moves(true);
  generate_moves(chess, *moves);
  return moves.count;
}

set_maxdepth :: (maxdepth: int) -> int {
  if difficulty == 8 then {
    return maxdepth;
  } else {
    return DEPTH_DIFFICULTY[difficulty-1];
  }
  DEPTH_DIFFICULTY :: int.[1, 2, 3, 4, 5, 6, 9];
}

pick_move :: (bestmove: Move16, topscore: s32, nummultipv: int, moves: *MoveQueue) -> Move16 {
  if difficulty == 8 then {
    // only looking for best move.
    return bestmove;
  } else {

    // pick randomly between the different suboptimal moves.
    // used to vary the computer difficulty and create
    // "different difficulty levels" for the
    // chess engine.
    // the greater the margin_error, the greater the chance of the computer making a 
    // mistake.

    margin_error := ERROR[difficulty-1];
    print("info string difficulty %1%2", difficulty, NEWLINE);

    if (random_u64(*move_rng) % 100) < BLUNDERING[difficulty-1] {
      // give the computer a random chance to blunder, increase error margin.
      margin_error += 256;
      print("info string blunder move%1", NEWLINE);
    }

    move := bestmove;
    i := 0;
    while i < moves.count {
      score: int = moves.array[i].priority;
      margin: int = cast(int)random_u64(*move_rng) % margin_error;
      score += margin;
      if score > topscore {
        move = moves.array[i].move;
      }
      i += 1;
    }

    return move;
  }

  ERROR :: int.[512, 256, 175, 128, 75, 50, 20];
  BLUNDERING :: u64.[50, 25, 25, 10, 10, 5, 2];
}

move_rng: PRNG = ---;

get_num_multipv :: (chess: *Chess) -> int {
  num_moves := count_moves(chess);
  num_multi_pv := multi_pv;
  if difficulty != 8 {
    num_multi_pv = max(LINES[difficulty-1], num_multi_pv);
  }

  num_multi_pv = min(num_moves, num_multi_pv);
  return num_multi_pv;

  LINES :: int.[8, 5, 4, 3, 3, 3, 2, 1];
}

initialize_move_randomness :: () {
  now := current_time_consensus();
  move_rng.seed = cast, no_check(u64)now.low ^ cast, no_check(u64)now.high;
}

negamax_root :: (chess: *ChessGame, root_moves: *MoveQueue, multipv: int, depth: int, alpha: int, beta: int, fifty: int) -> int {
  ply := chess.ply;

  // tt probe.
  tthit, ttentry := tt_probe_negamax(chess, ply, chess.hash, alpha, beta, depth);
  ttmove := chess.history.pv_table[ply][0];
  hash_move := ifx tthit then ttentry.ttmove else Move16.Quiet;

  defer {
    using chess.history;
    memset(*pv_table[ply+1], 0, size_of(PV_Line));
    killer_moves[ply+1][1] = 0;
    killer_moves[ply+1][0] = 0;
  }

  array_add(*chess.eval, INF);
  defer pop(*chess.eval);

  ep := chess.en_passant;
  hash_flag := TFLAGS.ALPHA;
  cap_moves: [32] Move16;
  quiet_moves: [64] Move16;
  num_captures := 0;
  num_quiets := 0;
  moves_searched := 0;

  tt_capture: bool = false;
  tt_quiet: bool   = false;

  move_count := 0;
  bmove := Move16.Quiet;
  pto := -1;
  best_score: int = -INF;
  for :pv move, move_score : chess {
    move_count += 1;
    if root_multipv(move, root_moves) {
      continue;
    }

    flags, from, to := decode_move16(move);
    ext := 0;
    if flags <= Move16.Double_Pawn_Push {
      // add quiet move.
      quiet_moves[num_quiets] = move;
      num_quiets += 1;
    } else {
      // add capture move.
      cap_moves[num_captures] = move;
      num_captures += 1;
    }
     
    // make move.
    next_fifty := fifty_move(chess, move, fifty);
    cap, castling := make_move(chess, move);
    eval := 0;
    if moves_searched == 0 {
      eval = -negamax_pv(chess, depth+ext-1, -beta, -alpha, next_fifty);
    } else {
      if in_check(chess) {
        // do not reduce depth on check.
        eval = -negamax_zw(chess, depth, -alpha-1, -alpha, next_fifty);
      } else {
        eval = -negamax_zw(chess, depth-1, -alpha-1, -alpha, next_fifty);
      }

      // search the move again that has failed to be proved to be bad with normal alpha beta score bounds
      if eval > alpha then {
        eval = -negamax_pv(chess, depth-1, -beta, -alpha, next_fifty);
      }
    }

    unmake_move(chess, move, cap, castling);
    chess.en_passant = ep;
    if eval > best_score then {
      best_score = eval;
      if best_score > alpha {
        using chess.history;
        hash_flag = TFLAGS.EXACT;
        bmove = move;
        pv_table[ply][0] = move;
        move_count := pv_table[ply+1].move_count;
        memcpy(*pv_table[ply][1], *pv_table[ply+1][0], move_count * size_of(Move16));
        pv_table[ply].move_count = move_count + 1;
        alpha = best_score;
     
        if best_score >= beta then {
          // non-captures == Quiet|Pawn Push Moves
          if flags <= Move16.Double_Pawn_Push 
            update_quiet(chess, move, depth, quiet_moves, num_quiets, cap_moves, num_captures);
          tt_store(chess.hash, best_score, TFLAGS.BETA, depth, move);
          return best_score;
        } 
      } 
    }
    moves_searched += 1;
  }

  if move_count == 0 then
    return ifx in_check(chess) then -INF+ply else 0+ply;

  if hash_flag == TFLAGS.EXACT && get_move16_flag(bmove) > Move16.Double_Pawn_Push then 
    update_tactics(chess, bmove, depth, cap_moves, num_captures, quiet_moves, num_quiets);

  tt_store(chess.hash, best_score, hash_flag, depth, bmove);
  append(root_moves, cast(s16)best_score, bmove);
  return best_score;

  root_multipv :: (move: Move16, moves: *MoveQueue) -> bool {
    i := 0;
    while i<moves.count {
      if move == moves.array[i].move then
        return true;
      i += 1;
    }
    return false;
  }
}

negamax_pv :: (chess: *ChessGame, depth: int, alpha: int, beta: int, fifty: int) -> int {
  ply := chess.ply;
  if fifty >= 100 then
    return 0+ply;

  // mate distance pruning
  alpha = max(alpha,-INF+ply);
  beta  = min(beta,  INF-ply);
  if alpha >= beta then {
    return alpha;
  }

  if is_draw(chess, fifty) then
    return 0+ply;

  if depth <= 0 then
    return quiescene(chess, alpha, beta, fifty);

  // cannot trust that tt_entry will remain the same.
  // it can be overwritten by accident due to hash collisions
  // esp. during multi-threading. need to copy out the ttentry.

  // tt probe.
  tthit, ttentry := tt_probe_negamax(chess, ply, chess.hash, alpha, beta, depth);
  ttmove := chess.history.pv_table[ply][0];
  hash_move := ifx tthit then ttentry.ttmove else Move16.Quiet;

  defer {
    using chess.history;
    memset(*pv_table[ply+1], 0, size_of(PV_Line));
    killer_moves[ply+1][1] = 0;
    killer_moves[ply+1][0] = 0;
  }

  // internal iterative deepening.
  if depth > 8 && ttmove == 0 && hash_move == 0 then 
    depth -= 1;

  // NOTE: we make eval really high,
  // so we will look at checks much more
  // carefully, when improving=1, more branches to look at.
  eval := INF;
  if tthit == true then
    eval = ttentry.score;
  else if !in_check(chess) then
    eval = cast(s16) evaluate(chess, fifty);

  array_add(*chess.eval, eval);
  defer pop(*chess.eval);

  ep := chess.en_passant;
  hash_flag := TFLAGS.ALPHA;
  cap_moves: [32] Move16;
  quiet_moves: [64] Move16;
  num_captures := 0;
  num_quiets := 0;
  moves_searched := 0;

  improving := get_improving(chess);
  late_move_prune := (3 + (depth*depth)) / (2-improving);

  tt_capture: bool = false;
  tt_quiet: bool   = false;

  move_count := 0;
  bmove := Move16.Quiet;
  pto := prev_to(chess);
  prev_to :: (chess: ChessGame) -> int {
    if chess.ply >= 1 {
      count := chess.moves.count;
      prev_move1 := chess.moves[count-1].mov16;
      to := get_move16_to(prev_move1);
      return to;
    }
    return -1;
  }

  best_score: int = -INF;
  score_margin := -80_000 * depth;
  for :pv move, move_score : chess {
    move_count += 1;
    if (chess.node_state & NodeState.SSE) == 0 && ply == chess.exply && move == chess.excluded_move then {
      continue;
    }

    flags, from, to := decode_move16(move);
    pfrom := piece_at(chess, from);
    att := piece_at(chess, from);
    vic := piece_at(chess, to);

    // piece
    if chess.depth>6 && moves_searched>0 {
      // Late Move Pruning. Search the Root Plies Exhuastively
      if flags <= Move16.Double_Pawn_Push && (moves_searched > late_move_prune) then
        break;
      if flags <= Move16.Double_Pawn_Push && move_score < score_margin then
        break;
      if depth < 6 && flags == Move16.Capture && PVALUE[att] > PVALUE[vic] && see(chess,move) < -250*depth  then
        continue;
      else if depth < 6 && flags <= Move16.Double_Pawn_Push && see(chess,move) < -90*depth*depth then
        continue;
    }

    ext := 0;
    if chess.node_state & NodeState.SSE && depth>=4 && move == hash_move && tthit && cast(int)ttentry.depth >= depth-5 
       && ttentry.flag == TFLAGS.ALPHA && abs(alpha) < (INF-50) {
      if to == pto && flags >= Move16.Capture {
        // recapture extension.
        ext = 1;
        tt_capture = true;
        tt_quiet   = false;
      } else {
        // singular extension:
        // if one move is better than all the rest, then we consider this singular
        // "singular" is determined by checking all other moves at a shallow depth on a nullwindow
        singular_beta := ttentry.score - depth;
        chess.excluded_move = move;
        chess.exply = ply;
        chess.node_state ^= NodeState.SSE;
        score := negamax_zw(chess, depth/2-1, singular_beta-1, singular_beta, fifty);
        chess.node_state ^= NodeState.SSE;
        chess.excluded_move = Move16.Quiet;
        chess.exply = INF;
        if score < singular_beta then {
          ext = 1;
          tt_capture = flags > Move16.Double_Pawn_Push;
          tt_quiet   = flags <= Move16.Double_Pawn_Push;
        } else if singular_beta >= beta then {
          return singular_beta;
        } else if ttentry.score >= beta then {
          ext = -2;
        } else if ttentry.score <= alpha && ttentry.score <= score {
          ext = -1;
        }
      }
    }

    if flags <= Move16.Double_Pawn_Push {
      // add quiet move.
      quiet_moves[num_quiets] = move;
      num_quiets += 1;
    } else {
      // add capture move.
      cap_moves[num_captures] = move;
      num_captures += 1;
    }
     
    // make move.
    next_fifty := fifty_move(chess, move, fifty);
    cap, castling := make_move(chess, move);
    eval := 0;
    if ext==1 || moves_searched == 0 {
      eval = -negamax_pv(chess, depth+ext-1, -beta, -alpha, next_fifty);
    } else {
      if in_check(chess) {
        // do not reduce depth on check.
        eval = -negamax_zw(chess, depth, -alpha-1, -alpha, next_fifty);
      } else if flags > Move16.Double_Pawn_Push {
        // captures. promotions.
        R := 1 - 4 * move_score / (abs(move_score) + 24576);
        R = max(0, R);
        eval = -negamax_zw(chess, depth+ext-R-1, -alpha-1, -alpha, next_fifty);
      } else if num_quiets > 3 && flags <= Move16.Double_Pawn_Push {
        // Late Move Reduction when not in check and not giving check.
        R := LateMoveReduction[min(depth,63)][min(moves_searched,63)];
        R -= improving;
        if chess.probcut then {
          R += 2;
        }

        R -= 1 + 15 / (3 + depth);

        // increase reduction if capture.
        if tt_capture then {
          R += 1;
        }

        // decrease reduction if quiet.
        if tt_quiet then {
          R -= 2;
        }

        R -= move_score / 10_000;
        R = max(0, R);
        eval = -negamax_zw(chess, depth+ext-R-1, -alpha-1, -alpha, next_fifty);
      } else {
        // do normal search.
        eval = -negamax_zw(chess, depth+ext-1, -alpha-1, -alpha, next_fifty);
      }

      // search the move again that has failed to be proved to be bad with normal alpha beta score bounds
      if eval > alpha then 
        eval = -negamax_pv(chess, depth+ext-1, -beta, -alpha, next_fifty);
    }

    unmake_move(chess, move, cap, castling);
    chess.en_passant = ep;
    if eval > best_score then {
      best_score = eval;
      if best_score > alpha {
        using chess.history;
        hash_flag = TFLAGS.EXACT;
        bmove = move;
        pv_table[ply][0] = move;
        move_count := pv_table[ply+1].move_count;
        memcpy(*pv_table[ply][1], *pv_table[ply+1][0], move_count * size_of(Move16));
        pv_table[ply].move_count = move_count + 1;
        alpha = eval;
     
        if best_score >= beta then {
          // non-captures == Quiet|Pawn Push Moves
          if flags <= Move16.Double_Pawn_Push 
            update_quiet(chess, move, depth, quiet_moves, num_quiets, cap_moves, num_captures);
          tt_store(chess.hash, best_score, TFLAGS.BETA, depth, move);
          return best_score;
        } 
      } 
    }
    moves_searched += 1;
  }

  if move_count == 0 then
    return ifx in_check(chess) then -INF+ply else 0+ply;

  if hash_flag == TFLAGS.EXACT && get_move16_flag(bmove) > Move16.Double_Pawn_Push then 
    update_tactics(chess, bmove, depth, cap_moves, num_captures, quiet_moves, num_quiets);

  tt_store(chess.hash, best_score, hash_flag, depth, bmove);
  return best_score;

}

update_tactics :: (chess: *ChessGame, move: Move16, depth: int, cap_moves: []Move16, num_captures: int, quiet_moves: []Move16, num_quiets: int) {
  ply := chess.ply;
  incr : s32 = min(cast(s32)(depth*depth), 128);
  prev1, to1 := get_prev_move(chess, 1);
  prev2, to2 := get_prev_move(chess, 2);
  prev4, to4 := get_prev_move(chess, 4);

  using chess.history;
  for i: 0..num_captures-1 {
    prev_move := cap_moves[i];
    if prev_move != move {
      from := get_move16_from(prev_move);
      p := piece_at(chess, from);
      to := get_move16_to(prev_move);
      opp := norm(piece_at(chess, to));
      incr_history(*cap_history[p][to][opp], -incr);
    }
  }

  // decrement all quiet moves which < alpha.
  for i: 0..num_quiets-1 {
    quiet_move := quiet_moves[i];
    from := get_move16_from(quiet_move);
    p := piece_at(chess, from);
    to := get_move16_to(quiet_move);
    incr_history(*history_moves[p][to], -incr);
    incr_history(*counter_history[prev1][to1][p][to], -incr);
    incr_history(*counter_history[prev2][to2][p][to], -incr);
    incr_history(*counter_history[prev4][to4][p][to], -incr);
  }

  from := get_move16_from(move);
  p := piece_at(chess, from);
  to := get_move16_to(move);
  opp := norm(piece_at(chess, to));
  incr_history(*cap_history[p][to][opp], incr);
}

pv :: (chess: *ChessGame, body: Code, f: For_Flags) #expand {
  // main principle variation search move picker.
  stage: enum {PV; CAPTURES; KILLERS; QUIETS; END; } = .PV;
  move_queue: MoveQueue;
  unsafe: u64 = 0;
  check: u64 = 0;
  turn := chess.turn;
  while outer_loop := !stop() {
    while move_queue.count <= 0 {
      if stage == {
      case .PV;
        stage = .CAPTURES;
        if is_legal(chess, `hash_move) then {
          append(*move_queue, 0x7FFF, `hash_move);
        } else if is_legal(chess, `ttmove) {
          append(*move_queue, 0x7FFF, `ttmove);
        }
      case .CAPTURES;
        stage = .KILLERS;
        unsafe, check = generate_attacks(chess);
        generate_tactics(unsafe, check, chess, *move_queue);
        filter_capture_pv(*move_queue, `ttmove, `hash_move);
        sort_captures(*move_queue, chess);
      case .KILLERS;
        using chess.history;
        stage = .QUIETS;
        move := killer_moves[`ply][0];
        if is_legal(chess, move) {
          append(*move_queue, 0x7FFF, move);
        }

        move = killer_moves[`ply][1];
        if is_legal(chess, move) {
          append(*move_queue, 0x7FFF-1, move);
        } 
      case .QUIETS;
        using chess.history;
        stage = .END;
        generate_quiets(unsafe, check, chess, *move_queue);
        kill1 := killer_moves[`ply][0];
        kill2 := killer_moves[`ply][1];
        filter_quiet_pv(*move_queue, `ttmove, `hash_move, kill1, kill2);
        sort_quiets(*move_queue, chess);
      case .END;
        break outer_loop; // terminate loop
      }
    }
    `it, priority := pop(*move_queue);
    `it_index := cast(int)priority;
    #insert body;
  }
}

pvcut :: (chess: *ChessGame, body: Code, f: For_Flags) #expand {
  // main principle variation search move picker.
  stage: enum {PV; CAPTURES; KILLERS; QUIETS; END; } = .PV;
  move_queue: MoveQueue;
  unsafe: u64 = 0;
  check: u64 = 0;
  turn := chess.turn;
  while outer_loop := !stop() {
    while move_queue.count <= 0 {
      if stage == {
      case .PV;
        stage = .CAPTURES;
        if is_legal(chess, `hash_move) then {
          append(*move_queue, 0x7FFF, `hash_move);
        } else if is_legal(chess, `ttmove) {
          append(*move_queue, 0x7FFF, `ttmove);
        }
      case .CAPTURES;
        stage = .END;
        unsafe, check = generate_attacks(chess);
        generate_tactics(unsafe, check, chess, *move_queue);
        filter_capture_pv(*move_queue, `ttmove, `hash_move);
        sort_captures(*move_queue, chess);
      case .END;
        break outer_loop; // terminate loop
      }
    }
    `it, priority := pop(*move_queue);
    `it_index := cast(int)priority;
    #insert body;
  }
}

filter_capture_pv :: (move_queue: *MoveQueue, pv: Move16, hash: Move16) {
  i := 0;
  while i < move_queue.count {
    move := move_queue.array[i].move;
    if move == pv || move == hash then {
      last := move_queue.count - 1;
      move_queue.array[i] = move_queue.array[last];
      move_queue.count -= 1;
    } else {
      i += 1;
    }
  }
}

filter_quiet_pv :: (move_queue: *MoveQueue, pv: Move16, hash: Move16, kill1: Move16, kill2: Move16) {
  i := 0;
  while i < move_queue.count {
    move := move_queue.array[i].move;
    if move == pv || move == hash || move == kill1 || move == kill2 then {
      last := move_queue.count - 1;
      move_queue.array[i] = move_queue.array[last];
      move_queue.count -= 1;
    } else {
      i += 1;
    }
  }
}

sort_captures :: (move_queue: *MoveQueue, chess: *ChessGame) {
  for i: 0..move_queue.count-1 {
     move := move_queue.array[i].move;
     flags, from, to := decode_move16(move);
     priority := score_capture(flags, from, to, chess);
     move_queue.array[i].priority = priority;
  }
  construct_heap(move_queue);

  score_capture :: (flag: Move16, from: int, to: int, chess: *ChessGame) -> s32 {
    using chess.history;
    if flag == {
    case .Capture;
      vic := norm(piece_at(chess, to));
      att := piece_at(chess, from);
      return mvv_lva(vic, att) + cap_history[att][to][vic];
    case .Ep_Capture;
      att := piece_at(chess, from);
      return mvv_lva(.W_PAWN, .W_PAWN) + cap_history[att][to][0];
    case .Knight_Promotion;
      att := piece_at(chess, from);
      return cap_history[att][to][0];
    case .Bishop_Promotion;
      att := piece_at(chess, from);
      return cap_history[att][to][0];
    case .Rook_Promotion;
      att := piece_at(chess, from);
      return cap_history[att][to][0];
    case .Queen_Promotion;
      att := piece_at(chess, from);
      return 20000 + cap_history[att][to][0];
    case .Knight_Promotion_Capture;
      vic := norm(piece_at(chess, to));
      att := piece_at(chess, from);
      return cap_history[att][to][vic];
    case .Bishop_Promotion_Capture;
      vic := norm(piece_at(chess, to));
      att := piece_at(chess, from);
      return cap_history[att][to][vic];
    case .Rook_Promotion_Capture;
      vic := norm(piece_at(chess, to));
      att := piece_at(chess, from);
      return cap_history[att][to][vic];
    case .Queen_Promotion_Capture;
      vic := norm(piece_at(chess, to));
      att := piece_at(chess, from);
      return cap_history[att][to][vic];
    case .King_Castle;
      att := piece_at(chess, from);
      return cap_history[att][to][0];
    case .Queen_Castle;
      att := piece_at(chess, from);
      return cap_history[att][to][0];
    }

    assert(false);
    return 0;
  }
}

sort_quiets :: (move_queue: *MoveQueue, chess: *ChessGame) {
  counter := get_countermove_history(chess, 1);
  follow1 := get_countermove_history(chess, 2);
  follow2 := get_countermove_history(chess, 4);

  for i: 0..move_queue.count-1 {
     move := move_queue.array[i].move;
     flags, from, to := decode_move16(move);
     priority := score_quiets(flags, from, to, chess, counter, follow1, follow2);
     move_queue.array[i].priority = priority;
  }
  construct_heap(move_queue);

  score_quiets :: (flag: Move16, from: int, to: int, chess: *ChessGame, counter: *[13][64] s32, follow1: *[13][64] s32, follow2: *[13][64] s32) -> s32 {
    piece := piece_at(chess, from);
    return chess.history.history_moves[piece][to] + ((<<counter)[piece][to] * 2) + (<<follow1)[piece][to] + ((<<follow2)[piece][to] / 2);
  }

}

negamax_zw :: (chess: *ChessGame, depth: int, alpha: int, beta: int, fifty: int) -> int {
  read_input(chess.main_thread, nodes_searched, chess.maxnodes, time_begin, chess.movetime);
  ply := chess.ply;
  if ply && fifty >= 100 then
    return 0+ply;

  if is_draw(chess, fifty) then
    return 0+ply;

  // mate distance pruning
  alpha = max(alpha,-INF+ply);
  beta  = min(beta,  INF-ply);
  if alpha >= beta then {
    return alpha;
  }

  // cannot trust that tt_entry will remain the same.
  // it can be overwritten by accident due to hash collisions
  // esp. during multi-threading. need to copy out the ttentry.

  // tt probe.
  tthit, ttentry := tt_probe_negamax(chess, ply, chess.hash, alpha, beta, depth);
  tt_prune(tthit, ttentry, ply, false, alpha, beta, depth);

  if depth <= 0 then
    return quiescene(chess, alpha, beta, fifty);

  ttmove := chess.history.pv_table[ply][0];
  hash_move := ifx tthit then ttentry.ttmove else Move16.Quiet;

  defer {
    using chess.history;
    memset(*pv_table[ply+1], 0, size_of(PV_Line));
    killer_moves[ply+1][1] = 0;
    killer_moves[ply+1][0] = 0;
  }

  // NOTE: we make eval really high,
  // so we will look at checks much more
  // carefully, when improving=1, more branches to look at.
  array_add(*chess.eval, INF);
  defer pop(*chess.eval);
  if !in_check(chess) {
    eval := ifx tthit then ttentry.score else evaluate(chess, fifty);
    chess.eval[chess.eval.count-1] = cast(s16) eval;
    improving := get_improving(chess);

    // reverse futility pruning. stockfish has margin at 214*depth
    margin := 125 *(depth-improving);
    if depth < 11 && (eval-margin) >= beta then {
      return eval;
    }

    // razoring.
    if depth <= 5 && eval + (200*depth) <= alpha {
      score := quiescene(chess, alpha, beta, fifty);
      if score <= alpha then {
        return score;
      }
    }

    // null move pruning w/ verification at higher depths.
    if depth > 3 && eval >= beta then {
      R := 4 + depth/3 + min((eval-beta) / 256, 3);
      ep := make_null_move(chess);
      score := -negamax_zw(chess, depth-R-1, -beta, -beta + 1, 0);
      unmake_null_move(chess, ep);

      // verification at higher depths.
      if depth>12 || zugzwang(chess) then {
        score = negamax_zw(chess, depth-R-1, beta-1, beta, 0);
      }
    
      if score >= beta then {
        return score;
      }
    }

    // prob cut.
    prob_beta := beta + 125 - 46 * improving;
    if depth > 5 && abs(beta) < 20_000 && !(tthit && ttentry.depth >= depth-3 && ttentry.score != 0 && ttentry.score < prob_beta) then {
      chess.probcut += 1;
      defer chess.probcut -= 1;
      ep := chess.en_passant;
      for :pvcut move, move_score: chess {
        flags, from, to := decode_move16(move);
        pfrom := piece_at(chess, from);
       
        // make move.
        cap, castling := make_move(chess, move);
        score := -quiescene(chess, -prob_beta, -prob_beta + 1, 0);
        if score >= prob_beta then
          score = -negamax_zw(chess, depth-4, -prob_beta, -prob_beta + 1, 0);
    
        // unmake move.
        unmake_move(chess, move, cap, castling);
        chess.en_passant = ep;
    
        if score >= prob_beta then {
          tt_store(chess.hash, score, TFLAGS.BETA, depth-4, move);
          return score;
        }
      }
    }
  }

  ep := chess.en_passant;
  cap_moves: [32] Move16;
  quiet_moves: [64] Move16;
  num_captures := 0;
  num_quiets := 0;
  moves_searched := 0;

  improving := get_improving(chess);
  late_move_prune := (3 + (depth*depth)) / (2-improving);

  tt_capture: bool = false;
  tt_quiet: bool   = false;

  move_count := 0;
  bmove := Move16.Quiet;
  pto := prev_to(chess);
  prev_to :: (chess: ChessGame) -> int {
    if chess.ply >= 1 {
      count := chess.moves.count;
      prev_move1 := chess.moves[count-1].mov16;
      to := get_move16_to(prev_move1);
      return to;
    }
    return -1;
  }

  best_score: int = -INF;
  score_margin := -80_000 * depth;
  for :pv move, move_score : chess {
    move_count += 1;
    if (chess.node_state & NodeState.SSE) == 0 && ply == chess.exply && move == chess.excluded_move then {
      continue;
    }

    flags, from, to := decode_move16(move);
    pfrom := piece_at(chess, from);
    att := piece_at(chess, from);
    vic := piece_at(chess, to);

    // piece
    if chess.depth>6 && moves_searched>0 {
      // Late Move Pruning. Search the Root Plies Exhuastively
      if flags <= Move16.Double_Pawn_Push && (moves_searched > late_move_prune) then
        break;
      if flags <= Move16.Double_Pawn_Push && move_score < score_margin then
        break;
      if depth < 6 && flags == Move16.Capture && PVALUE[att] > PVALUE[vic] && see(chess,move) < -250*depth  then
        continue;
      else if depth < 6 && flags <= Move16.Double_Pawn_Push && see(chess,move) < -90*depth*depth then
        continue;
    }

    ext := 0;
    if chess.node_state & NodeState.SSE && depth>=7 && move == hash_move && tthit && cast(int)ttentry.depth >= depth-5 
       && ttentry.flag == TFLAGS.ALPHA {
      if to == pto && flags >= Move16.Capture {
        // recapture extension.
        ext = 1;
        tt_capture = true;
        tt_quiet   = false;
      } else {
        // singular extension:
        // if one move is better than all the rest, then we consider this singular
        // singular is determined by checking all other moves at a shallow depth on a nullwindow
        singular_beta := ttentry.score - depth;
        chess.excluded_move = move;
        chess.exply = ply;
        chess.node_state ^= NodeState.SSE;
        score := negamax_zw(chess, depth/2-1, singular_beta-1, singular_beta, fifty);
        chess.node_state ^= NodeState.SSE;
        chess.excluded_move = Move16.Quiet;
        chess.exply = INF;
        if score < singular_beta then {
          ext = 1;
          tt_capture = flags > Move16.Double_Pawn_Push;
          tt_quiet   = flags <= Move16.Double_Pawn_Push;
        } else if singular_beta >= beta then {
          return singular_beta;
        } else if ttentry.score >= beta then {
          ext = -2;
        } else if ttentry.score <= alpha && ttentry.score <= score {
          ext = -1;
        }
      }
    }

    if flags <= Move16.Double_Pawn_Push {
      // add quiet move.
      quiet_moves[num_quiets] = move;
      num_quiets += 1;
    } else {
      // add capture move.
      cap_moves[num_captures] = move;
      num_captures += 1;
    }
     
    // make move.
    next_fifty := fifty_move(chess, move, fifty);
    cap, castling := make_move(chess, move);
    eval := 0;
    if ext==1 || moves_searched == 0 {
      eval = -negamax_zw(chess, depth+ext-1, -beta, -alpha, next_fifty);
    } else {
      if in_check(chess) {
        // do not reduce depth on check.
        eval = -negamax_zw(chess, depth, -alpha-1, -alpha, next_fifty);
      } else if flags > Move16.Double_Pawn_Push {
        // captures. promotions.
        R := 1 - 4 * move_score / (abs(move_score) + 24576);
        R = max(0, R);
        eval = -negamax_zw(chess, depth+ext-R-1, -alpha-1, -alpha, next_fifty);
      } else if ply > 0 && num_quiets > 3 && flags <= Move16.Double_Pawn_Push {
        // Late Move Reduction when not in check and not giving check.
        R := LateMoveReduction[min(depth,63)][min(moves_searched,63)];
        R -= improving;
        if chess.probcut then {
          R += 2;
        }

        // increase reduction if capture.
        if tt_capture then {
          R += 1;
        }

        // decrease reduction if quiet.
        if tt_quiet then {
          R -= 2;
        }

        R -= move_score / 10_000;
        R = max(0, R);
        eval = -negamax_zw(chess, depth+ext-R-1, -alpha-1, -alpha, next_fifty);
      } else {
        // do normal search.
        eval = -negamax_zw(chess, depth+ext-1, -alpha-1, -alpha, next_fifty);
      }
    }

    unmake_move(chess, move, cap, castling);
    chess.en_passant = ep;
    if eval >= best_score {
      best_score = eval;
      if best_score >= beta then {
        using chess.history;
        bmove = move;
        pv_table[ply][0] = move;
        move_count := pv_table[ply+1].move_count;
        memcpy(*pv_table[ply][1], *pv_table[ply+1][0], move_count * size_of(Move16));
        pv_table[ply].move_count = move_count + 1;
     
        // non-captures == Quiet|Pawn Push Moves
        if flags <= Move16.Double_Pawn_Push 
          update_quiet(chess, move, depth, quiet_moves, num_quiets, cap_moves, num_captures);
        tt_store(chess.hash, best_score, TFLAGS.BETA, depth, move);
        return best_score;
      } 
    }

    moves_searched += 1;
  }

  if move_count == 0 then
    return ifx in_check(chess) then -INF+ply else 0+ply;
  tt_store(chess.hash, best_score, .ALPHA, depth, bmove);
  return best_score;
}

update_quiet :: (chess: *ChessGame, move: Move16, depth: int, quiet_moves: []Move16, num_quiets: int, cap_moves: []Move16, num_captures: int) {
  ply := chess.ply;
  incr : s32 = min(cast(s32) (depth*depth), 512);
  prev1, to1 := get_prev_move(chess, 1);
  prev2, to2 := get_prev_move(chess, 2);
  prev4, to4 := get_prev_move(chess, 4);

  using chess.history;
  // decrement all quiet moves which < alpha.
  for i: 0..num_quiets-1 {
    prev_move := quiet_moves[i];
    if prev_move != move {
      from := get_move16_from(prev_move);
      p := piece_at(chess, from);
      to := get_move16_to(prev_move);
      incr_history(*history_moves[p][to], -incr);
      incr_history(*counter_history[prev1][to1][p][to], -incr*2);
      incr_history(*counter_history[prev2][to2][p][to], -incr);
      incr_history(*counter_history[prev4][to4][p][to], -incr/2);
    }
  }

  for i: 0..num_captures-1 {
    prev_move := cap_moves[i];
    from := get_move16_from(prev_move);
    p := piece_at(chess, from);
    to := get_move16_to(prev_move);
    opp := norm(piece_at(chess, to));
    incr_history(*cap_history[p][to][opp], -incr);
  }

  // update history heuristic
  p := piece_at(chess, get_move16_from(move));
  to := get_move16_to(move);
  incr_history(*history_moves[p][to], incr);
  incr_history(*counter_history[prev1][to1][p][to], incr*2);
  incr_history(*counter_history[prev2][to2][p][to], incr);
  incr_history(*counter_history[prev4][to4][p][to], incr/2);

  if move != killer_moves[ply][0] then {
    killer_moves[ply][1] = killer_moves[ply][0];
    killer_moves[ply][0] = move;
  }
}

incr_history :: (data: *s32, incr: s32) #expand {
  <<data += (64*incr) - (<<data)*incr / 1024;
}

norm :: (p: Piece) -> Piece #expand {
  if p >= Piece.B_KING
    p -= 7;
  return p;
}

tt_probe_negamax :: (chess: ChessGame, ply: int, hash: u64, alpha: int, beta: int, depth: int) -> bool, TTData {
  tthit: bool = false; 
  ttentry: TTData;

  if (chess.node_state & NodeState.SSE) == 0 {
    if ply != chess.exply then {
      tthit, ttentry = tt_probe(chess.hash, alpha, beta, depth);
    }
  } else {
    tthit, ttentry = tt_probe(chess.hash, alpha, beta, depth);
  }

  return tthit, ttentry;
}

tt_probe :: (hash: u64, alpha: int, beta: int, depth: int) -> bool, TTData {
  key  := hash % cast,no_check (u64) ttable.count;
  prefetch(*ttable[key], Prefetch_Hint.T0);
  entry := ttable[key];
  if (entry.hash ^ (entry.padding & ~0xFF)) == hash then {
    // change the tt age.
    entry.age = search_age;
    memcpy(*ttable[key], *entry, size_of(TTEntry));
    return true, entry.data;
  }
  return false, entry.data;
}

tt_prune :: (tthit: bool, ttentry: TTData, ply: int, pv_node: bool, alpha: int, beta: int, depth: int) #expand {
  if tthit && !pv_node && ply>0 && ttentry.depth >= depth {
    score := ttscore(ttentry.score);

    flag  := ttentry.flag;
    if flag == TFLAGS.EXACT then
      `return score;
    if flag == TFLAGS.ALPHA && score <= alpha then
      `return score;
    if flag == TFLAGS.BETA && score >= beta then
      `return score;
  }

  ttscore :: (score: int) -> int #expand {
    if score > INF-20  then
      return INF-ply;
    else if score < -INF+20 then
      return -INF+ply;
    return score;
  }
}

tt_store :: (hash: u64, score: int, flag: TFLAGS, depth: int, ttmove: Move16) {
  key  := hash % cast,no_check(u64) ttable.count;
  prefetch(*ttable[key], Prefetch_Hint.T0);
  entry: TTEntry;
  entry.score = cast (s16) score;
  entry.flag = flag;
  entry.depth = cast, trunc(u8) depth;
  entry.ttmove = ttmove;
  entry.age = search_age;
  entry.hash = hash ^ (entry.padding & ~0xFF);

  ttentry := *ttable[key];
  if depth > ttentry.depth || ttentry.age != search_age then 
    memcpy(ttentry, *entry, size_of(TTEntry));
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
                  //8_031_647_685);

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
                  15_833_292,
                  706_045_033);

  // position 4: castling (mirrored)
  setup_perft_run("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1",
                  6,
                  264,
                  9_467,
                  422_333,
                  15_833_292,
                  706_045_033);

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
                  3_894_594,
                  164_075_551);

  // position 7: promotion bugs
  setup_perft_run("n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1",
                  24,
                  496,
                  9_483,
                  182_838,
                  3_605_103);

  print("All perft tests complete!%1", NEWLINE);

  setup_perft_run :: ($fen: string, expected: ..int) #expand {
    print("Testing FEN=[%1]%2", fen, NEWLINE);
    if equal(fen, "startpos") {
      chess_startpos(*chess);
    } else {
      chess_fen(*chess, fen);
    }

    for exp, depth: expected {
      perft_run(depth+1, exp);
    }
    print("------------------------------------%1%1", NEWLINE);
  }

  perft_run :: (depth: int, expected: int) #expand {
    time_taken := get_time();
    nodes := perft(*chess, depth);
    time_taken = get_time() - time_taken;
    if nodes == expected {
      print("perft successful at the depth of: %1, %2 nodes found, time taken: %3%4", depth, nodes, time_taken, NEWLINE);
    } else {
      print("FAILED at the depth of: %1, expected: %2, nodes found: %3, time taken: %4\n", depth, expected, nodes, time_taken, NEWLINE);
    }
  }
}

perft_divide :: (chess: *Chess, depth: int) -> int {
  taken := get_time();
  if depth <= 0 then return 1;

  moves: Moves;
  generate_moves(chess, *moves);

  num_nodes := 0;
  perft_count := 0;

  ep := chess.en_passant;
  for i: 0..moves.count-1 {
    move := moves.array[i];
    cap, flags, hash := make_move(chess, move);
    move_count := perft(chess, depth-1);
    _, from, to := decode_move16(move);
    print("%1%2: %3 nodes%4", cast(serialized_bb)from, cast(serialized_bb)to, move_count, NEWLINE);

    num_nodes += move_count;
    unmake_move(chess, move, cap, flags, hash);
    chess.en_passant = ep;
    perft_count += 1;
  }

  print("moves from here: %1%2%2", perft_count, NEWLINE);
  taken = get_time() - taken;
  print("Total %1 nodes%3Time taken: %2%3", num_nodes, taken, NEWLINE);
  print("NPS: %1%2", cast(float)num_nodes / taken, NEWLINE);
  return num_nodes;
}

INF :: S16_MAX; // Alias

#import "Machine_X64";
// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (chess: *ChessGame, alpha: int, beta: int, fifty: int = 0) -> int {
  ply := chess.ply;
  pv_node := alpha != beta-1;
  tthit, ttentry := tt_probe(chess.hash, alpha, beta, 0);
  tt_prune(tthit, ttentry, ply, pv_node, alpha, beta, 0);
  best_move := Move16.Quiet;

  ttmove  := chess.history.pv_table[ply][0];
  if get_move16_flag(ttmove) < Move16.Capture || !is_legal(chess, ttmove) then {
    ttmove = 0;
  } 

  hashmove := Move16.Quiet;
  if tthit && ttmove == 0 && get_move16_flag(ttentry.ttmove) >= Move16.Capture then {
    hashmove = ttentry.ttmove;
  }

  defer {
    using chess.history;
    memset(*pv_table[ply+1], 0, size_of(PV_Line));
    killer_moves[ply+1][1] = 0;
    killer_moves[ply+1][0] = 0;
  }

  best_score: int = -INF;
  hash_flag := TFLAGS.ALPHA;
  pos_check := in_check(chess);
  if !pos_check {
    // no standing pat while in check 
    best_score = evaluate(chess, fifty);
    if best_score >= beta then {
      return best_score;
    }

    // delta pruning:
    if can_delta_prune(chess) {
      if best_score < (alpha - 975) then {
        return best_score; 
      }
    }

    if alpha < best_score then {
      // hash_flag = TFLAGS.EXACT;
      alpha = best_score; 
    }
  }

  // search captures only, captures negate the fifty move rule
  ep := chess.en_passant;
  move_count := 0;
  for :pv move, move_score: chess {
    move_count += 1;
    type, from, to := decode_move16(move);

    // skip bad captures w/ SEE algorithm.
    if pos_check == false && bad_capture(chess, move, from, to) then
      continue;

    cap, flags := make_move(chess, move);
    next_fifty := fifty_move(chess, move, fifty);
    score := -quiescene(chess, -beta, -alpha, next_fifty);
    unmake_move(chess, move, cap, flags);
    chess.en_passant = ep;
    if score >= best_score {
      best_score = score;
      if best_score > alpha then {
        hash_flag = TFLAGS.EXACT;
        best_move = move;
        alpha = best_score;
     
        using chess.history;
        pv_table[ply][0] = move;
        move_count := pv_table[ply+1].move_count;
        memcpy(*pv_table[ply][1], *pv_table[ply+1][0], move_count * size_of(Move16));
        pv_table[ply].move_count = move_count + 1;
        if best_score >= beta then {
          tt_store(chess.hash, best_score, TFLAGS.BETA, 0, move);
          return best_score;
        }
     
      }
    }

  }

  if move_count == 0 && pos_check then {
    return -INF+ply;
  }

  tt_store(chess.hash, best_score, hash_flag, 0, best_move);
  return best_score;

  pv :: (chess: *ChessGame, body: Code, f: For_Flags) #expand {
    stage: enum {PV; CAPTURES; QUIETS; END; } = .PV;

    move_queue: MoveQueue(32);
    unsafe: u64 = 0;
    check: u64 = 0;
    turn := chess.turn;
    while outer_loop := !stop() {
      while move_queue.count <= 0 {
        if stage == {
        case .PV;
          stage = .CAPTURES;
          if is_legal(chess, `ttmove) then {
            append(*move_queue, 0x7FFF, `ttmove);
          }
          if `hashmove != `ttmove && is_legal(chess, `hashmove) then {
            append(*move_queue, 0x7FFF-1, `hashmove);
          }
        case .CAPTURES;
          unsafe, check = generate_attacks(chess);
          if check == 0 then {
            stage = .END;
          } else {
            stage = .QUIETS;
          }
          generate_tactics(unsafe, check, chess, *move_queue);
          filter_capture_pv(*move_queue, `ttmove, `hashmove);
          sort_captures(*move_queue, chess);
        case .QUIETS;
          stage = .END;
          generate_quiets(unsafe, check, chess, *move_queue);
          filter_capture_pv(*move_queue, `ttmove, `hashmove);
          sort_quiets(*move_queue, chess);
        case .END;
          break outer_loop; // terminate loop
        }
      }
      `it, `it_index := pop(*move_queue);
      #insert body;
    }
  }

  can_delta_prune :: (using chess: *Chess) -> bool #expand {
    w := w_queen | w_rook | w_bishop | w_knight;
    b := b_queen | b_rook | b_bishop | b_knight;
    return w != 0 || b != 0;
  }

  is_promoting_pawn :: inline (using chess: *Chess) -> bool {
    return (w_pawn & cast(u64)rank_7) != 0 || (b_pawn & cast(u64)rank_2) != 0; 
  }

  // a bad capture => true, a good capture => false
  bad_capture :: (chess: *Chess, move: Move16, from: int, to: int) -> bool {
    pfrom := cast(int) piece_at(chess, from);
    pto   := cast(int) piece_at(chess, to);
    if PVALUE[pfrom] <= PVALUE[pto] then {
      return false;
    }

    return see(chess, move) < 0;
  }
}

PV_Line :: struct {
  move_count: u16;
  argmove: [79] Move16;
}

operator [] :: (using p: PV_Line, index: int) -> Move16 {
  return argmove[index];
}

operator []= :: (using p: *PV_Line, index: int, move: Move16) #expand {
  argmove[index] = move;
}

operator *[] :: (p: *PV_Line, index: int) -> *Move16 #expand {
  return *p.argmove[index];
}

operator [] :: (using m: Moves, index: int) -> Move16 {
  return array[index];
}

time_begin: float64;

// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (chess: *Chess, depth: int) -> int {
  if depth == 0 then return 1;

  if depth == 1 then {
    moves: Moves(true);
    generate_moves(chess, *moves);
    return moves.count;
  }

  num_nodes := 0;
  ep := chess.en_passant;
  for :gen_moves mov: << chess {
    cap, castling, hash := make_move(chess, mov);

    num_nodes += perft(chess, depth-1);

    unmake_move(chess, mov, cap, castling, hash);
    chess.en_passant = ep;
  }
  return num_nodes;

  gen_moves :: (chess: *Chess, body: Code, f: For_Flags) #expand {
    moves: Moves;
    unsafe, check := generate_attacks(chess);
    generate_tactics(unsafe, check, chess, *moves);
    i := 0;
    `it := Move16.Quiet;
    `it_index := 0;
    while i < moves.count {
      it = moves[i];
      #insert body;
      i += 1;
      it_index += 1;
    }
    moves.count = 0;
    memset(*moves, 0, size_of(Moves));
    generate_quiets(unsafe, check, chess, *moves);
    i = 0;
    while i < moves.count {
      it = moves[i];
      #insert body;
      i += 1;
      it_index += 1;
    }
  }
}

#no_reset LateMoveReduction: [64][64] int;
#run {
  for i: 1..63 {
    for j: 1..63 {
      LMR := log(cast(float)i) * log(cast(float)j) * 0.5 + 1.0;
      LateMoveReduction[i][j] = cast (int) LMR;
    }
  }
}

// most valuable victim, least valuable attacker.
// see: https://www.chessprogramming.org/MVV-LVA
mvv_lva :: (victim: Piece, attacker: Piece) -> score: s32 {
  v := cast(int) victim;
  a := cast(int) attacker;
  vs := piece_score[v] - (piece_score[a]/100) + 10000;
  return vs;

  piece_score :: #run -> [13] s32 {
    using Piece;
    array: [13] s32;
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

nodes_searched := 0;

History :: struct {
  pv_table:        [128] PV_Line;
  cap_history:     [13][64][7] s32;
  history_moves:   [13][64] s32;
  killer_moves:    [128][2] Move16;
  counter_history: [13][64][13][64] s32;
}

TTEntry :: struct {
  hash: u64;
  union {
    using data: TTData;
    padding: u64;
  }
}

ttable: [] TTEntry;

init_ttable :: (size: int = 16_000_000) {
  if ttable.count > 0 then
    array_free(ttable);
  num_entries := size / size_of(TTEntry);
  ttable = NewArray(num_entries, TTEntry);
  memset(*ttable[0], 0, size_of(TTEntry)*num_entries);
}

TTData :: struct {
  age   : u8; // note: we put age as the first byte to make it easier to mask.
  flag  : TFLAGS;
  depth : u8;
  ttmove: Move16;
  score : s16;
}

search_age : u8 = 0;

TFLAGS :: enum u8 { EXACT; ALPHA; BETA; }

Clear_Hash :: () {
  memset(*ttable[0], 0, size_of(TTEntry)*ttable.count);
}

Moves :: struct(perft1 := false) {
  count: s32;
  #if perft1 == false {
    array: [64] Move16;
  }
}

add_move :: (moves: *Moves, from: int, to: int, flags: Move16) #expand {
  #if moves.perft1 == false {
    move := to_move16(from, to, flags);
    moves.array[moves.count] = move;
  }
  moves.count += 1;
}

add_move :: (queue: *MoveQueue, from: int, to: int, flags: Move16) #expand {
  move := to_move16(from, to, flags);
  append(queue, 0, move);
}

// static exchange evaluation.
see :: (chess: *Chess, move: Move16) -> eval: int {
  _, from, to := decode_move16(move);
  target := cast(int) piece_at(chess, to);
  apiece := cast(int) piece_at(chess, from);

  gain: [16] s16;
  d := 0;
  may_x_ray: u64 = chess.w_pawn | chess.w_bishop | chess.w_rook | chess.w_queen
                 | chess.b_pawn | chess.b_bishop | chess.b_rook | chess.b_queen;
  from_set := cast(u64) 1 << from;
  occupied := chess.occupied;
  attadef  := attacks_to(occupied, to);
  gain[d] = PVALUE[target];
  turn := chess.turn;

  bishops := (chess.w_bishop|chess.b_bishop|chess.w_queen|chess.b_queen);
  rooks   := (chess.w_rook|chess.b_rook|chess.w_queen|chess.b_queen);

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
      attadef |= consider_x_rays(occupied, to, from_set, bishops, rooks);

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

  consider_x_rays :: (occ: u64, to: int, from_set: u64, bishops: u64, rooks: u64) -> u64 #expand {
    atts : u64 = 0;
    atts |= bishop_moves(to, occ) & bishops;
    atts |= rook_moves(to, occ) & rooks;
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

PVALUE :: #run -> [13] s16 {
  using Piece;
  array: [13] s16;
  array[cast(int)NONE     ] = 0;
  array[cast(int)W_KING   ] = 10000;
  array[cast(int)W_QUEEN  ] = 1000;
  array[cast(int)W_ROOK   ] = 500;
  array[cast(int)W_BISHOP ] = 300;
  array[cast(int)W_KNIGHT ] = 300;
  array[cast(int)W_PAWN   ] = 100;

  array[cast(int)B_KING   ] = 10000;
  array[cast(int)B_QUEEN  ] = 1000;
  array[cast(int)B_ROOK   ] = 500;
  array[cast(int)B_BISHOP ] = 300;
  array[cast(int)B_KNIGHT ] = 300;
  array[cast(int)B_PAWN   ] = 100;
  return array;
}

get_bestmove :: (c: *ChessGame) -> Move16 #expand {
  return c.history.pv_table[0][0];
}

copy_chessgame :: (dest: *ChessGame, src: *ChessGame) {
  memcpy(*dest.chess, *src.chess, size_of(Chess));
  // skip history, since that is zero.
  dest.ply = src.ply;
  dest.maxply = src.maxply;
  dest.depth = src.depth;
  dest.maxnodes = src.maxnodes;
  dest.movetime = src.movetime;
  dest.maxdepth = src.maxdepth;
  dest.excluded_move = src.excluded_move;
  dest.exply = src.exply;
  dest.probcut = src.probcut;

  // don't copy NNUEdata or node_state.
  array_copy(*dest.moves, src.moves);
  array_copy(*dest.rtable, src.rtable);
  array_copy(*dest.eval, src.eval);
  dest.fifty = src.fifty;
}

ChessGame :: struct {
  #as using chess: Chess;
  history: History;
  ply: int;
  maxply: int;
  depth: int;
  maxnodes: int;
  movetime: int;
  maxdepth: int;
  excluded_move: Move16;
  exply: int;
  probcut: s8 = 0;
  main_thread := false;
  fifty: int;
  score: s16 = 0;

  nnue: [] NNUEdata;
  node_state: NodeState;
  moves: [..] Move32;
  rtable: [..] u64;
  eval: [..] s16;
} 

free_chess_game :: (chess: *ChessGame) {
  array_free(chess.nnue);
  array_free(chess.moves);
  array_free(chess.rtable);
  array_free(chess.eval);
  free(chess);
}

clear_history :: (chess: *ChessGame) {
  using chess.history;
  memset(pv_table.data, 0, size_of(type_of(pv_table)));
  memset(cap_history.data, 0, size_of(type_of(cap_history)));
  memset(history_moves.data, 0, size_of(type_of(history_moves)));
  memset(killer_moves.data,  0, size_of(type_of(killer_moves)));
  memset(counter_history.data, 0, size_of(type_of(counter_history)));
}

NodeState :: enum_flags u8 {
  NULL;
  SSE;
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
  nnue = NewArray(MAX, NNUEdata, alignment=64);
  //assert((cast(s64)nnue.data % 64) == 0);
  MAX :: 500;
}

is_draw :: (using,except(fifty) c: *ChessGame, fifty: int) -> bool {
  count_p := popcount(c.occupied);
  if count_p <= 3 then {
    if count_p == 2 then {
      return true;
    }
    if (w_bishop|w_knight|b_bishop|b_knight) & c.occupied then {
      return true;
    }
  }

  hash_val := c.hash;
  repeat_count := 0;
  index := rtable.count-1;
  while fifty > 0 {
    if rtable[index] == hash_val then {
      repeat_count += 1;
      if repeat_count >= 2 then
        return true;
    }
    index -= 1;
    fifty -= 1;
  }

  return false;
}

make_move :: (c: *ChessGame, move: Move16) -> Piece, Castling {
  fetch_and_add(*nodes_searched);
  flags, from, to := decode_move16(move);
  piece := c.pieces[from];
  move32: Move32;
  move32.mov16 = move;
  move32.piece = piece;
  make_move_nnue(c, move);

  cap, castling, hash := make_move(*c.chess, move);
  key := hash % cast, no_check(u64) ttable.count;
  array_add(*c.moves, move32);
  array_add(*c.rtable, hash);

  c.ply += 1;
  c.maxply = max(c.maxply, c.ply);
  return cap, castling;

  make_move_nnue :: (using c: *ChessGame, move: Move16) #expand {
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

unmake_move :: (c: *ChessGame, move: Move16, cap: Piece, castling: Castling) {
  pop(*c.moves);
  hash := pop(*c.rtable);
  unmake_move(*c.chess, move, cap, castling, hash);
  c.ply -= 1;
}

get_prev_move :: (chess: *ChessGame, num: int) -> piece: int, to: int {
  if chess.ply < num return 0, 0;

  idx := chess.moves.count-num;
  prev_move := chess.moves[idx];
  piece, to := piece_to(prev_move);
  return piece, to;
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

make_null_move :: (c: *ChessGame) -> ep: u64 {
  ep, hash := make_null_move(*c.chess);
  null_move: Move32 = Move32.{0, 0};
  array_add(*c.moves, null_move);
  array_add(*c.rtable, hash);
  make_null_move_nnue(c);
  c.ply += 1;
  c.maxply = max(c.maxply, c.ply);
  return ep;

  make_null_move_nnue :: (using c: *ChessGame) #expand {
    memcpy(*c.nnue[c.ply+1].accumulator, *c.nnue[c.ply].accumulator, size_of(Accumulator));
    dp := *c.nnue[c.ply+1].dirtyPiece;
    dp.dirtyNum = 0;
  }
}

unmake_null_move :: (c: *ChessGame, ep: u64) {
  pop(*c.moves);
  hash := pop(*c.rtable);
  unmake_null_move(*c.chess, ep, hash);
  c.ply -= 1;
}

get_countermove_history :: (chess: *ChessGame, num: int) -> *[13][64]s32 {
  using chess.history;
  prev, to := get_prev_move(chess, num);
  return *counter_history[prev][to];
}

// fetch and add.
fetch_and_add :: (val: *int) #expand {
  #asm {
    mov incr: gpr, 1;
    xadd.q [val], incr;
  }
}

multi_pv: int = 1;

heapify :: (queue: *MoveQueue, index: int) {
  array: [] Queue_Pair = queue.array;
  while true {
    largest := index;
    left := 2 * index + 1;
    right := 2 * index + 2;
 
    N := queue.count;
 
    if left < N && array[left].priority > array[largest].priority then
      largest = left;
 
    if right < N && array[right].priority > array[largest].priority then
      largest = right;

    if largest == index then
      break;
 
    temp := array[index];
    array[index] = array[largest];
    array[largest] = temp;
    index = largest;
  }

}

pop :: (queue: *MoveQueue) -> move: Move16, priority: s32 {
  move := queue.array[0].move;
  priority := queue.array[0].priority;
  queue.count -= 1;
  queue.array[0] = queue.array[queue.count];
  heapify(queue, 0);
  return move, priority;
}

construct_heap :: (queue: *MoveQueue) {

  count := queue.array.count/2 - 1;
  for < index: count..0 {
    heapify(queue, index);
  }

}

MoveQueue :: struct(SZ: int = 128) {
  count: int;
  array: [SZ] Queue_Pair;
}

append :: (queue: *MoveQueue, priority: s16, move: Move16) {
  index := queue.count;
  queue.array[index].priority = priority;
  queue.array[index].move = move;
  queue.count += 1;
}

Queue_Pair :: struct {
  priority: s32;
  move: Move16;
}
