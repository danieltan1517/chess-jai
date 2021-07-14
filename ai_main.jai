#import "Basic";
#import "POSIX";
#import "String";

main :: () {
  init_global_bitboards();
  nnue_init();
  pieces, whose_turn, castling, ep := chess_start_pos();

  while true {
    input := getline();
    if equal(input, "quit") {
      break;
    } else if equal(input, "uci") {
      print(uci_response);
    } else if equal(input, "isready") {
      print("readyok\n");
    } else if equal(input, "ucinewgame") {

    } else if equal(input, "perft_all") {
      perft_all();
    } else if begins_with(input, "position ") {

    }
  }
}

uci_response :: #string DONE
uciok
id name Ai-Chess
id author Daniel Tan
DONE;

#scope_file

// TODO: does this actually do getline, or can
// it return "aaaa\nbbbb"?
getline :: () -> string {
  bytes_read := read(STDIN_FILENO, __buffer.data, __buffer.count-1);
  str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
  return str;
}

__buffer: [16384] u8;

/*
    case "negamax";
      pieces := chess_start_pos();
      depth := 3;
      mov, eval := negamax(*pieces, Castling.All, 0, depth, whose_turn=true);
      type, x, y := decode_move(mov);
      print("eval=%, search depth=%\n", eval, depth);
      print("bestmove %1%2\n", cast(serialized_bb)x, cast(serialized_bb)y);

      if begins_with(input, "perft ") {
        pieces, whose_turn, castling, ep := chess_start_from_fen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");

        /*captured : PieceType;
        make_move(*pieces, *castling, *ep, *captured, encode_move_bb(xx e1, xx d1, Move16.Quiet), whose_turn); 
        whose_turn = !whose_turn;

        make_move(*pieces, *castling, *ep, *captured, encode_move_bb(xx e8, xx c8, Move16.Queen_Castle), whose_turn); 
        whose_turn = !whose_turn;*/

        depth, TF := string_to_int(advance(input, 6));
        if TF == false {
          print("Not a number. [%]\n", advance(input, 6));
          continue;
        }
        t := get_time();
        nodes := divide(*pieces, castling, ep, whose_turn, depth);
        t = get_time() - t;
        print("time taken: %\n", t);
        print("number of nodes from startpos = %, depth = %\n", nodes, depth);
      }
*/
