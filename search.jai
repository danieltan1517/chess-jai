#import "Math";
#import "Basic";

search :: (chess: *ChessGame, depth: int, fifty: int) -> Move16 {
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  time_begin = get_time();
  // clear_hash_table();
  memset(pv_table.data, 0, size_of(type_of(pv_table)));
  memset(__cap_history.data, 0, size_of(type_of(__cap_history)));
  memset(__history_moves.data, 0, size_of(type_of(__history_moves)));
  memset(__killer_moves.data,  0, size_of(type_of(__killer_moves)));
  memset(__counter_history.data, 0, size_of(type_of(__counter_history)));
  __nodes_searched = 0;
  score : int; 
  best_move : Move16;
  alpha: int = -INF;
  beta:  int =  INF;
  delta := 50;
  cur_depth := 1;
  while cur_depth <= depth { 
    if cur_depth < 3 then {
      alpha = -INF;
      beta = INF;
    }
    reset_temporary_storage();
    chess.ply = 0;
    chess.maxply = 0; 
    chess.depth = cur_depth;
    score = negamax(chess, cur_depth, true, true, alpha, beta, fifty);
    time_taken := get_time() - time_begin;
    if stop_signal_triggered() then 
      break;

    if score <= alpha then {
      print("info depth % lowerbound %\n", cur_depth, score);
      alpha = max(alpha-delta, -INF);
      delta += delta + depth / 5;
      continue;
    }

    if score >= beta then {
      print("info depth % upperbound %\n", cur_depth, score);
      beta = min(beta+delta, INF);
      delta += delta + depth / 5;
      continue;
    }

    alpha = max(score - delta, -INF);
    beta  = min(score + delta, INF);

    best_move = pv_table[0][0];
    print_stats(cur_depth);
    cur_depth += 1;
  }

  search_age += 1;
  return best_move;

  print_stats :: (depth: int) #expand {
    builder: String_Builder;
    builder.allocator = temp;
    t_ms := cast(int)(`time_taken*1000.0); // convert secs to ms
    nps  := cast(int)(__nodes_searched/(`time_taken+0.0001));
    print_to_builder(*builder, "info depth % seldepth % ", depth, chess.maxply);
    if score >= -INF+20 && score <= INF-20 then {
      print_to_builder(*builder, "nodes % time % score cp % nps % pv ", __nodes_searched, t_ms, score, nps);
    } else {
      mate := INF - abs(score);
      mate = (mate/2) + (mate & 1);
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

negamax :: (chess: *ChessGame, depth: int, $null_flag: bool, $single_ext: bool, alpha: int, beta: int, fifty: int) -> int {
  ply := chess.ply;
  pv_node := alpha != beta-1;
  if (__nodes_searched & 2048) && stdin_stop_signal()
    return 0;
  // mate distance pruning
  if ply > 0 then {
    alpha = max(alpha,-INF+ply);
    beta  = min(beta,  INF-ply);
    if alpha >= beta then {
      return alpha;
    }
  }

  // cannot trust that tt_entry will remain the same.
  // it can be overwritten by accident due to hash collisions
  // esp. during multi-threading. need to copy out the ttentry.

  // tt probe.
  tthit: bool; 
  ttentry: TTData;

  // need to account for singular search extensions while probing.
  #if single_ext == false {
    if ply != chess.exply then
      tthit, ttentry = tt_probe(chess.hash, alpha, beta, depth);
  } else {
    tthit, ttentry = tt_probe(chess.hash, alpha, beta, depth);
  }

  tt_prune(tthit, ttentry, ply, pv_node, alpha, beta, depth);

  if depth <= 0 then
    return quiescene(chess, alpha, beta, fifty);

  if ply && fifty >= 100 then
    return 0+ply;

  status := check_for_repetition(chess, fifty);
  if !pv_node && status == ChessFlags.Threefold_Repetition 
    return 0+ply;

  ttmove := pv_table[ply][0];
  hash_move := ifx tthit then ttentry.ttmove else Move16.Quiet;

  defer {
    memset(*pv_table[ply+1], 0, size_of(PV_Line));
    __killer_moves[ply+1][1] = 0;
    __killer_moves[ply+1][0] = 0;
  }

  // internal iterative deepening.
  if pv_node && depth > 8 && ttmove == 0 && hash_move == 0 then 
    depth -= 1;

  // NOTE: we make eval really high,
  // so we will look at checks much more
  // carefully, when improving=1, more branches to look at.
  array_add(*chess.eval, INF);
  defer pop(*chess.eval);
  if ply>0 && !pv_node && status == ChessFlags.Normal && !in_check(chess) {
    eval := ifx tthit then ttentry.score else evaluate(chess, fifty);
    chess.eval[chess.eval.count-1] = cast(s16) eval;
    improving := get_improving(chess);

    // reverse futility pruning. stockfish has margin at 214*depth
    margin := 125 *(depth-improving);
    if depth < 11 && (eval-margin) >= beta then {
      return eval;
    }

    // razoring.
    if depth <= 7 && eval + (200*depth) <= alpha {
      score := quiescene(chess, alpha, beta, fifty);
      if score <= alpha then
        return score;
    }

    // null move pruning. check for zugzwang before searching.
    #if null_flag == true then {
      if depth > 3 && eval >= beta-256 then {
        R := 4 + depth/3 + min((eval-beta) / 256, 3);
        ep := make_null_move(chess);
        score := -negamax(chess, depth-R-1, false, false, -beta, -beta + 1, fifty);
        unmake_null_move(chess, ep);
     
        if score >= beta then {
          // null move w/ verification at higher depths.
          if depth>12 || zugzwang(chess) then {
            score = negamax(chess, depth-R-1, false, false, beta-1, beta, fifty);
            if score >= beta then 
              return beta;
          } else {
            return beta;
          }
        }
      }
    }

    if depth > 5 && abs(beta) < 20_000 then {
      chess.probcut += 1;
      defer chess.probcut -= 1;
      prob_beta := beta + 155 - 46 * improving;
      ep := chess.en_passant;
      for :probcut move, move_score: chess {
        flags, from, to := decode_move16(move);
        pfrom := piece_at(chess, from);
       
        // make move.
        cap, castling := make_move(chess, move);
        score := -quiescene(chess, -prob_beta, -prob_beta+1, 0);
        if score >= prob_beta then
          score = -negamax(chess, depth-4, null_flag, false, -prob_beta, -prob_beta + 1, 0);
    
        // unmake move.
        unmake_move(chess, move, cap, castling);
        chess.en_passant = ep;
    
        if score >= prob_beta then {
          return score;
        }
      }
    }
  }

  ep := chess.en_passant;
  hash_flag := TFLAGS.ALPHA;
  cap_moves: [32] Move16;
  quiet_moves: [64] Move16;
  num_captures := 0;
  num_quiets := 0;
  moves_searched := 0;

  improving := get_improving(chess);
  late_move_prune := 3 + ((depth*depth) / (2-improving));

  tt_capture: bool = false;
  tt_quiet: bool   = false;

  move_count := 0;
  bmove := Move16.Quiet;
  pto := prev_to(chess);
  prev_to :: (chess: ChessGame) -> int {
    if chess.ply >= 2 {
      count := chess.moves.count;
      prev_move1 := chess.moves[count-1].mov16;
      to1 := get_move16_to(prev_move1);
      prev_move2 := chess.moves[count-2].mov16;
      to2 := get_move16_to(prev_move2);
      if to1 == to2
        return to1;
    }
    return -1;
  }

  for :pv move, move_score : chess {
    move_count += 1;
    #if single_ext == false {
      if ply == chess.exply && move == chess.excluded_move then {
        continue;
      }
    }

    flags, from, to := decode_move16(move);
    print_curr_move();
    pfrom := piece_at(chess, from);
    att := piece_at(chess, from);
    vic := piece_at(chess, to);

    // piece
    if chess.depth>6 && ply>0 && moves_searched>0 {
      // Late Move Pruning. Search the Root Plies Exhuastively
      if flags <= Move16.Double_Pawn_Push && moves_searched > late_move_prune then
        break;
      if flags == Move16.Capture && PVALUE[att] > PVALUE[vic] && see(chess,move) < -250*depth  then
        continue;
      else if flags <= Move16.Double_Pawn_Push && see(chess,move) < -90*depth*depth then
        continue;
    }

    ext := 0;
    #if single_ext == true {
      if ply>0 && depth>=7 && ply<chess.depth && move == hash_move && tthit && cast(int)ttentry.depth >= depth-3 
         && abs(ttentry.score) < 20_000 && ttentry.flag == TFLAGS.ALPHA {

        if to == pto && flags >= Move16.Capture && move_score > 1_200*depth {
          // recapture extension.
          ext = 1;
          tt_capture = true;
          tt_quiet   = false;
        } else {
          // singular extension:
          // if one move is better than all the rest, then we consider this singular
          // "singular" is determined by checking all other moves at a shallow depth on a nullwindow
          singular_beta := ttentry.score - 3*depth;
          chess.excluded_move = move;
          chess.exply = ply;
          score := negamax(chess, depth/2-1, null_flag, false, singular_beta-1, singular_beta, fifty);
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
          }
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
    next_fifty := 0;
    if pfrom != Piece.W_PAWN && pfrom != Piece.B_PAWN && flags == Move16.Quiet {
      next_fifty = fifty + 1;
    }
    cap, castling := make_move(chess, move);
    eval := 0;
    if moves_searched == 0 {
      eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -beta, -alpha, next_fifty);
    } else {
      if in_check(chess) {
        // do not reduce depth on check.
        eval = -negamax(chess, depth, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      } else if flags > Move16.Double_Pawn_Push {
        // captures. promotions.
        R := 1 - 4 * move_score / (abs(move_score) + 24576);
        R = max(0, R);
        eval = -negamax(chess, depth+ext-R-1, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      } else if flags <= Move16.Double_Pawn_Push {
        // Late Move Reduction when not in check and not giving check.
        R := LateMoveReduction[min(depth,63)][min(moves_searched,63)];
        R -= improving;
        R += chess.probcut*2;
        if pv_node then {
          R -= 15 / (3 + depth);
          R -= 1;
        }

        // increase reduction if capture.
        if tt_capture then
          R += 1;

        // decrease reduction if quiet.
        if tt_quiet then 
          R -= 1;

        if R > 0x7FFF_FFF-2 then
          R -= 6;
        else
          R -= move_score / 48_480;
        R = max(0, R);
        eval = -negamax(chess, depth+ext-R-1, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      } else {
        // do normal search.
        eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -alpha-1, -alpha, next_fifty);
      }

      // search the move again that has failed to be proved to be bad with normal alpha beta score bounds
      if pv_node && eval > alpha then 
        eval = -negamax(chess, depth+ext-1, null_flag, single_ext, -beta, -alpha, next_fifty);
    }

    unmake_move(chess, move, cap, castling);
    chess.en_passant = ep;
    if eval > alpha {
      hash_flag = TFLAGS.EXACT;
      bmove = move;
      pv_table[ply].argmove[0] = move;
      move_count := pv_table[ply+1].move_count;
      memcpy(*pv_table[ply].argmove[1], *pv_table[ply+1].argmove[0], move_count * size_of(Move16));
      pv_table[ply].move_count = move_count + 1;
      alpha = eval;
    } 

    if eval >= beta then {
      hash_flag = TFLAGS.BETA;
      // non-captures == Quiet|Pawn Push Moves
      if flags <= Move16.Double_Pawn_Push {
        update_quiet(chess, move, depth, quiet_moves, num_quiets, cap_moves, num_captures);
      } 
      #if single_ext == true {
        tt_store(chess.hash, beta, TFLAGS.BETA, depth, move);
      }
      return beta;
    } 
    
    moves_searched += 1;
  }

  if move_count == 0 then
    return ifx in_check(chess) then -INF+ply else 0+ply;

  if status == ChessFlags.Threefold_Repetition || status == ChessFlags.Fifty then {
    hash_flag = TFLAGS.EXACT;
    alpha = 0+ply;
    depth = 100;
  }

  if pv_node && hash_flag == TFLAGS.EXACT && get_move16_flag(bmove) > Move16.Double_Pawn_Push then {
    update_tactics(chess, bmove, depth, cap_moves, num_captures, quiet_moves, num_quiets);
  }

  #if single_ext == true {
    tt_store(chess.hash, alpha, hash_flag, depth, bmove);
  }
  return alpha;

  update_tactics :: (chess: *ChessGame, move: Move16, depth: int, cap_moves: []Move16, num_captures: int, quiet_moves: []Move16, num_quiets: int) {
    ply := chess.ply;
    incr : s32 = min(cast(s32)(depth*depth), 128);
    prev1, to1 := get_prev_move(chess, 1);
    prev2, to2 := get_prev_move(chess, 2);
    prev4, to4 := get_prev_move(chess, 4);

    for i: 0..num_captures-1 {
      prev_move := cap_moves[i];
      if prev_move != move {
        from := get_move16_from(prev_move);
        p := piece_at(chess, from);
        to := get_move16_to(prev_move);
        opp := norm(piece_at(chess, to));
        incr_history(*__cap_history[p][to][opp], -incr);
      }
    }

    // decrement all quiet moves which < alpha.
    for i: 0..num_quiets-1 {
      quiet_move := quiet_moves[i];
      from := get_move16_from(quiet_move);
      p := piece_at(chess, from);
      to := get_move16_to(quiet_move);
      incr_history(*__history_moves[p][to], -incr);
      incr_history(*__counter_history[prev1][to1][p][to], -incr);
      incr_history(*__counter_history[prev2][to2][p][to], -incr);
      incr_history(*__counter_history[prev4][to4][p][to], -incr);
    }

    from := get_move16_from(move);
    p := piece_at(chess, from);
    to := get_move16_to(move);
    opp := norm(piece_at(chess, to));
    incr_history(*__cap_history[p][to][opp], incr);
  }

  update_quiet :: (chess: *ChessGame, move: Move16, depth: int, quiet_moves: []Move16, num_quiets: int, cap_moves: []Move16, num_captures: int) {
    ply := chess.ply;
    incr : s32 = min(cast(s32) (depth*depth), 512);
    prev1, to1 := get_prev_move(chess, 1);
    prev2, to2 := get_prev_move(chess, 2);
    prev4, to4 := get_prev_move(chess, 4);

    // decrement all quiet moves which < alpha.
    for i: 0..num_quiets-1 {
      prev_move := quiet_moves[i];
      if prev_move != move {
        from := get_move16_from(prev_move);
        p := piece_at(chess, from);
        to := get_move16_to(prev_move);
        incr_history(*__history_moves[p][to], -incr);
        incr_history(*__counter_history[prev1][to1][p][to], -incr*2);
        incr_history(*__counter_history[prev2][to2][p][to], -incr);
        incr_history(*__counter_history[prev4][to4][p][to], -incr/2);
      }
    }

    for i: 0..num_captures-1 {
      prev_move := cap_moves[i];
      from := get_move16_from(prev_move);
      p := piece_at(chess, from);
      to := get_move16_to(prev_move);
      opp := norm(piece_at(chess, to));
      incr_history(*__cap_history[p][to][opp], -incr);
    }

    // update history heuristic
    p := piece_at(chess, get_move16_from(move));
    to := get_move16_to(move);
    incr_history(*__history_moves[p][to], incr);
    incr_history(*__counter_history[prev1][to1][p][to], incr*2);
    incr_history(*__counter_history[prev2][to2][p][to], incr);
    incr_history(*__counter_history[prev4][to4][p][to], incr/2);

    if move != __killer_moves[ply][0] then {
      __killer_moves[ply][1] = __killer_moves[ply][0];
      __killer_moves[ply][0] = move;
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

  print_curr_move :: () #expand {
    if ply==0 && chess.depth>10 {
      time := get_time();
      if `alpha > -INF+20 && `alpha < INF-20 && (time-time_begin)>3 then {
        print("info depth %1 currmove %2%3 currmovenumber %4\n", chess.depth, cast(serialized_bb)`from, cast(serialized_bb)`to, `moves_searched+1);
      } 
    }
  }

  pv :: (chess: *ChessGame, body: Code, f: For_Flags) #expand {
    // main principle variation search move picker.
    stage: enum {PV; CAPTURES; KILLERS; QUIETS; END; } = .PV;
    killers: [] Move16 = __killer_moves[ply];
    moves: Negamax(64);
    moves.count = 0;
    moves.counter = get_countermove_history(chess, 1);
    moves.follow1 = get_countermove_history(chess, 2);
    moves.follow2 = get_countermove_history(chess, 4);

    unsafe: u64 = 0;
    check: u64 = 0;
    turn := chess.turn;
    while true {
      while moves.count <= 0 {
        if stage == {
        case .PV;
          stage = .CAPTURES;
          if is_legal(chess, ttmove) then {
            heap_add(*moves, ttmove, 0x7FFF_FFFF);
            moves.pv = ttmove;
          } 
          if ttmove != hash_move && is_legal(chess, hash_move) then {
            heap_add(*moves, hash_move, 0x7FFF_FFFF-1);
            moves.hashmove = hash_move;
          }
        case .CAPTURES;
          stage = .KILLERS;
          unsafe, check = generate_attacks(chess);
          generate_tactics(unsafe, check, chess, *moves);
        case .KILLERS;
          stage = .QUIETS;
          if is_legal(chess, killers[0]) {
            heap_add(*moves, killers[0], 0x7FFF_FFFF);
            moves.killer1 = killers[0];
          } 
          if is_legal(chess, killers[1]) {
            heap_add(*moves, killers[1], 0x7FFF_FFFF-1);
            moves.killer2 = killers[1];
          }
        case .QUIETS;
          stage = .END;
          generate_quiets(unsafe, check, chess, *moves);
        case .END;
          return; // terminate loop
        }
      }
      `it, `it_index := heap_pop(*moves);
      #insert body;
    }
  }

  probcut :: (chess: *ChessGame, body: Code, f: For_Flags) #expand {
    stage: enum {PV; CAPTURES; QUIETS; END; } = .PV;
    moves: Negamax(16); 
    moves.count = 0;
    moves.counter = get_countermove_history(chess, 1);
    moves.follow1 = get_countermove_history(chess, 2);
    moves.follow2 = get_countermove_history(chess, 4);

    unsafe: u64 = 0;
    check: u64 = 0;
    turn := chess.turn;
    while true {
      while moves.count <= 0 {
        if stage == {
        case .PV;
          stage = .CAPTURES;
          if is_legal(chess, ttmove) then {
            heap_add(*moves, ttmove, 0x7FFF_FFFF);
            moves.pv = ttmove;
          }
          if ttmove != hash_move && is_legal(chess, hash_move) then {
            heap_add(*moves, hash_move, 0x7FFF_FFFF-1);
            moves.pv = hash_move;
          }
        case .CAPTURES;
          stage = .END;
          unsafe, check = generate_attacks(chess);
          generate_tactics(unsafe, check, chess, *moves);
        case .END;
          return; // terminate loop
        }
      }

      `it, `it_index := heap_pop(*moves);
      #insert body;
    }
  }
}

tt_probe :: (hash: u64, alpha: int, beta: int, depth: int) -> bool, TTData {
  key  := hash % TSIZE;
  prefetch(*ttable.entries[key], Prefetch_Hint.T0);
  entry := ttable.entries[key];
  if entry.hash == hash then {
    ttable.entries[key].age = search_age;
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
      `return alpha;
    if flag == TFLAGS.BETA && score >= beta then
      `return beta;
  }

  ttscore :: (score: int) -> int #expand {
    if score > INF-20  then
      return score - ply;
    else if score < -INF+20 then
      return score + ply;
    return score;
  }
}

tt_store :: (hash: u64, score: int, flag: TFLAGS, depth: int, ttmove: Move16) {
  key  := hash % TSIZE;
  entry: ttable.TTEntry;
  entry.hash = hash;
  entry.score = cast(s16) score;
  entry.flag = flag;
  entry.depth = cast, trunc(u8) depth;
  entry.ttmove = ttmove;
  entry.age = search_age;

  prefetch(*ttable.entries[key], Prefetch_Hint.T0);
  ttentry := *ttable.entries[key];
  if depth >= ttentry.depth || ttentry.age != search_age then 
    memcpy(ttentry, *entry, size_of(ttable.TTEntry));
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
    print("%1%2: %3 nodes\n", cast(serialized_bb)from, cast(serialized_bb)to, move_count);

    num_nodes += move_count;
    unmake_move(chess, move, cap, flags, hash);
    chess.en_passant = ep;
    perft_count += 1;
  }

  print("moves from here: %\n\n", perft_count);
  taken = get_time() - taken;
  print("Total: % nodes, Time taken: %\n\n", num_nodes, taken);
  return num_nodes;
}

INF :: S16_MAX; // Alias
      
#import "Machine_X64";
// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (chess: *ChessGame, alpha: int, beta: int, fifty: int = 0) -> int {
  if (__nodes_searched & 2048) && stdin_stop_signal()
    return 0;
  ply := chess.ply;
  pv_node := alpha != beta-1;
  tthit, ttentry := tt_probe(chess.hash, alpha, beta, 0);
  tt_prune(tthit, ttentry, ply, pv_node, alpha, beta, 0);
  best_move := Move16.Quiet;

  ttmove  := pv_table[ply][0];
  if get_move16_flag(ttmove) < Move16.Capture || !is_legal(chess, ttmove) then {
    ttmove = 0;
  } 

  hashmove := Move16.Quiet;
  if tthit && ttmove == 0 && get_move16_flag(ttentry.ttmove) >= Move16.Capture then {
    hashmove = ttentry.ttmove;
  }

  hash_flag := TFLAGS.ALPHA;
  pos_check := in_check(chess);
  if !pos_check {
    // no standing pat while in check 
    eval := evaluate(chess, fifty);
    if eval >= beta then {
      return beta;
    }
  
    // delta pruning:
    if can_delta_prune(chess) {
      if eval < (alpha - 975) then {
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
  move_count := 0;
  for :pv move, move_score: chess {
    move_count += 1;
    type, from, to := decode_move16(move);

    // skip bad captures w/ SEE algorithm.
    if is_bad_capture(move, pos_check) then
      continue;

    cap, flags := make_move(chess, move);
    next_fifty := 0;

    pfrom := piece_at(chess, from);
    if pfrom != Piece.W_PAWN && pfrom != Piece.B_PAWN && type==Move16.Quiet {
      next_fifty = fifty + 1;
    }

    score := -quiescene(chess, -beta, -alpha, next_fifty);
    unmake_move(chess, move, cap, flags);
    chess.en_passant = ep;
    if score > alpha then {
      hash_flag = TFLAGS.EXACT;
      best_move = move;
      alpha = score;
      pv_table[ply].argmove[0] = move;
      move_count := pv_table[ply+1].move_count;
      memcpy(*pv_table[ply].argmove[1], *pv_table[ply+1].argmove[0], move_count * size_of(Move16));
      pv_table[ply].move_count = move_count + 1;
    }

    if score >= beta then {
      hash_flag = TFLAGS.BETA;
      alpha = beta;
      break;
    }
  }

  if move_count == 0 && pos_check then {
    return -INF+ply;
  }

  tt_store(chess.hash, alpha, hash_flag, 0, best_move);
  return alpha;

  pv :: (chess: *ChessGame, body: Code, f: For_Flags) #expand {
    stage: enum {PV; CAPTURES; QUIETS; END; } = .PV;
    moves: Negamax(16); 
    moves.count = 0;
    moves.counter = get_countermove_history(chess, 1);
    moves.follow1 = get_countermove_history(chess, 2);
    moves.follow2 = get_countermove_history(chess, 4);

    unsafe: u64 = 0;
    check: u64 = 0;
    turn := chess.turn;
    while true {
      while moves.count <= 0 {
        if stage == {
        case .PV;
          stage = .CAPTURES;
          if is_legal(chess, ttmove) then {
            heap_add(*moves, ttmove, 0x7FFF_FFFF);
            moves.pv = ttmove;
          }
          if hashmove != ttmove && is_legal(chess, hashmove) then {
            heap_add(*moves, hashmove, 0x7FFF_FFFF-1);
            moves.pv = hashmove;
          }
        case .CAPTURES;
          unsafe, check = generate_attacks(chess);
          if check == 0 then {stage = .END;} else {stage = .QUIETS;}
          generate_tactics(unsafe, check, chess, *moves);
        case .QUIETS;
          stage = .END;
          generate_quiets(unsafe, check, chess, *moves);
        case .END;
          return; // terminate loop
        }
      }
      `it, `it_index := heap_pop(*moves);
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
  is_bad_capture :: (move: Move16, check: bool) -> bool #expand {
    if check == true then
      return false;

    _, from, to := decode_move16(move);
    pfrom := cast(int) piece_at(chess, from);
    pto   := cast(int) piece_at(chess, to);
    if PVALUE[pfrom] > PVALUE[pto] then {
      return see(chess, move) < 0;
    }
    return false;
  }
}

PV_Line :: struct {
  move_count: u16;
  argmove: [79] Move16;
}

operator [] :: (using p: PV_Line, index: int) -> Move16 {
  return argmove[index];
}

operator [] :: (using m: Moves, index: int) -> Move16 {
  return array[index];
}

time_begin: float64;

pv_table: [128] PV_Line;

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
      LMR := log(cast(float)i) * log(cast(float)j) * 0.5;
      LateMoveReduction[i][j] = cast (int) LMR;
    }
  }
}

// most valuable victim, least valuable attacker.
// see: https://www.chessprogramming.org/MVV-LVA
mvv_lva :: (victim: Piece, attacker: Piece) -> score: int {
  v := cast(int) victim;
  a := cast(int) attacker;
  vs := piece_score[v] - (piece_score[a]/100) + 10000;
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
__cap_history:     [13][64][7] s32;
__history_moves:   [13][64] s32;
__killer_moves:    [128][2] Move16;
__counter_history: [13][64][13][64] s32;

// get something off the ground.
TSIZE :: 0x8000;

ttable: struct {
  entries:  [TSIZE] TTEntry;

  TTEntry :: struct {
    hash: u64;
    union {
      using data: TTData;
      padding: u64;
    }
  }
}

TTData :: struct {
  flag  : TFLAGS;
  depth : u8;
  ttmove: Move16;
  score : s16;
  age   : u8;
}

search_age : u8 = 0;

TFLAGS :: enum u8 { EXACT; ALPHA; BETA; }

clear_hash_table :: () #expand {
  memset(*ttable, 0, size_of(type_of(ttable)));
}

Negamax :: struct(N: int) {
  pv      : Move16;
  hashmove: Move16;
  killer1 : Move16;
  killer2 : Move16;
  counter : *[13][64] s32;
  follow1 : *[13][64] s32;
  follow2 : *[13][64] s32;
  count   : s16;
  items   : [N] Move16;
  score   : [N] s32;
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

  // full. TODO: just for correctness
  // prevent heap from overfilling.
  // not correct at all. probably 
  // want to find minimum element
  // and get rid of the min
  if count >= items.count then
    count -= 1;

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

add_move :: (chess: *Chess, heap: *Negamax, from: int, to: int, $flags: Move16, $in_check: bool) {
  using Move16;

  move := to_move16(from, to, flags);
  // move is part of principle variation. store it.
  if move == heap.pv || move == heap.hashmove then {
    return;
  }

  score := 0;

  #if flags == Capture {
    vic := norm(piece_at(chess, to));
    att := piece_at(chess, from);
    score = mvv_lva(vic, att) + __cap_history[att][to][vic];
  }

  #if flags == Ep_Capture {
    att := piece_at(chess, from);
    score = mvv_lva(Piece.W_PAWN, Piece.W_PAWN) + __cap_history[att][to][0];
  }

  #if flags == Knight_Promotion || flags == Bishop_Promotion || flags == Rook_Promotion {
    #if heap.N == 16 then
      return;
    att := piece_at(chess, from);
    score = 8000 + __cap_history[att][to][0];
  }

  #if flags == Queen_Promotion {
    att := piece_at(chess, from);
    score = 20000 + __cap_history[att][to][0];
  }

  #if flags == Queen_Promotion_Capture {
    vic := norm(piece_at(chess, to));
    att := piece_at(chess, from);
    score = 20000 + __cap_history[att][to][vic];
  }

  #if flags == Bishop_Promotion_Capture || flags == Knight_Promotion_Capture || flags == Rook_Promotion_Capture {
    #if heap.N == 16 then 
      return;
    vic := norm(piece_at(chess, to));
    att := piece_at(chess, from);
    score = 8000 + __cap_history[att][to][vic];
  }

  #if flags == King_Castle || flags == Queen_Castle {
    #if heap.N == 16 then return;
    att := piece_at(chess, from);
    score = 19500 + __cap_history[att][to][0];
  }

  #if flags == Quiet || flags == Double_Pawn_Push {
    if move == heap.killer1 {
      return;
    } else if move == heap.killer2 {
      return;
    }

    piece := cast(int) piece_at(chess, from);
    score = __history_moves[piece][to] 
         + ((<<heap.counter)[piece][to] * 2)
         + (<<heap.follow1)[piece][to] 
         + ((<<heap.follow2)[piece][to] / 2);
  }

  norm :: (p: Piece) -> Piece #expand {
    if p >= Piece.B_KING
      p -= 7;
    return p;
  }

  heap_add(heap, move, score);
}

Moves :: struct(perft1 := false) {
  count: s32;
  #if perft1 == false {
    array: [64] Move16;
  }
}

add_move :: (chess: *Chess, moves: *Moves, from: int, to: int, $flags: Move16, $in_check: bool) {
  #if moves.perft1 == false {
    move := to_move16(from, to, flags);
    moves.array[moves.count] = move;
  }
  moves.count += 1;
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

PVALUE :: #run -> [13] s16 {
  using Piece;
  array: [13] s16;
  array[cast(int)NONE     ] = 0;
  array[cast(int)W_KING   ] = INF;
  array[cast(int)W_QUEEN  ] = 1000;
  array[cast(int)W_ROOK   ] = 500;
  array[cast(int)W_BISHOP ] = 300;
  array[cast(int)W_KNIGHT ] = 300;
  array[cast(int)W_PAWN   ] = 100;

  array[cast(int)B_KING   ] = INF;
  array[cast(int)B_QUEEN  ] = 1000;
  array[cast(int)B_ROOK   ] = 500;
  array[cast(int)B_BISHOP ] = 300;
  array[cast(int)B_KNIGHT ] = 300;
  array[cast(int)B_PAWN   ] = 100;
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
  probcut: s8 = 0;
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

check_for_repetition :: (using c: *ChessGame, fifty: int) -> ChessFlags {
  hash_val := c.hash;
  count := 0;
  repeat_count := 0;
  for < repeat: rtable {
    if hash_val == repeat then
      repeat_count += 1;

    count += 1;
    if count > fifty
      break;
  }

  if repeat_count >= 2 then
    return ChessFlags.Threefold_Repetition;
  return ChessFlags.Normal;
}

make_move :: (c: *ChessGame, move: Move16) -> Piece, Castling {
  __nodes_searched += 1;
  flags, from, to := decode_move16(move);
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
  __nodes_searched += 1;
  ep, hash := make_null_move(*c.chess);
  null_move: Move32 = Move32.{0, 0};
  array_add(*c.moves, null_move);
  array_add(*c.rtable, hash);
  memcpy(*c.nnue[c.ply+1].accumulator, *c.nnue[c.ply].accumulator, size_of(Accumulator));
  c.ply += 1;
  c.maxply = max(c.maxply, c.ply);
  return ep;
}

unmake_null_move :: (c: *ChessGame, ep: u64) {
  pop(*c.moves);
  hash := pop(*c.rtable);
  unmake_null_move(*c.chess, ep, hash);
  c.ply -= 1;
}


get_countermove_history :: (chess: *ChessGame, num: int) -> *[13][64]s32 {
  prev, to := get_prev_move(chess, 1);
  return *__counter_history[prev][to];
}



