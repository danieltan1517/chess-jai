#import "Basic";
#import "Compiler";



ui_exe :: "chess";
ui_file_names :: string.["ui.jai", "movegen.jai"];

ai_exe :: "ceij";
ai_file_names :: string.["ai_main.jai", "search.jai", "eval.jai", "movegen.jai"];

#run {
  w := compiler_create_workspace("workspace");
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  args := target_options.compile_time_command_line;
  exe := ui_exe;
  file_names := ui_file_names;

  build_debug(w, exe, file_names);

  #if OS == .LINUX {
    add_build_file(tprint("%/%", #filepath, "linux.jai"), w);  
  } else #if OS == .WINDOWS {
    add_build_file(tprint("%/%", #filepath, "windows.jai"), w);  
  }

  while true {
    message := compiler_wait_for_message();
    if !message break;
    if message.kind == {
    case .COMPLETE;
      break;
    }
  }
  set_build_options_dc(.{do_output=false});

}

build_debug :: (w: Workspace, executable_name: string, file_names: [] string) {
  target_options := get_build_options(w);
  target_options.output_executable_name = executable_name;
  target_options.optimization_level = .DEBUG;
  target_options.backend = .X64;
  target_options.temporary_storage_size = 262144;
  target_options.stack_trace = true;

  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  for file_names {
    add_build_file(tprint("%/%", #filepath, it), w);  
  }
}

build_release :: (w: Workspace, executable_name: string, file_names: [] string) {
  target_options := get_build_options(w);
  target_options.output_executable_name = executable_name;
  target_options.optimization_level = .RELEASE;
  target_options.temporary_storage_size = 262144;
  set_optimization_level(*target_options, 3, 3); 
  target_options.stack_trace = false;

  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  for file_names {
    add_build_file(tprint("%/%", #filepath, it), w);  
  }
}


