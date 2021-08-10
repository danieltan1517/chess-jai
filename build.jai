#import "Basic";
#import "Compiler";

ui_exe :: "jai-chess";
ui_file_names :: string.["ui_main.jai", "asm.jai", "bitboard.jai"];

ai_exe :: "lion-tulip";
ai_file_names :: string.["ai_main.jai", "asm.jai", "bitboard.jai", "search.jai", "eval.jai"];

#run {
  args_option : enum { debug; release;} = .debug;
  choice : enum { ai_compile; ui_compile;} = .ai_compile;
  args := compiler_get_command_line_arguments();
  for arg: args {
    if arg == {
    case "debug";
      args_option = .debug;
    case "release";
      args_option = .release;
    case "ui";
      choice = .ui_compile;
    case "ai";
      choice = .ai_compile;
    case;
      print("Error: Invalid commandline argument: %\n", arg);
      return;
    }
  }

  exe : string;
  file_names : [] string; 
  if choice == {
  case .ui_compile;
    exe = ui_exe;
    file_names = ui_file_names;
  case .ai_compile;
    exe = ai_exe;
    file_names = ai_file_names;
  }

  if args_option == {
  case .debug;
    build_debug(exe, file_names, "debug");
  case .release;
    build_release(exe, file_names, "release");
  }
}

build_debug :: (executable_name: string, file_names: [] string, workspace_name: string) {
  w := compiler_create_workspace(workspace_name);
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = executable_name;
  target_options.optimization_level = .DEBUG;
  target_options.backend = .X64;
  target_options.temporary_storage_size = 32768;
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
  build_options := get_build_options();
  build_options.output_type = .NO_OUTPUT;  // No executable for the primary workspace.
  set_build_options(build_options);
}

build_release :: (executable_name: string, file_names: [] string, workspace_name: string) {
  w := compiler_create_workspace(workspace_name);
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = executable_name;
  target_options.optimization_level = .RELEASE;
  target_options.temporary_storage_size = 32768;
  set_optimization_level(*target_options, 1, 0); 

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
  build_options := get_build_options();
  build_options.output_type = .NO_OUTPUT;  // No executable for the primary workspace.
  set_build_options(build_options);
}

install :: () {
  // sudo apt install libc++abi-dev   --- Dear ImGui
  // sudo apt install libgl-dev       --- opengl 
  // sudo apt install libglfw3-dev     --- glfw
  // sudo apt install clang           --- clang
  // https://github.com/Matthies/NN
}

todo :: () {
  // Transposition Table. Should cut down on the moves
}


