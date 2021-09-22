#import "Basic";
#import "Math";
#import "File";
#import "Render";
#import "glfw";
#import "GL";
#import "POSIX";
#import "String";

welcome_message :: #string END
Welcome to Jai Chess!!!
--------------------------------
This program implements UCI (Universal Chess Interface), so
you can try out this program with chess engines that implement
UCI, e.g. Stockfish, Lc0, RubiChess, etc.

Command-Line Arguments:
depth=x      -- sets the search depth of the engine to x
hh           -- white=human vs black=human
hc           -- white=human vs black=ai
ch           -- white=ai vs black=human
cc           -- white=ai vs black=ai
r            -- random side, human vs computer
ai=Lc0       -- sets the ai to that particular ai. Must be in the resources directory.
fen="x"      -- loads the fen string into the board.
openings_on  -- turns openings book on
openings_off -- turns opening book off

Here is a sample command-line calling:

./jai-chess hc ai=stockfish depth=7

Here are the keyboard controls:
<Ctrl+N> -- new game, reset the board.
<Ctrl+Z> -- undo move.
<X>      -- flip the board.
-------------------------------
END

fen_string := "startpos";
//"r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1";
//"8/PPPk4/8/8/8/8/4Kppp/8 b - - 0 1";

main :: () {
  white_side := true;
  engine_name := handle_command_line();

  if !glfwInit() then return;
  defer glfwTerminate();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  window := glfwCreateWindow(680, 680, "Jai Chess", null, null);
  if !window then return;
  defer glfwDestroyWindow(window);

  glfwMakeContextCurrent(window);
  gl_load(*gl, glfwGetProcAddress);
  im_init_gl();
  path := tprint("%1%2", #filepath, "resources/");
  font = load_font(path, "AnonymousPro.ttf", 17); // @@ Search system fonts automatically?

  opening_book = load_opening_book("resources/openings.txt");
  t := New(Texture);
  defer {
    destroy_texture(t);
  }
  if !load_texture_from_file(t, "resources/chess_pieces.png") {
    print("Error loading texture");
    return;
  }

  if w_is_human == false || b_is_human == false {
    ai_chess_engine_path := join(#filepath, "resources/", engine_name);
    if !uci_init_uci_chess_engine(engine_name, ai_chess_engine_path) {
      print("Error initializing UCI chess interface\n");
      return;
    }
  } else {
    print(welcome_message);
  }

  defer {
    // send quit command to the chess engine 
    // before closing the uci chess engine.
    if w_is_human == false || b_is_human == false {
      print("Application closed\n");
      uci_write_command("stop\n");
      uci_write_command("quit\n");
      uci_close_chess_engine();
    }
  }
  zobrist_init_globals();
  init_global_bitboards();
  piece_bitboard: Piece_Bitboards;
  moves_arr: [..] Move16;
  array_reserve(*moves_arr, 70);    // generates all legal moves
  array_reserve(*hash_record, 200); // records the game down. I use this struct to backtrack and undo moves
  array_reserve(*move_record, 200); // records the game down. I use this struct to backtrack and undo moves
  flags: Castling = Castling.All;
  ep_sq: u64 = 0;
  
  if equal(fen_string, "startpos") {
    piece_bitboard, whose_turn, flags, ep_sq = chess_start_pos();
  } else {
    piece_bitboard, whose_turn, flags, ep_sq = chess_start_from_fen(fen_string);
  }
  generate_legal_moves(*piece_bitboard, flags, ep_sq, *moves_arr, whose_turn);
  seed := cast(s32)(get_time() * 1.1350e14);
  random_seed(seed);

  while !glfwWindowShouldClose(window) {
    ftime := cast(float)get_time();
    read_mouse_input(window);
    width, height : s32;
    glfwGetFramebufferSize(window, *width, *height);
    glViewport(0, 0, xx width, xx height);
    glClearColor(0.15555, 0.15555, 0.15555, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    im_draw_setup_gl();
    im_set_viewport_transform(2.0/width, 2.0/height, -1, -1);
    white_side = handle_flip_board(window, white_side);
    handle_undo_move(window, *piece_bitboard, *flags, *ep_sq, *moves_arr);
    handle_reset(window, *piece_bitboard, *flags, *ep_sq, *moves_arr);

    if w_human_turn() || b_human_turn() {
      handle_board_click(xx width, xx height, *piece_bitboard, *flags, *ep_sq, *moves_arr, white_side=white_side);
    }
    draw_chess(xx width, xx height, *piece_bitboard, t, highlight_the_square, possible_moves_bb, last_move_bb, white_side);
    im_flush();

    glfwSwapBuffers(window);
    glfwPollEvents();

    reset_temporary_storage();
    if w_is_human == false || b_is_human == false {
      uci_ai_game_loop (*piece_bitboard, *flags, *ep_sq, *moves_arr);
    }
    ftime = cast(float)get_time() - ftime;
    delta_time = ftime;
  }
}

timer_on := false;
delta_time : float32 = 0.0;
openings_on := true;

handle_command_line :: () -> string #expand {
  // TODO: 
  // NOTE: this is hard-coded. It does not cover general cases
  // I'm too lazy to create a pretty UI right now, so commandline will have to do
  // this is ad-hoc, and this is mainly for slapping together something to
  // get useful functionality.
  args := get_command_line_arguments();
  engine_name : string = "lion-tulip";
  for arg : args {
    if arg == {
    case "hc";
      w_is_human = true;
      b_is_human = false;
      `white_side = true;
    case "hh";
      w_is_human = true;
      b_is_human = true;
      `white_side = true;
    case "cc";
      w_is_human = false;
      b_is_human = false;
      `white_side = true;
    case "ch";
      w_is_human = false;
      b_is_human = true;
      `white_side = false;
    case "openings_on";
      openings_on = true;
    case "openings_off";
      openings_on = false;
    case "r";
      // TODO: use rand function????
      w_is_human = xx ((cast(int)(get_time() * 130598103698.923467)) & 1);
      b_is_human = !w_is_human;
      `white_side = w_is_human;
    case;
      if begins_with(arg, "ai=") {
        cpu_string := advance(arg, 3);
        // This is not good error checking... could crash the program
        if cpu_string.count != 0 {
          engine_name = cpu_string;
        } else {
          print("Invalid ai choice\n");
        }
      } else if begins_with(arg, "depth=") {
        __engine_depth_parameter = string_to_int(advance(arg, 6));
      } else if begins_with(arg, "fen=") {
        fen := advance(arg, 4);
        fen_string = fen; // TODO: hacky way of putting fen strings into the ui, figure out a better way.
      }
    }
  }
  return engine_name;
}

__game_status_text: string;

draw_chess :: (width: float, height: float, pieces: *Piece_Bitboards, texture: *Texture, highlight_square: u64, possible_moves_bb: u64, last_move_bb: u64, white_side: bool) {
  cen_x := width * 0.5; 
  cen_y := height * 0.5;
  if timer_on == true {
    if whose_turn then {
      w_clock_time -= delta_time;
    } else {
      b_clock_time -= delta_time;
    }
  }

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x := cen_x - len*.5;
  y := cen_y - len*.5;

  white_sq_color :: Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
  black_sq_color :: Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};

  // draw text
  if font {
    bottom : string  = ifx w_is_human then "human" else get_engine_name(); // white
    top    : string  = ifx b_is_human then "human" else get_engine_name();   // black
    bot_col: Vector4 = ifx  whose_turn then BLANK else L_BLANK;
    top_col: Vector4 = ifx !whose_turn then BLANK else L_BLANK;

    bot_time := w_clock_time;
    top_time := b_clock_time;
    if !white_side {
      swap(bottom, top);
      swap(bot_col, top_col);
      swap(bot_time, top_time);
    }

    bottom_string := tprint("% %:%", bottom, formatInt(cast(int)(bot_time/60.0),      minimum_digits=2), 
                                             formatInt(cast(int)fmod(bot_time, 60.0), minimum_digits=2));
    top_string    := tprint("% %:%", top,    formatInt(cast(int)(top_time/60.0),      minimum_digits=2),
                                             formatInt(cast(int)fmod(top_time, 60.0), minimum_digits=2));


    im_draw_text(font, x, y - square_len*0.5,       bot_col, bottom_string);
    im_draw_text(font, x, y + len + square_len*0.5, top_col, top_string);
    if __game_status_text {
      im_draw_text(font, 4, 4, BLANK, __game_status_text);
    }
  }

  im_set_texture(null);
  // NOTE: chessboard squares itself is same regardless of flipping board
  TF := false; 
  for i: 0..7 {
    for j: 0..7 {
      posx := x + i*square_len;
      posy := y + j*square_len;
      if TF {
        im_draw_rect(posx, posy, posx + square_len, posy + square_len, c=white_sq_color);
      } else {
        im_draw_rect(posx, posy, posx + square_len, posy + square_len, c=black_sq_color);
      }
      TF = TF ^ true;
    }
    TF = TF ^ true;
  }

  draw_bitboard(last_move_bb, u0=0.0, v0=0.0, u1=1.0, v1=1.0, YELLOW);
  draw_bitboard(possible_moves_bb, u0=0.0, v0=0.0, u1=1.0, v1=1.0, GREY);
  if font {
    // add board labels.
    letters : string = ifx white_side "abcdefgh" else "hgfedcba";
    numbers : string = ifx white_side "12345678" else "87654321";
    TF := true;
    col := BLANK;
    for i: 0..7 {
      im_draw_text(font, x + square_len*(i+1) - 10, y + 2, col, slice(letters, i, 1));
      im_draw_text(font, x + 2, y + square_len*(i+1) - 18, col, slice(numbers, i, 1));
      TF = !TF;
      col = ifx TF white_sq_color else black_sq_color;
    }
  }
  im_set_texture(texture);

  using pieces;
  // draw the idle piece
  draw_every_piece(draw_mouse_drag=false);
  if piece_select_state == {
  case .PIECE_IDLE; #through;
  case .PIECE_SELECTED;
    // draw the piece being dragged/dropped.
    draw_every_piece(draw_mouse_drag=true);
  case .PIECE_PROMOTION;
    draw_promotion_ui(promotion_sq);
  }

  // inner functions used...
  // chess.com uses yellow, so we follow their example...
  BLANK    :: Vector4.{1,1,1,1}; 
  L_BLANK    :: Vector4.{1,1,1,0.5}; 
  GREY     :: Vector4.{.5,.5,.2,.35}; 
  YELLOW   :: Vector4.{.9,.9,0,.55};
  LESS     :: Vector4.{1.0, 1.0, 1.0, 0.25};
  RED      :: Vector4.{.9, 0.25, 0.25, 0.65};
  GREY_SHADE_BOARD :: Vector4.{0.2, 0.2, 0.2, 0.35};

  draw_every_piece :: ($draw_mouse_drag := false) #expand {
    draw_bitboard(w_king & (~promotion_sq), u0=0.0, v0=0.0, u1=1.0/6.0, v1=0.5, BLANK, draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(w_queen & (~promotion_sq), u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=1.0/2.0, BLANK, draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(w_rook & (~promotion_sq), u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=1.0/2.0, BLANK,draw_mouse_drag=draw_mouse_drag );
    draw_bitboard(w_bishop & (~promotion_sq), u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=1.0/2.0, BLANK, draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(w_knight & (~promotion_sq), u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=1.0/2.0, BLANK,draw_mouse_drag=draw_mouse_drag );
    draw_bitboard(w_pawn & (~promotion_sq), u0=5.0/6.0, v0=0.0, u1=1.0, v1=1.0/2.0, BLANK,draw_mouse_drag=draw_mouse_drag);
 
    draw_bitboard(b_king & (~promotion_sq), u0=0.0, v0=0.5, u1=1.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_queen & (~promotion_sq), u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_rook & (~promotion_sq), u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_bishop & (~promotion_sq), u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_knight & (~promotion_sq), u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_pawn & (~promotion_sq), u0=5.0/6.0, v0=0.5, u1=1.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
  }

  draw_promotion_ui :: (promote_sq: u64) #expand {
    if whose_turn {
      if promtion_type == {
      case UI_PIECE.UI_QUEEN;
        draw_bitboard(promotion_sq, u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=0.5, BLANK);
      case UI_PIECE.UI_ROOK;
        draw_bitboard(promotion_sq, u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=0.5, BLANK);
      case UI_PIECE.UI_BISHOP;
        draw_bitboard(promotion_sq, u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=0.5, BLANK);
      case UI_PIECE.UI_KNIGHT;
        draw_bitboard(promotion_sq, u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=0.5, BLANK);
      }
    } else {
      if promtion_type == {
      case UI_PIECE.UI_QUEEN;
        draw_bitboard(promotion_sq, u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0, BLANK);
      case UI_PIECE.UI_ROOK;
        draw_bitboard(promotion_sq, u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0, BLANK);
      case UI_PIECE.UI_BISHOP;
        draw_bitboard(promotion_sq, u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0, BLANK);
      case UI_PIECE.UI_KNIGHT;
        draw_bitboard(promotion_sq, u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0, BLANK);
      }
    }

    // need to be done.
    im_set_texture(null);
    im_draw_rect(x, y, x + len, y + len, c=GREY_SHADE_BOARD);
    index := bit_scan_forward(promote_sq);
    i, j := 0;
    if white_side {
      i, j = index &  7, index >> 3;
    } else {
      i, j = 7 - index &  7, 7 - index >> 3;
    }
    posx := x + square_len*0.5 + i*square_len;
    posy := y + square_len*0.5 + j*square_len;
    scale_up_sq_len := square_len*1.15;

    if (white_side && (promote_sq & xx king_side)) || (!white_side && (promote_sq & xx queen_side)) {
      posx = posx - scale_up_sq_len*4;
    }
    PROMOTION_BACKGROUND :: Vector4.{1.0, 1.0, 1.0, 0.85};
    im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len*4, posy, c=PROMOTION_BACKGROUND);
    im_set_texture(texture);
    if whose_turn {
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=0.5, c=BLANK);
      posx += scale_up_sq_len;
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=0.5, c=BLANK);
      posx += scale_up_sq_len;
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=0.5, c=BLANK);
      posx += scale_up_sq_len;
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=0.5, c=BLANK);
    } else {
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0, c=BLANK);
      posx += scale_up_sq_len;
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0, c=BLANK);
      posx += scale_up_sq_len;
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0, c=BLANK);
      posx += scale_up_sq_len;
      im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len, posy, u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0, c=BLANK);
    }
  }

  draw_bitboard :: (bit_board: u64, $u0: float, $v0: float, $u1: float, $v1: float, $c: Vector4, $draw_mouse_drag := false) #expand {
    value: u64 = 0;
    #if !draw_mouse_drag 
      value = bit_board & (~highlight_square);
    else 
      value = bit_board & highlight_square;

    while value {
      index := bit_scan_forward(value);
      i, j := 0;
      if white_side {
        i = index &  7;
        j = index >> 3;
      } else {
        i = 7 - index &  7;
        j = 7 - index >> 3;
      }

      #if draw_mouse_drag {
        if mouse_button_1_state == .MOUSE_HOLD {
          posx := x + i*square_len;
          posy := y + j*square_len;
          im_draw_rect(posx, posy + square_len, posx + square_len, posy, u0=u0, v0=v0, u1=u1, v1=v1, c=LESS);
          posx = mouse_position_x - square_len*0.5;   
          posy = height - mouse_position_y - square_len*0.5;   
          im_draw_rect(posx, posy + square_len, posx + square_len, posy, u0=u0, v0=v0, u1=u1, v1=v1, c=c);
        } else {
          posx := x + i*square_len;
          posy := y + j*square_len;
          im_draw_rect(posx, posy + square_len, posx + square_len, posy, u0=u0, v0=v0, u1=u1, v1=v1, c=c);
        }
      } else {
        posx := x + i*square_len;
        posy := y + j*square_len;
        im_draw_rect(posx, posy + square_len, posx + square_len, posy, u0=u0, v0=v0, u1=u1, v1=v1, c=c);
      }
      value &= (value - 1);
    }
  }
}

mouse_position_x:     float = 0.0;
mouse_position_y:     float = 0.0;
mouse_button_1_state: enum {MOUSE_IDLE; MOUSE_PRESSED; MOUSE_HOLD; MOUSE_RELEASE; } = .MOUSE_IDLE;

read_mouse_input :: (window: *GLFWwindow) {
  x: float64;
  y: float64;
  glfwGetCursorPos(window, *x, *y);
  mouse_position_x = xx x;
  mouse_position_y = xx y;
  release := glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_1);
  handle_mouse_button_state(release);

  handle_mouse_button_state :: (release: s32) {
    if #complete mouse_button_1_state == {
    case .MOUSE_IDLE;
      if release == GLFW_PRESS then {
        mouse_button_1_state = .MOUSE_PRESSED;
      }
    case .MOUSE_PRESSED;
      if release == GLFW_PRESS then {
        mouse_button_1_state = .MOUSE_HOLD;
      } else if release == GLFW_RELEASE {
        mouse_button_1_state = .MOUSE_RELEASE;
      }
    case .MOUSE_HOLD;
      if release == GLFW_RELEASE then {
        mouse_button_1_state = .MOUSE_RELEASE;
      }
    case .MOUSE_RELEASE;
      mouse_button_1_state = .MOUSE_IDLE;
    }
  }
}

handle_board_click :: (width: float, height: float, piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..] Move16, white_side := true) {
  cen_x := width * 0.5; 
  cen_y := height * 0.5;

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x0 := cen_x - len*.5;
  y0 := cen_y - len*.5;
  x1 := cen_x + len*.5;
  y1 := cen_y + len*.5;
  wants_to_promote : bool = false;
  sq: u64 = 0;
  if piece_select_state == {
  case .PIECE_IDLE; #through;
  case .PIECE_SELECTED;
    promotion_sq = 0; // paranoid, make sure the promotion_sq is 0.
    if mouse_button_1_state == .MOUSE_PRESSED || mouse_button_1_state == .MOUSE_RELEASE {
      if x0 <= mouse_position_x && mouse_position_x <= x1 {
        if y0 <= mouse_position_y && mouse_position_y <= y1 {
          if white_side {
            sq_x_clicked: int = xx ((mouse_position_x - x0) / square_len);
            sq_y_clicked: int = 7 - xx ((mouse_position_y - y0) / square_len);
            i := sq_x_clicked + sq_y_clicked * 8;
            sq = xx (1 << i);
          } else {
            sq_x_clicked: int = 7 - xx ((mouse_position_x - x0) / square_len);
            sq_y_clicked: int = xx ((mouse_position_y - y0) / square_len);
            i := sq_x_clicked + sq_y_clicked * 8;
            sq = xx (1 << i);
          }
        }
      }
    }
    // only deal with things that output a 'sq', when 0, return
    if sq == 0 then return;
  case .PIECE_PROMOTION;
    wants_to_promote = mouse_button_1_state == .MOUSE_PRESSED;
    x := cen_x - len*.5;
    y := cen_y - len*.5;
    index := bit_scan_forward(promotion_sq);
    i, j := 0;
    if white_side {
      i, j = index &  7, index >> 3;
    } else {
      i, j = 7 - index &  7, 7 - index >> 3;
    }
    posx := x + square_len*0.5 + i*square_len;
    posy := len - (y + square_len*0.5 + j*square_len);
    scale_up_sq_len := square_len*1.15;

    if (white_side && (promotion_sq & xx king_side)) || (!white_side && (promotion_sq & xx queen_side)) {
      posx = posx - scale_up_sq_len*4;
    }
      number := 0;
      posy += square_len;
      while number < 4 {
        if posx <= mouse_position_x && mouse_position_x <= (posx + scale_up_sq_len) {
          if posy <= mouse_position_y && mouse_position_y <= (posy + scale_up_sq_len) {
            if number == {
            case 0;
              promtion_type = UI_PIECE.UI_QUEEN;
            case 1;
              promtion_type = UI_PIECE.UI_ROOK;
            case 2;
              promtion_type = UI_PIECE.UI_BISHOP;
            case 3;
              promtion_type = UI_PIECE.UI_KNIGHT;
            }
          }
        }
        posx += scale_up_sq_len;
        number += 1;
      }
  }
  // piece selection state machine.
  if piece_select_state == {
  case .PIECE_IDLE;
    if can_move(piece_bitboard, sq, whose_turn) && mouse_button_1_state == .MOUSE_PRESSED {
      highlight_the_square ^= xx sq;
      piece_select_state = .PIECE_SELECTED;
      possible_moves_bb = possible_moves_for(<<moves_arr, sq);
    }
  case .PIECE_SELECTED;
    if highlight_the_square == sq && mouse_button_1_state == .MOUSE_PRESSED {
      highlight_the_square = 0;
      piece_select_state = .PIECE_IDLE;
      possible_moves_bb = 0;
    } else if can_move(piece_bitboard, sq, whose_turn) && mouse_button_1_state == .MOUSE_PRESSED {
      highlight_the_square = xx sq;
      possible_moves_bb = possible_moves_for(<<moves_arr, sq);
    } else if !can_move(piece_bitboard, sq, whose_turn) {
      // make move
      from := highlight_the_square;
      to   := sq;
      if to & possible_moves_bb {
        mov := find_move(<<moves_arr, from, to);
        if move_is_promotion(mov) {
          // bring up promotion interface.
          piece_select_state = .PIECE_PROMOTION;
          promotion_sq = to;
          promote_move = mov;
        } else {
          last_move_bb = from | to;
          ui_handle_move_made(piece_bitboard, flags, ep_sq, moves_arr, mov);
          piece_select_state = .PIECE_IDLE;
        }
      } else {
        // let go of the piece without making a valid move.
        piece_select_state = .PIECE_IDLE;
        highlight_the_square = 0;
        possible_moves_bb = 0;
      }
    }
  case .PIECE_PROMOTION;
    if wants_to_promote {
      type, from_i, to_i := decode_move(promote_move);
      from := cast(u64) (1 << from_i);
      to   := cast(u64) (1 << to_i);
      mov: Move16;
      if Move16.Knight_Promotion <= type && type <= Move16.Queen_Promotion {
        if promtion_type == {
        case UI_PIECE.UI_QUEEN;
          mov = encode_move_bb(from, to, Move16.Queen_Promotion);
        case UI_PIECE.UI_ROOK;
          mov = encode_move_bb(from, to, Move16.Rook_Promotion);
        case UI_PIECE.UI_BISHOP;
          mov = encode_move_bb(from, to, Move16.Bishop_Promotion);
        case UI_PIECE.UI_KNIGHT;
          mov = encode_move_bb(from, to, Move16.Knight_Promotion); 
        }
      } else {
        if promtion_type == {
        case UI_PIECE.UI_QUEEN;
          mov = encode_move_bb(from, to, Move16.Queen_Promotion_Capture);
        case UI_PIECE.UI_ROOK;
          mov = encode_move_bb(from, to, Move16.Rook_Promotion_Capture);
        case UI_PIECE.UI_BISHOP;
          mov = encode_move_bb(from, to, Move16.Bishop_Promotion_Capture);
        case UI_PIECE.UI_KNIGHT;
          mov = encode_move_bb(from, to, Move16.Knight_Promotion_Capture); 
        }
      }

      last_move_bb = from | to;
      ui_handle_move_made(piece_bitboard, flags, ep_sq, moves_arr, mov);
      piece_select_state = .PIECE_IDLE;
    }
  }
}

x_key_state: enum { XKEY_IDLE; XKEY_PRESS; } = .XKEY_IDLE;

handle_flip_board :: (window: *GLFWwindow, white_side: bool)->bool {
  state := glfwGetKey(window, GLFW_KEY_X);
  if x_key_state == {
  case .XKEY_IDLE;
    if state == GLFW_PRESS {
      x_key_state = .XKEY_PRESS;
      white_side = !white_side;
    }
  case .XKEY_PRESS;
    if state == GLFW_RELEASE {
      x_key_state = .XKEY_IDLE;
    }
  }
  return white_side;
}

undo_key_state: enum {UNDO_KEY_IDLE; UNDO_KEY_PRESS; } = .UNDO_KEY_IDLE;

handle_undo_move :: (window: *GLFWwindow, piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..] Move16) {
  if w_is_human == false && b_is_human == false then
    return; // disable undo for AI vs AI.
  if piece_select_state != .PIECE_IDLE then
    return;

  z_state    := glfwGetKey(window, GLFW_KEY_Z);
  l_ctrl_key := glfwGetKey(window, GLFW_KEY_LEFT_CONTROL);
  r_ctrl_key := glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL);
  if undo_key_state == {
  case .UNDO_KEY_IDLE;
    if z_state == GLFW_PRESS && (l_ctrl_key == GLFW_PRESS || r_ctrl_key == GLFW_PRESS) {
      undo_key_state = .UNDO_KEY_PRESS;
      if move_record {
        board_state := pop(*move_record);
        // NOTE: need to flip whose_turn BEFORE generate_legal_moves, else we would get the opposite side's moves
        // by accident. We also need to copy the flags from the board_state BEFORE generate_legal_moves!
        <<ep_sq = board_state.en_paesant_sq;
        <<flags = board_state.flags;
        whose_turn = !whose_turn;
        unmake_move(piece_bitboard, board_state.captured, board_state.move, whose_turn);
        pop(*hash_record);
        
        while move_record && !w_human_turn() && !b_human_turn() {
          board_state := pop(*move_record);
          <<ep_sq = board_state.en_paesant_sq;
          <<flags = board_state.flags;
          whose_turn = !whose_turn;
          unmake_move(piece_bitboard, board_state.captured, board_state.move, whose_turn);
          pop(*hash_record);
        }

        array_reset(moves_arr);
        check_bb = generate_legal_moves(piece_bitboard, <<flags, <<ep_sq, moves_arr, whose_turn);

        highlight_the_square = 0;
        possible_moves_bb = 0;
        promote_move = cast(Move16) 0;
        if move_record {
          last_board_state := move_record[move_record.count - 1];
          type, x, y := decode_move(last_board_state.move);
          last_move_bb = (cast(u64)(1 << x)) | (cast(u64)(1 << y));
        } else {
          last_move_bb = 0;
        }
        if check_bb != 0 {
          __game_status_text = "Check.";
        } else {
          __game_status_text = "";
         
          TF, opening_name := get_opening_name(move_record, opening_book);
          // TODO: Optimize this. 
          if TF then {
            __game_status_text = opening_name;
          }
        }
      }
    }
  case .UNDO_KEY_PRESS;
    if z_state == GLFW_RELEASE || (l_ctrl_key == GLFW_RELEASE && r_ctrl_key == GLFW_RELEASE) {
      undo_key_state = .UNDO_KEY_IDLE;
    }
  }
}

reset_key_state: enum { RESET_IDLE; RESET_PRESS; } = .RESET_IDLE;

handle_reset :: (window: *GLFWwindow, piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..] Move16) {
  if piece_select_state != .PIECE_IDLE then
    return;
  n_state    := glfwGetKey(window, GLFW_KEY_N);
  l_ctrl_key := glfwGetKey(window, GLFW_KEY_LEFT_CONTROL);
  r_ctrl_key := glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL);
  if reset_key_state == {

  case .RESET_IDLE;
    if n_state == GLFW_PRESS && (l_ctrl_key == GLFW_PRESS || r_ctrl_key == GLFW_PRESS) {
      reset_key_state = .RESET_PRESS;
      timer_on = false;
      while move_record {
        board_state := pop(*move_record);
        <<ep_sq = board_state.en_paesant_sq;
        <<flags = board_state.flags;
        whose_turn = !whose_turn;
        unmake_move(piece_bitboard, board_state.captured, board_state.move, whose_turn);
        pop(*hash_record);
      }

      array_reset(moves_arr);
      check_bb = generate_legal_moves(piece_bitboard, <<flags, <<ep_sq, moves_arr, whose_turn);

      highlight_the_square = 0;
      possible_moves_bb = 0;
      promote_move = cast(Move16) 0;
      if move_record {
        last_board_state := move_record[move_record.count - 1];
        type, x, y := decode_move(last_board_state.move);
        last_move_bb = (cast(u64)(1 << x)) | (cast(u64)(1 << y));
      } else {
        last_move_bb = 0;
      }
      __game_status_text = "";
      w_clock_time = 30.0*60.0;
      b_clock_time = 30.0*60.0;
      uci_state = .UCI_NEWGAME;
    }
  case .RESET_PRESS;
    if n_state == GLFW_RELEASE || (l_ctrl_key == GLFW_RELEASE && r_ctrl_key == GLFW_RELEASE) {
      reset_key_state = .RESET_IDLE;
    }
  }
}

ui_handle_move_made :: (piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..] Move16, mov: Move16) {
  before_pawn := piece_bitboard.w_pawn | piece_bitboard.b_pawn;
  timer_on = true;
  // record the move down 
  record_move: Board_States;
  record_move.move = mov;
  record_move.flags = << (flags);
  record_move.en_paesant_sq = << (ep_sq);
  record_move.captured = PieceType.None;
  make_move(piece_bitboard, flags, ep_sq, *record_move.captured, mov, whose_turn);
  array_add(*move_record, record_move);
  whose_turn = !whose_turn;
  array_reset(moves_arr);
  check_bb = generate_legal_moves(piece_bitboard, <<flags, <<ep_sq, moves_arr, whose_turn);
  after_pawn := piece_bitboard.w_pawn | piece_bitboard.b_pawn;

  // zero if there has been a capture, or a pawn has moved.
  // else we hash.
  hash : u64 = 0;
  f := decode_move(mov);
  if f == Move16.Quiet && before_pawn == after_pawn {
    hash = zobrist_hash(piece_bitboard, <<flags, <<ep_sq, whose_turn);
  }

  array_add(*hash_record, hash);
  if moves_arr.count == 0 {
    if check_bb != 0 {
      __game_status_text = "Checkmate.";
      timer_on = false;
    } else {
      __game_status_text = "Stalemate.";
      timer_on = false;
    }
  } else if hash != 0 && check_for_repetition(hash_record, hash) {
    __game_status_text = "Stalemate by threefold repetition.";
    array_reset(moves_arr);
    timer_on = false;
  } else if check_bb != 0 {
    __game_status_text = "Check.";
  } else {
    __game_status_text = "";

    TF, opening_name := get_opening_name(move_record, opening_book);
    // TODO: Optimize this. 
    if TF then {
      __game_status_text = opening_name;
    }
  }

  highlight_the_square = 0;
  possible_moves_bb = 0;
  promote_move = cast(Move16) 0;

  check_for_repetition :: (hash_record: [] u64, hash: u64) -> bool #expand {
    count := 0;
    fifty := 0;
    for < hash_record {
      if it == 0 break;
      if it == hash {
        count += 1;
      }
      fifty += 1;
    }
    return count >= 3 || fifty >= 100;
  }

}

last_move_bb: u64 = 0;
whose_turn := true;  // whose_turn=true=white, whose_turn=false=black.
promotion_sq : u64 = 0;
highlight_the_square: u64 = 0;
piece_select_state: enum { PIECE_IDLE; PIECE_SELECTED; PIECE_PROMOTION; } = .PIECE_IDLE;
possible_moves_bb: u64 = 0;
check_bb : u64 = 0;
w_is_human : bool = true;
b_is_human : bool = true;

w_clock_time : float = 30*60;
b_clock_time : float = 30*60;

w_human_turn :: () => (w_is_human && whose_turn);
b_human_turn :: () => (b_is_human && !whose_turn);

UI_PIECE :: enum {
  UI_QUEEN;
  UI_ROOK;
  UI_BISHOP;
  UI_KNIGHT;
}

promtion_type := UI_PIECE.UI_QUEEN;
promote_move : Move16;

hash_record: [..] u64;
move_record: [..] Board_States;

Board_States :: struct {
  move: Move16;
  flags: Castling;
  en_paesant_sq: u64;
  captured: PieceType;
}

uci_position_command :: () -> string {
  builder: String_Builder;
  builder.allocator = __temporary_allocator;
  if equal(fen_string, "startpos") {
    print_to_builder(*builder, "position % moves", fen_string);
  } else {
    print_to_builder(*builder, "position fen % moves", fen_string);
  }

  for move: move_record {
    type, from, to := decode_move(move.move);
    if move_is_promotion(type) {
      //character
      c := get_promotion_character(type);
      print_to_builder(*builder, " %1%2", cast(serialized_bb) from, cast(serialized_bb) to);
      append(*builder, c);
    } else {
      print_to_builder(*builder, " %1%2", cast(serialized_bb) from, cast(serialized_bb) to);
    }
  }
  print_to_builder(*builder, "\n");
  str := builder_to_string(*builder, allocator=__temporary_allocator);
  return str;

  get_promotion_character :: (using type: Move16) -> u8 {
    if type == {
    case Knight_Promotion_Capture; #through;
    case Knight_Promotion;
      return #char "n";
    case Bishop_Promotion; #through;
    case Bishop_Promotion_Capture;
      return #char "b";
    case Rook_Promotion; #through;
    case Rook_Promotion_Capture;
      return #char "r";
    case Queen_Promotion; #through;
    case Queen_Promotion_Capture;
      return #char "q";
    case;
      return 0;
    } 
  }
}

uci_state : enum { 
  UCI_INIT; 
  UCI_UCIOK; 
  UCI_ISREADY; 
  UCI_NEWGAME; 
  UCI_IDLE;
  UCI_POS_CMD;
  UCI_GO_TURN;
  UCI_BUG;
} = .UCI_INIT;

uci_ai_game_loop :: (piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..]Move16) {
  if uci_state == {
  case .UCI_INIT;
    uci_write_command("uci\n");
    uci_state = .UCI_UCIOK;
  case .UCI_UCIOK;
    while true {
      cmd_string := uci_getline();
      if !cmd_string break;
      if equal(cmd_string, "uciok") {
        uci_state = .UCI_ISREADY;
      }
    }
  case .UCI_ISREADY;
    uci_write_command("isready\n");
    while true {
      cmd_string := uci_getline();
      if !cmd_string break;
      if equal(cmd_string, "readyok") {
        uci_state = .UCI_NEWGAME;
      } 
    }
  case .UCI_NEWGAME;
    uci_write_command("ucinewgame\n");
    uci_state = .UCI_IDLE;
  case .UCI_IDLE;
    uci_getline(); // getline and throw away input.
    reset_queue(); 


    // make sure there are moves that could be made.
    if moves_arr.count > 0 && !w_human_turn() && !b_human_turn() {
      
      if reset_key_state == .RESET_PRESS then {
        uci_state = .UCI_NEWGAME;
      } else if openings_on == true && equal(fen_string, "startpos") && (cast(int)(random_get()) % 100) < 90 {
        cmd_str := uci_position_command();
        uci_write_command(cmd_str);
        TF, mov := pick_random_opening(move_record, opening_book);
        if TF && mov != 0 {
          ui_handle_move_made(piece_bitboard, flags, ep_sq, moves_arr, mov);
          f, fbb, tbb := decode_move(mov);
          from := cast(u64)(1 << fbb);
          to   := cast(u64)(1 << tbb);
          last_move_bb = from|to;
        } else {
          cmd_str := uci_position_command();
          uci_write_command(cmd_str);
          uci_state = .UCI_POS_CMD;
        }
      } else {
        cmd_str := uci_position_command();
        uci_write_command(cmd_str);
        uci_state = .UCI_POS_CMD;
      }
    }

  case .UCI_POS_CMD;
    if reset_key_state == .RESET_PRESS {
      uci_state = .UCI_NEWGAME;
    } else {
      cmd_string := tprint("go depth %\n", __engine_depth_parameter);
      uci_write_command(cmd_string);
      uci_state = .UCI_GO_TURN;
      timeout_timer = 0.0;
    }

  case .UCI_GO_TURN;
    TIMEOUT_LIMIT :: 10.0;
    timeout_timer += delta_time;
    if reset_key_state == .RESET_PRESS {
      uci_write_command("stop\n");
      timeout_timer = 0.0;
      uci_state = .UCI_NEWGAME;
    } else if timeout_timer >= TIMEOUT_LIMIT {
      uci_write_command("stop\n");
      print("timeout!\n");
      timeout_timer = 0.0;
    } 
    while true {
      cmd_string := uci_getline();
      if !cmd_string break;
      if reset_key_state == .RESET_PRESS {
        reset_queue();
        continue;
      }

      if starts_with(cmd_string, "bestmove ") {
        TF, from, to, type := parse_best_move(cmd_string);
        // TODO: parse best move could fail, what to do if that happens????
        assert(TF);
        actual_move := find_move(<<moves_arr, from, to, type);
        if actual_move {
          ui_handle_move_made(piece_bitboard, flags, ep_sq, moves_arr, actual_move);
          last_move_bb = from|to;
          uci_state = .UCI_IDLE;
        } else {
          print("There is a bug.\n");
          uci_state = .UCI_BUG;
        }
      }
    }
  case .UCI_BUG;

  }

  parse_best_move :: (best_move_string: string) -> TF: bool, from: u64, to: u64, type: Move16 {
    parse_token(*best_move_string);
    move_sq_string := parse_token(*best_move_string);
    if move_sq_string.count < 4 {
      return false, 0, 0, Move16.Quiet;
    }

    // move string is like "a8h8q" or "d2d4". 
    a := cast(int)(move_sq_string[0] - #char "a");
    b := cast(int)(move_sq_string[1] - #char "1");
    c := cast(int)(move_sq_string[2] - #char "a");
    d := cast(int)(move_sq_string[3] - #char "1");
    move := Move16.Quiet;
    from : u64 = cast(u64) (1 << (b*8 + a));
    to   : u64 = cast(u64) (1 << (d*8 + c));
    // if move is a promotion
    if move_sq_string.count >= 5 && move_sq_string[4] != #char " " {
      character := to_lower(move_sq_string[4]);
      if character == #char "q" {
        move = Move16.Queen_Promotion;
      } else if character == #char "r" {
        move = Move16.Rook_Promotion;
      } else if character == #char "b" {
        move = Move16.Bishop_Promotion;
      } else if character == #char "n" {
        move = Move16.Knight_Promotion;
      }
    }

    return true, from, to, move;
  }
}

timeout_timer := 0.0;

#scope_file
__engine_pid := 0;
// Universal Chess Interface Protocol

uci_init_uci_chess_engine :: (engine_name: string, ai_path: string) -> bool {
  // I wish there was a high-level library for this in Jai,
  // but the #import "Process"; doesn't do what I want... <sigh>
  pipe_1: [2] s32;
  pipe_2: [2] s32;

  if pipe(*pipe_1) == -1 {
    print("Error creating pipe.\n");
    return false;
  }
  if pipe(*pipe_2) == -1 {
    print("Error creating pipe.\n");
    return false;
  }

  child_pid := fork();
  if child_pid == -1 {
    print("Error in fork.\n");
    return false;
  }

  if child_pid == 0 {
    // child process
    close(pipe_2[1]);
    close(pipe_1[0]);
    w := pipe_1[1];
    r := pipe_2[0];
    if dup2(w, STDOUT_FILENO) < 0 {
      print("Error in child stdout.\n");
      exit(-1);
    }

    // child input/output redirection: 
    if dup2(r, STDIN_FILENO) < 0 {
      print("Error in child stdin.\n");
      exit(-1);
    }

    args: [2] *u8;
    args[0] = to_c_string(ai_path);
    args[1] = null;
    execvp(args[0], args.data);
    exit(-1);
    return false;  // to shut the compiler up.
  } else {
    // parent process
    __engine_pid = child_pid;
    close(pipe_1[1]);
    close(pipe_2[0]);
    __write_pipe = pipe_2[1];
    __read_pipe  = pipe_1[0];
    setup_pipe_nonblock(__read_pipe);

    __engine_name = engine_name;
    return true; 
  }

  setup_pipe_nonblock :: (pipe: s32) #expand {
    flags := fcntl(pipe, F_GETFL, 0) | O_NONBLOCK;
    fcntl(pipe, F_SETFL, flags);
  }
}

uci_write_command :: (command: string) {
  write(__write_pipe, command.data, xx command.count);
}

swap :: (a: Code, b: Code) #expand {
  t := (#insert a);
  (#insert a) = (#insert b);
  (#insert b) = t;
}

__stop_signal := false;
__buffer: [16384] u8;
__array: [100] string;
__mark  := 0;
__count := 0;

enqueue :: (s: string) #expand {
  __array[__count] = s;
  __count += 1;
}

dequeue :: () -> string #expand {
  assert(__mark <= __count, "Error.\n");
  s := __array[__mark];
  __mark += 1;
  return s;
}

has_elements_to_dequeue :: () -> bool #expand {
  return __mark < __count;
}

reset_queue :: () #expand {
  __mark  = 0;
  __count = 0;
}

uci_getline :: () -> string {
  // TODO: create a queue. then pop from the queue. this way of doing it is unreliable
  // for "stop".
  if has_elements_to_dequeue() {
    s := dequeue();
    print("Engine [%]: %\n", __engine_name, s);
    return s; 
  }
  bytes_read := read(__read_pipe, __buffer.data, __buffer.count-1);
  if bytes_read <= 0
    return "";

  reset_queue();
  str := to_string(__buffer.data, bytes_read-1); // -1 the '\n' char
  for line: split(str, "\n") {
    enqueue(line);
  }

  s := dequeue();
  print("Engine [%]: %\n", __engine_name, s);
  return s;
}

uci_close_chess_engine :: () {
  // NOTE: this function does NOT call "uci_write_command("quit")",
  // that needs to be called explicitly
  value: s32;
  wait(*value);
  print("exit code: %\n" , value);
  close(__write_pipe);
  close(__read_pipe);
}

__read_pipe:  s32;
__write_pipe: s32;


font : *Dynamic_Font;
__engine_name : string;  // name of engine. exists for aesthetic purposes
__engine_depth_parameter : int = 8; // depth of engine search.

get_engine_name :: () => __engine_name;

BookNode :: struct {
  name : string;
  moves: [..] Move16;
  nodes: [..] *BookNode;
}

pick_random_opening :: (move_record: [..] Board_States, opening_book: *BookNode) -> bool, Move16 {
  iter := opening_book;

  for re: move_record {
    move := re.move;

    found, idx := array_find(iter.moves, move);
    if !found then {
      return false, Move16.Quiet;
    }

    iter = iter.nodes[idx];
  }

  if iter.moves.count == 0 then
    return false, Move16.Quiet;

  r := cast(int)random_get() % iter.moves.count;
  return true, iter.moves[r];
}

get_opening_name :: (move_record: [..] Board_States, opening_book: *BookNode) -> bool, string {
  iter := opening_book;
  ret := iter.name;
  for re: move_record {
    move := re.move;
    found, idx := array_find(iter.moves, move);
    if !found then {
      return false, "bad";
    }
    iter = iter.nodes[idx];
    ret = iter.name;
  }

  return true, ret;
}

// TODO: This function leaks memory!
load_opening_book :: (file_path: string) -> *BookNode {
  text := read_entire_file(file_path);
  lines := split(text, "\n");

  opening_book: *BookNode = New(BookNode);

  for line, i: lines {
    if i == 0 || !line continue;

    if line[0] == #char "#" continue; // TODO: Skip bugs for now...
    advance(*line, 4);

    t1_start := 0;
    t1_end   := 0;

    t2_start := 0;
    t2_end   := 0;

    j := 0;
    if line[j] == #char "\"" {
      j += 1;
      t1_start = 1;
      while line[j] != #char "\"" {
        j += 1;
      }
      t1_end = j;
    } else {
      t1_start = 0;
      while line[j] != #char "," {
        j += 1;
      }
      t1_end = j;
    }

    t2_start = t1_end + 1;
    t2_end   = line.count;
    opening_name := slice(line, t1_start, t1_end - t1_start); 
    moves := slice(line, t2_start, t2_end - t2_start);

    pieces, whose_turn, castling, ep := chess_start_pos();
    // TODO: this code is sloppy, need to fix.
    node := opening_book;
    for move_string : split(moves, " ") {
      if !move_string continue;
      capture := PieceType.None;
      mov := parse_algebraic_notation(move_string, pieces, whose_turn, castling, ep);
      make_move(*pieces, *castling, *ep, *capture, mov, whose_turn);
      whose_turn = !whose_turn;

      //node.name = opening_name;

      found, idx := array_find(node.moves, mov);
      if found then {
        //node.name = opening_name;
        node = node.nodes[idx];
      } else {
        // Add the move to the opening book
        next_node := New(BookNode);
        next_node.name = copy_string(opening_name);

        array_add(*node.moves, mov);
        array_add(*node.nodes, next_node);

        node = next_node;
      }
    }
  }

  return opening_book;

  parse_algebraic_notation :: (move_string: string, using pieces: Piece_Bitboards, whose_turn: bool, castling: Castling, ep: u64) -> Move16 {

    if move_string[0] == #char "," then    // TODO: parsing needs to be fixed!
      advance(*move_string, 1);

    if equal(move_string, "O-O") {
      // castle kingside.
      if whose_turn {
        return encode_move_bb(xx e1, xx g1, Move16.King_Castle);
      } else {
        return encode_move_bb(xx e8, xx g8, Move16.King_Castle);
      }
    } else if equal(move_string, "O-O-O") {
      if whose_turn {
        return encode_move_bb(xx e1, xx c1, Move16.Queen_Castle);
      } else {
        return encode_move_bb(xx e8, xx c8, Move16.Queen_Castle);
      }
    }

    from_bitboard : u64 = ~0;
    to_bitboard   : u64 = ~0;

    if move_string[0] == {
    case #char "K";
      from_bitboard &= ifx whose_turn w_king else b_king;
      advance(*move_string, 1);
    case #char "Q";
      from_bitboard &= ifx whose_turn w_queen else b_queen;
      advance(*move_string, 1);
    case #char "R";
      from_bitboard &= ifx whose_turn w_rook else b_rook;
      advance(*move_string, 1);
    case #char "B";
      from_bitboard &= ifx whose_turn w_bishop else b_bishop;
      advance(*move_string, 1);
    case #char "N";
      from_bitboard &= ifx whose_turn w_knight else b_knight;
      advance(*move_string, 1);
    case;
      from_bitboard &= ifx whose_turn w_pawn else b_pawn;
    }

    bitboard : u64 = ~0;
    if move_string[0] >= #char "a" && move_string[0] <= #char "h" {
      bitboard &= file_of(move_string[0] - #char "a");
      advance(*move_string, 1);
    }

    if move_string[0] >= #char "1" && move_string[0] <= #char "8" {
      bitboard &= rank_of(move_string[0] - #char "1");
      advance(*move_string, 1);
    }

    if !move_string || move_string[0] == #char "+" {
      to_bitboard &= bitboard;
    }

    if move_string && move_string[0] == #char "x" {
      from_bitboard &= bitboard;
      advance(*move_string, 1);
    }

    if move_string && move_string[0] >= #char "a" && move_string[0] <= #char "h" {
      from_bitboard &= bitboard;
      to_bitboard &= file_of(move_string[0] - #char "a");
      advance(*move_string, 1);
    }

    if move_string && move_string[0] >= #char "1" && move_string[0] <= #char "8" {
      from_bitboard &= bitboard;
      to_bitboard &= rank_of(move_string[0] - #char "1");
      advance(*move_string, 1);
    }

    moves_arr: [..] Move16;
    defer array_free(moves_arr);
    array_reserve(*moves_arr, 50);

    generate_legal_moves(*pieces, castling, ep, *moves_arr, whose_turn);

    // linear search through the legal moves
    for mov : moves_arr {
      f, from, to := decode_move(mov);
      from_mov_bb := cast(u64) (1 << from);
      to_mov_bb   := cast(u64) (1 << to);
      if (from_mov_bb & from_bitboard) && (to_mov_bb == to_bitboard) {
        return mov;
      }
    }
    // TODO: some of these WILL NOT load correctly!
    //assert(false);
    return Move16.Quiet;
  }

  file_of :: inline (i: int) -> u64 {
    file: u64 = (cast(u64) file_a) << i;
    return file;
  }

  rank_of :: inline (i: int) -> u64 {
    rank: u64 = (cast(u64) rank_1) << (8*i);
    return rank;
  }
}

opening_book : *BookNode;

