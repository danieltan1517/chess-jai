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
      pieces, whose_turn, castling, ep = chess_start_pos();

    } else if equal(input, "perft_all") {
      perft_all();
    } else if begins_with(input, "position ") {
      // set up the position
      setup_position(input);

    } else if begins_with(input, "go ") {

    }
  }

  setup_position :: (input: string) #expand {
    // TODO: this does not guard against incoherent IO, this is just
    // to get it working... 

    input = advance(input, 9);
    input = eat_spaces(input);
    if begins_with(input, "fen ") {
      input = advance(input, 4);
      input = eat_spaces(input);
      index, found :=  index_of_string(input, "moves");
 
      // TODO: fen parsing may not work correctly against malicious inputs
      fen_string := ifx found then slice(input, 0, index) else input;
      print("Debug: FEN=[%]\n", fen_string);
      pieces, whose_turn, castling, ep = chess_start_from_fen(fen_string);

      if found {
        input = advance(input, index);
        input = advance(input, 5);
        input = eat_spaces(input);
      } else {
        input = advance(input, input.count);
      }

    } else if begins_with(input, "startpos") {
      input = advance(input, 8);
      input = eat_spaces(input);
      pieces, whose_turn, castling, ep = chess_start_pos();
      index, found := index_of_string(input, "moves");
      if found {
        input = advance(input, index);
        input = advance(input, 5);
        input = eat_spaces(input);
      } else {
        input = advance(input, input.count);
      }
    } else {
      // we don't know what the input is, so return
      return;
    }

    // we setup the position, now just to parse the moves
    while input {
      token := parse_token(*input);
      x1 := cast(int)(token[0] - #char "a");
      x2 := cast(int)(token[1] - #char "1");
      y1 := cast(int)(token[2] - #char "a");
      y2 := cast(int)(token[3] - #char "1");
      move := Move16.Quiet;
      from : u64 = cast(u64) (1 << (x2*8 + x1));
      to   : u64 = cast(u64) (1 << (y2*8 + y1));

      print("%1%2\n", cast(bboard)from, cast(bboard)to);
    }
  }
}

#scope_file

uci_response :: #string DONE
uciok
id name Ai-Chess
id author Daniel Tan
DONE;




// TODO: does this actually do getline, or can
// it return "aaaa\nbbbb"?
getline :: () -> string {
  bytes_read := read(STDIN_FILENO, __buffer.data, __buffer.count-1);
  str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
  return str;
}

__buffer: [16384] u8;

