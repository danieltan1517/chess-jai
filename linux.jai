// contains linux OS specific code.

EXE :: ""; // nothing.
NEWLINE :: "\n";

OS :: struct {}

// defines the AI uci message loop.
getline :: (os: *OS, loop_body: Code, flags: For_Flags) #expand {
  nonblock_stdin();
  `it_index := 0;
  while outer := true {
    stopping = false;
    memset(buffera.data, 0, size_of(type_of(buffera)));
    memset(bufferb.data, 0, size_of(type_of(bufferb)));
    bytes_read := read(STDIN_FILENO, buffera.data, buffera.count-1);
    if bytes_read < 0 {
      sleep_milliseconds(25);
      continue;
    }

    messages := to_string(buffera.data, bytes_read);
    while messages {
      found, `it, rest := split_from_left(messages, #char "\n");
      if !found break;
      #insert (break=break outer) loop_body;
      messages = rest;
    }
  }

  nonblock_stdin :: () #expand {
    flags := fcntl(STDIN_FILENO, F_GETFL, 0) | O_NONBLOCK;
    fcntl(STDIN_FILENO, F_SETFL, flags);
  }
}

read_input :: (main_thread: bool, nodes: int, maxnodes: int, time_begin: float64, movetime: int) #expand {
  if stopping == true then
    `return 0;

  if (nodes & 8191) == 8191 {
    if nodes >= maxnodes {
      stopping = true;
      `return 0;
    }

    if main_thread == false
      return;

    if (nodes & 8191) == 8191 {
      time := get_time();
      left: int = xx (1000.0 * (time - time_begin));
      if left > movetime {
        stopping = true;
        `return 0;
      }
    }

    bytes_read := read(STDIN_FILENO, bufferb.data, bufferb.count-1);
    if bytes_read > 0 {
      str := to_string(bufferb.data, bytes_read-1); // -1 the '\n' char
      while str {
        found, msg, rest := split_from_left(str, #char "\n");
        if equal(str, "isready") {
          print("readyok\n");
        } 

        if equal(str, "stop") {
          stopping = true;
          `return 0;
        }

        if equal(str, "quit") {
          exit(0);
        } 

        str = rest;
        if !found break;
      }
    }
  }
}


stop :: () -> bool #expand {
  return stopping == true;
}

#scope_file
buffera: [4096] u8;
bufferb: [4096] u8;
stopping: bool = false;

#import "POSIX";
#import "Basic";
#import "String";
#import "System"; // For get_path_of_running_executable.
