#import "Basic";
#import "POSIX";
#import "String";

main :: () {
  init_global_bitboards();
  while true {
    input := getline();
    if input == {
    case "quit";
      break;

    case "uci";
      print(uci_response);

    case "isready";
      print("readyok");
    case "ucinewgame";
    case "perft";
      perft_start_pos();

    case "negamax";
      pieces := chess_start_pos();
      depth := 5;
      mov, eval := negamax(*pieces, Castling.All, 0, depth, whose_turn=true);
      type, x, y := decode_move(mov);
      print("eval=%, search depth=%\n", eval, depth);
      print("bestmove %1%2\n", cast(serialized_bb)x, cast(serialized_bb)y);

    case;
      if begins_with(input, "perft ") {
        pieces, whose_turn, castling, ep := chess_start_from_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
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

__buffer: [4096] u8;


