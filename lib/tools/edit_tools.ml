(** Edit/Replace tool - Precise text replacement inspired by gemini-cli *)

open Ogemini.Types
open Lwt.Infix

(** Parameters for edit operation *)
type edit_params = {
  file_path: string;
  old_string: string;
  new_string: string;
  expected_replacements: int option;
}

(** Count occurrences of substring in string *)
let count_occurrences str substr =
  if substr = "" then 0
  else
    let rec count pos acc =
      match String.index_from_opt str pos (String.get substr 0) with
      | None -> acc
      | Some idx ->
          if idx + String.length substr <= String.length str &&
             String.sub str idx (String.length substr) = substr then
            count (idx + String.length substr) (acc + 1)
          else
            count (idx + 1) acc
    in
    count 0 0

(** Replace all occurrences of old_string with new_string *)
let replace_all_occurrences content old_string new_string =
  if old_string = "" then content
  else
    let old_len = String.length old_string in
    let content_len = String.length content in
    
    let rec build_result acc pos =
      if pos >= content_len then
        List.rev acc |> String.concat ""
      else
        if pos + old_len <= content_len &&
           String.sub content pos old_len = old_string then
          build_result (new_string :: acc) (pos + old_len)
        else
          let char = String.make 1 (String.get content pos) in
          build_result (char :: acc) (pos + 1)
    in
    build_result [] 0

(** Validate edit parameters *)
let validate_edit_params params =
  (* For simplicity, allow both relative and absolute paths *)
  if params.file_path = "" then
    `Error "File path cannot be empty"
  else
    `Ok ()

(** Execute edit operation *)
let edit_file (params : edit_params) : simple_tool_result Lwt.t =
  match validate_edit_params params with
  | `Error msg -> 
      Lwt.return { content = ""; success = false; error_msg = Some msg }
  | `Ok () ->
      Lwt.catch
        (fun () ->
          (* Handle new file creation when old_string is empty *)
          if params.old_string = "" then
            if Sys.file_exists params.file_path then
              Lwt.return { content = ""; success = false; error_msg = Some "File already exists, cannot create" }
            else
              let dir_path = Filename.dirname params.file_path in
              (if dir_path <> "." && dir_path <> params.file_path then (
                try File_tools.create_directory_recursive dir_path
                with Unix.Unix_error _ -> ()
              ));
              Lwt_io.with_file ~mode:Lwt_io.Output params.file_path (fun oc ->
                Lwt_io.write oc params.new_string
              ) >>= fun () ->
              let msg = Printf.sprintf "Created new file: %s" params.file_path in
              Lwt.return { content = msg; success = true; error_msg = None }
          else
            (* Edit existing file *)
            Lwt_io.with_file ~mode:Lwt_io.Input params.file_path Lwt_io.read >>= fun current_content ->
            
            let occurrences = count_occurrences current_content params.old_string in
            let expected = match params.expected_replacements with 
              | Some n -> n 
              | None -> 1 
            in
            
            if occurrences = 0 then
              let msg = Printf.sprintf "Failed to edit, could not find the string to replace in %s" params.file_path in
              Lwt.return { content = ""; success = false; error_msg = Some msg }
            else if occurrences <> expected then
              let msg = Printf.sprintf "Failed to edit, expected %d occurrence(s) but found %d in %s" 
                expected occurrences params.file_path in
              Lwt.return { content = ""; success = false; error_msg = Some msg }
            else
              let new_content = replace_all_occurrences current_content params.old_string params.new_string in
              Lwt_io.with_file ~mode:Lwt_io.Output params.file_path (fun oc ->
                Lwt_io.write oc new_content
              ) >>= fun () ->
              let msg = Printf.sprintf "Successfully modified file: %s (%d replacements)" 
                params.file_path occurrences in
              Lwt.return { content = msg; success = true; error_msg = None })
        (fun exn ->
          let msg = Printexc.to_string exn in
          Lwt.return { content = ""; success = false; error_msg = Some msg })

(** Parse edit parameters from tool arguments *)
let parse_edit_params args =
  let file_path = List.assoc_opt "file_path" args |> Option.value ~default:"" in
  let old_string = List.assoc_opt "old_string" args |> Option.value ~default:"" in
  let new_string = List.assoc_opt "new_string" args |> Option.value ~default:"" in
  let expected_replacements = List.assoc_opt "expected_replacements" args 
    |> Option.map int_of_string_opt |> Option.join in
  { file_path; old_string; new_string; expected_replacements }

(** Main edit tool entry point *)
let tool_edit_file args =
  let params = parse_edit_params args in
  edit_file params