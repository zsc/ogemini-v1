open Lwt.Syntax
open Types

(** LLM-driven intelligent plan parser for Phase 5 **)

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
    let param_pairs = Str.split (Str.regexp ",[ ]*") params_str in
    List.filter_map (fun pair ->
      let pair_trimmed = String.trim pair in
      if Str.string_match (Str.regexp "\\([^=]+\\)=\\(.*\\)") pair_trimmed 0 then
        try
          let key = String.trim (Str.matched_group 1 pair_trimmed) in
          let value = String.trim (Str.matched_group 2 pair_trimmed) in
          (* Handle None values by converting to empty string *)
          let clean_value = if value = "None" then "" else value in
          Some (key, clean_value)
        with
        | Invalid_argument _ -> 
            Printf.printf "⚠️ Failed to extract matched groups from parameter: %s\n" pair_trimmed;
            None
      else
        None
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
      let content = List.assoc_opt "content" params |> Option.value ~default:"(* Generated OCaml file *)" in
      let clean_path = clean_file_path file_path in
      ToolCall { name = "write_file"; args = [("file_path", clean_path); ("content", content)]; rationale }
      
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
  let rec parse_tool_blocks acc current_tool current_params current_rationale = function
    | [] -> 
        (* Process final block if exists *)
        if current_tool <> "" then
          let action = create_action_from_parsed current_tool current_params current_rationale in
          List.rev (action :: acc)
        else
          List.rev acc
          
    | line :: rest ->
        let line_trim = String.trim line in
        
        if Str.string_match (Str.regexp "TOOL_CALL:[ ]*\\(.*\\)") line_trim 0 then
          (* New tool block started, process previous if exists *)
          let new_acc = 
            if current_tool <> "" then
              let action = create_action_from_parsed current_tool current_params current_rationale in
              action :: acc
            else
              acc
          in
          (try
            let tool_name = String.trim (Str.matched_group 1 line_trim) in
            parse_tool_blocks new_acc tool_name "" "" rest
          with
          | Invalid_argument _ ->
              Printf.printf "⚠️ Error parsing TOOL_CALL line: %s\n" line_trim;
              parse_tool_blocks new_acc "" "" "" rest)
          
        else if Str.string_match (Str.regexp "PARAMS:[ ]*\\(.*\\)") line_trim 0 then
          (try
            let params_str = String.trim (Str.matched_group 1 line_trim) in
            parse_tool_blocks acc current_tool params_str current_rationale rest
          with
          | Invalid_argument _ ->
              Printf.printf "⚠️ Error parsing PARAMS line: %s\n" line_trim;
              parse_tool_blocks acc current_tool "" current_rationale rest)
          
        else if Str.string_match (Str.regexp "RATIONALE:[ ]*\\(.*\\)") line_trim 0 then
          (try
            let rationale_str = String.trim (Str.matched_group 1 line_trim) in
            parse_tool_blocks acc current_tool current_params rationale_str rest
          with
          | Invalid_argument _ ->
              Printf.printf "⚠️ Error parsing RATIONALE line: %s\n" line_trim;
              parse_tool_blocks acc current_tool current_params "" rest)
          
        else
          (* Continue processing current block *)
          parse_tool_blocks acc current_tool current_params current_rationale rest
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