#import "Basic";
#import "Math";
#import "Render";
#import "glfw";
#import "GL";

main :: () {
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
  init_global_bitboards();
  moves_arr: [..] Move16;
  piece_bitboard := chess_start_pos();
  generate_legal_moves(*piece_bitboard, Castling.All, *moves_arr, true);

  white_side := true;

  while !glfwWindowShouldClose(window) {
    width, height : s32;
    glfwGetFramebufferSize(window, *width, *height);
    glViewport(0, 0, xx width, xx height);
    glClearColor(0.15555, 0.15555, 0.15555, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    im_draw_setup_gl();
    im_set_viewport_transform(2.0/width, 2.0/height, -1, -1);
    white_side = handle_flip_board(window, white_side);
    handle_board_click(xx width, xx height, *piece_bitboard, *moves_arr, white_side=white_side);
    draw_chess(xx width, xx height, *piece_bitboard, t, highlight_the_square, possible_moves_bb, last_move_bb, white_side);
    im_flush();
    glfwSwapBuffers(window);
    glfwPollEvents();
    read_mouse_input(window);
  }
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

  // chess.com uses yellow, so we follow their example...
  BLANK    :: Vector4.{1,1,1,1}; 
  GREY     :: Vector4.{.5,.5,.2,.35}; 
  YELLOW   :: Vector4.{.9,.9,0,.35}; 
  LESS     :: Vector4.{1.0, 1.0, 1.0, 0.25};
  RED      :: Vector4.{1, 0.25, 0.25, 0.5};
  draw_bitboard(last_move_bb, u0=0.0, v0=0.0, u1=1.0, v1=1.0, YELLOW);
  draw_bitboard(possible_moves_bb, u0=0.0, v0=0.0, u1=1.0, v1=1.0, RED);

  im_set_texture(texture);

  using pieces;
  // draw the idle piece
  draw_bitboard(w_king, u0=0.0, v0=0.0, u1=1.0/6.0, v1=0.5, BLANK);
  draw_bitboard(w_queen, u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=1.0/2.0, BLANK);
  draw_bitboard(w_rook, u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=1.0/2.0, BLANK);
  draw_bitboard(w_bishop, u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=1.0/2.0, BLANK);
  draw_bitboard(w_knight, u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=1.0/2.0, BLANK);
  draw_bitboard(w_pawn, u0=5.0/6.0, v0=0.0, u1=1.0, v1=1.0/2.0, BLANK);

  draw_bitboard(b_king, u0=0.0, v0=0.5, u1=1.0/6.0, v1=1.0, BLANK);
  draw_bitboard(b_queen, u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0, BLANK);
  draw_bitboard(b_rook, u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0, BLANK);
  draw_bitboard(b_bishop, u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0, BLANK);
  draw_bitboard(b_knight, u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0, BLANK);
  draw_bitboard(b_pawn, u0=5.0/6.0, v0=0.5, u1=1.0, v1=1.0, BLANK);

  // draw the piece being dragged/dropped.
  draw_bitboard(w_king, u0=0.0, v0=0.0, u1=1.0/6.0, v1=0.5, BLANK, true);
  draw_bitboard(w_queen, u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=1.0/2.0, BLANK, true);
  draw_bitboard(w_rook, u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=1.0/2.0, BLANK, true);
  draw_bitboard(w_bishop, u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=1.0/2.0, BLANK, true);
  draw_bitboard(w_knight, u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=1.0/2.0, BLANK, true);
  draw_bitboard(w_pawn, u0=5.0/6.0, v0=0.0, u1=1.0, v1=1.0/2.0, BLANK, true);
 
  draw_bitboard(b_king, u0=0.0, v0=0.5, u1=1.0/6.0, v1=1.0, BLANK, true);
  draw_bitboard(b_queen, u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0, BLANK, true);
  draw_bitboard(b_rook, u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0, BLANK, true);
  draw_bitboard(b_bishop, u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0, BLANK, true);
  draw_bitboard(b_knight, u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0, BLANK, true);
  draw_bitboard(b_pawn, u0=5.0/6.0, v0=0.5, u1=1.0, v1=1.0, BLANK, true);

  draw_bitboard :: (bit_board: u64, $u0: float, $v0: float, $u1: float, $v1: float, $c: Vector4, $draw_mouse_drag := false) #expand {
    value: u64 = 0;
    #if !draw_mouse_drag 
      value = bit_board & ~highlight_square;
    else 
      value = bit_board & highlight_square;

    while value {
      index := serialize_bit(value);
      i := 0;
      j := 0;
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

handle_board_click :: (width: float, height: float, piece_bitboard: *Piece_Bitboards, moves_arr: *[..] Move16, white_side := true) {
  cen_x := width * 0.5; 
  cen_y := height * 0.5;

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x0 := cen_x - len*.5;
  y0 := cen_y - len*.5;

  x1 := cen_x + len*.5;
  y1 := cen_y + len*.5;

  sq: u64 = 0;
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
        make_move(piece_bitboard, mov, whose_turn);
        last_move_bb = from | to;
        whose_turn = !whose_turn;
        array_reset(moves_arr);
        check := generate_legal_moves(piece_bitboard, Castling.All, moves_arr, whose_turn);
        if moves_arr.count == 0 {
          if check {
            if whose_turn {
              print("Black wins! Checkmate!\n");
            } else {
              print("White wins! Checkmate!\n");
            }
          } else {
            print("Stalemate\n");
          }
        }
      }
      highlight_the_square = 0;
      possible_moves_bb = 0;
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

// true=white, 
// false=black.
whose_turn := true; 

highlight_the_square: u64 = 0;
piece_select_state: enum { PIECE_IDLE; PIECE_SELECTED; } = .PIECE_IDLE;
possible_moves_bb: u64 = 0;

last_move_bb: u64 = 0;



