#import "Basic";
#import "Math";
#import "Render";
#import "glfw";
#import "GL";
#import "POSIX";
#import "String";

main :: () {
  white_side := true;
  engine_name := handle_command_line();

  if !glfwInit() then return;
  defer glfwTerminate();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  window := glfwCreateWindow(640, 480, "Jai Chess", null, null);
  if !window then return;
  defer glfwDestroyWindow(window);

  glfwMakeContextCurrent(window);
  gl_load(*gl, glfwGetProcAddress);
  im_init_gl();

  t := New(Texture);
  defer {
    destroy_texture(t);
  }
  if !load_texture_from_file(t, "resources/chess_pieces.png") {
    print("Error loading texture");
    return;
  }

  ai_chess_engine_path := join(#filepath, "resources/", engine_name);
  if !uci_init_uci_chess_engine(engine_name, ai_chess_engine_path) {
    print("Error initializing UCI chess interface\n");
    return;
  }

  defer {
    // send quit command to the chess engine 
    // before closing the uci chess engine.
    uci_write_command("quit\n");
    uci_close_chess_engine();
  }

  init_global_bitboards();
  moves_arr: [..] Move16;
  array_reserve(*moves_arr, 70);    // generates all legal moves
  array_reserve(*move_record, 200); // records the game down. I use this struct to backtrack and undo moves
  flags: Castling = Castling.All;
  ep_sq: u64 = 0;
  piece_bitboard := chess_start_pos();
  generate_legal_moves(*piece_bitboard, flags, ep_sq, *moves_arr, true);

  while !glfwWindowShouldClose(window) {
    read_mouse_input(window);
    width, height : s32;
    glfwGetFramebufferSize(window, *width, *height);
    glViewport(0, 0, xx width, xx height);
    glClearColor(0.15555, 0.15555, 0.15555, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    uci_ai_game_loop (*piece_bitboard, *flags, *ep_sq, *moves_arr);

    im_draw_setup_gl();
    im_set_viewport_transform(2.0/width, 2.0/height, -1, -1);
    white_side = handle_flip_board(window, white_side);
    handle_undo_move(window, *piece_bitboard, *flags, *ep_sq, *moves_arr);

    if w_human_turn() || b_human_turn() {
      handle_board_click(xx width, xx height, *piece_bitboard, *flags, *ep_sq, *moves_arr, white_side=white_side);
    }
    draw_chess(xx width, xx height, *piece_bitboard, t, highlight_the_square, possible_moves_bb, last_move_bb, white_side);
    im_flush();

    glfwSwapBuffers(window);
    glfwPollEvents();

    reset_temporary_storage();
  }
}

handle_command_line :: () -> string #expand {
  // TODO: 
  // NOTE: this is hard-coded. It does not cover general cases
  // I'm too lazy to create a pretty UI right now, so commandline will have to do
  // this is ad-hoc, and this is mainly for slapping together something to
  // get useful functionality.
  args := get_command_line_arguments();
  engine_name : string = "stockfish";
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
    case;
      if begins_with(arg, "ai=") {
        cpu_string := advance(arg, 3);
        // This is not good error checking... could crash the program
        if cpu_string.count != 0 {
          engine_name = cpu_string;
          print(engine_name);
        } else {
          print("Invalid ai choice\n");
        }
      }
    }
  }
  return engine_name;
}

draw_chess :: (width: float, height: float, pieces: *Piece_Bitboards, texture: *Texture, highlight_square: u64, possible_moves_bb: u64, last_move_bb: u64, white_side: bool) {
  cen_x := width * 0.5; 
  cen_y := height * 0.5;

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x := cen_x - len*.5;
  y := cen_y - len*.5;

  white_sq_color :: Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
  black_sq_color :: Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};
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
  draw_bitboard(check_bb, u0=0.0, v0=0.0, u1=1.0, v1=1.0, RED);
  draw_bitboard(possible_moves_bb, u0=0.0, v0=0.0, u1=1.0, v1=1.0, GREY);

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

  // chess.com uses yellow, so we follow their example...
  BLANK    :: Vector4.{1,1,1,1}; 
  GREY     :: Vector4.{.5,.5,.2,.35}; 
  YELLOW   :: Vector4.{.9,.9,0,.35}; 
  LESS     :: Vector4.{1.0, 1.0, 1.0, 0.25};
  RED      :: Vector4.{.9, 0.25, 0.25, 0.65};
  GREY_SHADE_BOARD :: Vector4.{0.2, 0.2, 0.2, 0.35};

  draw_every_piece :: ($draw_mouse_drag := false) #expand {
    draw_bitboard(w_king & ~promotion_sq, u0=0.0, v0=0.0, u1=1.0/6.0, v1=0.5, BLANK, draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(w_queen & ~promotion_sq, u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=1.0/2.0, BLANK, draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(w_rook & ~promotion_sq, u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=1.0/2.0, BLANK,draw_mouse_drag=draw_mouse_drag );
    draw_bitboard(w_bishop & ~promotion_sq, u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=1.0/2.0, BLANK, draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(w_knight & ~promotion_sq, u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=1.0/2.0, BLANK,draw_mouse_drag=draw_mouse_drag );
    draw_bitboard(w_pawn & ~promotion_sq, u0=5.0/6.0, v0=0.0, u1=1.0, v1=1.0/2.0, BLANK,draw_mouse_drag=draw_mouse_drag);
 
    draw_bitboard(b_king & ~promotion_sq, u0=0.0, v0=0.5, u1=1.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_queen & ~promotion_sq, u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_rook & ~promotion_sq, u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_bishop & ~promotion_sq, u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_knight & ~promotion_sq, u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
    draw_bitboard(b_pawn & ~promotion_sq, u0=5.0/6.0, v0=0.5, u1=1.0, v1=1.0, BLANK,draw_mouse_drag=draw_mouse_drag);
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
    index := serialize_bit(promote_sq);
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

    im_draw_rect(posx, posy + scale_up_sq_len, posx + scale_up_sq_len*4, posy, c=BLANK*0.75);
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
      value = bit_board & ~highlight_square;
    else 
      value = bit_board & highlight_square;

    while value {
      index := serialize_bit(value);
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
    index := serialize_bit(promotion_sq);
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

  // cannot use undo when in the promote pawn UI.
  if piece_select_state == .PIECE_PROMOTION then
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
        
        while move_record && !w_human_turn() && !b_human_turn() {
          board_state := pop(*move_record);
          // NOTE: need to flip whose_turn BEFORE generate_legal_moves, else we would get the opposite side's moves
          // by accident. We also need to copy the flags from the board_state BEFORE generate_legal_moves!
          <<ep_sq = board_state.en_paesant_sq;
          <<flags = board_state.flags;
          whose_turn = !whose_turn;
          unmake_move(piece_bitboard, board_state.captured, board_state.move, whose_turn);
        }

        array_reset(moves_arr);
        generate_legal_moves(piece_bitboard, <<flags, <<ep_sq, moves_arr, whose_turn);

        highlight_the_square = 0;
        possible_moves_bb = 0;
        promote_move = cast(Move16) 0;
        piece_select_state = .PIECE_IDLE;
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
      }
    }
  case .UNDO_KEY_PRESS;
    if z_state == GLFW_RELEASE || (l_ctrl_key == GLFW_RELEASE && r_ctrl_key == GLFW_RELEASE) {
      undo_key_state = .UNDO_KEY_IDLE;
    }
  }
}

ui_handle_move_made :: (piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..] Move16, mov: Move16) {
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
  print_bitboard(check_bb);
  if moves_arr.count == 0 {
    if check_bb != 0 {
      if whose_turn {
        print("Black wins! Checkmate!\n");
      } else {
        print("White wins! Checkmate!\n");
      }
    } else {
      print("Stalemate\n");
    }
  }
  highlight_the_square = 0;
  possible_moves_bb = 0;

  promote_move = cast(Move16) 0;
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

  print_to_builder(*builder, "position startpos moves ");
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
  UCI_READY_OK; 
  UCI_NEWGAME; 
  UCI_IDLE;
  UCI_POS_CMD;
  UCI_GO_TURN;
} = .UCI_INIT;

uci_ai_game_loop :: (piece_bitboard: *Piece_Bitboards, flags: *Castling, ep_sq: *u64, moves_arr: *[..]Move16) {
  if uci_state == {
  case .UCI_INIT;
    uci_write_command("uci\n");
    uci_state = .UCI_UCIOK;
  case .UCI_UCIOK;
    uci_read_incoming_commands();
    while uci_has_commands() {
      cmd_string := uci_getline();
      if equal(cmd_string, "uciok") {
        uci_state = .UCI_ISREADY;
      }
    }
  case .UCI_ISREADY;
    uci_write_command("isready\n");
    uci_state = .UCI_READY_OK;
  case .UCI_READY_OK;
    uci_read_incoming_commands();
    while uci_has_commands() {
      cmd_string := uci_getline();
      if equal(cmd_string, "readyok") {
        uci_state = .UCI_NEWGAME;
      }
    }
  case .UCI_NEWGAME;
    uci_write_command("ucinewgame\n");
    uci_state = .UCI_IDLE;
  case .UCI_IDLE;
    // make sure there are moves that could be made.
    if moves_arr.count > 0 && !w_human_turn() && !b_human_turn() {
      cmd_str := uci_position_command();
      uci_write_command(cmd_str);
      uci_state = .UCI_POS_CMD;
    }

  case .UCI_POS_CMD;
    cmd_string := tprint("go depth %\n", __engine_depth_parameter);
    uci_write_command(cmd_string);
    uci_state = .UCI_GO_TURN;

  case .UCI_GO_TURN;
    uci_read_incoming_commands();
    while uci_has_commands() {
      cmd_string := uci_getline();
      if starts_with(cmd_string, "bestmove ") {
        TF, from, to, type := parse_best_move(cmd_string);
        // TODO: parse best move could fail, what to do if that happens????
        assert(TF);
        uci_state = .UCI_IDLE;
        actual_move := find_move(<<moves_arr, from, to, type);
        ui_handle_move_made(piece_bitboard, flags, ep_sq, moves_arr, actual_move);
        last_move_bb = from|to;
      }
    }
  }

  parse_best_move :: (best_move_string: string) -> TF: bool, from: u64, to: u64, type: Move16 {
    move_sq_string := advance(best_move_string, 9);
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
    if move_sq_string.count >= 5 {
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


#scope_file

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
    close(pipe_1[1]);
    close(pipe_2[0]);
    __write_pipe = pipe_2[1];
    __read_pipe  = pipe_1[0];
    __commands_string_array.allocator = __temporary_allocator; 
    __engine_name = engine_name;
    __commands_string_array.allocator = __temporary_allocator;
    return true; 
  }
}

uci_write_command :: (command: string) {
  write(__write_pipe, command.data, xx command.count);
}

uci_read_incoming_commands :: (num_bytes : int = 16384) {
  __buffer := NewArray(num_bytes, u8, initialized=false, allocator=__temporary_allocator);
  bytes_read := read(__read_pipe, __buffer.data, cast(u64)(num_bytes-1));
  if bytes_read == 0 return;
  if bytes_read < 0 {
    print("uci_read_incoming_commands error, bytes_read = %.\n", bytes_read);
    return;
  }
  data: *u8 = __buffer.data;
  start := 0;
  for i: 0 .. bytes_read-1 {
    if __buffer[i] == #char "\n" {
      cmd_string: string; 
      cmd_string.data = data;
      cmd_string.count = (i - start);
      cmd_string_to_add := join(to_string(__edge_case_buffer.data, __edge_case_count), cmd_string);
      array_add(*__commands_string_array, cmd_string_to_add);
      data = * (__buffer[i+1]);
      start = min(i+1, bytes_read-1);
      break;
    }
  }

  for i: start .. bytes_read-1 {
    if __buffer[i] == #char "\n" {
      cmd_string: string;
      cmd_string.data = data;
      cmd_string.count = (i - start);
      array_add(*__commands_string_array, cmd_string);
      data = * (__buffer[i+1]);
      start = min(i+1, bytes_read-1);
    }
  }
  
  // detect an edge case.
  if start == (bytes_read-1) {
    __edge_case_count = bytes_read - start - 1;
    memcpy(__edge_case_buffer.data, data, __edge_case_count);
  }
}

uci_has_commands :: inline () -> bool {
  return __commands_string_array.count > 0;
}

uci_getline :: inline () -> string {
  ret := pop(*__commands_string_array);
  print("Engine Debug [%]: %\n", __engine_name, ret);
  return ret;
}

uci_close_chess_engine :: () {
  // NOTE: this function does NOT call "uci_write_command("quit")",
  // that needs to be called explicitly
  wait(null);
  close(__write_pipe);
  close(__read_pipe);
}

__read_pipe:  s32;
__write_pipe: s32;
__commands_string_array: [..] string;

__edge_case_buffer: [4096] u8;
__edge_case_count := 0;


__engine_name : string;  // name of engine. exists for aesthetic purposes
__engine_depth_parameter : int = 15; // depth of engine search.



