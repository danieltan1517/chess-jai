// global variables.
win: Window_Type;
chess_piece_bitmap: simp.Texture;
setting_bitmap: simp.Texture;
font: *simp.Dynamic_Font;
current_color_theme : s32 = 0;
options_on: bool = false;
display_coordinates: bool = true;
board_orientation: bool = true; // white=true, black=false
sound_on: bool = true;
highlight_moves_check: bool = true;
show_moves: bool = true;
blindfold_mode: bool = false;
commandline_on: bool = false;
game_status: string;
undo_list: [2048] UndoState;
ply := 0;

chess: Chess;
move_bitboards: Move_Bitboards;
highlighted_moves: u64 = 0;
previous_move: u64 = 0;

chess_mouse: ChessMouse = ChessMouse.Idle;
chess_square_select := -1;

// sound play and sound effects
sound_player : *Sound_Player;
sound_quiet_move: *Mixer_Sound_Data;
sound_capture_move: *Mixer_Sound_Data;

// board colors.
white_sq_color := Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
black_sq_color := Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};

// move animation states.
mov_anim_time: float = 0;
mov_anim_complete: float = .12;
mov_anim_state: MovAnim = MovAnim.Idle;

// dt calculation
dt: float = 0;
looptime_begin: float = 0;
looptime_end: float = 0;

// promotion selection
promote_to := -1;
promote_q_select := -1;
promote_r_select := -1;
promote_b_select := -1;
promote_n_select := -1;

main :: () {
  path := path_strip_filename(get_path_of_running_executable());
  set_working_directory(path);

  // initialize chess w/ the starting position.
  // generate chess moves.
  init_global_bitboards();
  chess_startpos(*chess);
  ui_new_game();

  // create a window. 
  // initialize fonts.
  // init ui.
  win = create_window(600, 600, "Chess");
  width, height := simp.get_render_dimensions(win);
  simp.set_render_target(win);

  init_sound();
  init_textures();

  init_fonts(height);
  ui_init();

  ctrl_pressed := 0;

  // main game loop
  while true {
    dt = looptime_end - looptime_begin;
    looptime_begin = looptime_end;

    update_window_events();
    for e: get_window_resizes() {
      // Simp will do nothing if it doesn't care about this window.
      simp.update_window(e.window);
      if e.window == win {
        if e.width != width || e.height != height then {
          width  = e.width;
          height = e.height;
          init_fonts(height);  // Resize the font for the new window size.
        }
      }
    }

    quit := false;

    mouse_event := false;
    key_pressed := 0;
    for e: events_this_frame {
      if e.type == .QUIT then quit = true;
      getrect_handle_event(e);
      if e.type == .KEYBOARD then {
        if e.key_code == .MOUSE_BUTTON_LEFT {
          key_pressed = e.key_pressed;
          mouse_event = true;
        } else if e.key_code == .CTRL {
          ctrl_pressed = e.key_pressed;
        } else if e.key_pressed == 1 && e.key_code == Key_Code_Z && ctrl_pressed {
          ui_undo_move(*chess);
        } else if e.key_pressed == 1 && e.key_code == Key_Code_N && ctrl_pressed {
          chess_startpos(*chess);
          ui_new_game();
        } else if e.key_pressed == 1 && e.key_code == Key_Code_Y && ctrl_pressed {
          ui_redo_move(*chess);
        } else if e.key_pressed == 1 && e.key_code == Key_Code_X && commandline_on == false {
          board_orientation = !board_orientation;
        } else if e.key_pressed == 1 && e.key_code == .ESCAPE {
          commandline_on = !commandline_on;
        }
      }

      Key_Code_Z : Key_Code : #char "Z";
      Key_Code_N : Key_Code : #char "N";
      Key_Code_Y : Key_Code : #char "Y";
      Key_Code_X : Key_Code : #char "X";
    }

    if quit == true then
      break;

    _, __, width, height := get_dimensions(win, true);
    x, y := get_mouse_pointer_position(win, true);
    draw_chess_board(xx width, xx height);
    draw_chess_pieces(xx width, xx height, xx x, xx y, mouse_event, key_pressed);
    draw_ui(width, height);

    pre_entity_update(sound_player);
    for sound_player.streams  it.marked = true;
    post_entity_update(sound_player, dt);


    simp.swap_buffers(win);
    sleep_milliseconds(20);
    reset_temporary_storage();
    looptime_end = cast(float)get_time();
  }


  draw_chess_board :: (width: float, height: float) {
    simp.clear_render_target(0.15555, 0.15555, 0.15555, 1.0);
    simp.set_shader_for_color();
    cen_x := width  / 2;
    cen_y := height / 2;
    square := 0.85 * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;
    white := false;
    for i: 0..7 {
      for j: 0..7 {
        color := ifx white then white_sq_color else black_sq_color;
        p0 := make_vector2(corner_x + i * square, corner_y + j * square);
        p1 := make_vector2(p0.x, p0.y + square);
        p2 := make_vector2(p0.x + square, p0.y + square);
        p3 := make_vector2(p0.x + square, p0.y);
        simp.immediate_quad(p0, p1, p2, p3, color);
        white = ! white;
      }
      white = ! white;
    }

    if display_coordinates then {
      letters : string = ifx board_orientation "abcdefgh" else "hgfedcba";
      numbers : string = ifx board_orientation "12345678" else "87654321";
      num_x: int = xx (corner_x + (square * .05));
      num_y: int = xx (corner_y + (square * .8));
      let_x: int = xx (corner_x + (square * .10));
      let_y: int = xx (corner_y + (square * .05));
      incr: int = cast(int) square;
      TF := true;
      col := white_sq_color;
      for i: 0..7 {

        letter := slice(letters, i, 1);
        number := slice(numbers, i, 1);
        simp.draw_text(font, num_x, num_y, number, col);
        simp.draw_text(font, let_x, let_y, letter, col);
        num_y += incr;
        let_x += incr;
        TF = !TF;
        col = ifx TF white_sq_color else black_sq_color;
        
      }
    }

    if game_status.count > 0 then
      simp.draw_text(font, 10, 10, game_status, Vector4.{1,1,1,1});
  }

  draw_chess_pieces :: (width: float, height: float, x: float, y: float, mouse_event: bool, key_pressed: int) {
    cen_x := width  / 2;
    cen_y := height / 2;
    square := 0.85 * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;
    end_x := corner_x + square * 8.0;
    end_y := corner_y + square * 8.0;

    if !options_on && mouse_event {
      if x >= corner_x && x <= end_x && y >= corner_y && y <= end_y then {
        mouse_coor_x := cast(int) ((x - corner_x) / square);
        mouse_coor_y := cast(int) ((y - corner_y) / square);
        if board_orientation == false then {
          mouse_coor_x = 7 - mouse_coor_x;
          mouse_coor_y = 7 - mouse_coor_y;
        }
        position := mouse_coor_x + mouse_coor_y * 8;
     
        if chess_mouse == {
        case .Idle;
          promote_to = -1;
          promote_q_select = -1;
          promote_r_select = -1;
          promote_b_select = -1;
          promote_n_select = -1;
          highlighted_moves = 0;
          if key_pressed == 1 {
            chess_mouse = ChessMouse.Drag;
            chess_square_select = position;
            highlighted_moves = move_bitboards.bitboard[chess_square_select];
          }
        case .Drag;
          if key_pressed == 0 {
            if chess_square_select == position {
              chess_mouse = ChessMouse.Select;
            } else {
              chess_mouse = ChessMouse.Idle;
              highlighted_moves = 0;
              from := chess_square_select;
              to := position;
              flag := get_move16_flag(*chess, from, to, #char "q");
              mov := to_move16(from, to, flag);
              piece := chess.pieces[from];
              if flag > Move16.Ep_Capture {
                if is_legal(*chess, mov) {
                  chess_mouse = ChessMouse.Promote;
                  promote_to = to;
                  if chess.turn == Turn.WHITE {
                    promote_q_select = to - 8;
                    promote_r_select = promote_q_select - 8;
                    promote_b_select = promote_r_select - 8;
                    promote_n_select = promote_b_select - 8;
                  } else {
                    promote_q_select = to + 8;
                    promote_r_select = promote_q_select + 8;
                    promote_b_select = promote_r_select + 8;
                    promote_n_select = promote_b_select + 8;
                  }
                } else {
                  chess_mouse = ChessMouse.Idle;
                  chess_square_select = -1;
                  highlighted_moves = 0;
                }
              } else {
                ui_make_move(*chess, mov, false);
                chess_square_select = -1;
                highlighted_moves = 0;
              }
            }
          }
        case .Select;
          piece := chess.pieces[position];
          using Turn; using Piece;
          if ((chess.turn == WHITE && piece >= W_KING && piece <= W_PAWN) || (chess.turn == BLACK && piece >= B_KING && piece <= B_PAWN)) {
            if chess_square_select == position {
              chess_mouse = ChessMouse.Idle;
              chess_square_select = -1;
              highlighted_moves = 0;
            } else {
              chess_mouse = ChessMouse.Drag;
              chess_square_select = position;
              highlighted_moves = move_bitboards.bitboard[chess_square_select];
            }
          } else {
            chess_mouse = ChessMouse.Idle;
            from := chess_square_select;
            to := position;
            flag := get_move16_flag(*chess, from, to, #char "q");
            mov := to_move16(from, to, flag);
            piece := chess.pieces[from];
            if flag > Move16.Ep_Capture {
              if is_legal(*chess, mov) {
                chess_mouse = ChessMouse.Promote;
                promote_to = to;
                if chess.turn == Turn.WHITE {
                  promote_q_select = to - 8;
                  promote_r_select = promote_q_select - 8;
                  promote_b_select = promote_r_select - 8;
                  promote_n_select = promote_b_select - 8;
                } else {
                  promote_q_select = to + 8;
                  promote_r_select = promote_q_select + 8;
                  promote_b_select = promote_r_select + 8;
                  promote_n_select = promote_b_select + 8;
                }
              } else {
                chess_mouse = ChessMouse.Idle;
                chess_square_select = -1;
                highlighted_moves = 0;
              }
            } else {
              ui_make_move(*chess, mov, false);
              chess_square_select = -1;
              highlighted_moves = 0;
            }
          }
        case .Promote;
          char: u8 = #char " ";
          to := promote_to;
          if position == promote_q_select || position == promote_to {
            char = #char "q";
          } else if position == promote_r_select {
            char = #char "r";
          } else if position == promote_b_select {
            char = #char "b";
          } else if position == promote_n_select {
            char = #char "n";
          }
          chess_mouse = ChessMouse.Idle;
          from := chess_square_select;
          flag := get_move16_flag(*chess, from, to, char);
          mov := to_move16(from, to, flag);
          ui_make_move(*chess, mov, false);
          chess_square_select = -1;
          highlighted_moves = 0;
        }
      } else {
        // outside of the board.
        chess_mouse = ChessMouse.Idle;
        chess_square_select = -1;
        highlighted_moves = 0;
      }
    }


    simp.immediate_begin();

    for piece, index: chess.pieces {
      row := 0; 
      col := 0; 

      if board_orientation then {
        row = index % 8;
        col = index / 8;
      } else {
        row = 7 - index % 8;
        col = 7 - index / 8;
      }

      p0 := make_vector2(corner_x + square * row, corner_y + square * col);
      p1 := make_vector2(p0.x, p0.y + square);
      p2 := make_vector2(p0.x + square, p0.y + square);
      p3 := make_vector2(p0.x + square, p0.y);

      bitboard := cast(u64) (1 << index);

      if highlight_moves_check == true {
        // draw previous move.
        if bitboard & previous_move then {
          simp.set_shader_for_color(true);
          prev_color :: Vector4.{.9,.9,0,.55};
          simp.immediate_quad(p0, p1, p2, p3, prev_color);
        }
      }
      
      if show_moves == true { 
        // draw highlighted moves.
        if bitboard & highlighted_moves then {
          if (bitboard & chess.occupied) == 0 {
            p0.x += square *.4;
            p0.y += square *.4;
            p1.x += square *.4;
            p1.y -= square *.4;
            p2.x -= square *.4;
            p2.y -= square *.4;
            p3.x -= square *.4;
            p3.y += square *.4;
            draw_quiet_move_suggestion(p0,p1,p2,p3);
          } else {
            draw_move_suggestion(p0, p1, p2, p3);
          }
        }
      }
      if chess_square_select == index && chess_mouse == .Drag
        continue;
      if mov_anim_state == .Play && previous_move & bitboard then
        continue;

      darkness := false;
      if chess_mouse == .Promote {
        simp.set_shader_for_color(true);
        COL :: Vector4.{1.,1.,1.,.85};
        if index == promote_q_select {
          piece = ifx chess.turn == .WHITE Piece.W_QUEEN else Piece.B_QUEEN;
          simp.immediate_quad(p0, p1, p2, p3, COL);
        } else if index == promote_r_select {
          piece = ifx chess.turn == .WHITE Piece.W_ROOK else Piece.B_ROOK;
          simp.immediate_quad(p0, p1, p2, p3, COL);
        } else if index == promote_b_select {
          piece = ifx chess.turn == .WHITE Piece.W_BISHOP else Piece.B_BISHOP;
          simp.immediate_quad(p0, p1, p2, p3, COL);
        } else if index == promote_n_select {
          piece = ifx chess.turn == .WHITE Piece.W_KNIGHT else Piece.B_KNIGHT;
          simp.immediate_quad(p0, p1, p2, p3, COL);
        } else if index == promote_to {
          piece = determine_piece(x, y, corner_x, corner_y, end_x, end_y, square);
        } else {
          darkness = true;
        }
      } 

      if chess_square_select != index || chess_mouse != .Promote || promote_q_select == chess_square_select
        draw_piece(p0, p1, p2, p3, piece);
      if darkness == true then {
        simp.set_shader_for_color(true);
        DARK :: Vector4.{.0,.0,.0,.45};
        simp.immediate_quad(p0, p1, p2, p3, DARK);
      }
    }

    if chess_mouse == ChessMouse.Drag then {
      p0 := make_vector2(x - square * 0.5, y - square * 0.5);
      p1 := make_vector2(p0.x, p0.y + square);
      p2 := make_vector2(p0.x + square, p0.y + square);
      p3 := make_vector2(p0.x + square, p0.y);
      assert(chess_square_select >= 0 && chess_square_select <= 63);
      piece := chess.pieces[chess_square_select];
      draw_piece(p0, p1, p2, p3, piece);
    }

    if mov_anim_state == MovAnim.Play && previous_move then {
      mov := undo_list[ply-1].move;
      _, from, to := decode_move16(mov);
      piece := chess.pieces[to];

      from_x := from % 8;
      from_y := from / 8;

      to_x := to % 8;
      to_y := to / 8;

      from_vector: Vector2; 
      from_vector.x = corner_x + square * from_x;
      from_vector.y = corner_y + square * from_y;

      to_vector: Vector2;
      to_vector.x = corner_x + square * to_x;
      to_vector.y = corner_y + square * to_y;

      ratio := mov_anim_time / mov_anim_complete;
      mov_anim_time += dt;
      if mov_anim_time >= mov_anim_complete {
        mov_anim_time = 0;
        mov_anim_state = MovAnim.Idle;
      }
      p0 := lerp(from_vector, to_vector, ratio);
      p1 := make_vector2(p0.x, p0.y + square);
      p2 := make_vector2(p0.x + square, p0.y + square);
      p3 := make_vector2(p0.x + square, p0.y);
      draw_piece(p0, p1, p2, p3, piece);
    }

    simp.immediate_flush();

    determine_piece :: (x: float, y: float, corner_x: float, corner_y: float, end_x: float, end_y: float, square: float) -> Piece {
      promotion_select_piece := Piece.NONE;
      if chess_mouse == .Promote {
        if chess.turn == .WHITE
          promotion_select_piece = Piece.W_QUEEN;
        else
          promotion_select_piece = Piece.B_QUEEN;
        if x >= corner_x && x <= end_x && y >= corner_y && y <= end_y then {
          mouse_coor_x := cast(int) ((x - corner_x) / square);
          mouse_coor_y := cast(int) ((y - corner_y) / square);
          if board_orientation == false then {
            mouse_coor_x = 7 - mouse_coor_x;
            mouse_coor_y = 7 - mouse_coor_y;
          }
          position := mouse_coor_x + mouse_coor_y * 8;
          if position == promote_q_select {
            promotion_select_piece = ifx chess.turn == .WHITE Piece.W_QUEEN else Piece.B_QUEEN;
          } else if position == promote_r_select {
            promotion_select_piece = ifx chess.turn == .WHITE Piece.W_ROOK else Piece.B_ROOK;
          } else if position == promote_b_select {
            promotion_select_piece = ifx chess.turn == .WHITE Piece.W_BISHOP else Piece.B_BISHOP;
          } else if position == promote_n_select {
            promotion_select_piece = ifx chess.turn == .WHITE Piece.W_KNIGHT else Piece.B_KNIGHT;
          }
        }
      }
      return promotion_select_piece;
    }
  }

  draw_quiet_move_suggestion :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    simp.set_shader_for_color(true);
    col :: Vector4.{.0,.0,.0,.1};
    simp.immediate_quad(p0, p1, p2, p3, col);
  }

  draw_move_suggestion :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    simp.set_shader_for_images(*setting_bitmap);
    col :: Vector4.{0,0,0,.1};
    uv0 :: Vector2.{.3, .3};
    uv1 :: Vector2.{.7, .3};
    uv2 :: Vector2.{.7, .7};
    uv3 :: Vector2.{.3, .7};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_piece :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, piece: Piece) {
    if blindfold_mode == true then return;

    if piece == Piece.NONE return;
    simp.set_shader_for_images(*chess_piece_bitmap);
    if piece == {
    case  Piece.W_KING;
      draw_wking(p0, p1, p2, p3);
    case  Piece.W_QUEEN;
      draw_wqueen(p0, p1, p2, p3);
    case  Piece.W_ROOK;
      draw_wrook(p0, p1, p2, p3);
    case  Piece.W_BISHOP;
      draw_wbishop(p0, p1, p2, p3);
    case  Piece.W_KNIGHT;
      draw_wknight(p0, p1, p2, p3);
    case  Piece.W_PAWN;
      draw_wpawn(p0, p1, p2, p3);
    case  Piece.B_KING;
      draw_bking(p0, p1, p2, p3);
    case  Piece.B_QUEEN;
      draw_bqueen(p0, p1, p2, p3);
    case  Piece.B_ROOK;
      draw_brook(p0, p1, p2, p3);
    case  Piece.B_BISHOP;
      draw_bbishop(p0, p1, p2, p3);
    case  Piece.B_KNIGHT;
      draw_bknight(p0, p1, p2, p3);
    case  Piece.B_PAWN;
      draw_bpawn(p0, p1, p2, p3);
    }
  }

  draw_ui :: (width: s32, height: s32) {
    ui_per_frame_update(win, width, height, looptime_end);

    button_height := height * .03;

    button_theme: Button_Theme;  // This will have the default Button_Theme values.
    button_theme.font = font;
    button_theme.frame_color = Vector4.{.40, .40, .50, 0.0};
    button_theme.frame_color_over = Vector4.{.55, .55, .45, 0.0};
    button_theme.frame_color_flash = Vector4.{.99, .99, .65, 0.0};
    button_theme.frame_color_down = Vector4.{.75, .75, .55, 0.0};
    // 'k' is some resolution-adjusting unit of distance. Right now it is
    // 1/10 of the screen height, so, 108 pixels at 1920x1080.
    k := height * .045;
    r := get_rect(xx width - 1.1 * k, xx height - 1.1 * k, k, k);

    button_theme.label_theme.alignment = .Left;
    if button(r, "", *button_theme, texture=*setting_bitmap) then {
      options_on = !options_on;
    }

    if commandline_on == true {
      r2 := get_rect(10.0, 10.0, cast(float)width - 20.0, k);
      text_theme: Text_Input_Theme;
      text_theme.font = font;
      action, console_string, state := text_input(r2, "", *text_theme);
      if action & .ENTERED {
        tf, mov := parse_move(console_string);
        if tf {
          ui_make_move(*chess, mov, true);
          if chess_mouse == ChessMouse.Promote then {
            chess_mouse = ChessMouse.Idle;
            chess_square_select = -1;
            highlighted_moves = 0;
            return;
          }
        } else {
          token, TF := parse_token(*console_string);
          console_string = eat_spaces(console_string);
          if TF && equal(token, "fen") {
            if !chess_fen(*chess, console_string) {
              chess_startpos(*chess);
            }
            ui_new_game();
          }
        }
        reset(state);
        activate(state);
      }
    }
    
    if options_on then {
      simp.set_shader_for_color();
      r.x -= k*0.2;
      simp.immediate_quad(r.x - k*7.2, r.y, r.x + k*7.0, r.y - k*15.75, color = Vector4.{.22, .22, .22, 1});
      // Color Dropdown Menu.
      r.x -= k*7.0;
      r.y -= k*1.2;
      r.w = k*8.0;
      r.h = k;

      if button(r, "New Game (Ctrl+N)", *button_theme) then {
        chess_startpos(*chess);
        ui_new_game();
      }

      r.y -= k*1.1;

      if button(r, "Undo (Ctrl+Z)", *button_theme) then {
        ui_undo_move(*chess);
      }

      r.y -= k*1.1;

      if button(r, "Redo (Ctrl+Y)", *button_theme) then {
        ui_redo_move(*chess);
      }

      r.y -= k*1.1;
      label_theme: Label_Theme;
      label_theme.alignment = .Left;
      label_theme.font = font;
      label_theme.alignment_pad_ems = .25;
      label(r, "Board Theme", *label_theme);

      dropdown_theme := *default_overall_theme.dropdown_theme;
      dropdown_theme.theme_for_current_value.alignment = .Left;
      dropdown_theme.theme_for_each_choice.alignment = .Left;
      dropdown_theme.theme_for_current_choice.alignment = .Left;
      dropdown_theme.theme_for_current_value.font = font;
      dropdown_theme.theme_for_each_choice.font = font;
      dropdown_theme.theme_for_current_choice.font = font;
       
      old_color_theme := current_color_theme;
      r.y -= k*0.9;
      dropdown(r, COLORS, *current_color_theme, dropdown_theme);
     
      COLORS :: string.["green", "blue", "grey", "brown", "purple", "red"]; 
      checkbox_theme: Checkbox_Theme;
      checkbox_theme.font = font;

      r.y -= k*1.1;
      if base_checkbox(r, "Board Orientation", board_orientation, *checkbox_theme) then {
        board_orientation = !board_orientation;
      }

      r.y -= k*1.1;

      if base_checkbox(r, "Display Coordinates", display_coordinates, *checkbox_theme) then {
        display_coordinates = !display_coordinates;
      }

      r.y -= k*1.1;

      if base_checkbox(r, "Audio", sound_on, *checkbox_theme) then {
        sound_on = !sound_on;
      }

      r.y -= k*1.1;

      if base_checkbox(r, "Highlight Moves", highlight_moves_check, *checkbox_theme) then {
        highlight_moves_check = !highlight_moves_check;
      }

      r.y -= k*1.1;

      if base_checkbox(r, "Show Legal Moves", show_moves, *checkbox_theme) then {
        show_moves = !show_moves;
      }

      r.y -= k*1.1;

      if base_checkbox(r, "Blindfold Mode", blindfold_mode, *checkbox_theme) then {
        blindfold_mode = !blindfold_mode;
      }

      r.y -= k*1.1;

      if base_checkbox(r, "Animations", mov_anim_state != MovAnim.Off, *checkbox_theme) then {
        if mov_anim_state == MovAnim.Off
          mov_anim_state = MovAnim.Idle;
        else
          mov_anim_state = MovAnim.Off;
      }

      r.y -= k*1.1;

      slider_theme: Slider_Theme;
      slider_theme.foreground.font = font;
      slider(r, *mov_anim_complete, 0.00, .32, 0.01, *slider_theme, "", " Animation");
     

      r.y -= k*1.1;

      if base_checkbox(r, "Command Line", commandline_on, *checkbox_theme) then {
        commandline_on = !commandline_on;
      }


      draw_popups();  // This draws Subwindows as well.
      if old_color_theme != current_color_theme {
        if current_color_theme == {
        case 0; 
          //green
          white_sq_color = Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
          black_sq_color = Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};
        case 1; 
          //blue
          white_sq_color = Vector4.{0.871, 0.890, 0.902, 1.0}; 
          black_sq_color = Vector4.{0.549, 0.635, 0.678, 1.0};
        case 2; 
          //grey
          white_sq_color = Vector4.{0.655, 0.655, 0.655, 1.0};
          black_sq_color = Vector4.{0.525, 0.525, 0.525, 1.0};
        case 3; 
          //brown
          white_sq_color = Vector4.{0.941, 0.851, 0.710, 1.0};
          black_sq_color = Vector4.{0.710, 0.533, 0.388, 1.0};
        case 4; 
          //purple
          white_sq_color = Vector4.{0.902, 0.859, 0.945, 1.0};
          black_sq_color = Vector4.{0.600, 0.490, 0.710, 1.0};
        case 5; 
          //red 
          white_sq_color = Vector4.{0.941, 0.847, 0.749, 1.0};
          black_sq_color = Vector4.{0.729, 0.333, 0.275, 1.0};
        }
      }
    }
  }

  draw_brook :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{4.0/6.0, 0.0};
    uv1 :: Vector2.{4.0/6.0, 0.5};
    uv2 :: Vector2.{5.0/6.0, 0.5};
    uv3 :: Vector2.{5.0/6.0, 0.0};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_wrook :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{4.0/6.0, 0.5};
    uv1 :: Vector2.{4.0/6.0, 1.0};
    uv2 :: Vector2.{5.0/6.0, 1.0};
    uv3 :: Vector2.{5.0/6.0, 0.5};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_bknight :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{3.0/6.0, 0.0};
    uv1 :: Vector2.{3.0/6.0, 0.5};
    uv2 :: Vector2.{4.0/6.0, 0.5};
    uv3 :: Vector2.{4.0/6.0, 0.0};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_wknight :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{3.0/6.0, 0.5};
    uv1 :: Vector2.{3.0/6.0, 1.0};
    uv2 :: Vector2.{4.0/6.0, 1.0};
    uv3 :: Vector2.{4.0/6.0, 0.5};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_wbishop :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{2.0/6.0, 0.5};
    uv1 :: Vector2.{2.0/6.0, 1.0};
    uv2 :: Vector2.{3.0/6.0, 1.0};
    uv3 :: Vector2.{3.0/6.0, 0.5};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_bbishop :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{2.0/6.0, 0.0};
    uv1 :: Vector2.{2.0/6.0, 0.5};
    uv2 :: Vector2.{3.0/6.0, 0.5};
    uv3 :: Vector2.{3.0/6.0, 0.0};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_bqueen :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{1.0/6.0, 0.0};
    uv1 :: Vector2.{1.0/6.0, 0.5};
    uv2 :: Vector2.{2.0/6.0, 0.5};
    uv3 :: Vector2.{2.0/6.0, 0.0};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_wqueen :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{1.0/6.0, 0.5};
    uv1 :: Vector2.{1.0/6.0, 1.0};
    uv2 :: Vector2.{2.0/6.0, 1.0};
    uv3 :: Vector2.{2.0/6.0, 0.5};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_bking :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{0.0/6.0, 0.0};
    uv1 :: Vector2.{0.0/6.0, 0.5};
    uv2 :: Vector2.{1.0/6.0, 0.5};
    uv3 :: Vector2.{1.0/6.0, 0.0};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_wking :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{0.0/6.0, 0.5};
    uv1 :: Vector2.{0.0/6.0, 1.0};
    uv2 :: Vector2.{1.0/6.0, 1.0};
    uv3 :: Vector2.{1.0/6.0, 0.5};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_wpawn :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{5.0/6.0, 0.5};
    uv1 :: Vector2.{5.0/6.0, 1.0};
    uv2 :: Vector2.{6.0/6.0, 1.0};
    uv3 :: Vector2.{6.0/6.0, 0.5};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  draw_bpawn :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) #expand {
    col :: Vector4.{1, 1, 1, 1};
    uv0 :: Vector2.{5.0/6.0, 0.0};
    uv1 :: Vector2.{5.0/6.0, 0.5};
    uv2 :: Vector2.{6.0/6.0, 0.5};
    uv3 :: Vector2.{6.0/6.0, 0.0};
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  init_fonts :: (height: int) {
    // Resize the font for the new window size.
    pixel_height := height / 32;
    font = simp.get_font_at_size("resources", "AnonymousPro.ttf", pixel_height);
    assert(font != null, "font not loaded properly");
  }

  init_sound :: () {
    sound_player = New(Sound_Player);
    sound_player.update_history = true;
    sound_quiet_move = load_wav_file("resources/move.wav");
    assert(sound_quiet_move != null);

    sound_capture_move = load_wav_file("resources/capture.wav");
    assert(sound_capture_move != null);

    // initialize sound player
    success := init(sound_player, win, true, true);
    assert(success);
  }


  load_wav_file :: (name: string) -> *Mixer_Sound_Data {
    file_data, success := read_entire_file(name);
    assert(success);
    data := New(Mixer_Sound_Data);
    data.name = copy_string(name);
    data.buffer = file_data;

    format, samples, success2, extra := get_wav_header(data.buffer);
    if !success2 {
      log("Unable to parse '%' as wav.\n", data.full_path);
      return data;
    }

    if format.wFormatTag == WAVE_FORMAT_PCM {
      data.type = Mixer_Sound_Data.Type.LINEAR_SAMPLE_ARRAY;
      data.nchannels = cast(u16) format.nChannels;
      data.nsamples_times_nchannels = samples.count/2;
    } else if format.wFormatTag == WAVE_FORMAT_DVI_ADPCM {
      data.type = Mixer_Sound_Data.Type.ADPCM_COMPRESSED;
      data.wSamplesPerBlock = extra.wSamplesPerBlock;
      data.nBlockAlign = format.nBlockAlign;
      data.nchannels = cast(u16) format.nChannels;
      data.nsamples_times_nchannels = extra.wSamplesAccordingToFactChunk * data.nchannels;
    } else {
      assert(false);
    }

    data.samples = cast(*s16) samples.data;
    data.sampling_rate = cast(u32) format.nSamplesPerSec;
    return data;
  }


  init_textures :: () {
    success := simp.texture_load_from_file(*chess_piece_bitmap, "resources/chess_pieces.png");
    assert(success);
    success = simp.texture_load_from_file(*setting_bitmap, "resources/settings_icon.png");
    assert(success);
  }

  GREY_SHADE_BOARD :: Vector4.{0.2, 0.2, 0.2, 0.35};
}

get_move16_flag :: (chess: *Chess, from: int, to: int, p: u8) -> Move16 {
  using Move16;
  piece := chess.pieces[from];
  topiece := chess.pieces[to];

  if piece == {
  case  Piece.NONE;
    return Quiet;
  case  Piece.W_KING;
    if cast(serialized_bb)from == serialized_bb.e1 && cast(serialized_bb)to == serialized_bb.g1 then
      return King_Castle;
    if cast(serialized_bb)from == serialized_bb.e1 && cast(serialized_bb)to == serialized_bb.c1 then
      return Queen_Castle;

  case  Piece.W_QUEEN;
  case  Piece.W_ROOK;
  case  Piece.W_BISHOP;
  case  Piece.W_KNIGHT;
  case  Piece.W_PAWN;
    fbb := cast(Bitboard) (1 << from);
    tbb := cast(Bitboard) (1 << to);
    if (fbb & rank_2) && (tbb & rank_4) then
      return Double_Pawn_Push;
    if cast(u64)tbb == chess.en_passant then
      return Ep_Capture;
    if tbb & rank_8 then {
      if topiece == Piece.NONE
        return promote(p);
      return promote_cap(p);
    }
    
  case  Piece.B_KING;
    if cast(serialized_bb)from == serialized_bb.e8 && cast(serialized_bb)to == serialized_bb.g8 then
      return King_Castle;
    if cast(serialized_bb)from == serialized_bb.e8 && cast(serialized_bb)to == serialized_bb.c8 then
      return Queen_Castle;

  case  Piece.B_QUEEN;
  case  Piece.B_ROOK;
  case  Piece.B_BISHOP;
  case  Piece.B_KNIGHT;
  case  Piece.B_PAWN;
    fbb := cast(Bitboard) (1 << from);
    tbb := cast(Bitboard) (1 << to);
    if (fbb & rank_7) && (tbb & rank_5) then
      return Double_Pawn_Push;
    if cast(u64)tbb == chess.en_passant then
      return Ep_Capture;
    if tbb & rank_1 then {
      if topiece == Piece.NONE
        return promote(p);
      return promote_cap(p);
    }

  }

  if topiece == Piece.NONE then
    return Quiet;
  else
    return Capture;

  promote :: (p: u8) -> Move16 {
    if p == #char "q" return Queen_Promotion;
    if p == #char "r" return Rook_Promotion;
    if p == #char "b" return Bishop_Promotion;
    if p == #char "n" return Knight_Promotion;
    return 0;
  }

  promote_cap :: (p: u8) -> Move16 {
    if p == #char "q" return Queen_Promotion_Capture;
    if p == #char "r" return Rook_Promotion_Capture;
    if p == #char "b" return Bishop_Promotion_Capture;
    if p == #char "n" return Knight_Promotion_Capture;
    return 0;
  }
}


add_move :: (chess: *Chess, moves: *Move_Bitboards, from: int, to: int, flags: Move16, in_check: bool) {
  moves.bitboard[from] |= cast(u64) (1 << to);
  moves.count += 1;
}

clear :: (moves: *Move_Bitboards) #expand {
  memset(moves, 0, size_of(Move_Bitboards));
}

clear_undo :: () #expand {
  memset(*undo_list, 0, size_of(type_of(undo_list)));
  ply = 0;
}

ui_make_move :: (chess: *Chess, mov: Move16, animate: bool) {
  // in case
  if ply >= undo_list.count {
    game_status = "Draw by Fifty Move Rule.";
    return;
  }

  if is_legal(chess, mov) then {
    _, from, to := decode_move16(mov);
    previous_move = (cast(u64) (1 << from)) | (cast(u64) (1 << to));
    cap, flags, hash := make_move(chess, mov);

    // store the undo state so we can restore it if needed.
    undo_list[ply].move = mov;
    undo_list[ply].cap = cap;
    undo_list[ply].flags = flags;
    undo_list[ply].hash = hash;
    ply += 1;

    // zero the next move
    // so we don't accidentally redo an illegal move.
    undo_list[ply].move = 0;

    clear(*move_bitboards);
    generate_moves(chess, *move_bitboards);

    if move_bitboards.count == 0 then {
      if in_check(chess) {
        game_status = "Checkmate.";
      } else {
        game_status = "Stalemate.";
      }
    } else if in_check(chess) {
      game_status = "Check.";
    } else {
      game_status = "";
    }

    cur_hash := chess.hash;
    count := 0;
    for < index: ply-1..0 {
      if get_move16_flag(undo_list[index].move) >= Move16.Double_Pawn_Push
        break;
      if undo_list[index].hash == cur_hash {
        count += 1;
      }
    }
    if count >= 2 then {
      game_status = "Draw by Threefold Repetition.";
    }

    if animate && mov_anim_state == MovAnim.Idle then {
      mov_anim_time = 0.0;
      mov_anim_state = MovAnim.Play;
    }

    // play sound only if the sound_on is true
    if sound_on == true {

      // pick the sound to play based on the type of move
      using Move16;
      flag := get_move16_flag(mov);
      sound: *Mixer_Sound_Data;
      if flag <= Double_Pawn_Push 
        sound = sound_quiet_move;
      else if flag == King_Castle 
        sound = sound_quiet_move;
      else if flag == Queen_Castle
        sound = sound_quiet_move;
      else if flag >= Knight_Promotion && flag <= Queen_Promotion
        sound = sound_quiet_move;
      else
        sound = sound_capture_move;

      stream := play_sound(sound);
    }
  }
}

ui_undo_move :: (chess: *Chess) {
  if ply <= 0 then return;

  if chess_mouse == ChessMouse.Promote then {
    chess_mouse = ChessMouse.Idle;
    chess_square_select = -1;
    highlighted_moves = 0;
    return;
  }

  ply -= 1;
  mov := undo_list[ply].move;
  cap := undo_list[ply].cap;
  flags := undo_list[ply].flags;
  hash := undo_list[ply].hash;
  unmake_move(chess, mov, cap, flags, hash);
  clear(*move_bitboards);
  generate_moves(chess, *move_bitboards);

  // update the display variables with the relevant data.
  if ply <= 0 then {
    previous_move = 0;
  } else {
    prev_move := undo_list[ply-1].move;
    _, from, to := decode_move16(prev_move);
    previous_move = (cast(u64) (1 << from)) | (cast(u64) (1 << to));
  }

  if in_check(chess) {
    game_status = "Check.";
  } else {
    game_status = "";
  }
}

ui_redo_move :: (chess: *Chess) {
  mov := undo_list[ply].move;
  if mov == 0 then return;
  next := undo_list[ply+1].move;
  ui_make_move(chess, mov, true);
  undo_list[ply].move = next;
}

get_uci_board_string :: () -> string {
  builder: String_Builder;
  builder.allocator = temp;
  append(*builder, "position startpos");
  if ply > 0
    append(*builder, " moves");
  for index: 0..ply-1 {
    move := undo_list[index].move;
    append(*builder, " ");
    append(*builder, move);
  }
  return builder_to_string(*builder, allocator=temp);
}

play_sound :: (data: *Mixer_Sound_Data, perturb: bool = true) -> *Sound_Stream {
  stream := make_stream(sound_player, data);

  if stream {
    stream.sound_data = data;
  }

  if perturb && stream {
    stream.user_volume_scale = random_get_within_range(0.7, 1.0);
    stream.desired_rate = random_get_within_range(0.7, 1.22);
  }

  if stream {
    // @Temporary @Hack! We do not get the duration by default from an ogg file...
    stream.repeat_end_position = cast(int)(data.sampling_rate * 234.475);
  }
  
  return stream;
}

parse_move :: (str: string) -> bool, Move16 {
  if str.count < 4 || str.count > 5 return false, 0;
  a := cast(int)(str[0] - #char "a");
  b := cast(int)(str[1] - #char "1");
  c := cast(int)(str[2] - #char "a");
  d := cast(int)(str[3] - #char "1");

  if a < 0 || a > 7 then
    return false, 0;
  if b < 0 || b > 7 then
    return false, 0;
  if c < 0 || c > 7 then
    return false, 0;
  if d < 0 || d > 7 then
    return false, 0;

  from := b*8 + a;
  to   := d*8 + c;
  p    := ifx (str.count == 5) str[4] else #char " ";
  flag := get_move16_flag(*chess, from, to, p);
  mov := to_move16(from, to, flag);
  return true, mov;
}

ui_new_game :: () {
  clear(*move_bitboards);
  generate_moves(*chess, *move_bitboards);
  highlighted_moves = 0;
  game_status = "";
  previous_move = 0;
  clear_undo();
  if chess_mouse == ChessMouse.Promote then {
    chess_mouse = ChessMouse.Idle;
    chess_square_select = -1;
    highlighted_moves = 0;
    return;
  }
}

ChessMouse :: enum {
  Idle;
  Drag;
  Select;
  Promote;
}

MovAnim :: enum {
  Off;
  Idle;
  Play;
}

UndoState :: struct {
  move: Move16;
  flags: Castling;
  cap: Piece;
  hash: u64;
}

Move_Bitboards :: struct {
  bitboard: [64] u64;
  count: int;
}

simp :: #import "Simp";
#import "System"; // For get_path_of_running_executable.
#import "String"; // For path_strip_filename. 
#import "Math";
#import "Basic";
#import "GetRect";
#import "Input";
#import "Window_Creation";
#import "GetRect";
#load "movegen.jai";
#import "Sound_Player";
#import "Wav_File";
#import "File";
#import "Random";
