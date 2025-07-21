(** Project coordination tools - Multi-file operations and dependency analysis *)

open Ogemini.Types
open Lwt.Infix

(** Project analysis result *)
type project_analysis = {
  files: string list;
  modules: (string * string list) list; (* module_name * dependencies *)
  entry_points: string list;
  build_files: string list;
}

(** Analyze OCaml project structure *)
let analyze_project_structure path =
  let rec scan_directory dir_path =
    Lwt.catch
      (fun () ->
        Lwt_unix.opendir dir_path >>= fun dir_handle ->
        let rec read_entries acc =
          Lwt.catch
            (fun () ->
              Lwt_unix.readdir dir_handle >>= fun entry ->
              if entry = "." || entry = ".." then
                read_entries acc
              else
                let full_path = Filename.concat dir_path entry in
                Lwt_unix.stat full_path >>= fun stat ->
                match stat.st_kind with
                | S_DIR when not (String.contains entry '.') ->
                    scan_directory full_path >>= fun sub_files ->
                    read_entries (sub_files @ acc)
                | S_REG when String.ends_with ~suffix:".ml" entry || 
                            String.ends_with ~suffix:".mli" entry ||
                            String.ends_with ~suffix:"dune" entry ||
                            String.ends_with ~suffix:"dune-project" entry ->
                    read_entries (full_path :: acc)
                | _ -> read_entries acc)
            (function
              | End_of_file ->
                  Lwt_unix.closedir dir_handle >>= fun () ->
                  Lwt.return acc
              | exn -> Lwt.fail exn)
        in
        read_entries [])
      (fun _ -> Lwt.return [])
  in
  scan_directory path >>= fun all_files ->
  
  let ml_files = List.filter (String.ends_with ~suffix:".ml") all_files in
  let build_files = List.filter (fun f -> 
    String.ends_with ~suffix:"dune" f || String.ends_with ~suffix:"dune-project" f) all_files in
  
  (* Extract module names and analyze dependencies *)
  let extract_module_name file_path =
    let basename = Filename.basename file_path in
    let name_without_ext = 
      if String.ends_with ~suffix:".ml" basename then
        String.sub basename 0 (String.length basename - 3)
      else basename
    in
    String.capitalize_ascii name_without_ext
  in
  
  (* Simple dependency analysis - look for module references *)
  let analyze_dependencies file_path =
    Lwt.catch
      (fun () ->
        Lwt_io.with_file ~mode:Lwt_io.Input file_path Lwt_io.read >>= fun content ->
        let lines = String.split_on_char '\n' content in
        let deps = List.fold_left (fun acc line ->
          let line = String.trim line in
          (* Look for open statements and module references *)
          if String.starts_with ~prefix:"open " line then
            let module_name = String.sub line 5 (String.length line - 5) |> String.trim in
            module_name :: acc
          else if String.contains line '.' then
            (* Look for Module.function patterns *)
            let parts = String.split_on_char ' ' line in
            List.fold_left (fun acc2 part ->
              if String.contains part '.' then
                let module_ref = String.split_on_char '.' part |> List.hd in
                if String.length module_ref > 0 && 
                   Char.uppercase_ascii (String.get module_ref 0) = String.get module_ref 0 then
                  module_ref :: acc2
                else acc2
              else acc2
            ) acc parts
          else acc
        ) [] lines in
        Lwt.return (List.sort_uniq String.compare deps))
      (fun _ -> Lwt.return [])
  in
  
  (* Analyze all ML files for dependencies *)
  let rec analyze_all_files files modules =
    match files with
    | [] -> Lwt.return modules
    | file :: rest ->
        let module_name = extract_module_name file in
        analyze_dependencies file >>= fun deps ->
        analyze_all_files rest ((module_name, deps) :: modules)
  in
  
  analyze_all_files ml_files [] >>= fun modules ->
  
  (* Determine entry points (files with main functions or executables) *)
  let find_entry_points files =
    let rec check_files acc = function
      | [] -> Lwt.return acc
      | file :: rest ->
          Lwt.catch
            (fun () ->
              Lwt_io.with_file ~mode:Lwt_io.Input file Lwt_io.read >>= fun content ->
              if Str.string_match (Str.regexp ".*let main.*") content 0 ||
                 Str.string_match (Str.regexp ".*let () =.*") content 0 then
                check_files (file :: acc) rest
              else
                check_files acc rest)
            (fun _ -> check_files acc rest)
    in
    check_files [] files
  in
  
  find_entry_points ml_files >>= fun entry_points ->
  
  Lwt.return {
    files = all_files;
    modules = modules;
    entry_points = entry_points;
    build_files = build_files;
  }

(** Find all references to a module across the project *)
let find_module_references module_name project_path =
  let search_pattern = Printf.sprintf "%s\\." module_name in
  let search_params = {
    Search_tools.pattern = search_pattern;
    path = Some project_path;
    file_pattern = Some "*.ml";
    context_lines = 2;
  } in
  Search_tools.perform_search search_params

(** Rename a module and update all references *)
let rename_module_across_project old_name new_name project_path =
  Printf.printf "🔄 Renaming module %s to %s across project\n" old_name new_name;
  flush_all ();
  
  (* Step 1: Find all references *)
  find_module_references old_name project_path >>= fun search_result ->
  
  if not search_result.success then
    Lwt.return { content = "Failed to search for module references"; success = false; error_msg = search_result.error_msg }
  else
    (* Step 2: Parse search results and plan replacements *)
    let references = String.split_on_char '\n' search_result.content in
    let file_updates = List.fold_left (fun acc line ->
      let line = String.trim line in
      if String.contains line ':' then
        let parts = String.split_on_char ':' line in
        match parts with
        | file_path :: _ :: _ ->
            if not (List.mem file_path acc) then file_path :: acc else acc
        | _ -> acc
      else acc
    ) [] references in
    
    Printf.printf "📋 Found %d files with references to %s\n" (List.length file_updates) old_name;
    flush_all ();
    
    (* Step 3: Update each file *)
    let rec update_files updated_count = function
      | [] -> 
          let msg = Printf.sprintf "Successfully renamed module %s to %s in %d files" 
            old_name new_name updated_count in
          Lwt.return { content = msg; success = true; error_msg = None }
      | file_path :: rest ->
          let old_pattern = old_name ^ "." in
          let new_pattern = new_name ^ "." in
          let edit_params = {
            Edit_tools.file_path = file_path;
            old_string = old_pattern;
            new_string = new_pattern;
            expected_replacements = None; (* Allow any number of replacements *)
          } in
          Edit_tools.edit_file edit_params >>= fun edit_result ->
          
          if edit_result.success then (
            Printf.printf "✅ Updated %s\n" file_path;
            flush_all ();
            update_files (updated_count + 1) rest
          ) else (
            Printf.printf "⚠️ Failed to update %s: %s\n" file_path 
              (Option.value edit_result.error_msg ~default:"Unknown error");
            flush_all ();
            update_files updated_count rest
          )
    in
    
    update_files 0 file_updates

(** Tool interface for project analysis *)
let tool_analyze_project args =
  let path = List.assoc_opt "path" args |> Option.value ~default:"/workspace" in
  
  Printf.printf "🔍 Analyzing project structure at %s\n" path;
  flush_all ();
  
  analyze_project_structure path >>= fun analysis ->
  
  let summary = Printf.sprintf {|📊 Project Analysis Results:

📁 Files found: %d
   - ML files: %d  
   - Build files: %d

🧩 Modules detected: %d
%s

🚀 Entry points: %d
%s

📋 Build configuration:
%s|}
    (List.length analysis.files)
    (List.length (List.filter (String.ends_with ~suffix:".ml") analysis.files))
    (List.length analysis.build_files)
    (List.length analysis.modules)
    (String.concat "\n" (List.map (fun (name, deps) ->
      Printf.sprintf "   - %s (deps: %s)" name (String.concat ", " deps)
    ) analysis.modules))
    (List.length analysis.entry_points)
    (String.concat "\n" (List.map (fun ep -> "   - " ^ ep) analysis.entry_points))
    (String.concat "\n" (List.map (fun bf -> "   - " ^ bf) analysis.build_files))
  in
  
  Lwt.return { content = summary; success = true; error_msg = None }

(** Tool interface for module renaming *)
let tool_rename_module args =
  let old_name = List.assoc_opt "old_name" args |> Option.value ~default:"" in
  let new_name = List.assoc_opt "new_name" args |> Option.value ~default:"" in
  let path = List.assoc_opt "path" args |> Option.value ~default:"/workspace" in
  
  if old_name = "" || new_name = "" then
    Lwt.return { content = ""; success = false; error_msg = Some "Both old_name and new_name are required" }
  else
    rename_module_across_project old_name new_name path