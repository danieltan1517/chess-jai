#import "Math";
#import "Basic";

search :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, repetitions: *[..] u64, depth: int, whose_turn: bool) -> Move16, float {
  // this is basically a fancy wrapper around negamax, negamax does all the work, this just sets everything up.
  time_begin := get_time();
  memset(__history_moves.data, 0, size_of(float)*2*64*64);
  memset(__killer_moves.data,  0, size_of(Move16)*2*64);
  __nodes_searched = 0;
  clear_hash_table();

  pv_line: PVLine;
  best_eval : float; best_move : Move16;
 
  for iter_depth : 1..depth { 
    best_eval, best_move = negamax(pieces, castling, ep, iter_depth, whose_turn, repetitions, *pv_line, 0);
    time_taken := get_time() - time_begin;
    print_stats(iter_depth);
  }
  return best_move, best_eval;

  print_stats :: (depth: int) #expand {
    Push_Temporary();
    builder: String_Builder;

    t_ms := cast(int)(`time_taken*1000.0); // convert secs to ms
    nps  := cast(int)(__nodes_searched/`time_taken);
    print_to_builder(*builder, "info depth % ", depth);
    print_to_builder(*builder, "nodes % time % score cp % nps % pv ", __nodes_searched, t_ms, best_eval, nps);
    print_move_to_buffer(best_move);
    for mv: pv_line.argmove {
      if mv == 0 then
        break;
      print_move_to_buffer(mv);
    }
    str := builder_to_string(*builder, allocator=__temporary_allocator);
    print("%\n", str);
    reset_temporary_storage();
    __nodes_searched = 0;
    memset(__killer_moves.data,  0, size_of(Move16)*2*64);
    print_move_to_buffer :: (mv: Move16) #expand {
      _, from, to := decode_move(mv);
      print_to_builder(*builder, "%1%2 ", cast(serialized_bb)from, cast(serialized_bb)to);
    }
  }
}

negamax :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, depth: int, whose_turn: bool, repetitions: *[..] u64, pv_line: *PVLine, ply: int = 0, alpha := -INF, beta := INF) -> float, Move16 {
  line: PVLine;
  __nodes_searched += 1;

  alpha_orig := alpha;

  transposition_table_lookup();

  if depth == 0 then {
    pv_line.cmove = 0;
    return quiescene(pieces, castling, ep, whose_turn, alpha, beta, __fifty), 0;
  }

  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  defer array_free(move_array);
  check := generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);

  if !move_array then {
    if check != 0 then {
      return -INF, 0;
    } else {
      return 0.0, 0;
    }
  }

  if check != 0 {
    depth += 1;  // we are in check. extend depth.
  }

  // principle variation search.
  move_ordering(pieces, move_array, whose_turn, pv_line, ply, bh_move);
  eval, bmov := -INF, move_array[0];
  for move, moves_searched : move_array {
    c_copy, ep_copy, capture := castling, ep, PieceType.None;

    before_pawn := pieces.w_pawn | pieces.b_pawn;
    make_move(pieces, *c_copy, *ep_copy, *capture, move, whose_turn);
    after_pawn := pieces.w_pawn | pieces.b_pawn;

    nm_hash : u64 = 0;
    mmflag := decode_move(move);
    if mmflag == Move16.Quiet && before_pawn == after_pawn {
      nm_hash = zobrist_hash(pieces, c_copy, ep_copy, whose_turn);
    }
    array_add(repetitions, nm_hash);

    FULL_DEPTH_MOVES :: 4;
    REDUCTION_LIMIT  :: 3;
    if moves_searched >= FULL_DEPTH_MOVES && depth >= REDUCTION_LIMIT && check == 0 && (mmflag >= Move16.Quiet && mmflag <= Move16.Queen_Castle) {
      // do late move reduction when not in check and making "quiet moves"
      eval = -negamax(pieces, c_copy, ep_copy, depth-2, !whose_turn, repetitions, *line, ply + 1, -beta, -alpha);
    } else {
      // do normal search.
      eval = -negamax(pieces, c_copy, ep_copy, depth-1, !whose_turn, repetitions, *line, ply + 1, -beta, -alpha);
    }

    unmake_move(pieces, capture, move, whose_turn);
    pop(repetitions);

    if eval > alpha {
      alpha = eval;
      bmov = move;
      bh_move = move;
      pv_line.argmove[0] = move;
      memcpy(*pv_line.argmove[1], *line.argmove[0], line.cmove * size_of(Move16));
      pv_line.cmove = line.cmove + 1;
      flags, from, to := decode_move(move);
      if !is_capture(flags) {
        __history_moves[cast(int)whose_turn][from][to] += depth*depth;
      }
    }

    if alpha >= beta then {
      m_flags := decode_move(move);
      if !is_capture(m_flags) {
        __killer_moves[1][ply] = __killer_moves[0][ply];
        __killer_moves[0][ply] = move;
      }
      break;
    }
  }

  // NOTE: do not return alpha, return eval
  transposition_table_store(eval, bh_move);
  return eval, bmov;

  transposition_table_lookup :: () #expand {
    // TODO: these can possibly be combined into one function and save some time...
    // TODO: write a better optimized version of this, this is just copy/paste from UI, and slightly
    // edited...

    count_rep : int;
    `__fifty : int;

    if repetitions.count > 0 {
      last_rep := (<<repetitions)[repetitions.count-1];
      if last_rep != 0 {
        count_rep, __fifty = check_for_repetition(<<repetitions, last_rep);
        if count_rep >= 3 || __fifty >= 100 then {
          `return 0.0, 0;  // STALEMATE
        }
      }
    }

    hash := zobrist_hash(pieces, castling, ep, whose_turn);
    key  := hash % TSIZE;
    `bh_move := ttable.entries[key].bmove;
    if ttable.hash[key] == hash && ttable.entries[key].depth >= depth then {
      if ttable.entries[key].depth >= depth then {
        value := ttable.entries[key].score;
        if ttable.entries[key].flag == TFLAGS.EXACT then {
          `return value, bh_move;
        } else if ttable.entries[key].flag == TFLAGS.LOWER then {
          alpha = max(alpha, value);
        } else if ttable.entries[key].flag == TFLAGS.UPPER then {
          beta  = min(beta, value);
        }
       
        if alpha >= beta then {
          `return value, bh_move;
        }
      }

    }
  }

  transposition_table_store :: (value: float, bmove: Move16) #expand {
    hash := zobrist_hash(pieces, castling, ep, whose_turn);
    key  := hash % TSIZE;

    ttable.hash[key] = hash;
    ttable.entries[key].score = eval;
    if value <= alpha_orig then {
      ttable.entries[key].flag = TFLAGS.UPPER;
    } else if value >= beta then {
      ttable.entries[key].flag = TFLAGS.LOWER;
    } else {
      ttable.entries[key].flag = TFLAGS.EXACT;
    }
    ttable.entries[key].depth = xx depth;
    ttable.entries[key].bmove = bmove;
  }

  check_for_repetition :: (hash_record: [] u64, hash: u64) -> int, int #expand {
    count := 0;
    fifty := 0;
    for < hash_record {
      if it == 0 break;
      if it == hash {
        count += 1;
      }
      fifty += 1;
    }
    return count, fifty;
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
  if depth <= 0 then return 1;
  num_nodes := 0;
  moves_array: [..] Move16;
  array_reserve(*moves_array, 40);
  defer { array_free(moves_array); }

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
  print("Total: % nodes\n", num_nodes);
  return num_nodes;
}

initialize_ai_globals :: () {
  zobrist_init_globals();
}

#scope_file

INF :: FLOAT32_INFINITY; // Alias

// search capture moves only, we do this to avoid horizon effect
// see: https://www.chessprogramming.org/Quiescence_Search
quiescene :: (pieces: *Piece_Bitboards, castling: Castling, ep: u64, whose_turn: bool, alpha: float, beta: float, fifty: int = 0) -> float {
  eval := nnue_evaluate(pieces, whose_turn, fifty);
  if eval >= beta then
    return beta;
  if alpha < eval then
    alpha = eval; 

  move_array: [..] Move16;
  array_reserve(*move_array, 40);
  defer array_free(move_array);
  generate_legal_moves(pieces, castling, ep, *move_array, whose_turn);
  filter_captures(move_array);
  capture_order(pieces, move_array, whose_turn);

  // search captures only, captures negate the fifty move rule
  for cap_move: move_array {
    c_copy  := castling;
    ep_copy := ep;
    capture := PieceType.None;
    flags, from, to := decode_move(cap_move);
    make_move(pieces, *c_copy, *ep_copy, *capture, cap_move, whose_turn);
    score := -quiescene(pieces, c_copy, ep_copy, !whose_turn, -beta, -alpha, 0);
    unmake_move(pieces, capture, cap_move, whose_turn);

    if score >= beta then
      return beta;
    if score > alpha then {
      alpha = score;
    }
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
  argmove: [10] Move16;  // TODO: WTF, THIS is the thing that is taking up SOO much time?!?!
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
    c_copy, ep_copy, capture := castling, ep, PieceType.None;
    make_move(p, *c_copy, *ep_copy, *capture, move, whose_turn);
    num_nodes = num_nodes + perft(p, c_copy, ep_copy, !whose_turn, depth-1);
    unmake_move(p, capture, move, whose_turn);
  }
  return num_nodes;
}

// Move Ordering currently consists of:
// MVV-LVA implementation
// Hash Move
// Principle Variation Moves
// History Moves.
// Killer moves. (Or at least what I think is the simplest implementation of killer moves)
move_ordering :: (pieces: *Piece_Bitboards, move_array: [..] Move16, whose_turn: bool, pv_line: *PVLine, ply: int, bh_move: Move16) {
  // TODO: I don't know if some other function wants to use temporary storage.
  count := move_array.count;
  order := NewArray(count, float, allocator=__temporary_allocator);
  defer reset_temporary_storage();

  pawns := ifx whose_turn pieces.w_pawn else pieces.b_pawn;
  p_attacks := ifx whose_turn then black_pawn_captures(pieces.b_pawn) else white_pawn_captures(pieces.w_pawn);

  for i: 0..count-1 {
    if move_array[i] == pv_line.argmove[0] {
      order[i] = INF;
      continue;
    } else if move_array[i] == bh_move {
      order[i] = 9.99e16;
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
      order[i] = 100000.0;
    } else if flags == King_Castle || flags == Queen_Castle {
      order[i] = 150.0;
    } else {
      if __killer_moves[0][ply] == move_array[i] {
        order[i] = 2500.0;
      } else if __killer_moves[1][ply] == move_array[i] {
        order[i] = 2250.0;
      } else if (from & ~pawns) && (to & p_attacks) {
        order[i] = -10.0;
      } else {
        order[i] = __history_moves[cast(int)whose_turn][from_index][to_index];
      }
    }
  }

  bubble_sort(order, move_array, count);
}

capture_order :: (pieces: *Piece_Bitboards, move_array: [..] Move16, whose_turn: bool) {
  // TODO: I don't know if some other function wants to use temporary storage.
  count := move_array.count;
  order := NewArray(count, float, allocator=__temporary_allocator);
  defer reset_temporary_storage();

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

bubble_sort :: (order: [] float, move_array: [] Move16, count: int) {
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
mvv_lva :: (victim: PieceType, attacker: PieceType) -> score: float {
  vs := piece_score(victim);
  as := piece_score(attacker);

  return vs + 1000.0 - (as * 0.015);

  piece_score :: (using p: PieceType) -> score: float {
    if p == {
    case King;   return 500000.0;
    case Queen;  return  90000.0;
    case Rook;   return  50000.0;
    case Bishop; return  35000.0;
    case Knight; return  32500.0;
    case Pawn;   return  10000.0;
    case;        return      0.0;
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
__history_moves: [2][64][64] float;

__killer_moves: [2][64] Move16;


// get something off the ground.
TSIZE :: 0x100_0000;

ttable : struct {
  hash:     [TSIZE] u64;
  entries:  [TSIZE] TTEntry;

  TTEntry :: struct {
    flag : TFLAGS;
    depth: s8;
    bmove: Move16;
    score: float;
  }
}

TFLAGS :: enum s8 {EXACT; LOWER; UPPER; }

clear_hash_table :: () {
  memset(*ttable, 0, size_of(type_of(ttable)));
}



