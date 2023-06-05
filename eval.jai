// for NNUE resources: https://hxim.github.io/Stockfish-Evaluation-Guide/

uci_evaluate :: (chess: *Chess) -> int {
  pieces, squares := initialize_piece_list(chess);
  return nnue_evaluate(xx chess.turn, *pieces[0], *squares[0]);
}

evaluate :: (chess: *ChessGame, fifty: int) -> int {
  TF, score := trivial_evaluation(chess, fifty); 
  if TF return score;

  eval := nnue_evaluate(chess);
  return (eval * (100-fifty)) / 200;
} 

#scope_file
nnue_evaluate :: (chess: *ChessGame) -> int {
  pieces, squares := initialize_piece_list(chess);
  a_nnue: [3] *NNUEdata;
  a_nnue[0] = null;
  a_nnue[1] = null;
  a_nnue[2] = null;

  i := 0;
  while i<3 && chess.ply >= i {
    a_nnue[i] = chess.nnue.data + chess.ply - i;
    i += 1;
  }

  return nnue_evaluate_incremental(xx chess.turn, *pieces[0], *squares[0], *a_nnue[0]);
}

initialize_piece_list :: (chess: *Chess) -> [33] s32, [33] s32 {
  pieces : [33] s32;
  squares: [33] s32;
  pieces[0] = xx Piece.W_KING;
  squares[0] = xx bit_scan_forward(chess.w_king);
  pieces[1] = xx Piece.W_KING;
  squares[1] = xx bit_scan_forward(chess.b_king);

  index := 2;
  occupied := chess.occupied & ~(chess.w_king | chess.b_king);
  while occupied {
    sq := cast(s32) bit_scan_forward(occupied);
    piece := cast(s32) chess.pieces[sq];
    pieces[index] = piece;
    squares[index] = sq;
    index += 1;
    occupied &= occupied - 1;
  }

  pieces[index] = 0;
  squares[index] = 0;

  return pieces, squares;
}


// We use trivial evaluation to deal with endgame positions.
trivial_evaluation :: (using chess: *Chess, fifty: int) -> bool, int {

  WIN_SCORE :: 5_000;

  eval_winning_position :: (strong_king: u64, q: u64, r: u64, b: u64, n: u64, p: u64, weak_king: u64) -> int {

    push_to_edge :: (sq: int) -> int {
      r := sq / 8;
      f := sq % 8;
      fd := min(f, 7-f);
      rd := min(r, 7-r);
      return 90 - (7 * fd * fd / 2 + 7 * rd * rd / 2);
    }

    eg_pawn_table :: int.[
      0,   0,   0,   0,   0,   0,   0,   0,
    750, 750, 750, 750, 750, 750, 750, 750,
    550, 550, 550, 550, 550, 550, 550, 550,
    250, 250, 250, 250, 250, 250, 250, 250,
    150, 150, 150, 150, 150, 150, 150, 150,
     50,  50,  50,  50,  50,  50,  50,  50,
     25,  25,  25,  25,  25,  25,  25,  25,
      0,   0,   0,   0,   0,   0,   0,   0,
    ];

    win := bit_scan_forward(strong_king);
    los := bit_scan_forward(weak_king);

    winx := win / 8;
    winy := win % 8;

    losx := los / 8;
    losy := los % 8;

    distance   := abs(winx - losx) + abs(winy - losy);
    push_close := 140 - 20 * distance;
    edge       := push_to_edge(los);
    mat        := popcount(q)*900 + popcount(r)*500 + popcount(b)*350 + popcount(n)*300;
    pawn_points:= 0;
    while p {
      i := bit_scan_forward(p);
      pawn_points += eg_pawn_table[i];
      p &= p-1;
    }

    return WIN_SCORE + push_close + edge + mat + pawn_points;
  }

  // used for trivial checkmates/draws.
  w_pieces := w_queen|w_rook|w_bishop|w_knight|w_pawn;
  b_pieces := b_queen|b_rook|b_bishop|b_knight|b_pawn;
  if b_pieces == 0 {
    if w_pieces & (~(w_pawn|w_knight)) {
      side := ifx turn == Turn.WHITE then 1 else -1; 
      eval := eval_winning_position(w_king, q=w_queen, r=w_rook, b=w_bishop, n=w_knight, p=bit_reverse64(w_pawn), b_king) * side;
      return true, eval;
    } 
  }

  if w_pieces == 0 {
    if b_pieces & (~(b_pawn|b_knight)) {
      side := ifx turn == Turn.WHITE then -1 else 1;
      eval := eval_winning_position(b_king, q=b_queen, r=b_rook, b=b_bishop, n=b_knight, p=b_pawn, w_king) * side;
      return true, eval;
    } 
  }
  return false, 0;
}

#import "File";
#import "String";

