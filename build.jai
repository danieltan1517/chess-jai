#import "Basic";
#import "Compiler";
#import "Machine_X64";
#import "String";
#import "File";
#import "File_Utilities";
#import "Process";

ui_exe_name :: "chess";
ai_exe_name :: "ceij";
author :: "Daniel Tan";

add_chess_engine_files :: (w: Workspace, cpu_info: *Cpu_X86, type: NNUE_Type) {

  // OS specific code.
  #if OS == .LINUX {
    add_build_file("linux.jai", w);  
  } else #if OS == .WINDOWS {
    add_build_file("windows.jai", w);  
  } else #if OS == .MACOS {
    add_build_file("macos.jai", w);  
  }

  // cross platform layer.
  add_build_file("uci.jai", w);  
  add_build_file("search.jai", w);  
  add_build_file("eval.jai", w);  
  add_build_file("movegen.jai", w);  

  // determine which NNUE SIMD to build.
  if type == .auto {
    // automatically add based on whether the CPU has AVX features or not.
    print("Detecting CPU instruction set.\n");
    if check_feature(cpu_info.feature_leaves, .AVX2) {
      type = .avx2;
    } else if check_feature(cpu_info.feature_leaves, .SSE) {
      type = .sse;
    } else {
      type = .cpu;
    }
  }

  if #complete type == {
  case .auto;
    assert(false);
  case .cpu;
    print("Building Chess Engine with NNUE CPU\n");
    add_build_file("nnue_cpu.jai", w);  
  case .sse;
    print("Building Chess Engine with NNUE SSE\n");
    add_build_file("nnue_sse.jai", w);  
  case .avx2; 
    print("Building Chess Engine with NNUE AVX2\n");
    add_build_file("nnue_avx2.jai", w);
  case .nnue_probe;
    print("Building Chess Engine with NNUE Probe\n");

    // I only tested this on Linux. I believe nnue-probe only works on Linux only,
    // and cannot run on windows/mac, but I could be wrong...
    library: string;
    location: string;
    if OS == .LINUX {
      library = "libnnueprobe.so";
      location = "nnue-probe/src/libnnueprobe.so";
    } else if OS == .WINDOWS {
      library =  "libnnueprobe.dll";
      location = "nnue-probe/src/libnnueprobe.dll";
    } else if OS == .MACOS {
      library =  "libnnueprobe.dylib";
      location = "nnue-probe/src/libnnueprobe.dylib";
    }
    if !file_exists(library) {
      if !file_exists("nnue-probe") {
        print("Downloading nnue-probe library by Daniel Shawul.\n");
        run_command("git", "clone", "https://github.com/dshawul/nnue-probe");
      }

      run_command("make", "--directory=nnue-probe/src");
      file_move(location, library);
    }

    add_build_file("nnue_probe.jai", w);
  case;
    assert(false, "Invalid build script.\n");
  }

  uci_message := create_uci_message();
  add_build_string(uci_message, w);
  create_uci_message :: () -> string #expand {

    NEWLINE := ifx OS == .WINDOWS "\r\n" else "\n";
    builder: String_Builder;
    print_to_builder(*builder, "uci_response :: #string END%1", NEWLINE);
    print_to_builder(*builder, "id name %1%2", ai_exe_name, NEWLINE);
    print_to_builder(*builder, "id author %1%2", author, NEWLINE);
    print_to_builder(*builder, "info string neural network type %1%2", type, NEWLINE);
    print_to_builder(*builder, "END%1", NEWLINE);
    return builder_to_string(*builder);
  }

}

add_ui_files :: (w: Workspace) {
  // OS specific code.
  #if OS == .LINUX {
    add_build_file("linux.jai", w);  
  } else #if OS == .WINDOWS {
    add_build_file("windows.jai", w);  
  } else #if OS == .MACOS {
    add_build_file("macos.jai", w);  
  }

  // cross platform layer.
  add_build_file("ui.jai", w);  
  add_build_file("movegen.jai", w);  
}

#run {
  cpu_info := get_cpu_info();
  defer set_build_options_dc(.{do_output=false});
  target_options := get_build_options();
  args := target_options.compile_time_command_line;
  flags: CompileFlags = 0;
  nnue_type: NNUE_Type = .auto;
  if args.count == 0 then {
    flags = CompileFlags.ui | .ai | .release;
  }

  for arg: args {
    if arg == {
    case "ui";
      flags |= .ui;
    case "ai";
      flags |= .ai;
    case "debug";
      flags &= ~.release;
    case "release";
      flags |= .release;
    case "avx2";
      nnue_type = .avx2;
    case "sse";
      nnue_type = .sse;
    case "cpu";
      nnue_type = .cpu;
    case "nnue_probe";
      nnue_type = .nnue_probe;
      
    }
  }

  if flags & .ai {
    w: Workspace;
    if flags & .release {
      w = build_release(*cpu_info, ai_exe_name);
    } else {
      w = build_debug(*cpu_info, ai_exe_name);
    }
    add_chess_engine_files(w, *cpu_info, nnue_type);
    print("Building Chess Engine [%]\n", ai_exe_name);
  }

  if flags & .ui {
    w: Workspace;
    if flags & .release {
      w = build_release(*cpu_info, ui_exe_name);
    } else {
      w = build_debug(*cpu_info, ui_exe_name);
    }
    add_ui_files(w);
    print("Building Chess User Interface [%]\n", ui_exe_name);
  }
}

CompileFlags :: enum_flags {
  release;
  ui;
  ai;
}

NNUE_Type :: enum {
  auto;
  cpu;
  sse;
  avx2;
  nnue_probe;
}

build_debug :: (cpu_info: *Cpu_X86, executable_name: string) -> Workspace {
  w := compiler_create_workspace(executable_name);
  options := get_build_options(w);
  options.output_executable_name = executable_name;
  set_optimization(*options, .DEBUG);
  options.backend = .X64;
  options.stack_trace = true;
  set_build_options(options, w);
  movegen_features(cpu_info, w);
  print("Creating Debug Build for: %\n", executable_name);
  return w;
}

build_release :: (cpu_info: *Cpu_X86, executable_name: string) -> Workspace {
  w := compiler_create_workspace(executable_name);
  options := get_build_options(w);
  options.output_executable_name = executable_name;
  set_optimization(*options, .VERY_OPTIMIZED);
  options.llvm_options.enable_split_modules = false;
  options.stack_trace = false;
  set_build_options(options, w);
  movegen_features(cpu_info, w);
  print("Creating Release Build for: %\n", executable_name);
  return w;
}

movegen_features :: (cpu_info: *Cpu_X86, w: Workspace) {
  enable_blsr := check_feature(cpu_info.feature_leaves, .BMI1) == true;
  code := tprint("ENABLE_BLSR :: %;\n", enable_blsr);
  print(code);
  add_build_string(code, w);

  enable_fancy_magic_bitboards := check_feature(cpu_info.feature_leaves, .BMI2) == true;
  code = tprint("FANCY_MAGIC_BITBOARDS :: %;\n", enable_fancy_magic_bitboards);
  print(code);
  add_build_string(code, w);
}
