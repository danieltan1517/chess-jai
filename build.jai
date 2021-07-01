#import "Basic";
#import "Compiler";

exe_name :: "chess-jai";

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

build_debug :: () {
  w := compiler_create_workspace();
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = exe_name;
  target_options.optimization_level = .DEBUG;
  target_options.backend = .X64;
  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  add_build_file(tprint("%/main.jai", #filepath), w);  
  add_build_file(tprint("%/asm.jai" , #filepath), w);  
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
  target_options.output_executable_name = exe_name;
  target_options.optimization_level = .RELEASE;
  set_optimization_level(*target_options, 3, 0);

  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  add_build_file(tprint("%/main.jai", #filepath), w);  
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

