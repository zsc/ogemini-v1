open Lwt.Syntax
open Types

(** LLM-driven intelligent dune file generator for Phase 5.1.2 **)

(** Project type detection *)
type project_type = 
  | SimpleExecutable of string        (* name *)
  | Library of string                 (* name *)
  | LibraryWithExecutable of string   (* name *)
  | GameProject of string             (* name *)
  | WebProject of string              (* name *)
  | Unknown

(** Detect project type from file list and description *)
let detect_project_type files description =
  let desc_lower = String.lowercase_ascii description in
  let has_file_with_ext ext = List.exists (fun f -> Filename.check_suffix f ext) files in
  let has_keyword keyword = 
    try 
      ignore (Str.search_forward (Str.regexp keyword) desc_lower 0); 
      true 
    with Not_found -> false in
  
  if has_keyword "game" || has_keyword "2048" || has_keyword "puzzle" then
    GameProject "game"
  else if has_keyword "web" || has_keyword "server" || has_keyword "http" then
    WebProject "server"
  else if has_keyword "library" || has_keyword "lib" then
    Library "mylib"
  else if has_file_with_ext ".ml" && has_file_with_ext ".mli" then
    LibraryWithExecutable "myproject"
  else
    SimpleExecutable "main"

(** Generate LLM prompt for dune-project file *)
let create_dune_project_prompt project_type description =
  let project_info = match project_type with
    | SimpleExecutable name -> Printf.sprintf "simple executable named '%s'" name
    | Library name -> Printf.sprintf "OCaml library named '%s'" name
    | LibraryWithExecutable name -> Printf.sprintf "OCaml project '%s' with both library and executable" name
    | GameProject name -> Printf.sprintf "game project '%s' (like 2048, puzzle games)" name
    | WebProject name -> Printf.sprintf "web server project '%s'" name
    | Unknown -> "general OCaml project"
  in
  
  Printf.sprintf {|
Generate a complete dune-project file for a %s.

Project description: %s

Requirements:
1. Use OCaml 5.1 or later (specify as 5.01)
2. Use MINIMAL dependencies - prefer NO dependencies for simple projects
3. Set up basic project metadata only
4. Use modern dune 3.0+ syntax

CRITICAL: For hello world or simple executable projects, use NO dependencies at all.
Do NOT include cmdliner, core, base, or any external dependencies unless absolutely required.

Only add dependencies if the project explicitly needs:
- Web functionality: then consider lwt, cohttp-lwt-unix
- JSON parsing: then consider yojson
- Graphics: then consider graphics

For simple executables, the dune-project should be minimal with no dependencies.

Generate ONLY the dune-project file content, no explanations.
|} project_info description

(** Generate LLM prompt for dune build file *)
let create_dune_build_prompt project_type description existing_files original_content =
  let project_info = match project_type with
    | SimpleExecutable name -> Printf.sprintf "simple executable named '%s'" name
    | Library name -> Printf.sprintf "OCaml library named '%s'" name  
    | LibraryWithExecutable name -> Printf.sprintf "project '%s' with both library and executable" name
    | GameProject name -> Printf.sprintf "game project '%s'" name
    | WebProject name -> Printf.sprintf "web server project '%s'" name
    | Unknown -> "general OCaml project"
  in
  
  let files_info = String.concat ", " existing_files in
  let original_info = if String.trim original_content = "" then "No original content provided" else
    "Original dune content provided: " ^ original_content in
  
  Printf.sprintf {|
Generate a complete dune file (build configuration) for a %s.

Project description: %s
Existing files: %s
%s

Requirements:
1. Create appropriate build targets (executable, library, or both)
2. Use ONLY standard OCaml libraries - NO external dependencies like 'core', 'base', etc.
3. For simple executables, use NO libraries field or only basic ones like 'unix', 'str'
4. Set up proper module structure
5. Use modern dune syntax compatible with OCaml 5.1

IMPORTANT: Do not include any external library dependencies unless absolutely necessary.
For hello world programs, use no dependencies at all.

For game projects: Use basic OCaml modules (no external deps)
For web projects: Consider lwt, cohttp only if really needed
For libraries: Use standard library only
For simple executables: NO dependencies

Generate ONLY the dune file content, no explanations.
Use proper indentation and modern dune syntax.
|} project_info description files_info original_info

(** Generate dune-project file using LLM *)
let generate_dune_project_file config project_type description =
  let prompt = create_dune_project_prompt project_type description in
  let+ response = Api_client.send_message config [
    { role = "user"; content = prompt; events = []; timestamp = Unix.time () }
  ] in
  match response with
  | Success msg ->
      let content = String.trim msg.content in
      (* Remove any markdown code blocks if present *)
      let clean_content = 
        if String.contains content '`' then
          let lines = String.split_on_char '\n' content in
          let filtered_lines = List.filter (fun line ->
            not (String.contains line '`')
          ) lines in
          String.concat "\n" filtered_lines
        else content
      in
      clean_content
  | Error err ->
      Printf.printf "⚠️ dune-project generation failed: %s\n" err;
      (* Fallback to basic dune-project *)
      {|(lang dune 3.0)
(package
 (name myproject)
 (depends ocaml dune))|}

(** Generate dune build file using LLM *)
let generate_dune_build_file config project_type description existing_files original_content =
  let prompt = create_dune_build_prompt project_type description existing_files original_content in
  let+ response = Api_client.send_message config [
    { role = "user"; content = prompt; events = []; timestamp = Unix.time () }
  ] in
  match response with
  | Success msg ->
      let content = String.trim msg.content in
      (* Remove any markdown code blocks if present *)
      let clean_content = 
        if String.contains content '`' then
          let lines = String.split_on_char '\n' content in
          let filtered_lines = List.filter (fun line ->
            not (String.contains line '`')
          ) lines in
          String.concat "\n" filtered_lines
        else content
      in
      clean_content
  | Error err ->
      Printf.printf "⚠️ dune build file generation failed: %s\n" err;
      (* Fallback to basic executable *)
      "(executable\n (public_name main)\n (name main))"

(** Smart dune file generation based on project context *)
let generate_smart_dune_files config description existing_files original_content =
  let project_type = detect_project_type existing_files description in
  Printf.printf "🎯 Detected project type: %s\n" (match project_type with
    | SimpleExecutable n -> "SimpleExecutable(" ^ n ^ ")"
    | Library n -> "Library(" ^ n ^ ")"
    | LibraryWithExecutable n -> "LibraryWithExecutable(" ^ n ^ ")"
    | GameProject n -> "GameProject(" ^ n ^ ")"
    | WebProject n -> "WebProject(" ^ n ^ ")"
    | Unknown -> "Unknown"
  );
  
  let* dune_project_content = generate_dune_project_file config project_type description in
  let* dune_build_content = generate_dune_build_file config project_type description existing_files original_content in
  
  Printf.printf "📋 Generated dune-project (%d chars)\n" (String.length dune_project_content);
  Printf.printf "📋 Generated dune build (%d chars)\n" (String.length dune_build_content);
  
  Lwt.return (dune_project_content, dune_build_content)

(** Enhanced write_file action that handles dune files specially *)
let enhance_write_file_action config action existing_files goal =
  match action with
  | ToolCall { name = "write_file"; args; rationale } ->
      let file_path = List.assoc_opt "file_path" args |> Option.value ~default:"" in
      let content = List.assoc_opt "content" args |> Option.value ~default:"" in
      
      if Filename.basename file_path = "dune-project" then
        let* (smart_dune_project, _) = generate_smart_dune_files config goal existing_files content in
        Lwt.return (ToolCall { 
          name = "write_file"; 
          args = [("file_path", file_path); ("content", smart_dune_project)]; 
          rationale = "Smart dune-project: " ^ rationale 
        })
      else if Filename.basename file_path = "dune" then
        let* (_, smart_dune_build) = generate_smart_dune_files config goal existing_files content in
        Lwt.return (ToolCall { 
          name = "write_file"; 
          args = [("file_path", file_path); ("content", smart_dune_build)]; 
          rationale = "Smart dune build: " ^ rationale 
        })
      else
        Lwt.return action
  | _ ->
      Lwt.return action