(** Shell execution tools with safety checks *)

open Ogemini.Types

(** Safe command whitelist - basic commands that are generally safe *)
let safe_commands = [
  "ls"; "cat"; "head"; "tail"; "wc"; "grep"; "find"; "pwd"; "date"; "cd";
  "echo"; "which"; "whoami"; "id"; "uname"; "hostname";
  "dune"; "opam"; "ocamlfind"; "ocaml"; "ocamlc"; "ocamlopt";
  "git"; "make"; "cmake"; "cargo"; "npm"; "node"; "python"; "python3";
]

(** Check if a command is in the safe list *)
let is_safe_command (command : string) : bool =
  let cmd_parts = String.split_on_char ' ' (String.trim command) in
  match cmd_parts with
  | [] -> false
  | first_cmd :: _ ->
      let base_cmd = Filename.basename first_cmd in
      List.mem base_cmd safe_commands

(** Check for dangerous patterns *)
let has_dangerous_patterns (command : string) : bool =
  let dangerous_patterns = [
    "rm "; "rmdir "; "mv "; "cp "; "> "; ">>"; "| rm"; "| rmdir";
    "sudo "; "su "; "chmod "; "chown "; "killall"; "pkill";
    "&& rm"; "&& rmdir"; "; rm"; "; rmdir"; "curl "; "wget ";
  ] in
  List.exists (fun pattern -> 
    let rec contains_substring s sub i =
      if i + String.length sub > String.length s then false
      else if String.sub s i (String.length sub) = sub then true
      else contains_substring s sub (i + 1)
    in
    contains_substring command pattern 0
  ) dangerous_patterns

(** Execute a shell command safely *)
let execute_shell (command : string) : simple_tool_result Lwt.t =
  let start_time = Unix.gettimeofday () in
  
  (* Basic safety checks *)
  if String.trim command = "" then
    Lwt.return { content = ""; success = false; error_msg = Some "Empty command" }
  else if has_dangerous_patterns command then
    Lwt.return { 
      content = ""; 
      success = false; 
      error_msg = Some "Command contains potentially dangerous patterns" 
    }
  else if not (is_safe_command command) then
    let base_cmd = command |> String.split_on_char ' ' |> List.hd |> Filename.basename in
    Lwt.return { 
      content = ""; 
      success = false; 
      error_msg = Some ("Command '" ^ base_cmd ^ "' is not in the safe command list") 
    }
  else
    (* Execute the command *)
    Lwt.catch
      (fun () ->
        let cmd = Printf.sprintf "cd %s && %s" (Sys.getcwd ()) command in
        let process = Unix.open_process_in cmd in
        let rec read_output acc =
          try
            let line = input_line process in
            read_output (line :: acc)
          with End_of_file -> List.rev acc
        in
        let output_lines = read_output [] in
        let exit_code = Unix.close_process_in process in
        let output = String.concat "\n" output_lines in
        let execution_time = Unix.gettimeofday () -. start_time in
        
        let success = match exit_code with
          | Unix.WEXITED 0 -> true
          | _ -> false
        in
        
        let result_msg = if output = "" && success then
          "Command executed successfully (no output)"
        else if output = "" && not success then
          "Command failed (no output)"
        else
          output
        in
        
        Printf.printf "📋 Shell execution: %s (%.2fs, exit code: %s)\n" 
          command execution_time
          (match exit_code with
           | Unix.WEXITED n -> string_of_int n
           | Unix.WSIGNALED n -> "signal " ^ string_of_int n
           | Unix.WSTOPPED n -> "stopped " ^ string_of_int n);
        
        Lwt.return { content = result_msg; success; error_msg = None }
      )
      (fun exn ->
        let execution_time = Unix.gettimeofday () -. start_time in
        let msg = Printf.sprintf "Shell execution failed: %s (%.2fs)" 
                    (Printexc.to_string exn) execution_time in
        Printf.printf "❌ %s\n" msg;
        Lwt.return { content = ""; success = false; error_msg = Some msg })

(** Get the list of safe commands *)
let get_safe_commands () : simple_tool_result Lwt.t =
  let content = "Safe commands whitelist:\n" ^ (String.concat ", " safe_commands) in
  Lwt.return { content; success = true; error_msg = None }