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

(** Write file tool *)
let write_file (file_path : string) (content : string) : simple_tool_result Lwt.t =
  Lwt.catch
    (fun () ->
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