math :: #import "Math";
#import "Basic";

search :: (chess: *Chess, repetitions: *[..] u64, depth: int, fifty: int) -> Move16 {
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  time_begin := get_time();
  memset(pv_table.data, 0, size_of(type_of(pv_table)));
  memset(__history_moves.data, 0, size_of(type_of(__history_moves)));
  memset(__killer_moves.data,  0, size_of(type_of(__killer_moves)));
  memset(__counter_moves.data, 0, size_of(type_of(__counter_moves)));
  __nodes_searched = 0;
  ply = 0;
  clear_hash_table();
  reset_temporary_storage();
  push_allocator(temp);

  score : int; 
  best_move : Move16;
  alpha: int = -INF;
  beta:  int =  INF;
  delta: int = 50;
  cur_depth := 1;
  while cur_depth <= depth { 
    clear_hash_table();
    reset_temporary_storage();
    score = negamax(chess, cur_depth, repetitions, alpha=alpha, beta=beta, fifty=fifty, prev_move=Move16.Quiet);
    __search_counter = (__search_counter + 1) % 64;

    time_taken := get_time() - time_begin;
    if stop_signal_triggered() then 
      break;

    if score <= alpha then {
      print("info depth % lowerbound %\n", cur_depth, alpha); 
      beta = (alpha + beta) / 2;
      alpha = max(score - delta, -INF);
      delta += 2*delta + delta/2;
      continue;
    } else if score >= beta then {
      print("info depth % upperbound %\n", cur_depth, beta); 
      beta =  min(score + delta,  INF);
      delta += 2*delta + delta/2;
      continue;
    }

    alpha = score - delta;
    beta  = score + delta;
    delta = 50;
    best_move = pv_table[0][0];
    print_stats(cur_depth);
    cur_depth += 1;
  }
  return best_move;

  print_stats :: (depth: int) #expand {
    builder: String_Builder;
    t_ms := cast(int)(`time_taken*1000.0); // convert secs to ms
    nps  := cast(int)(__nodes_searched/(`time_taken+0.0001));
    print_to_builder(*builder, "info depth % ", depth);
    print_to_builder(*builder, "nodes % time % score cp % nps % pv ", __nodes_searched, t_ms, score, nps);
    count := pv_table_count[0] - 1;
    for i: 0..count {
      mv := pv_table[0][i];
      print_move_to_buffer(mv);
    }
    str := builder_to_string(*builder, allocator=__temporary_allocator);
    print("%\n", str);

    print_move_to_buffer :: (mv: Move16) #expand {
      _, from, to := decode_move(mv);
      print_to_builder(*builder, "%1%2 ", cast(serialized_bb)from, cast(serialized_bb)to);
    }
  }
}

ply := 0;
pmove: Move16;

negamax :: (chess: *Chess, depth: int, repetitions: *[..]u64, $null_flag := true, alpha := -INF, beta := INF, fifty: int, prev_move: Move16) -> int {
  pmove = prev_move;
  FULL_DEPTH_MOVES :: 4;
  REDUCTION_LIMIT  :: 3;
  if (__nodes_searched & 16384) && stdin_stop_signal()
    return 0;
  auto_release_temp();
  pv_node := alpha != beta-1;
  __nodes_searched += 1;
  //transposition_table_lookup();

  if depth <= 0 then {
    pv_table_count[ply] = 0;
    pv_table[ply][0] = 0;
    return quiescene(chess, alpha, beta, fifty);
  }

  mate_distance_pruning();
  internal_iterative_deepening();

  move_array, status := generate_moves(chess, Heap(Move16, 80));

  check_for_checkmate_stalemate();
  zugzwang := has_zugzwang(chess);
  reverse_futility_pruning();
  null_move_pruning();
  razoring();

  hash_flag := TFLAGS.ALPHA;
  for move, moves_searched : move_array {
    mflag, from, to := decode_move(move);
    cap, castling := make_move(chess, move);
    ply += 1;
    next_fifty := 0;
    if mflag == Move16.Quiet && (((cast(u64) (1 << to)) & (chess.w_pawn|chess.b_pawn)) == 0) {
      next_fifty = fifty + 1;
    }

    eval := 0;
    if moves_searched == 0 {
      eval = -negamax(chess, depth-1, repetitions, null_flag, -beta, -alpha, next_fifty, move);
    } else {
      // nega-scout
      if ply && moves_searched > FULL_DEPTH_MOVES && depth >= REDUCTION_LIMIT && status != ChessFlags.Check && mflag <= Move16.Double_Pawn_Push {
        // do late move reduction when not in check and making "quiet moves" 
        R := LateMoveReduction[min(depth,63)][min(moves_searched,63)];
        eval = -negamax(chess, depth-R-1, repetitions, null_flag, -alpha-1, -alpha, next_fifty, move);
      } else {
        // do normal search.
        eval = -negamax(chess, depth-1, repetitions, null_flag, -alpha-1, -alpha, next_fifty, move);
      }

      // re-search the move that has failed to be proved to be bad with normal alpha beta score bounds
      if eval > alpha then {
        eval = -negamax(chess, depth-1, repetitions, null_flag, -beta, -alpha, next_fifty, move);
      } 
    }
    unmake_move(chess, move, cap, castling);
    ply -= 1;

    if eval >= beta then {
      hash_flag = TFLAGS.BETA;
      alpha = beta;
      piece_type := piece_at(chess, from);
      if cap == Piece.NONE {
        __history_moves[piece_type][to] += depth*depth;
        _pm_flag, pm_from, pm_to := decode_move(prev_move);
        prev_type := piece_at(chess, to);
        __counter_moves[prev_type][pm_to] = move;
        __killer_moves[1][ply] = __killer_moves[0][ply];
        __killer_moves[0][ply] = move;
      } 
      break;
    } 

    if eval > alpha {
      hash_flag = TFLAGS.EXACT;
      alpha = eval;
      pv_table[ply][0] = move;
      memcpy(*pv_table[ply][1], *pv_table[ply+1][0], pv_table_count[ply+1] * size_of(Move16));
      pv_table_count[ply] = pv_table_count[ply+1] + 1;
    } 
  }

  //transposition_table_store();
  return alpha;

  mate_distance_pruning :: () #expand {
    // mate distance pruning
    if ply > 0 then {
      alpha = max(alpha,-INF+ply);
      beta  = min(beta,  INF-ply);
      if alpha >= beta then {
        `return alpha;
      }
    }
  }

  transposition_table_lookup :: () #expand {
    `hash := zobrist_hash(pieces, castling, ep, whose_turn);
    `key  := hash % TSIZE;
    `h_move := Move16.Quiet;
    if ttable.hash[key] == hash then {
      entry := *ttable.entries[key];
      h_move = entry.bmove;
      value := entry.score;
      flag  := entry.flag & 0x3;
      counter := cast(int) (entry.flag >> 2);
      if counter == __search_counter && ply > 0 && entry.depth >= depth {
        if flag == {
        case TFLAGS.EXACT;
        `return value;

        case TFLAGS.ALPHA;
        if value <= alpha then {
          `return value; 
        }

        case TFLAGS.BETA;
        if value >= beta then {
          `return value; 
        }

        }
      }
    }
  }

  transposition_table_store :: () #expand {
    entry := *ttable.entries[key];
    counter := cast(int) (entry.flag >> 2);
    if entry.depth == 50 && counter == __search_counter
      return;

    ttable.hash[key] = hash;
    entry.score = xx alpha;
    entry.flag = (xx (__search_counter<<2)) | hash_flag;
    entry.depth = xx depth;
    entry.bmove = h_move;
  }

  check_for_checkmate_stalemate :: () #expand {
    if status == {
    case ChessFlags.Checkmate;
      `return -INF + ply;
    case ChessFlags.Stalemate;
      `return 0 + ply;
    }

    // threefold repetition check / fifty move rule.
    if fifty >= 100 then {
      `return 0 + ply;
    }

    /*count := 0;
    reps := 0;
    while count < fifty {
      i := max(rep.count-1-count, 0);
      if (<<rep) && hash == (<<rep) [i] then {
        reps += 1;
        if reps >= 2 then {
          `return 0 + ply;
        }
      }
      count += 1;
    }*/
  }

  null_move_pruning :: () #expand {
    NULL_MOVE_MAX :: 4;
    // check for zugwang before null move pruning && TODO: make sure engine doesn't bug out at en paesant.
    if ply && null_flag && depth >= NULL_MOVE_MAX && status != ChessFlags.Check && !zugzwang {
      R := min( math.abs(static_eval - beta) / 205, 2) + depth / 3 + 3;
      make_null_move(chess);
      score := -negamax(chess, depth-R-1, repetitions, false, -beta, -beta + 1, fifty, Move16.Quiet);
      unmake_null_move(chess);
      if score >= beta then {
        `return beta;
      }
    }
  }

  // zugzwang occurs primarily in King-Pawn endgames
  // zugzwang in chess is rare otherwise.
  has_zugzwang :: (using chess: *Chess) -> bool {
    w := w_queen | w_rook | w_bishop | w_knight;
    b := b_queen | b_rook | b_bishop | b_knight;
    return w == 0 || b == 0;
  } 

  reverse_futility_pruning :: () #expand {
    // taken from BBC chess engine...
    `static_eval := evaluate(chess, fifty);
    if !zugzwang && depth < 3 && !pv_node && status != ChessFlags.Check && math.abs(beta-1) > -INF + 100 then {
      futility_margin := 214 * depth; // stockfish has its futility_margin at 214 * depth.
      if static_eval - futility_margin >= beta then {
        `return static_eval - futility_margin;
      }
    }
  }

  razoring :: () #expand {
    // taken from BBC chess engine...
    if !zugzwang && !pv_node && status != ChessFlags.Check && depth <= 3 then {
      score := static_eval + 250;
      if score < beta && depth == 1 {
        new_score := quiescene(chess, alpha, beta, fifty);
        `return ifx new_score > score then new_score else score;
      }
      score += 350;
      if score < beta && depth <= 2 {
        new_score := quiescene(chess, alpha, beta, fifty);
        if new_score < beta {
          `return ifx new_score > score then new_score else score;
        }
      }
    }
  }

  internal_iterative_deepening :: () #expand {
    if pv_node && depth >= 7 && pv_table[ply][0] == 0 { 
      for cur_depth: 1..depth-2 {
        negamax(chess, cur_depth, repetitions, alpha=alpha, beta=beta, fifty=fifty, prev_move=prev_move);
        if stop_signal_triggered() then 
          break;
      }
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
  push_allocator(temp);
  auto_release_temp();
  taken := get_time();
  if depth <= 0 then return 1;
  num_nodes := 0;
  moves := generate_moves(chess, Perft(80));
  print("moves from here: %\n", moves.count);
  for move : moves {
    cap, flags := make_move(chess, move);
    add := perft(chess, depth-1);
    type, from, to := decode_move(move);
    print("%1%2: %3 nodes\n", cast(serialized_bb)from, cast(serialized_bb)to, add);

    num_nodes = num_nodes + add;
    unmake_move(chess, move, cap, flags);
  }

  taken = get_time() - taken;
  print("Total: % nodes, Time taken: %\n", num_nodes, taken);
  return num_nodes;
}

initialize_ai_globals :: () {
  //zobrist_init_globals();
}

INF :: 0x7FF_FFFF; // Alias

#scope_file
// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (chess: *Chess, alpha: int, beta: int, fifty: int = 0) -> int {
  if (__nodes_searched & 16384) && stdin_stop_signal()
    return 0;
  auto_release_temp();
  eval := evaluate(chess, fifty);
  return eval;
  /*if eval >= beta then
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

  if alpha < eval then
    alpha = eval; 

  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  moves, status := generate_moves(chess, [..] Move16);
  capture_order(chess, move_array);
  // search captures only, captures negate the fifty move rule
  for move: moves {
    cap, flags := make_move(chess, move);
    score := -quiescene(chess, -beta, -alpha, fifty=0);
    unmake_move(chess, move, cap, flags);

    if score >= beta then
      return beta;
    if score > alpha then
      alpha = score;
  }

  return alpha;*/

  can_delta_prune :: (using chess: *Chess) -> bool #expand {
    w := w_queen | w_rook | w_bishop | w_knight;
    b := b_queen | b_rook | b_bishop | b_knight;
    return w != 0 || b != 0;
  }

  is_promoting_pawn :: inline (using chess: *Chess) -> bool {
    return ((w_pawn|b_pawn) & xx (rank_7|rank_2)) != 0;
  }
}

__search_counter := 0;

pv_table: [64][64] Move16;
pv_table_count: [64] int;

// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (chess: *Chess, depth: int) -> int {
  if depth == 0 then return 1;

  auto_release_temp();
  num_nodes := 0;
  moves := generate_moves(chess, Perft(80));
  for move : moves {
    piece, flags := make_move(chess, move);
    num_nodes = num_nodes + perft(chess, depth-1);
    unmake_move(chess, move, piece, flags);
  }
  return num_nodes;
}

capture_order :: (chess: *Chess, move_array: [..] Move16) {
  auto_release_temp();
  count := move_array.count;
  order := NewArray(count, int, allocator=__temporary_allocator);
  for i: 0..count-1 {
    flags, from, to := decode_move(move_array[i]);
    piece_type := piece_at(chess, from);
    using Move16;
    if flags == Capture {
      piece_to_type := piece_at(chess, to);
      order[i] = mvv_lva(piece_to_type, piece_type);
    } else if flags == Ep_Capture {
      order[i] = mvv_lva(Piece.W_PAWN, Piece.W_PAWN);
    } else if Knight_Promotion <= flags && flags <= Queen_Promotion_Capture {
      order[i] = mvv_lva(Piece.W_QUEEN, Piece.W_PAWN);
    }
  }
  bubble_sort(order, move_array, count);
}

bubble_sort :: (order: [] int, move_array: [] Move16, count: int) {
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

  //print("%\n", order);

  // for sorting
  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
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
__history_moves:   [13][64] int;
__killer_moves:    [2][64] Move16;
__counter_moves:   [13][64] Move16;

// get something off the ground.
TSIZE :: 0x400_000;

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
Heap :: struct(T: Type, $N: int) {
  items: [N] T;
  score: [N] int;
  count: int;
}

heap_pop :: (using heap: *$H/Heap) -> H.T, int {
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

heap_add :: (using heap: *$H/Heap, item: H.T, num: int) {
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

add_move :: (chess: *Chess, heap: *$H/Heap, from: int, to: int, $flags: Move16) {
  using Move16;

  move := to_move16(from, to, flags);
  score := 0;
  if move == pv_table[ply][0] then {
    score = INF;
    heap_add(heap, move, score);
    return;
  }

  #if flags == Capture {
    att := piece_at(chess, from);
    vic := piece_at(chess, to);
    score = mvv_lva(vic, att);
  }
  #if flags == Ep_Capture {
    score = mvv_lva(Piece.W_PAWN, Piece.W_PAWN);
  }

  #if flags == Knight_Promotion || flags == Knight_Promotion_Capture {
    score = 32500;
  }
  #if flags == Bishop_Promotion || flags == Bishop_Promotion_Capture {
    score = 35000;
  }
  #if flags == Rook_Promotion || flags == Rook_Promotion_Capture {
    score = 50000;
  }
  #if flags == Queen_Promotion || flags == Queen_Promotion_Capture {
    score = 90000;
  }

  #if flags == Quiet || flags == Double_Pawn_Push || flags == King_Castle || flags == Queen_Castle {
    if __killer_moves[0][ply] {
      score = 9500;
    } else if __killer_moves[1][ply] {
      score = 8850;
    } else {
      piece := cast(int) piece_at(chess, from);
      score = __history_moves[piece][to];
    }

    _, __, pto := decode_move(pmove);
    prev_piece := cast(int) piece_at(chess, pto);
    if move == __counter_moves[prev_piece][pto] then {
      COUNTER_BONUS :: 900;
      score += COUNTER_BONUS;
    }
  }

  heap_add(heap, move, score);
}

Perft :: struct($N: int) {
  count: int;
  array: [N] Move16;
}

for_expansion :: (using heap: *$H/Heap, code: Code, f: For_Flags) #expand {
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

add_move :: (chess: *Chess, using perft: *$P/Perft, from: int, to: int, $flags: Move16) {
  move := to_move16(from, to, flags);
  array[count] = move;
  count += 1;
}

