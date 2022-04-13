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
hh           -- white=human vs black=human
hc           -- white=human vs black=ai
ch           -- white=ai vs black=human
cc           -- white=ai vs black=ai

Here are the keyboard controls:
<Ctrl+N> -- new game, reset the board.
<Ctrl+Z> -- undo move.
<ESC> -- opens a terminal for more complex commands
<X>      -- flip the board.
-------------------------------
END

fen_string := "startpos";

main :: () {
  print(welcome_message);
  white_side := true;
  handle_command_line();

  if !glfwInit() then return;
  defer glfwTerminate();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  window := glfwCreateWindow(680, 680, "Jai Chess", null, null);
  engines: [..] UCI_Engine;

  if !window then return;
  defer glfwDestroyWindow(window);

  glfwMakeContextCurrent(window);
  gl_load(*gl, glfwGetProcAddress);
  glfwSetCharCallback(window, console_text_input);
  im_init_gl();
  path := tprint("%1%2", #filepath, "resources/");
  font = load_font(path, "AnonymousPro.ttf", 20);

  t := New(Texture);
  defer {
    destroy_texture(t);
  }
  if !load_texture_from_file(t, "resources/chess_pieces.png") {
    print("Error loading texture");
    return;
  }

  {
    engine_name := "leviathan";
    ai_chess_engine_path := join(#filepath, "resources/", engine_name);
    engine, success := init_uci_engine(engine_name, ai_chess_engine_path);
    if !success then {
      print("Error initializing UCI chess interface\n");
      return;
    }
    array_add(*engines, engine);
  }

  defer {
    // send quit command to the chess engine 
    // before closing the uci chess engine.
    for *engine: engines {
      uci_write_command(engine, "stop\n");
      uci_write_command(engine, "quit\n");
      uci_close(engine);
    }
  }

  init_global_bitboards();
  chess: Chess;
  array_reserve(*move_record, 200); // records the game down. I use this struct to backtrack and undo moves
  ep_sq: u64 = 0;
  
  chess_startpos(*chess);
  moves_arr: [..] Move16;
  array_reserve(*moves_arr, 100);
  generate_moves(*chess, *moves_arr);
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
    handle_reset(window, *chess, *moves_arr);
    console_input(*engines, window, *chess, *moves_arr);
    if !console_on {
      white_side = handle_flip_board(window, white_side);
    }
    handle_undo_move(window, *chess, *moves_arr);

    if w_human_turn(*chess) || b_human_turn(*chess) {
      handle_board_click(xx width, xx height, *chess, *moves_arr, white_side=white_side);
    }
    draw_chess(xx width, xx height, *chess, t, highlight_the_square, possible_moves_bb, last_move_bb, white_side);
    draw_console(xx width, xx height, window);


    im_flush();

    glfwSwapBuffers(window);
    glfwPollEvents();

    reset_temporary_storage();
    for *engine: engines {
      uci_ai_loop(engine, *chess, *moves_arr);
    }
    ftime = cast(float)get_time() - ftime;
    delta_time = ftime;
  }
}

timer_on := false;
delta_time : float32 = 0.0;
openings_on := true;

handle_command_line :: () #expand {
  args := get_command_line_arguments();
  for arg : args {
    if arg == {
    case "hc";
      w_is_human = true;
      b_is_human = false;
      `white_side = true;
      b_engine_name = "leviathan";
    case "hh";
      w_is_human = true;
      b_is_human = true;
      `white_side = true;
    case "cc";
      w_is_human = false;
      b_is_human = false;
      `white_side = true;
      w_engine_name = "leviathan";
      b_engine_name = "leviathan";
    case "ch";
      w_is_human = false;
      b_is_human = true;
      `white_side = false;
      w_engine_name = "leviathan";
    }
  }
}

__game_status_text: string;

console_key: enum {CONSOLE_PRESS; CONSOLE_RELEASE;} = .CONSOLE_PRESS;
console_on := false;
console_text_buffer: [1024] u8;
console_text_count := 0;
console_character : u8;
console_backspace_timer := 0.0;
console_paste_key: enum {PASTE_PRESS; PASTE_RELEASE;} = .PASTE_PRESS;

console_text_input :: (window: *GLFWwindow, codepoint: u32) #c_call {
  if console_on {
    if console_text_count >= 1024 {
      return;
    }
    console_text_buffer[console_text_count] = cast(u8) codepoint;
    console_text_count += 1;
  } 
}

console_input :: (engines: *[..] UCI_Engine, window: *GLFWwindow, chess: *Chess, moves_arr: *[..]Move16) {
  esc := glfwGetKey(window, GLFW_KEY_ESCAPE);
  l_ctrl_key := glfwGetKey(window, GLFW_KEY_LEFT_CONTROL);
  r_ctrl_key := glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL);
  if console_key == {
  case .CONSOLE_PRESS;
    if esc == GLFW_PRESS {
      console_key = .CONSOLE_RELEASE;
      console_on = !console_on;
    }
  case .CONSOLE_RELEASE;
    if esc == GLFW_RELEASE {
      console_key = .CONSOLE_PRESS;
    }
  }

  if console_on {

    if console_paste_key == {
    case .PASTE_PRESS; 
      if glfwGetKey(window, GLFW_KEY_V) == GLFW_PRESS && (l_ctrl_key == GLFW_PRESS || r_ctrl_key == GLFW_PRESS) {
        str: string;
        str.data  = glfwGetClipboardString(window);
        str.count = c_style_strlen(str.data);
        i := console_text_count;
        console_text_count += str.count;
        memcpy(*console_text_buffer[i], str.data, str.count * size_of(u8));
        console_paste_key = .PASTE_RELEASE;
      }
    case .PASTE_RELEASE;
      if glfwGetKey(window, GLFW_KEY_V) == GLFW_RELEASE || (l_ctrl_key == GLFW_RELEASE && r_ctrl_key == GLFW_RELEASE) {
        console_paste_key = .PASTE_PRESS;
      }
    }

    if glfwGetKey(window, GLFW_KEY_BACKSPACE) == GLFW_PRESS {
      console_backspace_timer += delta_time;
      if console_backspace_timer > 0.0 {
        console_text_count = max(console_text_count-1, 0);
        console_backspace_timer = -0.10;
      }
    } else {
      console_backspace_timer = 0.0;
    }
    if glfwGetKey(window, GLFW_KEY_ENTER) == GLFW_PRESS {
      str : string;
      str.data = console_text_buffer.data;
      str.count = console_text_count;

      for tokens: split(str, ", ") {
        console_write_command(engines, tokens, chess, moves_arr);
      }

      console_text_count = 0;
    }
  }
}

draw_console :: (width: float, height: float, window: *GLFWwindow) {
  if console_on == false return;
  im_set_texture(null);
  im_draw_rect(0, 0, width, height, c=Vector4.{0,0,0,0.85});
  str : string;
  str.data = console_text_buffer.data;
  str.count = console_text_count;
  im_draw_text(font, 10, 5, Vector4.{1,1,1,1}, tprint(">%", str));
}


white_sq_color := Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
black_sq_color := Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};
coordinates_on := true;

console_write_command :: (engines: *[..] UCI_Engine, str: string, chess: *Chess, moves_arr: *[..]Move16) {
  command, success := parse_token(*str);
  if !success return;
  while str && str[0] == #char " " {
    advance(*str, 1); // eat spaces.
  }

  if command == {
  case "board_theme";
    if str == {
    case "green";
      white_sq_color = Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
      black_sq_color = Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};

    case "blue"; 
      white_sq_color = Vector4.{0.871, 0.890, 0.902, 1.0}; 
      black_sq_color = Vector4.{0.549, 0.635, 0.678, 1.0};

    case "grey";
      white_sq_color = Vector4.{0.655, 0.655, 0.655, 1.0};
      black_sq_color = Vector4.{0.525, 0.525, 0.525, 1.0};

    case "brown";
      white_sq_color = Vector4.{0.941, 0.851, 0.710, 1.0};
      black_sq_color = Vector4.{0.710, 0.533, 0.388, 1.0};

    case "purple";
      white_sq_color = Vector4.{0.902, 0.859, 0.945, 1.0};
      black_sq_color = Vector4.{0.600, 0.490, 0.710, 1.0};

    case "red";
      white_sq_color = Vector4.{0.941, 0.847, 0.749, 1.0};
      black_sq_color = Vector4.{0.729, 0.333, 0.275, 1.0};
    }
    return;
  case "coordinates";
    if str == {
    case "true";
      coordinates_on = true;
    case "false";
      coordinates_on = false;
    }
    return;

  case "stop";
    timeout_timer = timeout_limit + delta_time;
    return;

  case "fen";
    // TODO: is reset(chess, moves_arr) neccessary??
    reset(chess, moves_arr);
    while str && str[0] == #char " " {
      advance(*str, 1);
    }
    if str {
      fen_string = copy_string(str); // TODO: eventually need to free memory up.
      if equal(fen_string, "startpos") then {
        print("startpos\n");
        chess_startpos(chess);
      } else {
        if !chess_fen(chess, fen_string) then {
          print("fail fen parsing.\n");
          chess_startpos(chess);
          fen_string = "startpos";
        }
      }
    }
    array_reset(moves_arr);
    generate_moves(chess, moves_arr);
    print("%\n", moves_arr.count);
    return;

  case "white";
    w_is_human = true;
    if w_engine_name free(w_engine_name);
    w_engine_name = copy_string(str); // TODO: Leak!
    for e : (<<engines) {
      if equal(e.name, str) {
        w_is_human = false;
        return;
      }
    }
    return;

  case "black";
    b_is_human = true;
    if b_engine_name free(b_engine_name);
    b_engine_name = copy_string(str); // TODO: Leak
    for e : (<<engines) {
      if equal(e.name, str) {
        b_is_human = false;
        return;
      }
    }
    return;

  case "load_engine";
    for e : (<<engines) {
      if equal(e.name, str) {
        print("***Error. Engine % already has been loaded.\n", str);
        return;
      }
    }

    path := join(#filepath, "resources/", str);
    engine, success := init_uci_engine(str, path);
    if !success {
      print("***Error. Engine % cannot be loaded.\n", str);
      return;
    }
    array_add(engines, engine);
    return;

  case "timeout";
    value, success := parse_float(*str);
    if success {
      timeout_limit = value;
    } else {
      print("***Error. Invalid timeout parameter: %\n", str);
    }
    return;
  }

  for *eng: <<engines {
    if equal(command,eng.name) {
      token, success := parse_token(*str);
      if !success return;

      if token == {
      case "depth";
        number, success := parse_int(*str);
        if !success || number < 1 {
          print("***Error. Invalid depth parameter: %\n", str);
          return;
        }
        eng.depth = number;
      }

      return;
    }
  }

}

draw_chess :: (width: float, height: float, chess: *Chess, texture: *Texture, highlight_square: u64, possible_moves_bb: u64, last_move_bb: u64, white_side: bool) {
  cen_x := width * 0.5; 
  cen_y := height * 0.5;
  if timer_on == true {
    if chess.turn == Turn.WHITE then {
      w_clock_time -= delta_time;
    } else {
      b_clock_time -= delta_time;
    }
  }

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x := cen_x - len*.5;
  y := cen_y - len*.5;

  // draw text
  if font {
    bottom : string  = w_engine_name;
    top    : string  = b_engine_name;
    bot_col: Vector4 = ifx chess.turn == Turn.WHITE then BLANK else L_BLANK;
    top_col: Vector4 = ifx chess.turn == Turn.BLACK then BLANK else L_BLANK;

    bot_time := w_clock_time;
    top_time := b_clock_time;
    if !white_side {
      swap(bottom, top);
      swap(bot_col, top_col);
      swap(bot_time, top_time);
    }

    bottom_string := tprint("%:%", formatInt(cast(int)(bot_time/60.0),      minimum_digits=2), 
                                   formatInt(cast(int)fmod(bot_time, 60.0), minimum_digits=2));
    top_string    := tprint("%:%", formatInt(cast(int)(top_time/60.0),      minimum_digits=2),
                                   formatInt(cast(int)fmod(top_time, 60.0), minimum_digits=2));
    im_draw_text(font, x, y - square_len*0.33, bot_col, bottom);
    im_draw_text(font, x, y + square_len*8.13, top_col, top);

    im_draw_text(font, x+square_len*7.25, y - square_len*0.33, bot_col, bottom_string);
    im_draw_text(font, x+square_len*7.25, y + square_len*8.13, top_col, top_string);
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

  if coordinates_on == true && font {
    // add board labels.
    letters : string = ifx white_side "abcdefgh" else "hgfedcba";
    numbers : string = ifx white_side "12345678" else "87654321";
    TF := true;
    col := white_sq_color;
    for i: 0..7 {
      im_draw_text(font, x + square_len*(i+1) - 10, y + 2, col, slice(letters, i, 1));
      im_draw_text(font, x + 2, y + square_len*(i+1) - 18, col, slice(numbers, i, 1));
      TF = !TF;
      col = ifx TF white_sq_color else black_sq_color;
    }
  }

  im_set_texture(texture);

  using chess;
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

  draw_move :: (move: Move16, c: Vector4) #expand {
    _, from, to := decode_move16(move);
    i0, j0, i1, j1 := 0;
    if white_side {
      i0, j0 = from & 7, from >> 3;
      i1, j1 = to &  7, to >> 3;
    } else {
      i0, j0 = 7 - from & 7, 7 - from >> 3;
      i1, j1 = 7 - to & 7, 7 - to >> 3;
    }
 
    im_draw_rect(x + square_len*(0.4+i0), y + square_len*(0.4+j0), x + square_len*(0.6+i0), y + square_len*(0.6+j0), c=c);
    im_draw_line(x + square_len*(0.5+i0), y + square_len*(0.5+j0), x + square_len*(0.5+i1), y + square_len*(0.5+j1), c=c);
    im_draw_rect(x + square_len*(0.4+i1), y + square_len*(0.4+j1), x + square_len*(0.6+i1), y + square_len*(0.6+j1), c=c);
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
    if chess.turn == Turn.WHITE {
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
    if chess.turn == Turn.WHITE {
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

timeout_limit := 1.75;
mouse_position_x: float = 0.0;
mouse_position_y: float = 0.0;
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

handle_board_click :: (width: float, height: float, chess: *Chess, moves_arr: *[..] Move16, white_side := true) {
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
    if can_move(chess, sq) && mouse_button_1_state == .MOUSE_PRESSED {
      highlight_the_square ^= xx sq;
      piece_select_state = .PIECE_SELECTED;
      possible_moves_bb = possible_moves_for(<<moves_arr, sq);
    }
  case .PIECE_SELECTED;
    if highlight_the_square == sq && mouse_button_1_state == .MOUSE_PRESSED {
      highlight_the_square = 0;
      piece_select_state = .PIECE_IDLE;
      possible_moves_bb = 0;
    } else if can_move(chess, sq) && mouse_button_1_state == .MOUSE_PRESSED {
      highlight_the_square = xx sq;
      possible_moves_bb = possible_moves_for(<<moves_arr, sq);
    } else if !can_move(chess, sq) {
      // make move
      from := highlight_the_square;
      to   := sq;
      if to & possible_moves_bb {
        mov := find_move(moves_arr, bit_scan_forward(from), bit_scan_forward(to));
        if move_is_promotion(mov) {
          // bring up promotion interface.
          piece_select_state = .PIECE_PROMOTION;
          promotion_sq = to;
          promote_move = mov;
        } else {
          last_move_bb = from | to;
          ui_handle_move_made(chess, moves_arr, mov);
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
      type, from_i, to_i := decode_move16(promote_move);
      from := cast(u64) (1 << from_i);
      to   := cast(u64) (1 << to_i);
      mov: Move16;
      if Move16.Knight_Promotion <= type && type <= Move16.Queen_Promotion {
        if promtion_type == {
        case UI_PIECE.UI_QUEEN;
          mov = to_move16(from_i, to_i, Move16.Queen_Promotion);
        case UI_PIECE.UI_ROOK;
          mov = to_move16(from_i, to_i, Move16.Rook_Promotion);
        case UI_PIECE.UI_BISHOP;
          mov = to_move16(from_i, to_i, Move16.Bishop_Promotion);
        case UI_PIECE.UI_KNIGHT;
          mov = to_move16(from_i, to_i, Move16.Knight_Promotion); 
        }
      } else {
        if promtion_type == {
        case UI_PIECE.UI_QUEEN;
          mov = to_move16(from_i, to_i, Move16.Queen_Promotion_Capture);
        case UI_PIECE.UI_ROOK;
          mov = to_move16(from_i, to_i, Move16.Rook_Promotion_Capture);
        case UI_PIECE.UI_BISHOP;
          mov = to_move16(from_i, to_i, Move16.Bishop_Promotion_Capture);
        case UI_PIECE.UI_KNIGHT;
          mov = to_move16(from_i, to_i, Move16.Knight_Promotion_Capture); 
        }
      }

      last_move_bb = from | to;
      ui_handle_move_made(chess, moves_arr, mov);
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

add_move :: (chess: *Chess, moves: *[..] Move16, from: int, to: int, flags: Move16, in_check: bool) {
  move := to_move16(from, to, flags);
  array_add(moves, move);
}

handle_undo_move :: (window: *GLFWwindow, chess: *Chess, moves_arr: *[..] Move16) {
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
        unmake_move(chess, board_state.move, board_state.captured, board_state.flags, board_state.hash);
        
        while move_record && !w_human_turn(chess) && !b_human_turn(chess) {
          board_state := pop(*move_record);
          unmake_move(chess, board_state.move, board_state.captured, board_state.flags, board_state.hash);
        }

        array_reset(moves_arr); // TODO:
        status := generate_moves(chess, moves_arr);

        highlight_the_square = 0;
        possible_moves_bb = 0;
        promote_move = cast(Move16) 0;
        if move_record {
          last_board_state := move_record[move_record.count - 1];
          type, x, y := decode_move16(last_board_state.move);
          last_move_bb = (cast(u64)(1 << x)) | (cast(u64)(1 << y));
        } else {
          last_move_bb = 0;
        }
        if status == ChessFlags.Check {
          __game_status_text = "Check.";
        } else {
          __game_status_text = "";
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

reset :: (chess: *Chess, moves_arr: *[..]Move16) {
  timer_on = false;
  array_reset(*move_record);
  array_reset(moves_arr); // TODO: is this a leak???
  chess_startpos(chess);
  generate_moves(chess, moves_arr);
  last_move_bb = 0;
  highlight_the_square = 0;
  possible_moves_bb = 0;
  promote_move = cast(Move16) 0;
  __game_status_text = "";
  w_clock_time = 30.0*60.0;
  b_clock_time = 30.0*60.0;
}


handle_reset :: (window: *GLFWwindow, chess: *Chess, moves_arr: *[..] Move16) {
  if piece_select_state != .PIECE_IDLE then
    return;
  n_state    := glfwGetKey(window, GLFW_KEY_N);
  l_ctrl_key := glfwGetKey(window, GLFW_KEY_LEFT_CONTROL);
  r_ctrl_key := glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL);
  if reset_key_state == {

  case .RESET_IDLE;
    if n_state == GLFW_PRESS && (l_ctrl_key == GLFW_PRESS || r_ctrl_key == GLFW_PRESS) {
      reset_key_state = .RESET_PRESS;
      reset(chess, moves_arr);
      fen_string = "startpos";
    }
  case .RESET_PRESS;
    if n_state == GLFW_RELEASE || (l_ctrl_key == GLFW_RELEASE && r_ctrl_key == GLFW_RELEASE) {
      reset_key_state = .RESET_IDLE;
    }
  }
}

ui_handle_move_made :: (chess: *Chess, moves_arr: *[..] Move16, mov: Move16) {
  timer_on = true;
  // record the move down 
  record_move: Board_States;
  record_move.move = mov;
  record_move.hash = chess.hash;
  record_move.captured, record_move.flags = make_move(chess, mov);
  array_add(*move_record, record_move);

  array_reset(moves_arr);
  generate_moves(chess, moves_arr);
  check := in_check(chess);

  if check && moves_arr.count == 0 {
    __game_status_text = "Checkmate.";
    timer_on = false;
  } else if (!check && moves_arr.count == 0) {
    __game_status_text = "Stalemate.";
    timer_on = false;
  } else if false {
    __game_status_text = "Stalemate by threefold repetition.";
    array_reset(moves_arr);
    timer_on = false;
  } else if check {
    __game_status_text = "Check.";
  } else {
    __game_status_text = "";
  }

  highlight_the_square = 0;
  possible_moves_bb = 0;
  promote_move = cast(Move16) 0;
}

last_move_bb: u64 = 0;
promotion_sq : u64 = 0;
highlight_the_square: u64 = 0;
piece_select_state: enum { PIECE_IDLE; PIECE_SELECTED; PIECE_PROMOTION; } = .PIECE_IDLE;
possible_moves_bb: u64 = 0;
check_bb : u64 = 0;

w_is_human : bool = true;
b_is_human : bool = true;
w_engine_name: string;
b_engine_name: string;

w_clock_time : float = 30*60;
b_clock_time : float = 30*60;

w_human_turn :: (c) => (w_is_human && c.turn == Turn.WHITE);
b_human_turn :: (c) => (b_is_human && c.turn == Turn.BLACK);

UI_PIECE :: enum {
  UI_QUEEN;
  UI_ROOK;
  UI_BISHOP;
  UI_KNIGHT;
}

promtion_type := UI_PIECE.UI_QUEEN;
promote_move : Move16;

move_record: [..] Board_States;

Board_States :: struct {
  move: Move16;
  flags: Castling;
  captured: Piece;
  hash: u64;
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
    type, from, to := decode_move16(move.move);
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

uci_ai_loop :: (using engine: *UCI_Engine, chess: *Chess, moves_arr: *[..]Move16) {
  if uci_state == {
  case .UCI_INIT;
    uci_write_command(engine, "uci\n");
    uci_state = .UCI_UCIOK;

  case .UCI_UCIOK;
    for message: uci_messages(engine) {
      if equal(message, "uciok") {
        uci_state = .UCI_ISREADY;
      }
    }

  case .UCI_ISREADY;
    uci_write_command(engine, "isready\n");
    uci_state = .UCI_READYOK;
  case .UCI_READYOK;
    for message: uci_messages(engine) {
      if equal(message, "readyok") {
        uci_state = .UCI_NEWGAME;
      } 
    }

  case .UCI_NEWGAME;
    uci_state = .UCI_IDLE;
    uci_write_command(engine, "ucinewgame\n");
  case .UCI_IDLE;
    for message: uci_messages(engine) {
      // getline and throw away input.
    } 

    // make sure there are moves that could be made.
    if moves_arr.count > 0 && 
       ( ((equal(w_engine_name, engine.name) && !w_is_human && chess.turn == Turn.WHITE)) || 
         ((equal(b_engine_name, engine.name) && !b_is_human && chess.turn == Turn.BLACK))) {
      
      if reset_key_state == .RESET_PRESS then {
        uci_state = .UCI_NEWGAME;
      } else {
        cmd_str := uci_position_command();
        uci_write_command(engine, cmd_str);
        uci_state = .UCI_POS_CMD;
      }
    }

  case .UCI_POS_CMD;
    if reset_key_state == .RESET_PRESS {
      uci_state = .UCI_NEWGAME;
    } else {
      cmd_string := tprint("go depth %\n", engine.depth);
      uci_write_command(engine, cmd_string);
      uci_state = .UCI_GO_TURN;
      timeout_timer = 0.0;
    }

  case .UCI_GO_TURN;

    // need to make sure AI does not transform into human halfway.
    if !(((equal(w_engine_name, engine.name) && !w_is_human && chess.turn == Turn.WHITE)) || 
        ((equal(b_engine_name, engine.name) && !b_is_human && chess.turn == Turn.BLACK))) {
      uci_write_command(engine, "stop\n");
      timeout_timer = 0.0;
    }

    timeout_timer += delta_time;
    if reset_key_state == .RESET_PRESS {
      uci_write_command(engine, "stop\n");
      timeout_timer = 0.0;
      uci_state = .UCI_NEWGAME;
      print("timeout!\n");
    } else if timeout_timer >= timeout_limit {
      uci_write_command(engine, "stop\n");
      timeout_timer = 0.0;
      print("timeout!\n");
    } 

    for message: uci_messages(engine) {
      if starts_with(message, "bestmove ") {
        parse_token(*message);
        TF, from, to, type := parse_move(message);
        assert(TF, "null move.\n");
        actual_move := find_move(moves_arr, from, to, type);
        if actual_move {
          ui_handle_move_made(chess, moves_arr, actual_move);
          last_move_bb = cast(u64)((1<<from)|(1<<to));
          uci_state = .UCI_IDLE;
        } else {
          print("There is a bug.\n");
          uci_state = .UCI_BUG;
        }
      }
    }

  case .UCI_BUG;

  }

}

parse_move :: (best_move_string: string) -> TF: bool, from: int, to: int, type: Move16 {
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
  from : int = b*8 + a;
  to   : int = d*8 + c;
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


timeout_timer := 0.0;

#scope_file
// Universal Chess Interface Protocol

init_uci_engine :: (engine_name: string, ai_path: string) -> UCI_Engine, bool {
  // I wish there was a high-level library for this in Jai,
  // but the #import "Process"; doesn't do what I want... <sigh>
  engine: UCI_Engine;
  pipe_1: [2] s32;
  pipe_2: [2] s32;

  if pipe(*pipe_1) == -1 {
    print("Error creating pipe.\n");
    return engine, false;
  }
  if pipe(*pipe_2) == -1 {
    print("Error creating pipe.\n");
    return engine, false;
  }

  child_pid := fork();
  if child_pid == -1 {
    print("Error in fork.\n");
    return engine, false;
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
    return engine, false;  // to shut the compiler up.
  } else {
    // parent process
    engine.pid = child_pid;
    close(pipe_1[1]);
    close(pipe_2[0]);
    engine.write_pipe = pipe_2[1];
    engine.read_pipe  = pipe_1[0];
    setup_pipe_nonblock(engine.read_pipe);

    engine.name = copy_string(engine_name);
    return engine, true; 
  }

  setup_pipe_nonblock :: (pipe: s32) #expand {
    flags := fcntl(pipe, F_GETFL, 0) | O_NONBLOCK;
    fcntl(pipe, F_SETFL, flags);
  }
}

uci_write_command :: (using engine: *UCI_Engine, command: string) {
  write(write_pipe, command.data, xx command.count);
}

swap :: (a: Code, b: Code) #expand {
  t := (#insert a);
  (#insert a) = (#insert b);
  (#insert b) = t;
}

UCI_Message_Loop :: struct {
  using engine: *UCI_Engine;
}

uci_messages :: (engine : *UCI_Engine) -> UCI_Message_Loop {
  uci_message_loop: UCI_Message_Loop;
  uci_message_loop.engine = engine;
  return uci_message_loop;
}

for_expansion :: (loop: *UCI_Message_Loop, loop_body: Code, flags: For_Flags) #expand {
  using loop.engine;
  buffer := NewArray(16384, u8, allocator=__temporary_allocator);
  while true {
    bytes_read := read(read_pipe, buffer.data, xx (buffer.count-1));
    if bytes_read <= 0 then {
      break;
    }

    auto_release_temp();
    messages := to_string(buffer.data, bytes_read); // -1 the '\n' char
    if messages[bytes_read - 1] == #char "\n" then {
      messages.count -= 1;
    } else {

    }

    for message, i: split(messages, "\n") {
      print("[%] %\n", name, message);
      `it := message;
      `it_index := i;
      #insert (break={return;}) loop_body;
    }
  }
}

uci_close :: (using engine: *UCI_Engine) {
  // NOTE: this function does NOT call "uci_write_command(engine, "quit")",
  // that needs to be called explicitly
  status: s32;
  waitpid(pid, *status, 0);
  print("[%] quits with return code: %\n" , name, status);
  close(write_pipe);
  close(read_pipe);
}

UCI_Engine :: struct {
  uci_state : enum { 
    UCI_INIT; 
    UCI_UCIOK; 
    UCI_ISREADY; 
    UCI_READYOK;
    UCI_NEWGAME; 
    UCI_IDLE;
    UCI_POS_CMD;
    UCI_GO_TURN;
    UCI_BUG;
  } = .UCI_INIT;

  name: string;
  pid: pid_t;
  read_pipe:  s32;
  write_pipe: s32;
  depth: int = 30;
}


font : *Dynamic_Font;

find_move :: (moves: *[..]Move16, from: int, to: int, typ: Move16=Move16.Quiet) -> Move16 {
  if typ == Move16.Quiet {
    for mov: <<moves {
      flags, from2, to2 := decode_move16(mov);
      if from == from2 && to == to2 {
        return mov;
      }
    }
  } else if Move16.Knight_Promotion <= typ && typ <= Move16.Queen_Promotion_Capture {
    for mov: <<moves {
      flags, fr2, to2 := decode_move16(mov);
      if from == fr2 && to == to2 && ((flags == typ) || flags == (typ + xx 4)) {
        return mov;
      }
    }
  }
  return 0;
}

possible_moves_for :: (moves: [..] Move16, from: u64) -> u64 {
  ret: u64 = 0;
  for move: moves {
    type, i, j := decode_move16(move);
    from_move := cast(u64) (1 << i);
    to_move   := cast(u64) (1 << j);
    if from == from_move {
      ret = ret | to_move;
    }
  }
  return ret;
}

