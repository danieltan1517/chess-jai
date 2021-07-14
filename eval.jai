// for NNUE resources: https://hxim.github.io/Stockfish-Evaluation-Guide/
#load "asm.jai";
#load "bitboard.jai";

nnue_init :: () {
  __nnue_init(eval_file=eval_file);
}

nnue_evaluate :: (using p: *Piece_Bitboards, whose_turn: bool) -> int {
  player := ifx (whose_turn==true) 0 else 1;
  pieces: [65] int;
  squares: [65] int;

  index := 0;
  translate_bitboard(w_king, 1);
  translate_bitboard(w_queen, 2);
  translate_bitboard(w_rook, 3);
  translate_bitboard(w_bishop, 4);
  translate_bitboard(w_knight, 5);
  translate_bitboard(w_pawn, 6);

  translate_bitboard(b_king, 7);
  translate_bitboard(b_queen, 8);
  translate_bitboard(b_rook, 9);
  translate_bitboard(b_bishop, 10);
  translate_bitboard(b_knight, 11);
  translate_bitboard(b_pawn, 12);

  print("pieces: %, squares: %\n", pieces, squares);

  return __nnue_evaluate(player, pieces.data, squares.data);

  translate_bitboard :: (bb: u64, piece_type: int) #expand {
    while bb {
      i := serialize_bit(bb);
      pieces [index] = piece_type;
      squares[index] = i;
      print("index %: %, %\n", index, pieces[index], squares[index]);
      index += 1;
      bb = bb & ( bb - 1 );//~cast(u64)(1 << i);
    }
  }
}

main :: () {
  nnue_init();

  pieces, whose_turn, castling, ep := chess_start_pos();



  eval1 := __nnue_evaluate_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
  eval2 := nnue_evaluate(*pieces, whose_turn); 
  print("% %\n", eval1, eval2);

}

#scope_file
nnue :: #foreign_library "nnue-probe/src/libnnueprobe";


eval_file :: "resources/nn-fb50f1a2b1-20210705.nnue";

/**

**/
__nnue_init :: (eval_file: *s8) #foreign nnue "nnue_init"; 

/**
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
*/

__nnue_evaluate :: (player: int, pieces: *int, squares: *int) -> int #foreign nnue "nnue_evaluate";

__nnue_evaluate_fen :: (fen: *s8) -> int #foreign nnue "nnue_evaluate_fen";

