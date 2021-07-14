// for NNUE resources: https://hxim.github.io/Stockfish-Evaluation-Guide/

nnue_init :: () {
  __nnue_init(eval_file=eval_file);
}

nnue_evaluate :: (using p: *Piece_Bitboards, whose_turn: bool) -> float {
  pieces: [65] s32;
  squares: [65] s32;

  index := 0;
  translate_bitboard(w_king, 1);
  translate_bitboard(b_king, 7);

  translate_bitboard(w_queen, 2);
  translate_bitboard(w_rook, 3);
  translate_bitboard(w_bishop, 4);
  translate_bitboard(w_knight, 5);
  translate_bitboard(w_pawn, 6);

  translate_bitboard(b_queen, 8);
  translate_bitboard(b_rook, 9);
  translate_bitboard(b_bishop, 10);
  translate_bitboard(b_knight, 11);
  translate_bitboard(b_pawn, 12);

  // sort by piece squares 
  while true {
    TF := false;
    for i: 3..index-1 {
      if squares[i-1] < squares[i]
        continue;
      swap(squares[i-1], squares[i]);
      swap(pieces[i-1], pieces[i]);
      TF = true;
    }
    if !TF break;
  }

  eval : s32 = 0;
  if whose_turn {
    eval = __nnue_evaluate(player=0, pieces.data, squares.data);
  } else {
    eval = __nnue_evaluate(player=1, pieces.data, squares.data);
  }

  return cast(float)(eval) * 0.01;

  translate_bitboard :: (bb: u64, piece_type: s32) #expand {
    while bb {
      pieces [index] = piece_type;
      squares[index] = xx serialize_bit(bb);
      index += 1;
      bb &= bb - 1;
    }
  }

  swap :: (a: Code, b: Code) #expand {
    t := (#insert a);
    (#insert a) = (#insert b);
    (#insert b) = t;
  }
}

#scope_file
nnue :: #foreign_library "nnue-probe/src/libnnueprobe";

eval_file :: "resources/nn-fb50f1a2b1-20210705.nnue";

__nnue_init :: (eval_file: *s8) #foreign nnue "nnue_init"; 
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
