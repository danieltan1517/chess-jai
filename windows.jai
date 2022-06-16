// contains windows OS specific code.

main :: () {
  path := path_strip_filename(get_path_of_running_executable());
  set_working_directory(path);
  exe_name := join(path, "stockfish.exe");

  child_stdin_read: HANDLE = null;
  child_stdin_write: HANDLE = null;
  child_stdout_read: HANDLE = null;
  child_stdout_write: HANDLE = null;

  // set bInheritHandle flag so pipe handles are inherited.
  sa: SECURITY_ATTRIBUTES;
  sa.nLength = size_of(SECURITY_ATTRIBUTES);
  sa.bInheritHandle = .TRUE;
  sa.lpSecurityDescriptor = null;

  // create pipe for child process's STDOUT.
  if !CreatePipe(*child_stdout_read, *child_stdout_write, *sa, 0) {
    print("Error. 1\n");
  }

  if !SetHandleInformation(child_stdout_read, HANDLE_FLAG_INHERIT, 0) {
    print("Error. 2\n");
  }

  // create pipe for child process's STDIN.
  if !CreatePipe(*child_stdin_read, *child_stdin_write, *sa, 0) {
    print("Error. 3\n");
  }

  if !SetHandleInformation(child_stdin_write, HANDLE_FLAG_INHERIT, 0) {
    print("Error. 4\n");
  }

  // create child process.
  piProcInfo: PROCESS_INFORMATION;
  siStartInfo: STARTUPINFOA;
  
  // set up members of PROCESS_INFORMATION struct.
  memset(*piProcInfo, 0, size_of(PROCESS_INFORMATION));

  // set up members of STARTUPINFO struct.
  memset(*siStartInfo, 0, size_of(STARTUPINFOA));
  siStartInfo.cb = size_of(STARTUPINFOA);
  siStartInfo.hStdError = child_stdout_write;
  siStartInfo.hStdOutput = child_stdout_write;
  siStartInfo.hStdInput = child_stdin_read;
  siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

  exe := to_c_string(exe_name);
  if !CreateProcessA(exe, "child", null, null, .TRUE, 0, null, null, *siStartInfo, *piProcInfo)
    print("error.\n");
  else {
    CloseHandle(piProcInfo.hProcess);
    CloseHandle(piProcInfo.hThread);
    CloseHandle(child_stdout_write);
    CloseHandle(child_stdin_read);
  }

  // write proc.
  write_proc(child_stdin_write, "uci\n");
  sleep_milliseconds(1000);
  read_proc(child_stdout_read);
  write_proc(child_stdin_write, "go depth 20\n");
  sleep_milliseconds(1000);
  read_proc(child_stdout_read);
  write_proc(child_stdin_write, "quit\n");
}

write_proc :: (write_pipe: HANDLE, command: string) {
  print("%\n", command);
  written: u32;
  WriteFile(write_pipe, command.data, xx command.count, *written, null);
}

read_proc :: (read_pipe: HANDLE) {

  bytes_read: u32;
  buffer := NewArray(16384, u8, allocator=temp);
  
  while true {

    success := ReadFile(read_pipe, buffer.data, 16383, *bytes_read, null);
    if !success || bytes_read == 0 break;
    messages := to_string(buffer.data, bytes_read);
    print("%\n", messages);
    break;
  }
}

#scope_file
#import "Windows";
#import "Basic";
#import "String";
#import "System"; // For get_path_of_running_executable.
