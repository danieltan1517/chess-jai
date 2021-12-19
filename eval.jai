// for NNUE resources: https://hxim.github.io/Stockfish-Evaluation-Guide/

nnue_init :: () {
  __nnue_init(eval_file=eval_file);
}

evaluate :: (using chess: *Chess, fifty: int) -> int {
  // attempt trivial eval. else use NNUE.
  TF, score := trivial_evaluation(chess, fifty); 
  if TF return score;
  return nnue_evaluate(chess, fifty);
}

WIN_SCORE :: 200_000;

#scope_file

nnue_evaluate :: (chess: *Chess, fifty: int) -> int {
  pieces : [40] s32;
  squares: [40] s32;
  pieces[0] = xx Piece.W_KING;
  squares[0] = xx bit_scan_forward(chess.w_king);

  pieces[1] = xx Piece.W_KING;
  squares[1] = xx bit_scan_forward(chess.b_king);
  index := 2;
  piece := chess.occupied & ~(chess.w_king|chess.b_king);
  for i: 0..63 {
    bitboard := cast(u64) (1<<i);
    if bitboard & piece {
      pieces[index] = xx chess.pieces[i];
      squares[index] = xx i;
      index += 1;
    }
  }
  pieces[index] = 0;
  squares[index] = 0;
  
  eval := __nnue_evaluate(xx chess.turn, pieces.data, squares.data);
  return (eval * (100 - fifty)) / 100;
}

// We use trivial evaluation to deal with endgame positions.
trivial_evaluation :: (using chess: *Chess, fifty: int) -> bool, int {
  // used for trivial checkmates/draws.
  w_pieces := w_queen|w_rook|w_bishop|w_knight|w_pawn;
  b_pieces := b_queen|b_rook|b_bishop|b_knight|b_pawn;

  if w_pieces == 0 && b_pieces == 0 {
    return true, 0;  // K v K.
  }
  if b_pieces == 0 {

    if w_bishop|w_knight == w_pieces && popcount(w_pieces) == 1
      return true, 0;


    if w_pieces & (~(w_pawn|w_knight)) {
      side := ifx turn == Turn.WHITE then 1 else -1; 
      eval := eval_winning_position(w_king, q=w_queen, r=w_rook, b=w_bishop, n=w_knight, p=bit_reverse64(w_pawn), b_king) * side;
      return true, (eval * (100 - fifty)) / 100;
    } 
  }

  if w_pieces == 0 {
    if b_bishop|b_knight == b_pieces && popcount(b_pieces) == 1
      return true, 0;

    if b_pieces & (~(b_pawn|b_knight)) {
      side := ifx turn == Turn.WHITE then -1 else 1;
      eval := eval_winning_position(b_king, q=b_queen, r=b_rook, b=b_bishop, n=b_knight, p=b_pawn, w_king) * side;
      return true, (eval * (100 - fifty)) / 100;
    } 
  }
  return false, 0;

  eval_winning_position :: (strong_king: u64, q: u64, r: u64, b: u64, n: u64, p: u64, weak_king: u64) -> int {
    win := bit_scan_forward(strong_king);
    los := bit_scan_forward(weak_king);

    winx := win / 8;
    winy := win % 8;

    losx := los / 8;
    losy := los % 8;

    distance   := math.abs(winx - losx) + math.abs(winy - losy);
    push_close := 140 - 20 * distance;
    edge       := king_endgame[los];
    mat        := popcount(q)*90000 + popcount(r)*50000 + popcount(b)*35000 + popcount(n)*30000;
    pawn_points:= 0;
    while p {
      i := bit_scan_forward(p);
      pawn_points += eg_pawn_table[i];
      p &= p-1;
    }

    return WIN_SCORE + push_close + edge + mat + pawn_points;

    king_endgame :: int.[
      500,400,300,200,200,300,400,500,
      400,300,200,200,200,200,300,400,
      300,200,100,100,100,100,200,300,
      300,200,100,  0,  0,100,200,300,
      300,200,100,  0,  0,100,200,300,
      300,200,100,100,100,100,200,300,
      400,300,200,200,200,200,300,400,
      500,400,300,300,300,300,400,500];

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

  }
}

nnue :: #foreign_library "nnue-probe/src/libnnueprobe";

//eval_file :: #run join(#filepath, "resources/nn-fb50f1a2b1-20210705.nnue");
eval_file :: #run join(#filepath, "resources/nn-04cf2b4ed1da.nnue");
//eval_file :: #run join(#filepath, "resources/nn-eba324f53044.nnue");

__nnue_init :: (eval_file: *u8) #foreign nnue "nnue_init"; 
__nnue_evaluate :: (player: s32, pieces: *s32, squares: *s32) -> s32 #foreign nnue "nnue_evaluate";
__nnue_evaluate_fen :: (fen: *s8) -> int #foreign nnue "nnue_evaluate_fen";


/**
* NOTES:
* Evaluation subroutine suitable for chess engines.
* -------------------------------------------------
* Piece codes are
*     wking=1, wqueen=2, wrook=3, wbishop= 4, wknight= 5, wpawn= 6,
*     bking=7, bqueen=8, brook=9, bbishop=10, bknight=11, bpawn=12,
* Squares are
*     A1=0, B1=1 ... H8=63
* Input format:
*     piece[0] is white king, square[0] is its location
*     piece[1] is black king, square[1] is its location
*     ..
*     piece[x], square[x] can be in any order
*     ..
*     piece[n+1] is set to 0 to represent end of array
* Returns
*   Score relative to side to move in approximate centi-pawns

  player = white=0 black=1

  NOTE: int=s32
*/
