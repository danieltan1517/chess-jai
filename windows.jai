// contains windows OS specific code.


EXE :: ".exe"; // nothing.
NEWLINE :: "\r\n";


OS :: struct {
  none: void;
}

// defines the AI uci message loop.
getline :: (os: *OS, loop_body: Code, flags: For_Flags) #expand {
  stdin = GetStdHandle(STD_INPUT_HANDLE);
  `it_index := 0;
  while outer := true {
    stopping = false;
    memset(buffera.data, 0, size_of(type_of(buffera)));
    memset(bufferb.data, 0, size_of(type_of(bufferb)));
    bytes_read: u32;
    if !ReadFile(stdin, buffera.data, buffera.count, *bytes_read, null) then {
      sleep_milliseconds(25);
      continue;
    }

    messages := to_string(buffera.data, cast(int)bytes_read);
    while messages {
      found, `it, rest := split_from_left(messages, "\r\n");
      if ends_with(it, "\r\n")
        it.count -= 2;
      if ends_with(it, "\n") then {
        it.count -= 1;
      } 
      #insert (break=break outer) loop_body;
      messages = rest;
      if !found break;
    }
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

    bytes_read: u32;
    bytes_available: u32;
    success := PeekNamedPipe(stdin, null, 0, null, *bytes_available, null) != 0;
    if success && bytes_available {
      ReadFile(stdin, bufferb.data, cast(u32) bufferb.count, *bytes_read, null);
      str := to_string(bufferb.data, bytes_read);
      while str {
        found, msg, rest := split_from_left(str, "\r\n");
        if equal(str, "isready") {
          print("readyok\r\n");
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

stdin: HANDLE;


#import "Windows";
#import "Windows_Utf8";
#import "Basic";
#import "String";
#import "System"; // For get_path_of_running_executable.
