// contains windows OS specific code.

Proc :: struct {
  hProcess: HANDLE;
  write: HANDLE;
  read: HANDLE;
}

create_proc :: (command: string) -> Proc, bool {
  proc: Proc;
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
    return proc, false;
  }

  if !SetHandleInformation(child_stdout_read, HANDLE_FLAG_INHERIT, 0) {
    return proc, false;
  }

  // create pipe for child process's STDIN.
  if !CreatePipe(*child_stdin_read, *child_stdin_write, *sa, 0) {
    return proc, false;
  }

  if !SetHandleInformation(child_stdin_write, HANDLE_FLAG_INHERIT, 0) {
    return proc, false;
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

  exe := to_c_string(join(command, ".exe"));
  if !CreateProcessA(exe, "child", null, null, .TRUE, 0, null, null, *siStartInfo, *piProcInfo)
    return proc, false;

  CloseHandle(piProcInfo.hProcess);
  CloseHandle(piProcInfo.hThread);
  CloseHandle(child_stdout_write);
  CloseHandle(child_stdin_read);
  proc.hProcess = piProcInfo.hProcess;
  proc.write = child_stdin_write;
  proc.read = child_stdout_read;
  return proc, true;

}

close_proc :: (using proc: *Proc) -> int {
  code: u32;
  success := GetExitCodeProcess(hProcess, *code);
  CloseHandle(write);
  CloseHandle(read);
  return code;
}

write_proc :: (using proc: *Proc, command: string) {
  written: u32;
  WriteFile(write, command.data, xx command.count, *written, null);
}

loop :: (proc: *Proc, loop_body: Code, flags: For_Flags) #expand {

  bytes_read: u32;
  buffer := NewArray(16384, u8, allocator=temp);
  `it_index := 0;
  
  while true {
    dw: DWORD;
    if !PeekNamedPipe(proc.read, null, 0, null, *dw, null)
      break;
    if dw <= 0 then
      break;

    if !ReadFile(proc.read, buffer.data, 16383, *bytes_read, null) then
      break;
    if bytes_read == 0 then
      break;

    auto_release_temp();
    messages := to_string(buffer.data, bytes_read);
    if ends_with(messages, "\r\n") then {
      messages.count -= 2;
    } 
    found: bool = true;
    msg: string;
    while messages {
      found, msg, messages = split_from_left(messages, #char "\n");
      `it := msg;
      #insert (break=break outer)loop_body;
      it_index += 1;
      if !found break;
    }
  }

}

#scope_file
#import "Windows";
#import "Basic";
#import "String";
#import "System"; // For get_path_of_running_executable.
