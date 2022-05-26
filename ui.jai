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
chess: Chess;
chess_mouse: ChessMouse = ChessMouse.Idle;
chess_square_select := -1;


sound_player : *Sound_Player;
sound_quiet_move: *Mixer_Sound_Data; // load_audio_file(name);
sound_capture_move: *Mixer_Sound_Data; // load_audio_file(name);

white_sq_color := Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
black_sq_color := Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};

main :: () {
  path := path_strip_filename(get_path_of_running_executable());
  set_working_directory(path);

  // create a window. 
  // initialize fonts.
  // init ui.
  win = create_window(600, 800, "Chess");
  width, height := simp.get_render_dimensions(win);
  simp.set_render_target(win);

  init_sound();
  init_textures();

  init_fonts(height);
  ui_init();

  // initialize chess w/ the starting position.
  init_global_bitboards();
  chess_startpos(*chess);

  // main game loop
  while true {
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
      if e.type == .KEYBOARD then {
        if e.key_code == .MOUSE_BUTTON_LEFT {
          key_pressed = e.key_pressed;
          mouse_event = true;
        } 
      }
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
    post_entity_update(sound_player, 0);


    simp.swap_buffers(win);
    sleep_milliseconds(10);
    reset_temporary_storage();
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
  }

  draw_chess_pieces :: (width: float, height: float, x: float, y: float, mouse_event: bool, key_pressed: int) {
    cen_x := width  / 2;
    cen_y := height / 2;
    square := 0.85 * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;
    end_x := corner_x + square * 8.0;
    end_y := corner_y + square * 8.0;

    // TODO: get this to actually work correctly!
    // TODO: handle the moves correctly.
    // chess board logic on the mouse event.
    if mouse_event {
      if x >= corner_x && x <= end_x then {
        if y >= corner_y && y <= end_y then {
          mouse_coor_x := cast(int) ((x - corner_x) / square);
          mouse_coor_y := cast(int) ((y - corner_y) / square);
          if board_orientation == false then {
            mouse_coor_x = 7 - mouse_coor_x;
            mouse_coor_y = 7 - mouse_coor_y;
          }
     
          if chess_mouse == {
          case ChessMouse.Idle;
            if key_pressed == 1 {
              chess_mouse = ChessMouse.Drag;
              position := mouse_coor_x + mouse_coor_y * 8;
              chess_square_select = position;
            }
          case ChessMouse.Drag;
            if key_pressed == 0 {
              position := mouse_coor_x + mouse_coor_y * 8;
              if chess_square_select == position {
                chess_mouse = ChessMouse.Select;
              } else {
                chess_mouse = ChessMouse.Idle;
                from := chess_square_select;
                to := position;
                flag := get_move16_flag(*chess, from, to);
                mov := to_move16(from, to, flag);
                ui_make_move(*chess, mov);
                chess_square_select = -1;
              }
            }
          case ChessMouse.Select;
            position := mouse_coor_x + mouse_coor_y * 8;
            from := chess_square_select;
            to := position;
            flag := get_move16_flag(*chess, from, to);
            mov := to_move16(from, to, flag);
            ui_make_move(*chess, mov);
            chess_square_select = -1;
            chess_mouse = ChessMouse.Idle;
          }
        }
      }
    }

    simp.set_shader_for_images(*chess_piece_bitmap);
    simp.immediate_begin();

    for piece, index: chess.pieces {
      if chess_mouse == ChessMouse.Drag && chess_square_select == index then 
        continue;
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
      draw_piece(p0, p1, p2, p3, piece);
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
    simp.immediate_flush();
  }

  draw_piece :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, piece: Piece) {
    if piece == {
    case  Piece.NONE;
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
    current_time := get_time();
    ui_per_frame_update(win, width, height, current_time);

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
    pressed := button(r, "", *button_theme, texture=*setting_bitmap);
    if pressed then {
      options_on = !options_on;
    }
    
    if options_on then {
      simp.set_shader_for_color();
      simp.immediate_quad(r.x - k*7.0, r.y, r.x + k*7.0, r.y - k*8.0, color = Vector4.{.22, .22, .22, 1});
      // Color Dropdown Menu.
      r.x -= k*7.0;
      r.y -= k*1.1;
      r.w = k*8.0;
      r.h = k;

      pressed = button(r, "New Game", *button_theme);
      if pressed then {
        chess_startpos(*chess);
      }


      dropdown_theme := *default_overall_theme.dropdown_theme;
      dropdown_theme.theme_for_current_value.alignment = .Left;
      dropdown_theme.theme_for_each_choice.alignment = .Left;
      dropdown_theme.theme_for_current_choice.alignment = .Left;
      dropdown_theme.theme_for_current_value.font = font;
      dropdown_theme.theme_for_each_choice.font = font;
      dropdown_theme.theme_for_current_choice.font = font;
       
      old_color_theme := current_color_theme;
      r.y -= k*1.1;
      dropdown(r, COLORS, *current_color_theme, dropdown_theme);
     
      COLORS :: string.["green", "blue", "grey", "brown", "purple", "red"]; 
      checkbox_theme: Checkbox_Theme;
      checkbox_theme.font = font;

      r.y -= k*1.1;
      pressed = base_checkbox(r, "Board Orientation", board_orientation, *checkbox_theme);
      if pressed then {
        board_orientation = !board_orientation;
      }

      r.y -= k*1.1;

      pressed = base_checkbox(r, "Display Coordinates", display_coordinates, *checkbox_theme);
      if pressed then {
        display_coordinates = !display_coordinates;
      }

      r.y -= k*1.1;

      pressed = base_checkbox(r, "Audio", sound_on, *checkbox_theme);
      if pressed then {
        sound_on = !sound_on;
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
    pixel_height := height / 40;
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

get_move16_flag :: (chess: *Chess, from: int, to: int) -> Move16 {
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
        return Queen_Promotion;
      return Queen_Promotion_Capture;
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
        return Queen_Promotion;
      return Queen_Promotion_Capture;
    }

  }

  if topiece == Piece.NONE then
    return Quiet;
  else
    return Capture;
}


ChessMouse :: enum {
  Idle;
  Drag;
  Select;
}

ui_make_move :: (chess: *Chess, mov: Move16) {
  if is_legal(chess, mov) then {
    print_move(mov);
    make_move(chess, mov);
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
      stream.flags |= .REPEATING;
      stream.repeat_end_position = cast(int)(data.sampling_rate * 234.475);  // @Temporary @Hack! We do not get the duration by default from an ogg file...
      stream.category = .MUSIC;
  }
  
  return stream;
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
