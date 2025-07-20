(** Simplified file tools without lwt ppx *)

open Ogemini.Types
open Lwt.Infix

(** Read file tool *)
let read_file (file_path : string) : simple_tool_result Lwt.t =
  Lwt.catch
    (fun () ->
      if not (Sys.file_exists file_path) then
        Lwt.return { content = ""; success = false; error_msg = Some "File not found" }
      else
        Lwt_io.with_file ~mode:Lwt_io.Input file_path Lwt_io.read >>= fun content ->
        Lwt.return { content; success = true; error_msg = None })
    (fun exn ->
      let msg = Printexc.to_string exn in
      Lwt.return { content = ""; success = false; error_msg = Some msg })

(** Create directory recursively *)
let rec create_directory_recursive dir_path =
  if not (Sys.file_exists dir_path) then (
    let parent_dir = Filename.dirname dir_path in
    if parent_dir <> dir_path then (
      create_directory_recursive parent_dir
    );
    Unix.mkdir dir_path 0o755
  )

(** Write file tool *)
let write_file (file_path : string) (content : string) : simple_tool_result Lwt.t =
  Lwt.catch
    (fun () ->
      (* Create parent directory if it doesn't exist *)
      let dir_path = Filename.dirname file_path in
      (if dir_path <> "." && dir_path <> file_path then (
        try create_directory_recursive dir_path
        with Unix.Unix_error _ -> ()
      ));
      Lwt_io.with_file ~mode:Lwt_io.Output file_path (fun oc ->
        Lwt_io.write oc content
      ) >>= fun () ->
      let msg = "File written: " ^ file_path in
      Lwt.return { content = msg; success = true; error_msg = None })
    (fun exn ->
      let msg = Printexc.to_string exn in
      Lwt.return { content = ""; success = false; error_msg = Some msg })

(** List files tool *)
let list_files (dir_path : string) : simple_tool_result Lwt.t =
  let dir_path = if dir_path = "" then "." else dir_path in
  Lwt.catch
    (fun () ->
      let entries = Sys.readdir dir_path |> Array.to_list |> List.sort String.compare in
      let result = String.concat "\n" entries in
      Lwt.return { content = result; success = true; error_msg = None })
    (fun exn ->
      let msg = Printexc.to_string exn in
      Lwt.return { content = ""; success = false; error_msg = Some msg })