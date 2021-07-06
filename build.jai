#import "Basic";
#import "Compiler";

#run {
  args_option : enum { debug; release;} = .debug;
  args := compiler_get_command_line_arguments();
  for arg: args {
    if arg == {
    case "debug";
      args_option = .debug;
    case "release";
      args_option = .release;
    case;
      print("Error: Invalid commandline argument: %\n", arg);
      return;
    }
  }

  if args_option == {
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
  build_options := get_build_options();
  build_options.output_type = .NO_OUTPUT;  // No executable for the primary workspace.
  set_build_options(build_options);
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
  build_options := get_build_options();
  build_options.output_type = .NO_OUTPUT;  // No executable for the primary workspace.
  set_build_options(build_options);
}

install :: () {
  // sudo apt install libc++abi-dev   --- Dear ImGui
  // sudo apt install libgl-dev       --- opengl 
  // sudo apt install libglfw-dev     --- glfw
  // sudo apt install clang           --- clang
}

todo :: () {
  //   -- unmake move
  //   -- output/input redirection for UCI interface.
  //   -- parse FEN strings
  //   -- chess ai get started..
}

notes_about_uci :: () {
  //    https://ucichessengine.wordpress.com/introduction/
  //    -- specification is independent of the operating system.
  //    -- engine is a normal executable file, either console or "real" application
  //    -- all communication is done via standard IO with text commands
  //    -- engine should boot and wiat for GUI input
  //    -- engine should wait for the "isready" or "setoption" command to set up its internal parameters as the boot process should be as quick as possible
  //    -- the engine must always be able to process input from stdin, even while thinking
  //    -- all command strings the engine recieves will end with "\n",
  //    -- all commands the gui recieves should end with "\n"
  //    -- engine will alwas be in forced mode, never start calculating or pondering without recieving a "go" command first
  //    -- before engine is asked to search on a position, there will always be a position command to tell the engine about the current position
  //    -- opening book handled by gui
  //    -- if unknown command, ignore it and try to parse the rest of the string
  //    -- if engine receives command which is not supposed to come, e.g. stop when engine is not calculating, ignore it.

  //    https://ucichessengine.wordpress.com/description/
  //    -- all the information about UCI
}







