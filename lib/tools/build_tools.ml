(** Build and compilation tools *)

open Ogemini.Types
open Ogemini.Build_error_parser

(** Execute dune build with optional target *)
let dune_build (target : string option) : simple_tool_result Lwt.t =
  let start_time = Unix.gettimeofday () in
  let command = match target with
    | None -> "dune build"
    | Some t -> "dune build " ^ t
  in
  
  (* Determine the correct build directory:
     If we're in a container with /workspace mounted, use that for building *)
  let build_dir = 
    if Sys.file_exists "/workspace" && Sys.is_directory "/workspace" then 
      "/workspace"
    else 
      Sys.getcwd ()
  in
  
  Lwt.catch
    (fun () ->
      let cmd = Printf.sprintf "cd %s && %s 2>&1" build_dir command in
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
      
      let formatted_output = if output = "" then
        if success then "Build completed successfully (no output)"
        else "Build failed (no output)"
      else
        "Build output:\n" ^ output
      in
      
      (* Analyze build errors if build failed *)
      let analysis_output = if not success && output <> "" then (
        let existing_files = try
          let files = Sys.readdir build_dir |> Array.to_list in
          List.filter (fun f -> not (String.contains f '/')) files
        with _ -> []
        in
        Printf.printf "🔍 Build directory: %s\n" build_dir;
        Printf.printf "🔍 Found files: [%s]\n" (String.concat "; " existing_files);
        Printf.printf "🔍 Analyzing build errors...\n";
        let auto_fix = analyze_build_error output existing_files in
        match auto_fix with
        | Some fix_cmd ->
            Printf.printf "🔧 Attempting auto-fix: %s\n" fix_cmd;
            let full_cmd = Printf.sprintf "cd %s && %s" build_dir fix_cmd in
            let fix_result = Sys.command full_cmd in
            if fix_result = 0 then
              "\n🔧 Auto-fix applied successfully"
            else
              "\n❌ Auto-fix failed"
        | None ->
            "\n⚠️ Manual fix required"
      ) else "" in
      
      Printf.printf "%s Build: %s (%.2fs)\n" 
        (if success then "✅" else "❌") command execution_time;
      
      Lwt.return { content = formatted_output ^ analysis_output; success; error_msg = None }
    )
    (fun exn ->
      let execution_time = Unix.gettimeofday () -. start_time in
      let msg = Printf.sprintf "Build execution failed: %s (%.2fs)" 
                  (Printexc.to_string exn) execution_time in
      Printf.printf "❌ %s\n" msg;
      Lwt.return { content = ""; success = false; error_msg = Some msg })

(** Execute dune test with optional target *)
let dune_test (target : string option) : simple_tool_result Lwt.t =
  let start_time = Unix.gettimeofday () in
  let command = match target with
    | None -> "dune test"
    | Some t -> "dune test " ^ t
  in
  
  Lwt.catch
    (fun () ->
      let cmd = Printf.sprintf "cd %s && %s 2>&1" (Sys.getcwd ()) command in
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
      
      let formatted_output = if output = "" then
        if success then "Tests completed successfully (no output)"
        else "Tests failed (no output)"
      else
        "Test output:\n" ^ output
      in
      
      Printf.printf "%s Test: %s (%.2fs)\n" 
        (if success then "✅" else "❌") command execution_time;
      
      Lwt.return { content = formatted_output; success; error_msg = None }
    )
    (fun exn ->
      let execution_time = Unix.gettimeofday () -. start_time in
      let msg = Printf.sprintf "Test execution failed: %s (%.2fs)" 
                  (Printexc.to_string exn) execution_time in
      Printf.printf "❌ %s\n" msg;
      Lwt.return { content = ""; success = false; error_msg = Some msg })

(** Clean build artifacts *)
let dune_clean () : simple_tool_result Lwt.t =
  let start_time = Unix.gettimeofday () in
  
  Lwt.catch
    (fun () ->
      let cmd = Printf.sprintf "cd %s && dune clean 2>&1" (Sys.getcwd ()) in
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
      
      let result_msg = if success then "Build artifacts cleaned successfully" else output in
      
      Printf.printf "🧹 Clean: dune clean (%.2fs)\n" execution_time;
      
      Lwt.return { content = result_msg; success; error_msg = None }
    )
    (fun exn ->
      let execution_time = Unix.gettimeofday () -. start_time in
      let msg = Printf.sprintf "Clean execution failed: %s (%.2fs)" 
                  (Printexc.to_string exn) execution_time in
      Printf.printf "❌ %s\n" msg;
      Lwt.return { content = ""; success = false; error_msg = Some msg })

(** Helper function for string prefix checking *)
let has_prefix prefix s =
  let len_pre = String.length prefix in
  let len_s = String.length s in
  len_s >= len_pre && String.sub s 0 len_pre = prefix

(** Format build output for better readability *)
let parse_build_output (output : string) : string =
  let lines = String.split_on_char '\n' output in
  let rec process_lines acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" then process_lines acc rest
        else if has_prefix "Error:" trimmed then
          process_lines (("❌ " ^ trimmed) :: acc) rest
        else if has_prefix "Warning:" trimmed then
          process_lines (("⚠️  " ^ trimmed) :: acc) rest
        else if has_prefix "File \"" trimmed then
          process_lines (("📁 " ^ trimmed) :: acc) rest
        else
          process_lines (trimmed :: acc) rest
  in
  let processed_lines = process_lines [] lines in
  String.concat "\n" processed_lines