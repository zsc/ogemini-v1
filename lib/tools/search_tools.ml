(** Search/Grep tool - Regular expression search inspired by gemini-cli *)

open Ogemini.Types
open Lwt.Infix

(** Parameters for search operation *)
type search_params = {
  pattern: string;
  path: string option;
  file_pattern: string option;
  context_lines: int;
}

(** Search match result *)
type search_match = {
  file_path: string;
  line_number: int;
  line: string;
}

(** Check if a command is available in the system *)
let is_command_available cmd =
  Lwt.catch
    (fun () ->
      let check_cmd = if Sys.win32 then "where " ^ cmd ^ " > NUL 2>&1" else "command -v " ^ cmd ^ " > /dev/null 2>&1" in
      Lwt_unix.system check_cmd >>= function
      | Unix.WEXITED 0 -> Lwt.return true
      | _ -> Lwt.return false)
    (fun _ -> Lwt.return false)

(** Parse grep output in format file:line:content *)
let parse_grep_output output base_path =
  let lines = String.split_on_char '\n' output in
  List.fold_left (fun acc line ->
    let line = String.trim line in
    if line = "" then acc
    else
      match String.index_opt line ':' with
      | None -> acc
      | Some first_colon ->
          let remaining = String.sub line (first_colon + 1) (String.length line - first_colon - 1) in
          (match String.index_opt remaining ':' with
          | None -> acc
          | Some second_colon_rel ->
              let file_path = String.sub line 0 first_colon in
              let line_num_str = String.sub remaining 0 second_colon_rel in
              let content = String.sub remaining (second_colon_rel + 1) 
                (String.length remaining - second_colon_rel - 1) in
              (match int_of_string_opt line_num_str with
              | None -> acc
              | Some line_number ->
                  let relative_path = 
                    if Filename.is_relative file_path then file_path
                    else if String.length file_path > String.length base_path &&
                            String.sub file_path 0 (String.length base_path) = base_path then
                      String.sub file_path (String.length base_path + 1) 
                        (String.length file_path - String.length base_path - 1)
                    else file_path
                  in
                  { file_path = relative_path; line_number; line = content } :: acc))
  ) [] lines |> List.rev

(** Perform system grep search using shell execution *)
let system_grep_search pattern search_path file_pattern =
  (* Try to use system grep if available, otherwise fallback to OCaml *)
  is_command_available "grep" >>= fun has_grep ->
  if has_grep then
    let include_arg = match file_pattern with
      | Some pattern -> Printf.sprintf " --include='%s'" pattern
      | None -> ""
    in
    let cmd = Printf.sprintf 
      "cd '%s' && grep -r -n -H -E --exclude-dir=.git --exclude-dir=node_modules%s '%s' . 2>/dev/null || true"
      search_path include_arg pattern in
    
    (* Use Shell_tools for consistent command execution *)
    Shell_tools.execute_shell cmd >>= fun result ->
    if result.success && String.trim result.content <> "" then
      Lwt.return (Some result.content)
    else
      Lwt.return None
  else
    Lwt.return None

(** Fallback: Pure OCaml search implementation *)
let ocaml_search pattern search_path file_pattern =
  let regexp = 
    try Some (Str.regexp pattern)
    with _ -> None
  in
  match regexp with
  | None -> Lwt.return []
  | Some regex ->
      (* Simple recursive file traversal *)
      let rec find_files dir =
        if Sys.is_directory dir then
          let entries = Sys.readdir dir in
          Array.fold_left (fun acc entry ->
            let full_path = Filename.concat dir entry in
            if Sys.is_directory full_path then
              if entry <> ".git" && entry <> "node_modules" && entry <> "bower_components" then
                find_files full_path @ acc
              else acc
            else
              let matches_pattern = match file_pattern with
                | None -> true
                | Some pat -> 
                    (* Simple wildcard matching for *.ext *)
                    if String.contains pat '*' then
                      let ext = String.sub pat 1 (String.length pat - 1) in
                      Filename.check_suffix entry ext
                    else
                      String.equal (Filename.basename entry) pat
              in
              if matches_pattern then full_path :: acc else acc
          ) [] entries
        else []
      in
      let files = find_files search_path in
      Lwt_list.fold_left_s (fun acc file_path ->
        Lwt.catch
          (fun () ->
            Lwt_io.with_file ~mode:Lwt_io.Input file_path Lwt_io.read >>= fun content ->
            let lines = String.split_on_char '\n' content in
            let matches = List.mapi (fun i line ->
              if Str.string_match regex line 0 then
                Some { 
                  file_path = if String.length file_path > String.length search_path &&
                             String.sub file_path 0 (String.length search_path) = search_path then
                    String.sub file_path (String.length search_path + 1) 
                      (String.length file_path - String.length search_path - 1)
                  else file_path;
                  line_number = i + 1; 
                  line 
                }
              else None
            ) lines |> List.filter_map (fun x -> x) in
            Lwt.return (matches @ acc))
          (fun _ -> Lwt.return acc)
      ) [] files

(** Main search function with fallback strategy *)
let perform_search params =
  let search_path = match params.path with
    | Some p -> p
    | None -> "."
  in
  
  if not (Sys.file_exists search_path) then
    Lwt.return { content = ""; success = false; error_msg = Some "Search path does not exist" }
  else
    (* Try system grep first *)
    is_command_available "grep" >>= fun grep_available ->
    if grep_available then
      system_grep_search params.pattern search_path params.file_pattern >>= function
      | Some output ->
          let matches = parse_grep_output output search_path in
          let result = if matches = [] then
            Printf.sprintf "No matches found for pattern \"%s\" in path \"%s\"" 
              params.pattern search_path
          else
            let match_count = List.length matches in
            let grouped = List.fold_left (fun acc m ->
              let existing = List.assoc_opt m.file_path acc |> Option.value ~default:[] in
              (m.file_path, m :: existing) :: (List.remove_assoc m.file_path acc)
            ) [] matches in
            let formatted = List.map (fun (file, file_matches) ->
              let sorted_matches = List.sort (fun a b -> compare a.line_number b.line_number) file_matches in
              let lines = List.map (fun m -> 
                Printf.sprintf "L%d: %s" m.line_number (String.trim m.line)
              ) sorted_matches in
              Printf.sprintf "File: %s\n%s" file (String.concat "\n" lines)
            ) grouped in
            Printf.sprintf "Found %d match(es) for pattern \"%s\" in path \"%s\":\n---\n%s\n---" 
              match_count params.pattern search_path (String.concat "\n---\n" formatted)
          in
          Lwt.return { content = result; success = true; error_msg = None }
      | None ->
          (* Fallback to OCaml implementation *)
          ocaml_search params.pattern search_path params.file_pattern >>= fun matches ->
          let result = if matches = [] then
            Printf.sprintf "No matches found for pattern \"%s\" in path \"%s\"" 
              params.pattern search_path
          else
            let match_count = List.length matches in
            Printf.sprintf "Found %d match(es) for pattern \"%s\" in path \"%s\" (OCaml fallback)" 
              match_count params.pattern search_path
          in
          Lwt.return { content = result; success = true; error_msg = None }
    else
      (* Use OCaml fallback *)
      ocaml_search params.pattern search_path params.file_pattern >>= fun matches ->
      let result = if matches = [] then
        Printf.sprintf "No matches found for pattern \"%s\" in path \"%s\"" 
          params.pattern search_path
      else
        let match_count = List.length matches in
        Printf.sprintf "Found %d match(es) for pattern \"%s\" in path \"%s\" (OCaml fallback)" 
          match_count params.pattern search_path
      in
      Lwt.return { content = result; success = true; error_msg = None }

(** Parse search parameters from tool arguments *)
let parse_search_params args =
  let pattern = List.assoc_opt "pattern" args |> Option.value ~default:"" in
  let path = List.assoc_opt "path" args in
  let file_pattern = List.assoc_opt "file_pattern" args in
  let context_lines = List.assoc_opt "context_lines" args 
    |> Option.map int_of_string_opt |> Option.join |> Option.value ~default:0 in
  { pattern; path; file_pattern; context_lines }

(** Main search tool entry point *)
let tool_search_files args =
  let params = parse_search_params args in
  if params.pattern = "" then
    Lwt.return { content = ""; success = false; error_msg = Some "Pattern cannot be empty" }
  else
    perform_search params