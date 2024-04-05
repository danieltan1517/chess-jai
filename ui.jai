// global variables.
path: string;
win: Window_Type;
chess_piece_bitmap: simp.Texture;
setting_bitmap: simp.Texture;
font: *simp.Dynamic_Font;
current_color_theme : s32 = 0;
piece_set: s32 = 0;
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
engine_debug: bool = false;
dark_theme: bool = true;

background_r: float = 0.1555;
menu_r: float = 0.22;
COMBO := 0.8;


// right-click highlight square.
highlighted_squares_bitboard: u64 = 0;
highlight_color :: Vector4.{.9, .35, 0, .55};
arrow_color :: Vector4.{1., .55, 0, .55};

reset_switch: bool = false;
engine_lines: bool = false;

chess: Chess;
move_bitboards: Move_Bitboards;
highlighted_moves: u64 = 0;
previous_move: u64 = 0;

chess_mouse: ChessMouse = .Idle;
chess_highlight: ChessMouse = .Idle;
chess_square_select := -1;
chess_highlight_select := -1;
arrows: [128] Arrow;
arrow_index: int = 0;
num_arrows: int = 0;

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

// chess engine AIs
chess_engines: [..] Engine;
w_engine_index : s32 = -1;
b_engine_index : s32 = -1;
NOT_AI :: -1;

// clock / move variables.
time_control_option := TimeControl.none;
wtime: float;
btime: float;
winc: float;
binc: float;
clockon: bool = true;
search_depth: int = 20;
time_per_move: int = 2000;

// new game window.
subwindow_newgame: Subwindow_Info;
subwindow_ok: bool = false;
subwindow_fenstring: string;
subwindow_time := TimeControl.none;
subtime: float = 15*60;
subincr: float = 1;
submove: float = 2.0;
subdepth: int = 10;
newgame_w_choice: s32 = 0;
newgame_b_choice: s32 = 0;

// load engine window.
subwindow_load_engine: Subwindow_Info;
subwindow_engine_name: string;
subwindow_engine_icon: string;
subwindow_engine_file: string;
scroll_value: float;
subwindow_engine_select: s32; 

// fen string
fen_string: string = "";

// board scale factor.
board_scale_factor := 0.87;

// background color:

main :: () {

  render_arrow :: (arrow: Arrow, corner_x: float, corner_y: float, square: float) {
    arrow_point :: (index: int, corner_x: float, corner_y: float, square: float, half_square: float) -> Vector2 {
      row := 0; 
      col := 0; 
      if board_orientation then {
        row = index % 8;
        col = index / 8;
      } else {
        row = 7 - index % 8;
        col = 7 - index / 8;
      }
      return Vector2.{corner_x + square * row + half_square, corner_y + square * col + half_square};
    }

    hsquare := square * .5;
    from_pt := arrow_point(arrow.from, corner_x, corner_y, square, hsquare);
    to\ _pt := arrow_point(arrow.to\, corner_x, corner_y, square, hsquare);
    dx := to_pt.x - from_pt.x;
    dy := to_pt.y - from_pt.y;
    hypotenuse := sqrt(dx*dx + dy*dy);

    // ... I suck at trigonometry...haven't done it in a while... so this...
    ct   := (dx / hypotenuse);
    st   := (dy / hypotenuse);
    size := square * .12;
    w    := Vector2.{ct, st} * size;
    h    := Vector2.{st, -ct} * size;

    qsquare := square * .70;
    from_pt.x += ct * square * .425;
    from_pt.y += st * square * .425;
    to_pt.x -= ct * qsquare;
    to_pt.y -= st * qsquare;

    p0 := from_pt - w - h;
    p1 := to_pt + w - h;
    p2 := to_pt + w + h;
    p3 := from_pt - w + h;

    simp.set_shader_for_color(true);
    simp.immediate_quad(p0, p1, p2, p3, arrow_color);

    from_pt = to_pt;
    to_pt.x += ct * qsquare * .6;
    to_pt.y += st * qsquare * .6;
    w  = Vector2.{ct, st} * size;
    h  = Vector2.{st, -ct} * size;
    p0 = from_pt + w - h * 2.25;
    p1 = to_pt + w;
    p2 = from_pt + w + h * 2.25;
    simp.immediate_quad(p0, p1, p1, p2, arrow_color);


  }


  update_clock :: (dt: float) {
    if time_control_option != .clock || clockon == false then return;
    if chess.turn == Turn.WHITE then {
      wtime -= dt;
      if wtime < 0 {
        wtime = 0;
        clockon = false;
        game_status = "White Timeout";
      }
    } else {
      btime -= dt;
      if btime < 0 {
        btime = 0;
        clockon = false;
        game_status = "Black Timeout";
      }
    }
  }

  draw_ui :: (width: s32, height: s32) {
    ui_per_frame_update(win, width, height, looptime_end);

    button_height := height * .03;

    // use the GetRect default theme.
    button_theme := *default_overall_theme.button_theme;
    dropdown_theme := *default_overall_theme.dropdown_theme;
    dropdown_theme.theme_for_current_value.alignment = .Left;
    dropdown_theme.theme_for_each_choice.alignment = .Left;
    dropdown_theme.theme_for_current_choice.alignment = .Left;
    checkbox_theme := *default_overall_theme.checkbox_theme;
    slider_theme := *default_overall_theme.slider_theme;
    text_theme: *Text_Input_Theme = *default_overall_theme.text_input_theme;
    label_theme := *default_overall_theme.label_theme;
    label_theme.alignment = .Left;
    label_theme.alignment_pad_ems = .25;
    subwindow_theme := *default_overall_theme.subwindow_theme;

    // 'k' is some resolution-adjusting unit of distance. Right now it is
    k := height * .045;

    draw_clock :: () #expand {
      cen_x := width  / 2;
      cen_y := height / 2;
      square := board_scale_factor * min(width, height) / 8.0;
      corner_x := cen_x - square * 4.0;
      corner_y := cen_y - square * 4.0;
      end_x := corner_x + square * 8.0;
      end_y := corner_y + square * 8.0;
      center := xx width / 2.0;

      digit :: #bake_arguments formatInt(minimum_digits=2);
      name := "";
      if w_engine_index != -1 {
        name = chess_engines[w_engine_index].name;
      }

      wmins := cast(int) (wtime / 60.0);
      wsecs := cast(int) fmod(wtime, 60.0);

      wstring := name;
      if time_control_option == .clock then
        wstring = tprint("% %:%", name, digit(wmins), digit(wsecs));

      name = "";
      if b_engine_index != -1 {
        name = chess_engines[b_engine_index].name;
      }

      bmins := cast(int) (btime / 60.0);
      bsecs := cast(int) fmod(btime, 60.0);
      bstring := name;
      if time_control_option == .clock then
        bstring = tprint("% %:%", name, digit(bmins), digit(bsecs));


      bottom_string := "";
      top_string := "";
      if board_orientation == true {
        bottom_string = wstring;
        top_string = bstring;
      } else {
        bottom_string = bstring;
        top_string = wstring;
      }

      clk_box := get_rect(corner_x, corner_y, center, k);
      clk_box.y -= k;
      label(clk_box, bottom_string, label_theme);
      clk_box = get_rect(corner_x, corner_y + square * 8.0, center, k);
      label(clk_box, top_string, label_theme);
    }


    // draw the clock.
    draw_clock();
    r := get_rect(3.0, xx height - 1.1 * k, k, k);
    button_theme.label_theme.alignment = .Left;
    if button(r, "", button_theme, texture=*setting_bitmap) then {
      options_on = !options_on;
    }

    if commandline_on == true {
      r2 := get_rect(10.0, 10.0, cast(float)width - 20.0, k);
      action, console_string, state := text_input(r2, "", text_theme);
      if action & .ENTERED {
        should_reset := true;
        tf, mov := parse_move(console_string);
        if tf {
          ui_make_move(*chess, mov, true);
          if chess_mouse == ChessMouse.Promote then {
            chess_mouse = ChessMouse.Idle;
            chess_square_select = -1;
            highlighted_moves = 0;
            return;
          }
        } else if equal(console_string, "undo") {
          ui_undo_move(*chess);
          should_reset = false;
        } else if equal(console_string, "redo") {
          ui_redo_move(*chess);
          should_reset = false;
        } else if equal(console_string, "close_engines") {
          for *engine: chess_engines {
            close_engine(engine);
            remove engine;
          }
        } else {
          token, TF := parse_token(*console_string);
          console_string = eat_spaces(console_string);
          if TF == true {

            get_engine_index :: (console_string: string) -> index: s32 {
              if equal(console_string, "(none)") then {
                return -1;
              } else {
                for *engines, index: chess_engines {
                  if equal(engines.name, console_string) {
                    return cast, no_check(s32) index;
                  }
                }
              }
              return -1;
            }

            if equal(token, "fen") {
              if chess_fen(*chess, console_string) {
                if fen_string free(fen_string);
                fen_string = copy_string(console_string);
              } else {
                chess_startpos(*chess);
                fen_string = "";
              }
              ui_new_game();
            } else if equal(token, "w") {
              w_engine_index = get_engine_index(console_string);
            } else if equal(token, "b") {
              b_engine_index = get_engine_index(console_string);
            }
          }
        }
        if should_reset then
          reset(state);
        activate(state);
      }
    }
    
    old_color_theme := current_color_theme;
    if options_on then {
      simp.set_shader_for_color();
      //  background_r = ifx dark_theme == true  0.1555 else 0.8555;
      simp.immediate_quad(r.x, r.y, r.x + k*8.0 + 6.0, r.y - k*20.75, color = Vector4.{menu_r, menu_r, menu_r, 1});
      // Color Dropdown Menu.
      r.x += 3.0;
      r.y -= k*1.2;
      r.w = k*8.0;
      r.h = k;
      if button(r, "New Game (Ctrl+N)", button_theme) then {
        options_on = false;
        subwindow_newgame.open = true;
        subwindow_time = TimeControl.none;
        newgame_w_choice = w_engine_index + 1;
        newgame_b_choice = b_engine_index + 1;
        subwindow_time = TimeControl.none;
        subtime = 15*60;
        subincr = 1;
        submove = 2.0;
        subdepth = 10;
      }

      r.y -= k*1.1;
      if button(r, "Engines", button_theme) then {
        options_on = false;
        subwindow_load_engine.open = true;
      }

      r.y -= k*1.1;
      if button(r, "Undo (Ctrl+Z)", button_theme) then {
        ui_undo_move(*chess);
      }

      r.y -= k*1.1;
      if button(r, "Redo (Ctrl+Y)", button_theme) then {
        ui_redo_move(*chess);
      }

      r.y -= k*1.1;
      PIECE_SET :: string.["Classic", "Modern", "Magnetic", "Medieval", "Letters"];
      dropdown(r, PIECE_SET, *piece_set, dropdown_theme);
      COMBO = 0.2 * (4-piece_set);

      r.y -= k*1.1;
      COLORS :: string.["green board", "blue board", "grey board", "brown board", "purple board", "red board"]; 
      dropdown(r, COLORS, *current_color_theme, dropdown_theme);

      r.y -= k*1.1;
      if base_checkbox(r, "Dark Theme", dark_theme, checkbox_theme) then {
        dark_theme = !dark_theme;
        theme := ifx dark_theme == true then Default_Themes.Grayscale else .Nimbus;
        set_default_theme(default_theme_procs[theme]());
        background_r = ifx dark_theme == true  0.1555 else 0.8255;
        menu_r = ifx dark_theme == true 0.22 else 0.95;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Board Orientation", board_orientation, checkbox_theme) then {
        board_orientation = !board_orientation;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Display Coordinates", display_coordinates, checkbox_theme) then {
        display_coordinates = !display_coordinates;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Audio", sound_on, checkbox_theme) then {
        sound_on = !sound_on;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Highlight Moves", highlight_moves_check, checkbox_theme) then {
        highlight_moves_check = !highlight_moves_check;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Show Legal Moves", show_moves, checkbox_theme) then {
        show_moves = !show_moves;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Blindfold Mode", blindfold_mode, checkbox_theme) then {
        blindfold_mode = !blindfold_mode;
      }

      r.y -= k*1.1;
      if base_checkbox(r, "Animations", mov_anim_state != MovAnim.Off, checkbox_theme) then {
        if mov_anim_state == MovAnim.Off
          mov_anim_state = MovAnim.Idle;
        else
          mov_anim_state = MovAnim.Off;
      }

      r.y -= k*1.1;
      slider(r, *mov_anim_complete, 0.00, 1.0, 0.01, slider_theme, "", " Animation");
     
      r.y -= k*1.1;
      if base_checkbox(r, "Command Line", commandline_on, checkbox_theme) then {
        commandline_on = !commandline_on;
      }

      r.y -= k*1.1;
      slider(r, *board_scale_factor, 0.30, 0.92, 0.01, slider_theme, "", " Board Scale");

      r.y -= k*1.1;
      if base_checkbox(r, "Engine Debug", engine_debug, checkbox_theme) then {
        engine_debug = !engine_debug;
      }

      r.y -= k*0.9;
      if base_checkbox(r, "Display Engine PV", engine_lines, checkbox_theme) then {
        engine_lines = !engine_lines;
        if engine_lines == false then {
          clear_arrows();
        }
      }
    }

    if subwindow_newgame.open {  // The Subwindow starts open, but pressing the Close button can close it.
      add_subwindow(*subwindow_newgame, subwindow_theme);
    }

    if subwindow_load_engine.open {  // The Subwindow starts open, but pressing the Close button can close it.
      add_subwindow(*subwindow_load_engine, subwindow_theme);
    }

    draw_popups();  // This draws Subwindows as well.
    if subwindow_ok == true {
      w_engine_index = newgame_w_choice-1;
      b_engine_index = newgame_b_choice-1;
      time_control_option = subwindow_time;
      board_orientation = true;
      if w_engine_index == NOT_AI {
        board_orientation = true;
      } else if b_engine_index == NOT_AI {
        board_orientation = false;
      }
      subwindow_newgame.open = false;
      subwindow_ok = false;
    }

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

  draw_piece :: (a: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Vector4) {
    b := a + 1;
    a /= 6.0;
    b /= 6.0;
    uv0 := Vector2.{a, 0.0};
    uv1 := Vector2.{a, 0.2};
    uv2 := Vector2.{b, 0.2};
    uv3 := Vector2.{b, 0.0};
    uv0.y += COMBO;
    uv1.y += COMBO;
    uv2.y += COMBO;
    uv3.y += COMBO;
    simp.immediate_quad(p0, p1, p2, p3, col, uv0, uv1, uv2, uv3);
  }

  init_fonts :: (height: int) {
    // Resize the font for the new window size.
    pixel_height := height / 32;
    font = simp.get_font_at_size("resources", "AnonymousPro.ttf", pixel_height);
    assert(font != null, "font not loaded properly");
  }

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

  draw_chess_pieces :: (width: float, height: float, x: float, y: float, mouse_event: bool, key_pressed: int) {
    cen_x := width  / 2;
    cen_y := height / 2;
    square := board_scale_factor * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;
    end_x := corner_x + square * 8.0;
    end_y := corner_y + square * 8.0;

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

      p0 := Vector2.{corner_x + square * row, corner_y + square * col};
      p1 := Vector2.{p0.x, p0.y + square};
      p2 := Vector2.{p0.x + square, p0.y + square};
      p3 := Vector2.{p0.x + square, p0.y};

      bitboard := cast, no_check(u64) (1 << index);
      if highlighted_squares_bitboard & bitboard {
        simp.set_shader_for_color(true);
        simp.immediate_quad(p0, p1, p2, p3, highlight_color);
      }

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
      p0 := Vector2.{x - square * 0.5, y - square * 0.5};
      p1 := Vector2.{p0.x, p0.y + square};
      p2 := Vector2.{p0.x + square, p0.y + square};
      p3 := Vector2.{p0.x + square, p0.y};
      assert(chess_square_select >= 0 && chess_square_select <= 63);
      piece := chess.pieces[chess_square_select];
      draw_piece(p0, p1, p2, p3, piece);
    }

    if mov_anim_state == MovAnim.Play && previous_move then {
      mov := undo_list[ply-1].move;
      _, from, to := decode_move16(mov);
      piece := chess.pieces[to];

      from_x: int;
      from_y: int;
      to_x: int;
      to_y: int;

      if board_orientation then {
        from_x = from % 8;
        from_y = from / 8;
        to_x = to % 8;
        to_y = to / 8;
      } else {
        from_x = 7 - from % 8;
        from_y = 7 - from / 8;
        to_x = 7 - to % 8;
        to_y = 7 - to / 8;
      }

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
      p1 := Vector2.{p0.x, p0.y + square};
      p2 := Vector2.{p0.x + square, p0.y + square};
      p3 := Vector2.{p0.x + square, p0.y};
      draw_piece(p0, p1, p2, p3, piece);
    }

    for index: 0..num_arrows-1 {
      arrow: Arrow = arrows[index];
      render_arrow(arrow, corner_x, corner_y, square);
    }

    simp.immediate_flush();
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

    wcol :: Vector4.{1.0, 1.0, 1.0, 1};
    bcol :: Vector4.{0.25, 0.25, 0.25, 1};
    KING :: 0.0;
    QUEEN :: 1.0;
    ROOK  :: 2.0;
    BISHOP :: 3.0;
    KNIGHT :: 4.0;
    PAWN :: 5.0;

    if piece == {
    case  Piece.W_KING;
      draw_piece(KING, p0, p1, p2, p3, wcol);
    case  Piece.W_QUEEN;
      draw_piece(QUEEN, p0, p1, p2, p3, wcol);
    case  Piece.W_ROOK;
      draw_piece(ROOK, p0, p1, p2, p3, wcol);
    case  Piece.W_BISHOP;
      draw_piece(BISHOP, p0, p1, p2, p3, wcol);
    case  Piece.W_KNIGHT;
      draw_piece(KNIGHT, p0, p1, p2, p3, wcol);
    case  Piece.W_PAWN;
      draw_piece(PAWN, p0, p1, p2, p3, wcol);
    case  Piece.B_KING;
      draw_piece(KING, p0, p1, p2, p3, bcol);
    case  Piece.B_QUEEN;
      draw_piece(QUEEN, p0, p1, p2, p3, bcol);
    case  Piece.B_ROOK;
      draw_piece(ROOK, p0, p1, p2, p3, bcol);
    case  Piece.B_BISHOP;
      draw_piece(BISHOP, p0, p1, p2, p3, bcol);
    case  Piece.B_KNIGHT;
      draw_piece(KNIGHT, p0, p1, p2, p3, bcol);
    case  Piece.B_PAWN;
      draw_piece(PAWN, p0, p1, p2, p3, bcol);
    }
  }


  chess_mouse_event :: (width: float, height: float, x: float, y: float, mouse_event: bool, key_pressed: int, left_or_right: bool) {
    cen_x := width  / 2;
    cen_y := height / 2;
    square := board_scale_factor * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;
    end_x := corner_x + square * 8.0;
    end_y := corner_y + square * 8.0;

    not_open := !subwindow_newgame.open && !subwindow_load_engine.open ;

    if not_open && !options_on && mouse_event {
      if x >= corner_x && x <= end_x && y >= corner_y && y <= end_y then {
        mouse_coor_x := cast(int) ((x - corner_x) / square);
        mouse_coor_y := cast(int) ((y - corner_y) / square);
        if board_orientation == false then {
          mouse_coor_x = 7 - mouse_coor_x;
          mouse_coor_y = 7 - mouse_coor_y;
        }
        position := mouse_coor_x + mouse_coor_y * 8;
        if left_or_right == true {
          chess_highlight = .Idle;
          highlighted_squares_bitboard = 0;
          clear_arrows();
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
                if is_human_turn() {
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
                      chess_mouse = .Idle;
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
              if is_human_turn() {
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
                  ui_make_move(*chess, mov, true);
                  chess_square_select = -1;
                  highlighted_moves = 0;
                }
              }
            }
          case .Promote;
            if key_pressed == 1 {
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
          }
        } else {

          if chess_highlight == {
          case .Idle;
            if key_pressed == 1 {
              chess_highlight_select = position;
              chess_highlight = .Select;
            }
          case .Select;
            if key_pressed == 0 {
              if chess_highlight_select == position {
                bitboard := cast(u64) (1 << position);
                highlighted_squares_bitboard ^= bitboard;
              } else {
                // add an arrow...
                arrow: Arrow;
                arrow.from = cast(u8) chess_highlight_select;
                arrow.to   = cast(u8) position;
                add_arrow(arrow);
              }

              chess_highlight = .Idle;
            }
          }

        }
      } else {
        // outside of the board.
        chess_mouse = ChessMouse.Idle;
        chess_highlight = .Idle;
        chess_square_select = -1;
        highlighted_moves = 0;
        highlighted_squares_bitboard = 0;
        clear_arrows();
      }
    }
  }

  draw_chess_board :: (width: float, height: float) {
    simp.clear_render_target(background_r, background_r, background_r, 1.0);
    simp.set_shader_for_color();
    cen_x := width  / 2;
    cen_y := height / 2;
    square := board_scale_factor * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;
    white := false;
    for i: 0..7 {
      for j: 0..7 {
        color := ifx white then white_sq_color else black_sq_color;
        p0 := Vector2.{corner_x + i * square, corner_y + j * square};
        p1 := Vector2.{p0.x, p0.y + square};
        p2 := Vector2.{p0.x + square, p0.y + square};
        p3 := Vector2.{p0.x + square, p0.y};
        simp.immediate_quad(p0, p1, p2, p3, color);
        white = ! white;
      }
      white = ! white;
    }

    if display_coordinates && board_scale_factor > .50 then {
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


  init_textures :: () {
    success := simp.texture_load_from_file(*chess_piece_bitmap, "resources/chess_pieces.png");
    assert(success);
    success = simp.texture_load_from_file(*setting_bitmap, "resources/settings_icon.png");
    assert(success);
  }

  GREY_SHADE_BOARD :: Vector4.{0.2, 0.2, 0.2, 0.35};

  path = copy_string(path_strip_filename(get_path_of_running_executable()));
  set_default_theme(default_theme_procs[Default_Themes.Grayscale]());
  set_working_directory(path);

  // initialize chess w/ the starting position.
  // generate chess moves.
  init_global_bitboards();
  chess_startpos(*chess);
  fen_string = "";
  ui_new_game();

  // create a window. 
  // initialize fonts.
  // init ui.
  win = create_window(600, 600, "Chess");
  width, height := simp.get_render_dimensions(win);
  simp.set_render_target(win);

  init_textures();

  init_fonts(height);
  ui_init();
  init_sound();

  subwindow_newgame.rect = get_rect(100,100,400,300);
  subwindow_newgame.draw = draw_subwindow_newgame;
  subwindow_newgame.title_text = "New Game";
  subwindow_newgame.open = false;
  subwindow_fenstring = copy_string("startpos");

  subwindow_load_engine.rect = get_rect(100,25,400,500);
  subwindow_load_engine.draw = draw_subwindow_load_engine;
  subwindow_load_engine.title_text = "Engines";
  subwindow_load_engine.open = false;

  ctrl_pressed := 0;
  engine, etf := load_engine("ceij", "ceij");
  if etf == true {
    array_add(*chess_engines, engine);
  }

  defer {
    for *engine: chess_engines {
      close_engine(engine);
    }
  }

  // main game loop
  while outer_loop := true {
    reset_switch = false;
    dt = looptime_end - looptime_begin;
    update_clock(dt);
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

    x, y := get_mouse_pointer_position(win, true);

    mouse_event := false;
    key_pressed := 0;
    for e: events_this_frame {
      if e.type == .QUIT then
        break outer_loop;
      getrect_handle_event(e);

      Key_Code_Z : Key_Code : #char "Z";
      Key_Code_N : Key_Code : #char "N";
      Key_Code_Y : Key_Code : #char "Y";
      Key_Code_X : Key_Code : #char "X";
      if e.type == .KEYBOARD then {
        if e.key_code == .MOUSE_BUTTON_LEFT {
          key_pressed = e.key_pressed;
          mouse_event = true;
          chess_mouse_event(xx width, xx height, xx x, xx y, mouse_event, key_pressed, true);
        } else if e.key_code == .MOUSE_BUTTON_RIGHT {
          key_pressed = e.key_pressed;
          mouse_event = true;
          chess_mouse_event(xx width, xx height, xx x, xx y, mouse_event, key_pressed, false);
        } else if e.key_code == .CTRL {
          ctrl_pressed = e.key_pressed;
        } else if e.key_pressed == 1 && e.key_code == Key_Code_Z && ctrl_pressed {
          ui_undo_move(*chess);
        } else if e.key_pressed == 1 && e.key_code == Key_Code_N && ctrl_pressed {
          reset_switch = true;
          subwindow_newgame.open = true;
          subwindow_time = TimeControl.none;
          newgame_w_choice = w_engine_index + 1;
          newgame_b_choice = b_engine_index + 1;
          subwindow_time = TimeControl.none;
          subtime = 15*60;
          subincr = 1;
          submove = 2.0;
          subdepth = 10;
        } else if e.key_pressed == 1 && e.key_code == Key_Code_Y && ctrl_pressed {
          ui_redo_move(*chess);
        } else if e.key_pressed == 1 && e.key_code == Key_Code_X && commandline_on == false {
          board_orientation = !board_orientation;
        } else if e.key_pressed == 1 && e.key_code == .ESCAPE {
          commandline_on = !commandline_on;
        }
      }
    }

    draw_chess_board(xx width, xx height);
    draw_chess_pieces(xx width, xx height, xx x, xx y, mouse_event, key_pressed);
    draw_ui(width, height);
    Sound.update();

    for *engine, id: chess_engines
      update_uci_engine(engine, id, dt, reset_switch);

    simp.swap_buffers(win);
    sleep_milliseconds(20);
    reset_temporary_storage();
    looptime_end = cast(float)seconds_since_init();
  }


}

draw_subwindow_newgame :: (r: Rect, data: *void) {
  get_engine_names :: () -> [..] string {
    arr: [..] string;
    arr.allocator = temp;
    array_add(*arr, "(none)");
    for engine: chess_engines {
      array_add(*arr, engine.name);
    }
    return arr;
  }

  TimeCtrl :: string.[
    "None", 
    "Clock",
    "Time Per Move",
    "Depth"
  ];

  width, height := simp.get_render_dimensions(win);
  button_theme := *default_overall_theme.button_theme;
  slider_theme := *default_overall_theme.slider_theme;
  dropdown_theme := *default_overall_theme.dropdown_theme;
  dropdown_theme.theme_for_current_value.alignment = .Left;
  dropdown_theme.theme_for_each_choice.alignment = .Left;
  dropdown_theme.theme_for_current_choice.alignment = .Left;
  label_theme := *default_overall_theme.label_theme;
  text_theme: *Text_Input_Theme = *default_overall_theme.text_input_theme;
  label_theme.alignment = .Left;
  label_theme.alignment_pad_ems = .25;
  subwindow_ok = false;

  k := height * .045;

  arr := get_engine_names();

  rect := get_rect(r.x + 3, r.y + r.h - k - 3, r.w - k*2.1 - 9, k);
  label(rect, "Fen", label_theme);
  rect.x += k * 2.1;
  action_c, _, fen_state := text_input(rect, subwindow_fenstring, text_theme);
  if action_c & .TEXT_MODIFIED {
    subwindow_fenstring = get_result(fen_state);
  }

  rect.y -= k * 1.1;

  if button(rect, "Current Position") {
    fen_string := to_fen_string(*chess);
    set_input(fen_state, fen_string); 
  }

  rect.y -= k * 1.1;
  rect.x -= k * 2.1;
  label(rect, "White", label_theme);
  rect.x += k * 2.1;
  dropdown(rect, arr, *newgame_w_choice, dropdown_theme);
  rect.x -= k * 2.1;
  rect.y -= k * 1.1;
  label(rect, "Black", label_theme);
  rect.x += k * 2.1;
  dropdown(rect, arr, *newgame_b_choice, dropdown_theme);
  rect.y -= k * 1.1;
  rect.x -= k * 2.1;
  label(rect, "Time", label_theme);
  rect.x += k * 2.1;
  dropdown(rect, TimeCtrl, cast(*s32)*subwindow_time, dropdown_theme);
  rect.y -= k * 1.1;

  if subwindow_time == {
  case .none;
  case .clock;
    function := slider_theme.format_text_float;
    slider_theme.format_text_float = format_float_time;
    slider(rect, *subtime, 0, 40*60, 1.0, slider_theme);
    slider_theme.format_text_float = function;
    rect.y -= k * 1.1;
    slider(rect, *subincr, 0, 30, .1, slider_theme, "", " seconds increment");
    rect.y -= k * 1.1;
  case .time_per_move;
    slider(rect, *submove, 0.01, 10.0, 0.01, slider_theme, "", " seconds per move");
    rect.y -= k * 1.1;
  case .depth;
    slider(rect, *subdepth, 1, 50, 1, slider_theme, "Depth ", "");
    rect.y -= k * 1.1;
  }

  rect.y = r.y + 9;
  if button(rect, "Play", button_theme) {
    str := get_result(fen_state);
    if !str || equal(str, "startpos") then {
      chess_startpos(*chess);
      fen_string = "";
    } else {
      if chess_fen(*chess, str) {
        fen_string = copy_string(str);
      } else {
        chess_startpos(*chess);
        fen_string = "";
      }
    }
    set_input(fen_state, "startpos"); 
    subwindow_fenstring = "startpos";
    ui_new_game();
    subwindow_ok = true;

    if #complete subwindow_time == {
    case .none;
    case .clock;
      wtime = cast(float)(subtime);
      btime = cast(float)(subtime);
      winc = xx subincr;
      binc = xx subincr;
    case .time_per_move;
      time_per_move = xx (submove * 1000);
    case .depth;
      search_depth = subdepth;
    }
  }

}

draw_subwindow_load_engine :: (r: Rect, data: *void) {

  get_engine_names :: () -> [..] string {
    arr: [..] string;
    arr.allocator = temp;
    for engine: chess_engines {
      array_add(*arr, engine.name);
    }
    array_add(*arr, "Add Engine...");
    return arr;
  }

  width, height := simp.get_render_dimensions(win);
  button_theme := *default_overall_theme.button_theme;
  checkbox_theme := *default_overall_theme.checkbox_theme;
  slider_theme := *default_overall_theme.slider_theme;
  dropdown_theme := *default_overall_theme.dropdown_theme;
  dropdown_theme.theme_for_current_value.alignment = .Left;
  dropdown_theme.theme_for_each_choice.alignment = .Left;
  dropdown_theme.theme_for_current_choice.alignment = .Left;
  label_theme := *default_overall_theme.label_theme;
  text_theme: *Text_Input_Theme = *default_overall_theme.text_input_theme;
  slidable_region_theme := *default_overall_theme.scrollable_region_theme;
  label_theme.alignment = .Left;
  label_theme.alignment_pad_ems = .25;
  subwindow_ok = false;
  XVAL :: 2.4;

  k := height * .045;
  rect := get_rect(r.x + 3, r.y + r.h - k - 3, r.w-9, k);
  arr := get_engine_names();
  rect.x -= k * XVAL;
  label(rect, "Engine", label_theme);
  rect.x += k * XVAL;
  dropdown(rect, arr, *subwindow_engine_select, dropdown_theme);
  if equal(arr[subwindow_engine_select], "Add Engine...") {
    rect.y -= k * 1.1;
    label(rect, "Name", label_theme);
    rect.x += k * XVAL;
    rect.w -= k * XVAL;
    action_c1, _, fen_state1 := text_input(rect, subwindow_engine_name, text_theme);
    if action_c1 & .TEXT_MODIFIED {
      subwindow_engine_name = get_result(fen_state1);
    }
 
    rect.w += k * XVAL;
    rect.x -= k * XVAL;
 
    rect.y -= k * 1.1;
    label(rect, "File", label_theme);
    rect.x += k * XVAL;
    rect.w -= k * XVAL;
    action_c3, ___, fen_state3 := text_input(rect, subwindow_engine_file, text_theme);
    if action_c3 & .TEXT_MODIFIED {
      subwindow_engine_file = get_result(fen_state3);
    }

    rect.y -= k * 1.1;
    if button(rect, "Load", button_theme) {
      engine, TF := load_engine(subwindow_engine_name, subwindow_engine_file);
      if TF {
        array_add(*chess_engines, engine);
        reset(fen_state1);
        reset(fen_state3);
        subwindow_engine_name = "";
        subwindow_engine_icon = "";
        subwindow_engine_file = "";
      } 
    }

  } else {
    // Engine Options for Engine. Scrollable Region.
    engine := *chess_engines[subwindow_engine_select];
    rect_cover := rect.y;
 
    rect.y =  r.y + 9;
    rect.w =  r.w - 9;
 
    compute := (w_engine_index != NOT_AI || b_engine_index != NOT_AI) && w_engine_index == b_engine_index;
    disable_change := engine.state != .idle || compute;
    rect1 := rect;
    rect1.w /= 2;
    if button(rect1, "Apply Changes", button_theme, disable_over=disable_change, disable_press=disable_change) {
      process := *engine.process;
      for *option: engine.options {
        using option;
        if type == {
        case .check;
          if check_value != check_value_old {
            check_value_old = check_value;
            opt := tprint("setoption name % value %\n", name, check_value);
            write_to_process(process, to_u8_array(opt));
          }
        case .spin;
          if spin_value != spin_value_old {
            spin_value_old = spin_value;
            opt := tprint("setoption name % value %\n", name, spin_value);
            write_to_process(process, to_u8_array(opt));
          }
        case .combo;
          if combo_value != combo_value_old {
            combo_value_old = combo_value;
            opt := tprint("setoption name % value %\n", name, combo_value);
            write_to_process(process, to_u8_array(opt));
          }
        case .button;
        case .uci_string;
          if !equal(string_value, string_value_old) {
            string_value = string_value_old;
            opt := tprint("setoption name % value %\n", name, string_value);
            write_to_process(process, to_u8_array(opt));
          }
        }
      }
    }
 
    rect1.x += rect1.w;
    if button(rect1, "Cancel", button_theme, disable_over=disable_change, disable_press=disable_change) {
      for *option: engine.options {
          using option;
          check_value = check_value_old;
          spin_value = spin_value_old;
          combo_value = combo_value_old;
          string_value = string_value_old;
      }
    }
 
    rect.y += k * 1.1;
    rect.h =  rect_cover-rect.y-6;
 
    slidable_region_theme.region_background.shape.rounding_flags = 0;
    region, inside := begin_scrollable_region(rect, slidable_region_theme);
    s := inside;
    s.y = s.y + s.h - k;
    s.h = k;
    s.y += scroll_value;
    index := 0;
    for *option : engine.options {
      name := option.name;
      if option.type == {
      case .check;
        if base_checkbox(s, name, option.check_value, checkbox_theme, identifier=index) {
          option.check_value = !option.check_value;
        }
        index += 1;
      case .spin;
        slider(s, *option.spin_value, option.spin_min, option.spin_max, 1, slider_theme, tprint("% ", name), "", identifier=index);
        index += 3;
      case .combo;
        dropdown(s, option.combo_values, *option.combo_value, dropdown_theme, identifier=index);
        index += 1;
      case .button;
        process := *engine.process;
        if button(s, name, button_theme, identifier=index) {
          opt := tprint("setoption name %\n", name);
          write_to_process(process, to_u8_array(opt));
        }
        index += 1;
      case .uci_string;
        label(s, name, label_theme);
        s.x += k * XVAL * 2;
        s.w -= k * XVAL * 2;
        action, console_string, state := text_input(s, option.string_value, text_theme, identifier=index);
        s.w += k * XVAL * 2;
        s.x -= k * XVAL * 2;
        index += 1;
      }
      s.y -= floor(k * 1.1 + 0.5);
    }
    end_scrollable_region(region, s.x + s.w, s.y, *scroll_value);
  }
}

draw_subwindow_engine_options :: (r: Rect, data: *void) {

  get_engine_names :: () -> [..] string {
    arr: [..] string;
    arr.allocator = temp;
    for engine: chess_engines {
      array_add(*arr, engine.name);
    }
    return arr;
  }

  width, height := simp.get_render_dimensions(win);
  button_theme := *default_overall_theme.button_theme;
  slider_theme := *default_overall_theme.slider_theme;
  dropdown_theme := *default_overall_theme.dropdown_theme;
  dropdown_theme.theme_for_current_value.alignment = .Left;
  dropdown_theme.theme_for_each_choice.alignment = .Left;
  dropdown_theme.theme_for_current_choice.alignment = .Left;
  label_theme := *default_overall_theme.label_theme;
  text_theme: *Text_Input_Theme = *default_overall_theme.text_input_theme;
  label_theme.alignment = .Left;
  label_theme.alignment_pad_ems = .25;
  subwindow_ok = false;
  arr := get_engine_names();
  if !arr return;

  k := height * .045;
  rect := get_rect(r.x + 3, r.y + r.h - k - 3, k*9, k);
  dropdown(rect, arr, *subwindow_engine_select, dropdown_theme);
  engine := *chess_engines[subwindow_engine_select];

}

add_move :: (moves: *Move_Bitboards, from: int, to: int, flags: Move16) {
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
  highlighted_squares_bitboard = 0;
  clear_arrows();
  if clockon == false return;
  if ply >= undo_list.count {
    game_status = "Draw by Fifty Move Rule.";
    return;
  }

  if is_legal(chess, mov) then {
    if time_control_option == .clock {
      if chess.turn == .WHITE
        wtime += winc;
      else
        btime += binc;
    }

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
    sound_data: *Sound.Sound_Data;
    mov_flag := get_move16_flag(mov);
    if (mov_flag >= .Quiet && mov_flag <= .Queen_Castle) || (mov_flag >= .Knight_Promotion && mov_flag <= .Queen_Promotion) then {
      sound_data = *sound_quiet_move;
    } else {
      sound_data = *sound_capture_move;
    }
    if sound_on == true then {
      play_sound(sound_data);
    }

    clear(*move_bitboards);
    generate_moves(chess, *move_bitboards);

    if move_bitboards.count == 0 then {
      clockon = false;
      if in_check(chess) {
        game_status = "Checkmate.";
      } else {
        game_status = "Stalemate.";
      }
    } else if in_check(chess) {
      game_status = "Check.";
      clockon = true;
    } else {
      game_status = "";
      clockon = true;
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
      clockon = false;
      game_status = "Draw by Threefold Repetition.";
    }
    
    if is_draw() {
      clockon = false;
      game_status = "Draw by Insufficient Material.";
    }

    if animate && mov_anim_state == MovAnim.Idle then {
      mov_anim_time = 0.0;
      mov_anim_state = MovAnim.Play;
    }
  }
}

ui_undo_move :: (chess: *Chess) {
  if ply <= 0 then return;
  if w_engine_index != NOT_AI && b_engine_index != NOT_AI then return;

  if chess_mouse == ChessMouse.Promote then {
    chess_mouse = ChessMouse.Idle;
    chess_highlight = .Idle;
    chess_square_select = -1;
    highlighted_moves = 0;
    return;
  }

  curply := ply;

  clockon = true;
  while ply == curply || !is_human_turn() {
    ply -= 1;
    if ply < 0 {
      ply = 0;
      clockon = false;
      break;
    }
    mov := undo_list[ply].move;
    cap := undo_list[ply].cap;
    flags := undo_list[ply].flags;
    hash := undo_list[ply].hash;
    unmake_move(chess, mov, cap, flags, hash);
  }

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

  highlighted_squares_bitboard = 0;
  clear_arrows();
}

ui_redo_move :: (chess: *Chess) {
  mov := undo_list[ply].move;
  if mov == 0 then return;
  next := undo_list[ply+1].move;
  ui_make_move(chess, mov, true);
  undo_list[ply].move = next;
  if chess_mouse == ChessMouse.Promote then {
    chess_mouse = .Idle;
    chess_highlight = .Idle;
    chess_square_select = -1;
    highlighted_moves = 0;
    return;
  }
}

get_uci_board_string :: () -> string {
  builder: String_Builder;
  builder.allocator = temp;
  if fen_string then
    print_to_builder(*builder, "position fen %", fen_string);
  else
    append(*builder, "position startpos");
  if ply > 0
    append(*builder, " moves");
  for index: 0..ply-1 {
    move := undo_list[index].move;
    append(*builder, " ");
    append(*builder, move);
  }
  append(*builder, NEWLINE);
  return builder_to_string(*builder,, allocator=temp);
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
  reset_switch = true;
  clockon = true;
  clear(*move_bitboards);
  generate_moves(*chess, *move_bitboards);
  highlighted_moves = 0;
  game_status = "";
  previous_move = 0;
  clear_undo();
  if chess_mouse == ChessMouse.Promote then {
    chess_mouse = .Idle;
    chess_highlight = .Idle;
    chess_square_select = -1;
    highlighted_moves = 0;
  }

  // cover an edge case.
  if move_bitboards.count == 0 then {
    clockon = false;
    if in_check(*chess) {
      game_status = "Checkmate.";
    } else {
      game_status = "Stalemate.";
    }
  } else if in_check(*chess) {
    game_status = "Check.";
    clockon = true;
  } else {
    game_status = "";
    clockon = true;
  }
}

load_engine :: (name: string, exe_name: string) -> Engine, bool {
  chess_engine: Engine;
  // TODO: figure out whether we want to load from a different path.
  if name then
    chess_engine.name = copy_string(name);
  else {
    chess_engine.name = copy_string(exe_name);
  }

  // TODO: only works on windows...
  // TODO: debug this stupid bug in the compiler...
  command := join(path, exe_name, EXE);
  process := *chess_engine.process;
  success := create_process(process, command, capture_and_return_output=true);
  chess_engine.timer = FLOAT32_INFINITY; // for keeping track of time
  return chess_engine, success;
}

update_uci_engine :: (engine: *Engine, id: int, dt: float, reset: bool) {

  get_search_string :: () -> string {
    if #complete time_control_option == {
    case .none;
      return "go movetime 1500\n";
    case .clock;
      wtimeint := cast(int) (wtime*1000);
      btimeint := cast(int) (btime*1000);
      wincint  := cast(int) (winc*1000);
      bincint  := cast(int) (binc*1000);
      return tprint("go wtime % btime % winc % binc %\n", wtimeint, btimeint, wincint, bincint);
    case .time_per_move;
      return tprint("go movetime %\n", time_per_move);
    case .depth;
      return tprint("go depth %\n", search_depth);
    }
  }

  name := engine.name;
  state := engine.state;
  defer engine.state = state;
  process := *engine.process;
  SIZE :: 4096;
  // read.
  if state == {
  case .uciok;
    out_buff := NewArray(SIZE, u8,, allocator=temp);
    err_buff: [] u8; // nothing.
    success, output_bytes := read_from_process(process, out_buff, err_buff, timeout_ms=0);
    messages: string;
    messages.data = out_buff.data;
    messages.count = output_bytes;
    for msg, index: split(messages, NEWLINE) {
      message := msg;
      engine_log(engine, message);
      if equal(message, "uciok") then {
        state = .isready;
        engine.timer = FLOAT32_INFINITY;
      } else if begins_with(message, "option name") {
        message = advance(message, 11);
        message = eat_spaces(message);
        TF, option := parse_uci_option(message);
        if TF {
          array_add(*engine.options, option);
        }
      }
    }

  case .isready;
    out_buff := NewArray(SIZE, u8,, allocator=temp);
    err_buff: [] u8; // nothing.
    success, output_bytes := read_from_process(process, out_buff, err_buff, timeout_ms=0);
    messages: string;
    messages.data = out_buff.data;
    messages.count = output_bytes;
    for msg, index: split(messages, NEWLINE) {
      message := msg;
      engine_log(engine, message);
      if equal(message, "readyok") then {
        state = .ucinewgame;
        engine.timer = FLOAT32_INFINITY;
      } 
    }
  case .ucinewgame;
    state = .idle;
  case .idle;
    if is_engine_turn(id) && clockon == true then {
      state = .go;
      engine.timer = FLOAT32_INFINITY;
    }
    if reset then
      state = .ucinewgame;
  case .go;
    state = .bestmove;
    if reset then {
      write_to_process(process, to_u8_array("stop\n"));
      state = .ucinewgame;
    }
  case .bestmove;
    if !is_engine_turn(id) then {
      state = .idle;
      engine.timer = FLOAT32_INFINITY;
    } else {
      if reset then {
        write_to_process(process, to_u8_array("stop\n"));
        state = .ucinewgame;
        out_buff := NewArray(SIZE, u8,, allocator=temp);
        err_buff: [] u8; // nothing.
        read_from_process(process, out_buff, err_buff, timeout_ms=0);
      } else {
        out_buff := NewArray(SIZE, u8,, allocator=temp);
        err_buff: [] u8; // nothing.
        success, output_bytes := read_from_process(process, out_buff, err_buff, timeout_ms=0);
        messages: string;
        messages.data = out_buff.data;
        messages.count = output_bytes;
        for msg, index: split(messages, NEWLINE) {
          message := msg;
          engine_log(engine, message);
          if starts_with(message, "bestmove ") then {
            parse_token(*message);
            message = eat_spaces(message);
            mov_token := parse_token(*message);
            TF, mov := parse_move(mov_token);
            if TF {
              ui_make_move(*chess, mov, true);
              state = .idle;
            } else {
              state = .bug;
              engine_log(engine, "BUG");
            }
          } else {
            if engine_lines == true {
              _, __, pv := split_from_left(msg, " pv");
              pv = eat_spaces(pv);
              if pv then {
                clear_arrows();
              }
              while pv {
                mov_token := parse_token(*pv);
                pv = eat_spaces(pv);
                TF, mov := parse_move(mov_token);
                _, from, to := decode_move16(mov);
                arrow: Arrow;
                arrow.from = cast(u8) from;
                arrow.to   = cast(u8) to;
                add_arrow(arrow);
              }
            }
          }
        }
      }
    }
  }

  engine.timer += dt;

  // write.
  if state == {
  case .uciok;
    if engine.timer > 3.0 then {
      write_to_process(process, to_u8_array("uci\n"));
      engine.timer = 0.0;
    } 
  case .isready;
    if engine.timer > 5.0 then {
      write_to_process(process, to_u8_array("isready\n"));
      engine.timer = 0.0;
    } 
  case .ucinewgame;
    if engine.timer > 5.0 then {
      write_to_process(process, to_u8_array("ucinewgame\n"));
      engine.timer = 0.0;
    }
  case .idle;
    engine.timer = FLOAT32_INFINITY;
  case .go;
    str := get_uci_board_string();
    gostr := get_search_string();
    write_to_process(process, to_u8_array(str));
    write_to_process(process, to_u8_array(gostr));
  case .bestmove;
    // waiting to get the best move.
    // don't do anything.
  case .bug;

  }
}

to_u8_array :: (str: string) -> [] u8 {
  array: [] u8;
  array.data = str.data;
  array.count = str.count;
  return array;
}

close_engine :: (engine: *Engine) {
  // send a "quit" command before closing the chess engine.
  process := *engine.process;
  quit := "quit\n";
  write_buffer: [] u8;
  write_buffer.data = quit.data;
  write_buffer.count = quit.count;
  print("quit %\n", engine.name);
  write_to_process(process, write_buffer);
  deinit(process);
}

parse_uci_option :: (message: string) -> bool, Engine_Option #must {
  string_to_uci_type :: (token: string) -> UCI_Types, TF: bool = true {
    if token == {
    case "check";
      return .check;
    case "spin";
      return .spin;
    case "combo";
      return .combo;
    case "button";
      return .button;
    case "string";
      return .uci_string;
    }
    return .check, false;
  }
  // TODO: this may leak memory on bad input.
  option: Engine_Option;
  TF: bool;
  option_name: string;
  uci_type: string;
  rest: string;

  TF, option_name, rest = split_from_right(message, " type");
  if TF == false return false, option;

  option.name = copy_string(option_name);

  rest = eat_spaces(rest);
  uci_type, TF = parse_token(*rest);
  if TF == false return false, option;

  uci_option_type: UCI_Types;
  uci_option_type, TF = string_to_uci_type(uci_type);
  if TF == false return false, option;

  option.type = uci_option_type;
  
  rest = eat_spaces(rest);

  combo_default: string;

  token: string;
  while rest {
    token, TF = parse_token(*rest);
    if TF == false return false, option;
    rest = eat_spaces(rest);
    if token == {
    case "default";
      value,TF := parse_token(*rest);
      rest = eat_spaces(rest);
      if uci_option_type == {
      case .check;
        option.check_value,TF = parse_bool(*value);
        option.check_value_old = option.check_value;
        if TF == false return false, option;
      case .spin;
        option.spin_value,TF = parse_int(*value);
        option.spin_value_old = option.spin_value;
        if TF == false return false, option;
      case .combo;
        combo_default = value;
      case .button;
        return false, option;
      case .uci_string;
      }

    case "max";
      value,TF := parse_token(*rest);
      if TF == false return false, option;
      rest = eat_spaces(rest);
      if uci_option_type == {
      case .check;
        return false, option;
      case .spin;
        option.spin_max,TF = parse_int(*value);
        if TF == false return false, option;
      case .combo;
      case .button;
        return false, option;
      case .uci_string;
        return false, option;
      }

    case "min";
      value,TF := parse_token(*rest);
      if TF == false return false, option;
      rest = eat_spaces(rest);
      if uci_option_type == {
      case .check;
        return false, option;
      case .spin;
        option.spin_min,TF = parse_int(*value);
        if TF == false return false, option;
      case .combo;
      case .button;
        return false, option;
      case .uci_string;
        return false, option;
      }
    case "var";
      value,TF := parse_token(*rest);
      if TF == false return false, option;
      rest = eat_spaces(rest);

      combo_option := copy_string(value);
      array_add(*option.combo_values, combo_option);

    case;
      return false, option;
    }
  }

  if uci_option_type == .combo then {
    found : s32 = -1;
    for combos, index: option.combo_values {
      if equal(combo_default, combos) then {
        found = xx index;
        break;
      }
    }
    if found == -1 return false, option;
    option.combo_value = found;
    option.combo_value_old = found;
  }

  return true, option;

}


is_human_turn :: () -> bool {
  if chess.turn == .WHITE && w_engine_index == NOT_AI
    return true;
  if chess.turn == .BLACK && b_engine_index == NOT_AI
    return true;
  return false;
}

is_engine_turn :: (id: int) -> bool {
  if chess.turn == .WHITE {
    if id == w_engine_index
      return true;
  } else if chess.turn == .BLACK {
    if id == b_engine_index
      return true;
  }

  return false;
}

engine_log :: (engine: *Engine, format: string, args: ..Any) {
  if engine_debug && format {
    print("[%1]: ", engine.name);
    print(format, ..args);
    print(NEWLINE);
  }
} @PrintLike

fmod :: inline (x: float, y: float) -> float {
  return x - (floor(x/y) * y); 
}

add_arrow :: (arrow: Arrow) {
  arrows[arrow_index] = arrow;
  arrow_index += 1;
  arrow_index %= arrows.count;
  num_arrows += 1;
  num_arrows = min(num_arrows, arrows.count);
}

clear_arrows :: () #expand {
  arrow_index = 0;
  num_arrows = 0;
}

format_float_time :: (prefix: string, suffix: string, value: float64, theme: *Slider_Theme, state: *Slider_State, mode: Slider_Format_Text_Mode) -> string {
  mins := cast(int) (value / 60.0);
  secs := cast(int) fmod(cast(float)value, 60.0);
  return tprint("%1:%2", mins, formatInt(secs, minimum_digits=2));
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

Engine :: struct {
  name: string;
  process: Process;
  state: EngineState = .uciok;
  timer: float = FLOAT32_INFINITY; // for keeping track of time
  options: [..] Engine_Option;
}

Engine_Option :: struct {
  name: string;
  type: UCI_Types;
  check_value: bool;
  spin_value: int;
  spin_max: int;
  spin_min: int;
  combo_value: s32;
  combo_values: [..] string;
  string_value: string;

  check_value_old: bool;
  spin_value_old: int;
  combo_value_old: s32;
  string_value_old: string;

}

Arrow :: struct {
  from: u8;
  to: u8;
}

EngineState :: enum {
  uciok;
  isready;
  ucinewgame;
  idle;
  go;
  bestmove;
  bug;
}

TimeControl :: enum s32 {
  none;
  clock;
  time_per_move;
  depth;
}

UCI_Types :: enum {
  check;
  spin;
  combo;
  button;
  uci_string;
}

is_draw :: () -> bool {
  count_p := popcount(chess.occupied);
  if count_p <= 3 then {
    if count_p == 2 then {
      return true;
    }
    if (chess.w_bishop|chess.w_knight|chess.b_bishop|chess.b_knight) & chess.occupied then {
      return true;
    }
  }

  return false;
}

sound_quiet_move: Sound.Sound_Data;
sound_capture_move: Sound.Sound_Data;

init_sound :: () {
  sound_quiet_move = Sound.load_audio_file("resources/move.wav");
  assert(sound_quiet_move.loaded);

  sound_capture_move = Sound.load_audio_file("resources/capture.wav");
  assert(sound_capture_move.loaded);

  // initialize sound player
  Sound.sound_player_init(.{});
}

stage_sound :: (data: *Sound.Sound_Data, category := Sound.Sound_Category.GENERAL_SFX, perturb := true) -> *Sound.Sound_Stream {
  stream := Sound.make_stream(data, category);
  if perturb {
    stream.user_volume_scale = random_get_within_range(0.5, 1.4);
    stream.rate_scale        = random_get_within_range(0.7, 1.22);
  }
  return stream;
}

play_sound :: (sound: *Sound.Sound_Data) {
  stream := stage_sound(sound, .GENERAL_SFX, true);
  Sound.start_playing(stream);
}

simp :: #import "Simp";
#import "System"; // For get_path_of_running_executable.
#import "String"; // For path_strip_filename. 
#import "Math";
#import "Basic";
#import "GetRect";
#import "Input";
#import "Window_Creation";
Sound :: #import "Sound_Player";
#import "Wav_File";
#import "File";
#import "Random";
#import "Process";
