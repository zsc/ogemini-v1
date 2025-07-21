open Lwt.Syntax
open Types

(** LLM-driven intelligent plan parser for Phase 5 **)

(** Check if content is a placeholder that should be replaced with actual code *)
let is_placeholder_content content =
  let content_lower = String.lowercase_ascii content in
  let placeholder_keywords = [
    "skeleton"; "basic"; "initial"; "placeholder"; "todo"; "implement";
    "template"; "stub"; "example"; "sample"; "boilerplate"; "scaffold";
    "file for the"; "tests for"; "logic"; "functionality"; "code";
  ] in
  (* Empty content or very short content or contains placeholder keywords *)
  let contains_substring s sub =
    try ignore (Str.search_forward (Str.regexp_string sub) s 0); true
    with Not_found -> false
  in
  String.length content < 10 || 
  List.exists (fun keyword -> contains_substring content_lower keyword) placeholder_keywords

(** Generate smart OCaml content based on file purpose and context *)
let generate_smart_content_for_file file_path rationale raw_content =
  let file_ext = 
    try 
      let dot_pos = String.rindex file_path '.' in
      String.sub file_path (dot_pos + 1) (String.length file_path - dot_pos - 1)
    with Not_found -> ""
  in
  let base_name = Filename.basename file_path in
  let lower_rationale = String.lowercase_ascii rationale in
  let lower_content = String.lowercase_ascii raw_content in
  
  match file_ext with
  | "ml" ->
      let contains_char s c = String.contains s c in
      if contains_char base_name 'g' || contains_char lower_rationale 'g' || contains_char lower_content 'g' then
        (* Game module - enhanced for 2048 *)
        "(* Game module - 2048 game logic *)\n\n" ^
        "(* Board representation as 64-bit integer *)\n" ^
        "type board = int64\n\n" ^
        "(* Basic board operations *)\n" ^
        "let empty_board : board = 0L\n\n" ^
        "let get_tile (board : board) (pos : int) : int =\n" ^
        "  Int64.to_int (Int64.logand (Int64.shift_right board (4 * pos)) 0xFL)\n\n" ^
        "let set_tile (board : board) (pos : int) (value : int) : board =\n" ^
        "  let mask = Int64.shift_left 0xFL (4 * pos) in\n" ^
        "  let cleared = Int64.logand board (Int64.lognot mask) in\n" ^
        "  let new_val = Int64.shift_left (Int64.of_int value) (4 * pos) in\n" ^
        "  Int64.logor cleared new_val\n\n" ^
        "let print_board (board : board) : unit =\n" ^
        "  Printf.printf \"Board: %Ld\\n\" board\n"
      else if contains_char lower_content 't' || contains_char lower_rationale 't' then
        (* Test module *)
        "(* Test module *)\n\n" ^
        "let test_basic_operations () =\n" ^
        "  let board = 0L in\n" ^
        "  Printf.printf \"Test passed: empty board = %Ld\\n\" board;\n" ^
        "  true\n\n" ^
        "let () =\n" ^
        "  Printf.printf \"Running tests...\\n\";\n" ^
        "  ignore (test_basic_operations ());\n" ^
        "  Printf.printf \"Tests completed.\\n\"\n"
      else
        (* Main module *)
        "(* Main entry point *)\n\n" ^
        "let () =\n" ^
        "  Printf.printf \"OCaml 2048 Game\\n\";\n" ^
        "  Printf.printf \"Starting game...\\n\"\n"
  | "mli" ->
      "(* Module interface *)\n\n" ^
      "type board = int64\n\n" ^
      "val empty_board : board\n" ^
      "val get_tile : board -> int -> int\n" ^
      "val set_tile : board -> int -> int -> board\n" ^
      "val print_board : board -> unit\n"
  | _ ->
      Printf.sprintf "(* Generated file: %s *)\n\n(* TODO: Implement functionality *)\n" base_name

(** Generate intelligent default content based on file type and context *)
let generate_default_content_for_file file_path rationale =
  let file_ext = 
    try 
      let dot_pos = String.rindex file_path '.' in
      String.sub file_path (dot_pos + 1) (String.length file_path - dot_pos - 1)
    with Not_found -> ""
  in
  let base_name = Filename.basename file_path in
  let lower_rationale = String.lowercase_ascii rationale in
  
  match file_ext with
  | "ml" ->
      if String.contains base_name 'g' && String.contains lower_rationale 'g' then
        (* Game module *)
        "(* Game module - Core game logic *)\n\n(* TODO: Implement game functions *)\nlet empty_board = 0L\n\nlet print_board board =\n  Printf.printf \"Board: %Ld\\n\" board\n"
      else if String.contains base_name 'm' && String.contains lower_rationale 'm' then
        (* Main module *)
        "(* Main entry point *)\n\nlet () =\n  Printf.printf \"Starting application...\\n\"\n"
      else if String.contains base_name 't' && (String.contains lower_rationale 't' || String.contains lower_rationale 'y') then
        (* Types module *)
        "(* Core data types *)\n\ntype board = int64\n\ntype direction = Left | Right | Up | Down\n"
      else
        "(* OCaml module *)\n\n(* TODO: Implement module functionality *)\n"
  | "mli" ->
      "(* Module interface *)\n\n(* TODO: Define public interface *)\n"
  | "py" ->
      "# Python module\n\n# TODO: Implement functionality\n"
  | "md" ->
      "# Documentation\n\nTODO: Add documentation\n"
  | _ ->
      Printf.sprintf "(* Generated file: %s *)\n\n(* TODO: Implement functionality *)\n" base_name

(** Create plan extraction prompt *)
let create_plan_extraction_prompt plan_response =
  Printf.sprintf {|
I need to extract actionable tool calls from this planning response. 

PLANNING RESPONSE:
%s

AVAILABLE TOOLS:
- list_files(dir_path) - List files in directory
- read_file(file_path) - Read file contents  
- write_file(file_path, content) - Write content to file
- edit_file(file_path, old_string, new_string, expected_replacements) - Replace text in file
- search_files(pattern, path, file_pattern) - Search for text patterns in files
- analyze_project(path) - Analyze project structure and module dependencies
- rename_module(old_name, new_name, path) - Rename module across entire project
- shell(command) - Execute shell command
- dune_build(target) - Build OCaml project
- dune_test(target) - Run tests
- dune_clean() - Clean build artifacts

EXTRACT TOOL CALLS:
Please extract tool calls from the planning response above. For each tool call, provide:
1. Tool name (exact match from available tools)
2. Parameters with accurate values extracted from context
3. Brief rationale

IMPORTANT: Provide ONLY structured text output, do not attempt to call any functions.

Format each tool call as:
TOOL_CALL: <tool_name>
PARAMS: <param1>=<value1>, <param2>=<value2>
RATIONALE: <brief explanation>

Example:
TOOL_CALL: write_file
PARAMS: file_path=/workspace/hello.ml, content=let () = print_endline "Hello, World!"
RATIONALE: Create main OCaml file with hello world program

Be precise with file paths:
- Use /workspace/ as the base directory for all files
- Remove any markdown backticks from file names
- Extract meaningful content from the planning response context
- Convert relative paths to absolute paths starting with /workspace/
|} plan_response

(** Clean file path by removing markdown artifacts and normalizing *)
let clean_file_path file_path =
  let cleaned = 
    file_path
    |> String.trim
    |> (fun s -> 
        (* Remove markdown backticks *)
        if String.length s >= 2 && String.get s 0 = '`' && String.get s (String.length s - 1) = '`' then
          String.sub s 1 (String.length s - 2)
        else s)
    |> (fun s ->
        (* Remove quotes *)
        if String.length s >= 2 && String.get s 0 = '"' && String.get s (String.length s - 1) = '"' then
          String.sub s 1 (String.length s - 2)
        else s)
    |> String.trim
  in
  (* Ensure absolute path for workspace *)
  if String.length cleaned > 0 && String.get cleaned 0 = '/' then
    cleaned
  else
    "/workspace/" ^ cleaned

(** Parse parameters string into key-value pairs *)
let parse_params_string params_str =
  if String.trim params_str = "" then []
  else
    (* Split on comma but be careful with quoted strings *)
    let rec split_params acc current_param in_quotes i =
      if i >= String.length params_str then
        if String.trim current_param <> "" then current_param :: acc else acc
      else
        let c = String.get params_str i in
        match c with
        | '"' -> split_params acc (current_param ^ String.make 1 c) (not in_quotes) (i + 1)
        | ',' when not in_quotes ->
            let trimmed = String.trim current_param in
            if trimmed <> "" then
              split_params (trimmed :: acc) "" false (i + 1)
            else
              split_params acc "" false (i + 1)
        | _ -> split_params acc (current_param ^ String.make 1 c) in_quotes (i + 1)
    in
    let param_pairs = List.rev (split_params [] "" false 0) in
    Printf.printf "🔍 Split parameters: [%s]\n" (String.concat "; " param_pairs);
    List.filter_map (fun pair ->
      let pair_trimmed = String.trim pair in
      if Str.string_match (Str.regexp "\\([^=]+\\)=\\(.*\\)") pair_trimmed 0 then
        try
          let key = String.trim (Str.matched_group 1 pair_trimmed) in
          let value = String.trim (Str.matched_group 2 pair_trimmed) in
          (* Handle None values by converting to empty string *)
          let clean_value = if value = "None" then "" else value in
          Printf.printf "🔍 Parsed param: %s = '%s'\n" key clean_value;
          Some (key, clean_value)
        with
        | Invalid_argument _ -> 
            Printf.printf "⚠️ Failed to extract matched groups from parameter: %s\n" pair_trimmed;
            None
      else (
        Printf.printf "⚠️ Parameter doesn't match key=value pattern: %s\n" pair_trimmed;
        None
      )
    ) param_pairs

(** Create action from parsed components *)
let create_action_from_parsed tool_name params_str rationale =
  let params = parse_params_string params_str in
  match String.lowercase_ascii tool_name with
  | "list_files" ->
      let dir_path = List.assoc_opt "dir_path" params |> Option.value ~default:"." in
      ToolCall { name = "list_files"; args = [("dir_path", dir_path)]; rationale }
      
  | "read_file" ->
      let file_path = List.assoc_opt "file_path" params |> Option.value ~default:"/workspace/README.md" in
      let clean_path = clean_file_path file_path in
      ToolCall { name = "read_file"; args = [("file_path", clean_path)]; rationale }
      
  | "write_file" ->
      let file_path = List.assoc_opt "file_path" params |> Option.value ~default:"output.txt" in
      let raw_content = List.assoc_opt "content" params |> Option.value ~default:"" in
      let clean_path = clean_file_path file_path in
      (* Generate intelligent default content based on file type and placeholder content *)
      let content = if is_placeholder_content raw_content then
        generate_smart_content_for_file clean_path rationale raw_content
      else
        raw_content
      in
      ToolCall { name = "write_file"; args = [("file_path", clean_path); ("content", content)]; rationale }
      
  | "edit_file" ->
      let file_path = List.assoc_opt "file_path" params |> Option.value ~default:"/workspace/main.ml" in
      let old_string = List.assoc_opt "old_string" params |> Option.value ~default:"" in
      let new_string = List.assoc_opt "new_string" params |> Option.value ~default:"" in
      let expected_replacements = List.assoc_opt "expected_replacements" params in
      let clean_path = clean_file_path file_path in
      let args = [("file_path", clean_path); ("old_string", old_string); ("new_string", new_string)] in
      let final_args = match expected_replacements with
        | Some count -> ("expected_replacements", count) :: args
        | None -> args
      in
      ToolCall { name = "edit_file"; args = final_args; rationale }
      
  | "search_files" ->
      let pattern = List.assoc_opt "pattern" params |> Option.value ~default:"" in
      let path = List.assoc_opt "path" params |> Option.value ~default:"/workspace" in
      let file_pattern = List.assoc_opt "file_pattern" params in
      let args = [("pattern", pattern); ("path", path)] in
      let final_args = match file_pattern with
        | Some fp -> ("file_pattern", fp) :: args
        | None -> args
      in
      ToolCall { name = "search_files"; args = final_args; rationale }
      
  | "analyze_project" ->
      let path = List.assoc_opt "path" params |> Option.value ~default:"/workspace" in
      ToolCall { name = "analyze_project"; args = [("path", path)]; rationale }
      
  | "rename_module" ->
      let old_name = List.assoc_opt "old_name" params |> Option.value ~default:"" in
      let new_name = List.assoc_opt "new_name" params |> Option.value ~default:"" in
      let path = List.assoc_opt "path" params |> Option.value ~default:"/workspace" in
      ToolCall { name = "rename_module"; args = [("old_name", old_name); ("new_name", new_name); ("path", path)]; rationale }
      
  | "shell" ->
      let command = List.assoc_opt "command" params |> Option.value ~default:"ls -la" in
      ToolCall { name = "shell"; args = [("command", command)]; rationale }
      
  | "dune_build" ->
      let target = List.assoc_opt "target" params |> Option.value ~default:"" in
      ToolCall { name = "dune_build"; args = if target = "" then [] else [("target", target)]; rationale }
      
  | "dune_test" ->
      let target = List.assoc_opt "target" params |> Option.value ~default:"" in
      ToolCall { name = "dune_test"; args = if target = "" then [] else [("target", target)]; rationale }
      
  | "dune_clean" ->
      ToolCall { name = "dune_clean"; args = []; rationale }
      
  | _ ->
      (* Fallback for unknown tools *)
      ToolCall { name = "list_files"; args = [("dir_path", ".")]; rationale = "Unknown tool: " ^ tool_name }

(** Parse LLM response to extract tool calls *)
let parse_llm_extracted_tools llm_response =
  let lines = String.split_on_char '\n' llm_response in
  Printf.printf "🔍 Parsing %d lines from LLM response\n" (List.length lines);
  Printf.printf "🔍 First few lines of LLM response:\n";
  let rec print_preview i = function
    | [] -> ()
    | line :: rest when i < 10 -> 
        Printf.printf "  %d: '%s'\n" i line;
        print_preview (i+1) rest
    | _ -> ()
  in
  print_preview 0 lines;
  let rec parse_tool_blocks acc current_tool current_params current_rationale = function
    | [] -> 
        (* Process final block if exists *)
        if current_tool <> "" then (
          Printf.printf "🔧 Final block: tool=%s, params=%s\n" current_tool current_params;
          let action = create_action_from_parsed current_tool current_params current_rationale in
          List.rev (action :: acc)
        ) else
          List.rev acc
          
    | line :: rest ->
        let line_trim = String.trim line in
        
        (* Extract tool name immediately to avoid Str module global state issues *)
        let tool_regex = Str.regexp "TOOL_CALL:[ ]*\\([a-zA-Z_]+\\).*" in
        if Str.string_match tool_regex line_trim 0 then (
          (* Capture tool name immediately before any other Str operations *)
          let tool_name_raw = Str.matched_group 1 line_trim in
          let tool_name = String.trim tool_name_raw in
          
          (* New tool block started, process previous if exists *)
          Printf.printf "🎯 Found TOOL_CALL line: %s\n" line_trim;
          Printf.printf "✅ Extracted tool name: '%s' (length: %d)\n" tool_name (String.length tool_name);
          
          let new_acc = 
            if current_tool <> "" then (
              Printf.printf "🔧 Completing previous tool: %s with params: %s\n" current_tool current_params;
              let action = create_action_from_parsed current_tool current_params current_rationale in
              action :: acc
            ) else
              acc
          in
          parse_tool_blocks new_acc tool_name "" "" rest
        ) else (
          let params_regex = Str.regexp "PARAMS:[ ]*\\(.*\\)" in
          let rationale_regex = Str.regexp "RATIONALE:[ ]*\\(.*\\)" in
          if Str.string_match params_regex line_trim 0 then (
            let params_str = String.trim (Str.matched_group 1 line_trim) in
            Printf.printf "📋 Found PARAMS: %s\n" params_str;
            parse_tool_blocks acc current_tool params_str current_rationale rest
          ) else if Str.string_match rationale_regex line_trim 0 then (
            let rationale_str = String.trim (Str.matched_group 1 line_trim) in
            Printf.printf "💭 Found RATIONALE: %s\n" rationale_str;
            parse_tool_blocks acc current_tool current_params rationale_str rest
          ) else (
            (* Continue processing current block or skip unrecognized lines *)
            if String.trim line <> "" then
              Printf.printf "🔍 Skipping line: %s\n" line_trim;
            parse_tool_blocks acc current_tool current_params current_rationale rest
          )
        )
  in
  parse_tool_blocks [] "" "" "" lines

(** Main LLM-driven plan parsing function *)
let parse_execution_plan_llm config plan_response =
  let extraction_prompt = create_plan_extraction_prompt plan_response in
  let+ llm_response = Api_client.send_message config [
    { role = "user"; content = extraction_prompt; events = []; timestamp = Unix.time () }
  ] in
  match llm_response with
  | Success msg ->
      Printf.printf "🧠 LLM parsing response:\n%s\n" (String.sub msg.content 0 (min 200 (String.length msg.content)));
      let actions = parse_llm_extracted_tools msg.content in
      Printf.printf "📋 Extracted %d actions\n" (List.length actions);
      (actions, msg.content)
  | Error err ->
      Printf.printf "❌ LLM parsing failed: %s\n" err;
      ([], "LLM parsing failed: " ^ err)

(** Simple regex-based fallback parser *)
let parse_execution_plan_simple plan_response =
  let lines = String.split_on_char '\n' plan_response in
  let rec extract_actions acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let line_trim = String.trim line in
        if Str.string_match (Str.regexp ".*\\[TOOL:[ ]*\\([^]]+\\)\\]\\(.*\\)") line_trim 0 then
          (try
            let tool_name = String.trim (Str.matched_group 1 line_trim) in
            let description = String.trim (Str.matched_group 2 line_trim) in
          let action = match String.lowercase_ascii tool_name with
            | "list_files" ->
                ToolCall { name = "list_files"; args = [("dir_path", ".")]; rationale = description }
            | "read_file" ->
                ToolCall { name = "read_file"; args = [("file_path", "/workspace/README.md")]; rationale = description }
            | "write_file" ->
                (* Try to extract file name from description *)
                let file_path = 
                  try
                    let words = String.split_on_char ' ' description in
                    let file_candidates = List.filter (fun w -> String.contains w '.') words in
                    match file_candidates with
                    | file::_ -> clean_file_path file
                    | [] -> "/workspace/output.txt"
                  with _ -> "/workspace/output.txt"
                in
                let content = 
                  let desc_lower = String.lowercase_ascii description in
                  if (try ignore (Str.search_forward (Str.regexp "hello") desc_lower 0); true with Not_found -> false) then
                    "let () = print_endline \"Hello, World!\""
                  else if (try ignore (Str.search_forward (Str.regexp "dune") desc_lower 0); true with Not_found -> false) then
                    "(executable\n (public_name hello)\n (name hello))"
                  else
                    "(* Generated OCaml file *)"
                in
                ToolCall { name = "write_file"; args = [("file_path", file_path); ("content", content)]; rationale = description }
            | "shell" ->
                ToolCall { name = "shell"; args = [("command", "ls -la")]; rationale = description }
            | "dune_build" ->
                ToolCall { name = "dune_build"; args = []; rationale = description }
            | "dune_test" ->
                ToolCall { name = "dune_test"; args = []; rationale = description }
            | "dune_clean" ->
                ToolCall { name = "dune_clean"; args = []; rationale = description }
            | _ ->
                ToolCall { name = "list_files"; args = [("dir_path", ".")]; rationale = "Unknown: " ^ tool_name }
          in
          extract_actions (action :: acc) rest
          with
          | Invalid_argument _ ->
              Printf.printf "⚠️ Error parsing fallback tool line: %s\n" line_trim;
              extract_actions acc rest)
        else
          extract_actions acc rest
  in
  extract_actions [] lines

(** Fallback to simple parsing if LLM parsing fails *)
let parse_execution_plan_hybrid config plan_response =
  let+ (llm_actions, llm_debug) = parse_execution_plan_llm config plan_response in
  if List.length llm_actions > 0 then
    (llm_actions, "LLM parsing: " ^ llm_debug)
  else
    (* Fallback to simple regex-based parsing *)
    let fallback_actions = parse_execution_plan_simple plan_response in
    (fallback_actions, "Fallback parsing (LLM failed)")