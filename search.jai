#import "Math";
#import "Basic";

search :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, repetitions: *[..] u64, depth: int, whose_turn: bool, fifty: int) -> Move16 {
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  time_begin := get_time();
  memset(__history_moves.data, 0, size_of(float)*2*64*64);
  memset(__killer_moves.data,  0, size_of(Move16)*2*64);
  __nodes_searched = 0;
  clear_hash_table();
  reset_temporary_storage();

  Push_Temporary();

  pv_line: PVLine;
  best_eval : int; best_move : Move16;
  for iter_depth : 1..depth { 
    best_eval = negamax(pieces, castling, ep, iter_depth, whose_turn, *pv_line, repetitions, fifty=fifty);
    if stdin_stop_signal() then
      break;
    best_move = pv_line.argmove[0];
    time_taken := get_time() - time_begin;
    print_stats(iter_depth);
  }

  return best_move;

  print_stats :: (depth: int) #expand {
    builder: String_Builder;
    t_ms := cast(int)(`time_taken*1000.0); // convert secs to ms
    nps  := cast(int)(__nodes_searched/`time_taken);
    print_to_builder(*builder, "info depth % ", depth);
    print_to_builder(*builder, "nodes % time % score cp % nps % pv ", __nodes_searched, t_ms, best_eval, nps);
    for mv: pv_line.argmove {
      if mv == 0 then
        break;
      print_move_to_buffer(mv);
    }
    str := builder_to_string(*builder, allocator=__temporary_allocator);
    print("%\n", str);
    reset_temporary_storage();
    __nodes_searched = 0;

    print_move_to_buffer :: (mv: Move16) #expand {
      _, from, to := decode_move(mv);
      print_to_builder(*builder, "%1%2 ", cast(serialized_bb)from, cast(serialized_bb)to);
    }
  }
}

negamax :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, depth: int, whose_turn: bool, pv_line: *PVLine, repetitions: *[..]u64, ply: int = 0, $null_flag := true, alpha := -INF, beta := INF, fifty: int) -> int {
  FULL_DEPTH_MOVES :: 4;
  REDUCTION_LIMIT  :: 3;
  if (__nodes_searched & 16384) && stdin_stop_signal()
    return 0;

  auto_release_temp();
  line: PVLine;

  __nodes_searched += 1;
  hash := zobrist_hash(pieces, castling, ep, whose_turn);
  key  := hash % TSIZE;

  TF, tt_score, bh_move := transposition_table_lookup(alpha, beta, hash, key, depth);
  if TF then {
    pv_line.cmove = 0;
    pv_line.argmove[0] = bh_move;
    return tt_score;
  }

  if depth <= 0 then {
    pv_line.cmove = 0;
    return quiescene(pieces, castling, ep, whose_turn, alpha, beta, fifty);
  }

  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  check := generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);
  check_for_checkmate_stalemate();
  null_move_pruning();

  //reverse_futility_pruning();
  //razoring();

  best_pv := true;
  move_ordering(pieces, move_array, whose_turn, pv_line, ply, bh_move);
  hash_flag := TFLAGS.UPPER;
  for move, moves_searched : move_array {
    c_copy, ep_copy, capture := castling, ep, PieceType.None;
    mflag, from, to := decode_move(move);


    before_pawn := pieces.w_pawn | pieces.b_pawn;
    make_move(pieces, *c_copy, *ep_copy, *capture, move, whose_turn);
    after_pawn := pieces.w_pawn | pieces.b_pawn;

    next_fifty := 0;
    if mflag == Move16.Quiet && before_pawn == after_pawn {
      next_fifty = fifty + 1;
    }

    eval := 0;
    if best_pv {
      eval = -negamax(pieces, c_copy, ep_copy, depth-1, !whose_turn, *line, repetitions, ply + 1, null_flag, -beta-1, -alpha, next_fifty);
    } else {
      // nega-scout
      if moves_searched >= FULL_DEPTH_MOVES && depth >= REDUCTION_LIMIT && check == 0 && mflag == Move16.Quiet { 
        // do late move reduction when not in check and making "quiet moves" 
        eval = -negamax(pieces, c_copy, ep_copy, depth-2, !whose_turn, *line, repetitions, ply + 1, null_flag, -alpha-1, -alpha, next_fifty);
      } else {
        // do normal search.
        eval = -negamax(pieces, c_copy, ep_copy, depth-1, !whose_turn, *line, repetitions, ply + 1, null_flag, -alpha-1, -alpha, next_fifty);
      }

      // re-search the move that has failed to be proved to be bad with normal alpha beta score bounds
      if eval > alpha && eval < beta then {
        eval = -negamax(pieces, c_copy, ep_copy, depth-1, !whose_turn, *line, repetitions, ply + 1, null_flag, -beta, -alpha, next_fifty);
      }
    }
    unmake_move(pieces, capture, move, whose_turn);

    if eval >= beta then {
      hash_flag = TFLAGS.LOWER;
      alpha = beta;
      if !is_capture(mflag) {
        __history_moves[cast(int)whose_turn][from][to] += depth*depth;
      }
      break;
    }

    if eval > alpha {
      hash_flag = TFLAGS.EXACT;
      best_pv = false;
      alpha = eval;
      pv_line.argmove[0], bh_move = move;
      memcpy(*pv_line.argmove[1], *line.argmove[0], line.cmove * size_of(Move16));
      pv_line.cmove = line.cmove + 1;
      if !is_capture(mflag) {
        __killer_moves[1][ply] = __killer_moves[0][ply];
        __killer_moves[0][ply] = move;
      }
    }
  }
  transposition_table_store(hash, key, alpha, hash_flag, depth, bh_move);
  return alpha;

  transposition_table_lookup :: (alpha: int, beta: int, hash: u64, key: u64, depth: int) -> bool, int, Move16 {
    bh_move := Move16.Quiet;
    if ttable.hash[key] == hash {
      bh_move = ttable.entries[key].bmove;
      if ttable.entries[key].depth >= depth then {
        value := ttable.entries[key].score;
        flag  := ttable.entries[key].flag;
        if flag == TFLAGS.EXACT then {
          return true, value, 0;
        } else if flag == TFLAGS.LOWER && value <= alpha then {
          return true, alpha, 0;
        } else if flag == TFLAGS.UPPER && value >= beta then {
          return true, beta, 0;
        }
      }
    }

    return false, 0, bh_move;
  }

  transposition_table_store :: (hash: u64, key: u64, value: int, hash_flag: TFLAGS, depth: int, bmove: Move16) {
    ttable.hash[key] = hash;
    ttable.entries[key].score = xx value;
    ttable.entries[key].flag = hash_flag;
    ttable.entries[key].depth = xx depth;
    ttable.entries[key].bmove = bmove;
  }

  check_for_checkmate_stalemate :: () #expand {
    if !move_array then {
      if check != 0 then {
        `return -INF + ply;
      } else {
        `return 0;
      }
    }

    if fifty >= 100 then {
      r := random_get() % move_array.count;
      pv_line.argmove[0] = move_array[r];  // TODO: I don't know picking a random move helps or not...
      `return 0;
    }

    // threefold repetition check.
    count := 0;
    reps := 0;
    while count < fifty {
      if hash == (<<repetitions) [repetitions.count - 1 - count] then {
        reps += 1;
        if reps >= 2 then {
          r := random_get() % move_array.count;
          pv_line.argmove[0] = move_array[r];  // TODO: I don't know picking a random move helps or not...
          `return 0;
        }
      }
      count += 1;
    }
    array_add(repetitions, hash);
    `defer pop(repetitions);
  }

  null_move_pruning :: () #expand {
    NULL_MOVE_MAX :: 4;
    // check for zugwang before null move pruning
    if null_flag && depth >= NULL_MOVE_MAX && check == 0 && !has_ep(pieces) && !has_zugzwang(pieces) {
      score := -negamax(pieces, castling, 0, depth-2, !whose_turn, *line, repetitions, ply+1, false, -beta, -beta + 1, fifty);
      if score >= beta then {
        `return beta;
      }
    }

    has_ep :: (using pieces: *Piece_Bitboards) -> bool #expand {
      pawn := ifx whose_turn w_pawn else b_pawn;
      return ((((ep << 1) & xx (~file_a)) | ((ep >> 1) & xx (~file_h))) & pawn) != 0;
    }

    // zugzwang occurs primarily in King-Pawn endgames
    // zugzwang in chess is rare otherwise.
    has_zugzwang :: (pieces: *Piece_Bitboards) -> bool {
      using pieces;
      w := w_queen | w_rook | w_bishop | w_knight;
      b := b_queen | b_rook | b_bishop | b_knight;
      return w == 0 || b == 0;
    } 
  }

  reverse_futility_pruning :: () #expand {
    // taken from BBC chess engine...
    `static_eval := nnue_evaluate(pieces, whose_turn, fifty);
    /*if depth < 3 && !pv_node && check == 0 && abs(beta-1) > -INF + 100 then {
      futility_margin := 500 * depth; // stockfish has its futility_margin at 214 * depth.
      if static_eval - futility_margin >= beta then {
        `return static_eval - futility_margin;
      }
    }*/
  }

  razoring :: () #expand {
    // taken from BBC chess engine...
    if !pv_node && check == 0 && depth <= 3 then {
      score := static_eval + 125;
      if score < beta && depth == 1 {
        new_score := quiescene(pieces, castling, ep, whose_turn, alpha, beta, fifty);
        `return ifx new_score > score then new_score else score;
      }
      score += 175;
      if score < beta && depth <= 2 {
        new_score := quiescene(pieces, castling, ep, whose_turn, alpha, beta, fifty);
        if new_score < beta {
          `return ifx new_score > score then new_score else score;
        }
      }
    }
  }
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
  Push_Temporary();
  auto_release_temp();
  taken := get_time();
  if depth <= 0 then return 1;
  num_nodes := 0;
  moves_array: [..] Move16;
  array_reserve(*moves_array, 40);

  generate_legal_moves(p, castling, ep, *moves_array, whose_turn);
  print("legal moves from here: %\n", moves_array.count);
  for move : moves_array {
    c_copy, ep_copy, capture := castling, ep, PieceType.None;
    make_move(p, *c_copy, *ep_copy, *capture, move, whose_turn);
    add := perft(p, c_copy, ep_copy, !whose_turn, depth-1);

    type, from, to := decode_move(move);
    print("%1%2: %3 nodes\n", cast(serialized_bb)from, cast(serialized_bb)to, add);

    num_nodes = num_nodes + add;
    unmake_move(p, capture, move, whose_turn);
  }

  taken = get_time() - taken;
  print("Total: % nodes, Time taken: %\n", num_nodes, taken);
  return num_nodes;
}

initialize_ai_globals :: () {
  zobrist_init_globals();
}

INF :: 0x7FFF_FFFF; // Alias

#scope_file
// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, alpha: int, beta: int, fifty: int = 0) -> int {
  auto_release_temp();
  eval := evaluate(pieces, whose_turn, fifty);
  if eval >= beta then
    return beta;
  if alpha < eval then
    alpha = eval; 

  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  generate_legal_moves(pieces, castling, ep, *move_array, whose_turn, captures_only=true);
  capture_order(pieces, move_array, whose_turn);

  // search captures only, captures negate the fifty move rule
  for cap_move: move_array {
    c_copy, ep_copy, capture := castling, ep, PieceType.None;
    make_move(pieces, *c_copy, *ep_copy, *capture, cap_move, whose_turn);
    score := -quiescene(pieces, c_copy, ep_copy, !whose_turn, -beta, -alpha, 0);
    unmake_move(pieces, capture, cap_move, whose_turn);

    if score >= beta then
      return beta;
    if score > alpha then
      alpha = score;
  }

  return alpha;
}

filter_captures :: (move_array: [..] Move16) {
  for mov, i: move_array {
    flags := decode_move(mov);
    if !is_capture(flags)
      remove mov;
  }
}

PVLine :: struct {
  cmove: int;
  argmove: [16] Move16;  // TODO: WTF, THIS is the thing that is taking up SOO much time?!?!
}

// performance test
// walks the move generation tree of strictly legal moves to count the leaf nodes
perft :: (p: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, depth: int) -> int {
  if depth == 0 then return 1;

  auto_release_temp();
  num_nodes := 0;
  moves_array: [..] Move16;
  array_reserve(*moves_array, 40);
  generate_legal_moves(p, castling, ep, *moves_array, whose_turn);
  for move : moves_array {
    c_copy, ep_copy, capture := castling, ep, PieceType.None;
    make_move(p, *c_copy, *ep_copy, *capture, move, whose_turn);
    num_nodes = num_nodes + perft(p, c_copy, ep_copy, !whose_turn, depth-1);
    unmake_move(p, capture, move, whose_turn);
  }
  return num_nodes;
}

move_ordering :: (pieces: *Piece_Bitboards, move_array: [..] Move16, whose_turn: bool, pv_line: *PVLine, ply: int, bh_move: Move16) {
  // TODO: I don't know if some other function wants to use temporary storage.
  auto_release_temp();
  count := move_array.count;
  order := NewArray(count, int, allocator=__temporary_allocator);

  for i: 0..count-1 {
    if move_array[i] == pv_line.argmove[0] {
      order[i] = INF;
      continue;
    } else if move_array[i] == bh_move {
      order[i] = INF - 100;
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
      EP_SCORE :: #run mvv_lva(PieceType.Queen, PieceType.Pawn);
      order[i] = EP_SCORE;
    } else if flags == Knight_Promotion || flags == Knight_Promotion_Capture {
      order[i] = 32500;
    } else if flags == Bishop_Promotion || flags == Bishop_Promotion_Capture {
      order[i] = 35000;
    } else if flags == Rook_Promotion || flags == Rook_Promotion_Capture {
      order[i] = 50000;
    } else if flags == Queen_Promotion || flags == Queen_Promotion_Capture {
      order[i] = 90000;
    } else {
      if __killer_moves[0][ply] == move_array[i] {
        order[i] = 9000;
      } else if __killer_moves[1][ply] == move_array[i] {
        order[i] = 8500;
      } else {
        order[i] = __history_moves[cast(int)whose_turn][from_index][to_index];
      }
    }
  }

  bubble_sort(order, move_array, count);
}

capture_order :: (pieces: *Piece_Bitboards, move_array: [..] Move16, whose_turn: bool) {
  // TODO: I don't know if some other function wants to use temporary storage.
  auto_release_temp();
  count := move_array.count;
  order := NewArray(count, int, allocator=__temporary_allocator);
  for i: 0..count-1 {
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
    } else if Knight_Promotion_Capture <= flags && flags <= Queen_Promotion_Capture {
      piece_to_type := piece_type_at(to, pieces, !whose_turn);
      order[i] = mvv_lva(piece_to_type, PieceType.Pawn);
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

  // for sorting
  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

// most valuable victim, least valuable attacker.
// see: https://www.chessprogramming.org/MVV-LVA
mvv_lva :: (victim: PieceType, attacker: PieceType) -> score: int {
  vs := piece_score(victim);
  as := piece_score(attacker);

  return vs + 1000 - (as / 100);

  piece_score :: (using p: PieceType) -> score: int {
    if p == {
    case King;   return 500000;
    case Queen;  return  90000;
    case Rook;   return  50000;
    case Bishop; return  35000;
    case Knight; return  32500;
    case Pawn;   return  10000;
    case;        return      0;
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


__nodes_searched := 0;
__history_moves: [2][64][64] int;
__killer_moves: [2][64] Move16;


// get something off the ground.
TSIZE :: 0x100_000;

ttable : struct {
  hash:     [TSIZE] u64;
  entries:  [TSIZE] TTEntry;

  TTEntry :: struct {
    flag : TFLAGS;
    depth: s8;
    bmove: Move16;
    score: s32;
  }
}

TFLAGS :: enum s8 { EXACT; LOWER; UPPER; }

clear_hash_table :: () {
  memset(*ttable, 0, size_of(type_of(ttable)));
}



