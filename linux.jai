// contains linux OS specific code.

Proc :: struct {
  pid: pid_t;
  read_pipe:  s32;
  write_pipe: s32;
}

create_proc :: (command: string) -> Proc, bool {
  proc: Proc;
  pipe_1: [2] s32;
  pipe_2: [2] s32;

  if pipe(*pipe_1) == -1 {
    print("Error creating pipe.\n");
    return proc, false;
  }
  if pipe(*pipe_2) == -1 {
    print("Error creating pipe.\n");
    return proc, false;
  }

  child_pid := fork();
  if child_pid == -1 {
    print("Error in fork.\n");
    return proc, false;
  }

  if child_pid == 0 {
    // child process
    close(pipe_2[1]);
    close(pipe_1[0]);
    w := pipe_1[1];
    r := pipe_2[0];
    if dup2(w, STDOUT_FILENO) < 0 {
      print("Error in child stdout.\n");
      exit(-1);
    }

    // child input/output redirection: 
    if dup2(r, STDIN_FILENO) < 0 {
      print("Error in child stdin.\n");
      exit(-1);
    }

    args: [2] *u8;
    args[0] = to_c_string(command);
    args[1] = null;
    execvp(args[0], args.data);
    exit(-1);
    return proc, false;  // to shut the compiler up.
  } else {
    // parent process
    proc.pid = child_pid;
    close(pipe_1[1]);
    close(pipe_2[0]);
    proc.write_pipe = pipe_2[1];
    proc.read_pipe  = pipe_1[0];
    setup_pipe_nonblock(proc.read_pipe);

    return proc, true; 
  }

  setup_pipe_nonblock :: (pipe: s32) #expand {
    flags := fcntl(pipe, F_GETFL, 0) | O_NONBLOCK;
    fcntl(pipe, F_SETFL, flags);
  }
}

write_proc :: (using proc: *Proc, command: string) {
  print("%\n", command);
  write(write_pipe, command.data, xx command.count);
}

loop :: (proc: *Proc, loop_body: Code, flags: For_Flags) #expand {
  using proc;
  buffer := NewArray(16384, u8, allocator=temp);
  `it_index := 0;
  while outer := true {
    sleep_milliseconds(1000);
    bytes_read := read(read_pipe, buffer.data, xx (buffer.count-1));
    if bytes_read <= 0 then {
      break;
    }

    auto_release_temp();
    messages := to_string(buffer.data, bytes_read); // -1 the '\n' char
    if messages[bytes_read - 1] == #char "\n" then {
      messages.count -= 1;
    } else {

    }

    for message, i: split(messages, "\n") {
      `it := message;
      #insert (break=break outer)loop_body;
      it_index += 1;
    }
  }
}

close_proc :: (using proc: *Proc) {
  // NOTE: this function does NOT call "uci_write_command(engine, "quit")",
  // that needs to be called explicitly
  status: s32;
  waitpid(pid, *status, 0);
  print("[%] quits with return code: %\n" , pid, status);
  close(write_pipe);
  close(read_pipe);
}

main :: () {
  path := path_strip_filename(get_path_of_running_executable());
  set_working_directory(path);
  proc, TF := create_proc(join(path, "resources/", "ceij"));
  print("% %\n", proc, TF);
  write_proc(*proc, "uci\n");
  for :loop str, index: proc {
    print("[immortal %] %\n", index, str);
    //if index == 4 break;
  }
  print("go depth 20\n");
  write_proc(*proc, "go depth 20\n");
  for :loop str, index: proc {
    print("[immortal] %\n", str);
    //if index == 20 break;
  }
  write_proc(*proc, "quit\n");
  print("end of program.\n");
  close_proc(*proc);
}

#scope_file
#import "POSIX";
#import "Basic";
#import "String";
#import "System"; // For get_path_of_running_executable.
