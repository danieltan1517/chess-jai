win: Window_Type;
chess_piece_bitmap: simp.Texture;
font: *simp.Dynamic_Font;
current_color_theme : s32 = 0;

main :: () {
  path := path_strip_filename(get_path_of_running_executable());
  set_working_directory(path);



  win = create_window(600, 800, "Chess");
  width, height := simp.get_render_dimensions(win);
  simp.set_render_target(win);
  success := simp.texture_load_from_file(*chess_piece_bitmap, "resources/chess_pieces.png");
  init_fonts(height);
  ui_init();

  assert(success);

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
    for e: events_this_frame {
      if e.type == .QUIT then quit = true;
    }

    if quit == true then
      break;

    draw_chess_board(xx width, xx height);
    draw_chess_pieces(xx width, xx height);
    draw_ui();


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
  }

  draw_chess_pieces :: (width: float, height: float) {
    cen_x := width  / 2;
    cen_y := height / 2;
    square := 0.85 * min(width, height) / 8.0;
    corner_x := cen_x - square * 4.0;
    corner_y := cen_y - square * 4.0;

    simp.set_shader_for_images(*chess_piece_bitmap);
    simp.immediate_begin();

    p0 := make_vector2(corner_x, corner_y + square * 7);
    p1 := make_vector2(p0.x, p0.y + square);
    p2 := make_vector2(p0.x + square, p0.y + square);
    p3 := make_vector2(p0.x + square, p0.y);
    draw_brook(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 7, corner_y + square * 7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_brook(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 7, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wrook(p0, p1, p2, p3);

    p0 = make_vector2(corner_x, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wrook(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wknight(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 6, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wknight(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square, corner_y + square * 7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_bknight(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 6, corner_y + square*7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_bknight(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 5, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wbishop(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 2, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wbishop(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 5, corner_y + square*7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_bbishop(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 2, corner_y + square*7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_bbishop(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 3, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wqueen(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 3, corner_y + square*7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_bqueen(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 4, corner_y);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_wking(p0, p1, p2, p3);

    p0 = make_vector2(corner_x + square * 4, corner_y + square*7);
    p1 = make_vector2(p0.x, p0.y + square);
    p2 = make_vector2(p0.x + square, p0.y + square);
    p3 = make_vector2(p0.x + square, p0.y);
    draw_bking(p0, p1, p2, p3);

    for i: 0..7 {
      p0 = make_vector2(corner_x + square * i, corner_y + square);
      p1 = make_vector2(p0.x, p0.y + square);
      p2 = make_vector2(p0.x + square, p0.y + square);
      p3 = make_vector2(p0.x + square, p0.y);
      draw_wpawn(p0, p1, p2, p3);
     
      p0 = make_vector2(corner_x + square * i, corner_y + square*6);
      p1 = make_vector2(p0.x, p0.y + square);
      p2 = make_vector2(p0.x + square, p0.y + square);
      p3 = make_vector2(p0.x + square, p0.y);
      draw_bpawn(p0, p1, p2, p3);
    }

    simp.immediate_flush();
  }

  draw_ui :: () {
    current_time := get_time();
    x, y, width, height := get_dimensions(win, true);
    ui_per_frame_update(win, width, height, current_time);

    button_height := height * .03;
    
    //
    // Dropdown stuff.
    //
    k := height * .1;
    r := get_rect(k*.5, 9.0*k, 3*k * 0.5, k * 0.5);
    dropdown_theme := *default_overall_theme.dropdown_theme;
    // The 'dropdown' function causes a popup to be created, which
    // gets rendered at the end of the frame when we call draw_popups().
    // The theme and choices array must remain valid until after that time!
    // The 'current_theme' pointer also needs to remain pointing at valid memory
    // until after that time, as that is when it will be changed.
    old_color_theme := current_color_theme;
    dropdown(r, COLORS, *current_color_theme, dropdown_theme);

    COLORS :: string.["green", "blue", "grey", "brown", "purple", "red"]; 

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
    pixel_height := height / 24;
    font = simp.get_font_at_size("resources", "AnonymousPro.ttf", pixel_height);
    assert(font != null, "font not loaded properly");
  }
}

white_sq_color := Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
black_sq_color := Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};

simp :: #import "Simp";
#import "System"; // For get_path_of_running_executable.
#import "String"; // For path_strip_filename. 
#import "Math";
#import "Basic";
#import "GetRect";
#import "Input";
#import "Window_Creation";
#import "GetRect";

