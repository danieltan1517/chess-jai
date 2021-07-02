#import "Basic";
#import "Compiler";

#run {
  option : enum { debug; release;} = .debug;

  args := compiler_get_command_line_arguments();
  for arg: args {
    if arg == {
    case "debug";
      option = .debug;
    case "release";
      option = .release;
    case;
      print("Invalid commandline argument: %\n", arg);
    }
  }

  if option == {
  case .debug;
    build_debug();
  case .release;
    build_release();
  }
}

executable_name :: "chess-jai";
file_names :: string.["main.jai", "asm.jai", "bitboard.jai"];

build_debug :: () {
  w := compiler_create_workspace();
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = executable_name;
  target_options.optimization_level = .DEBUG;
  target_options.backend = .X64;
  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  for file_names {
    add_build_file(tprint("%/%", #filepath, it), w);  
  }


  while true {
    message := compiler_wait_for_message();
    if !message break;
    if message.kind == {
    case .COMPLETE;
      break;
    }
  }
  compiler_end_intercept(w);
  options := get_build_options();
  options.output_type = .NO_OUTPUT;  // No executable for the primary workspace.
  set_build_options(options);
}

build_release :: () {
  w := compiler_create_workspace();
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = executable_name;
  target_options.optimization_level = .RELEASE;
  set_optimization_level(*target_options, 3, 0);

  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  // add all the files
  for file_names {
    add_build_file(tprint("%/%", #filepath, it), w);  
  }
  while true {
    message := compiler_wait_for_message();
    if !message break;
    if message.kind == {
    case .COMPLETE;
      break;
    }
  }
  compiler_end_intercept(w);
  options := get_build_options();
  options.output_type = .NO_OUTPUT;  // No executable for the primary workspace.
  set_build_options(options);
}

install :: () {
  // sudo apt install libc++abi-dev   --- Dear ImGui
  // sudo apt install libgl-dev       --- opengl 
  // sudo apt install libglfw-dev     --- glfw
  // sudo apt install clang           --- clang
}

todo :: () {
  // glfw needs to get working
  // imgui needs to get working
  // draw chessboard on screen
}




