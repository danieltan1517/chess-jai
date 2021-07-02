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
  if !load_texture_from_file(t, "resources/chess_pieces.png") {
    print("Error loading texture");
    return;
  }

  piece_bitboard := chess_start_pos();

  defer {
    destroy_texture(t);
  }
  white_side := true;
  while !glfwWindowShouldClose(window) {
    width, height : s32;
    glfwGetFramebufferSize(window, *width, *height);
    glViewport(0, 0, xx width, xx height);
    glClear(GL_COLOR_BUFFER_BIT);

    im_draw_setup_gl();
    im_set_viewport_transform(2.0/width, 2.0/height, -1, -1);
    white_side = handle_flip_board(window, white_side);
    handle_board_click(xx width, xx height, white_side=white_side);
    draw_chess(xx width, xx height, *piece_bitboard, t, white_side);
    im_flush();

    glfwSwapBuffers(window);
    glfwPollEvents();
    read_mouse_input(window);
  }
}

draw_chess :: (width: float, height: float, pieces: *Piece_Bitboards, texture: *Texture, white_side: bool) {
  // NOTE: chessboard squares itself is same regardless of flipping board
  cen_x := width * 0.5; 
  cen_y := height * 0.5;

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x := cen_x - len*.5;
  y := cen_y - len*.5;

  white_sq_color :: Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
  black_sq_color :: Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};
  im_set_texture(null);

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


  im_set_texture(texture);
  BLANK :: Vector4.{1,1,1,1}; 
  /*value := pieces.w_king;
  while value {
    index := serialize_bit(value);
    i := index &  7;
    j := index >> 3;
    posx := x + i*square_len;
    posy := y + j*square_len;
    im_draw_rect(posx + square_len, posy + square_len, posx, posy, u0=0.0, v0=0.0, u1=1.0/6.0, v1=0.5, c=BLANK);
    value &= (value - 1);
  }*/

  draw_piece(pieces.w_king, u0=0.0, v0=0.0, u1=1.0/6.0, v1=0.5);
  draw_piece(pieces.w_queen, u0=1.0/6.0, v0=0.0, u1=2.0/6.0, v1=1.0/2.0);
  draw_piece(pieces.w_rook, u0=4.0/6.0, v0=0.0, u1=5.0/6.0, v1=1.0/2.0);
  draw_piece(pieces.w_bishop, u0=2.0/6.0, v0=0.0, u1=3.0/6.0, v1=1.0/2.0);
  draw_piece(pieces.w_knight, u0=3.0/6.0, v0=0.0, u1=4.0/6.0, v1=1.0/2.0);
  draw_piece(pieces.w_pawn, u0=5.0/6.0, v0=0.0, u1=1.0, v1=1.0/2.0);

  draw_piece(pieces.b_king, u0=0.0, v0=0.5, u1=1.0/6.0, v1=1.0);
  draw_piece(pieces.b_queen, u0=1.0/6.0, v0=0.5, u1=2.0/6.0, v1=1.0);

  draw_piece(pieces.b_rook, u0=4.0/6.0, v0=0.5, u1=5.0/6.0, v1=1.0);
  draw_piece(pieces.b_bishop, u0=2.0/6.0, v0=0.5, u1=3.0/6.0, v1=1.0);
  draw_piece(pieces.b_knight, u0=3.0/6.0, v0=0.5, u1=4.0/6.0, v1=1.0);
  draw_piece(pieces.b_pawn, u0=5.0/6.0, v0=0.5, u1=1.0, v1=1.0);

  draw_piece :: (bit_board: u64, $u0: float, $v0: float, $u1: float, $v1: float) #expand {
    value := bit_board;
    while value {
      index := serialize_bit(value);
      // white
      i := 0;
      j := 0;
      if white_side {
        i = index &  7;
        j = index >> 3;
      } else {
        i = 7 - index &  7;
        j = 7 - index >> 3;
      }
      posx := x + i*square_len;
      posy := y + j*square_len;
      im_draw_rect(posx, posy + square_len, posx + square_len, posy, u0=u0, v0=v0, u1=u1, v1=v1, c=BLANK);
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

handle_board_click :: (width: float, height: float, white_side := true) {
  //mouse_position_x:     float = 0.0;
  //mouse_position_y:     float = 0.0;
  //mouse_button_1_state: enum {MOUSE_IDLE; MOUSE_PRESSED; MOUSE_HOLD; MOUSE_RELEASE; } = .MOUSE_IDLE;
  cen_x := width * 0.5; 
  cen_y := height * 0.5;

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x0 := cen_x - len*.5;
  y0 := cen_y - len*.5;

  x1 := cen_x + len*.5;
  y1 := cen_y + len*.5;

  if mouse_button_1_state == .MOUSE_PRESSED {
    if x0 <= mouse_position_x && mouse_position_x <= x1 {
      if y0 <= mouse_position_y && mouse_position_y <= y1 {
        if white_side {
          sq_x_clicked: int = xx ((mouse_position_x - x0) / square_len);
          sq_y_clicked: int = 7 - xx ((mouse_position_y - y0) / square_len);
          i := sq_x_clicked + sq_y_clicked * 8;
          sq := cast(bboard) (1 << i);
          print("Board Clicked! (%, %) %\n", sq_x_clicked, sq_y_clicked, sq); 
        } else {
          sq_x_clicked: int = 7 - xx ((mouse_position_x - x0) / square_len);
          sq_y_clicked: int = xx ((mouse_position_y - y0) / square_len);
          i := sq_x_clicked + sq_y_clicked * 8;
          sq := cast(bboard) (1 << i);
          print("Board Clicked! (%, %) %\n", sq_x_clicked, sq_y_clicked, sq); 
        }
      }
    }
  }
  
}

handle_flip_board :: (window: *GLFWwindow, white_side: bool)->bool {
  state := glfwGetKey(window, GLFW_KEY_X);
  if (state == GLFW_PRESS)
  {
    return !white_side;
  }

  return white_side;
}
















