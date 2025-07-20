open Lwt.Syntax
open Types

(** Core cognitive engine for autonomous agent behavior *)

(** Create planning prompt for goal decomposition *)
let create_planning_prompt goal context_list =
  let context_str = String.concat "\n- " context_list in
  Printf.sprintf {|
I need to analyze this goal and create a step-by-step execution plan.

GOAL: %s

CONTEXT:
- %s

Please create a concrete execution plan using ONLY these available tools:
- list_files (dir_path) - List files in a directory
- read_file (file_path) - Read a file's contents  
- write_file (file_path, content) - Write content to a file
- shell (command) - Execute a shell command
- dune_build (target) - Build an OCaml project
- dune_test (target) - Run tests
- dune_clean () - Clean build artifacts

Generate a numbered list of steps. Each step should be one line and follow this format:
1. [TOOL: list_files] List files in current directory to understand structure
2. [TOOL: read_file] Read README.md to understand project
3. [TOOL: write_file] Create hello.ml with OCaml code

Keep each step concise and actionable. Focus on tools that will actually help achieve the goal.
|} goal context_str

(** Extract action plan from LLM response *)
let parse_execution_plan response_content =
  (* Look for lines with [TOOL: toolname] format *)
  let lines = String.split_on_char '\n' response_content in
  let rec extract_actions acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let line_trim = String.trim line in
        
        (* Look for [TOOL: toolname] pattern *)
        if Str.string_match (Str.regexp ".*\\[TOOL:[ ]*\\([^]]+\\)\\]\\(.*\\)") line_trim 0 then
          let tool_name = String.trim (Str.matched_group 1 line_trim) in
          let description = String.trim (Str.matched_group 2 line_trim) in
          
          (* Extract parameters from description or use defaults *)
          let action = match String.lowercase_ascii tool_name with
            | "list_files" ->
                let dir = 
                  if String.contains description '/' then
                    try
                      let start = String.index description '/' in
                      let substr = String.sub description start (String.length description - start) in
                      let end_idx = try String.index substr ' ' with Not_found -> String.length substr in
                      String.sub substr 0 end_idx
                    with _ -> "."
                  else "."
                in
                ToolCall { 
                  name = "list_files"; 
                  args = [("dir_path", dir)]; 
                  rationale = description 
                }
                
            | "read_file" ->
                let file_path = 
                  if String.contains description '.' then
                    (* Try to extract filename *)
                    try
                      let words = Str.split (Str.regexp "[ \t]+") description in
                      List.find (fun w -> String.contains w '.') words
                    with Not_found -> "/workspace/README.md"
                  else "/workspace/README.md"
                in
                ToolCall { 
                  name = "read_file"; 
                  args = [("file_path", if String.get file_path 0 = '/' then file_path else "/workspace/" ^ file_path)]; 
                  rationale = description 
                }
                
            | "write_file" ->
                let file_path = 
                  try
                    let words = Str.split (Str.regexp "[ \t]+") description in
                    List.find (fun w -> String.contains w '.') words
                  with Not_found -> "output.txt"
                in
                ToolCall { 
                  name = "write_file"; 
                  args = [
                    ("file_path", if String.get file_path 0 = '/' then file_path else "/workspace/" ^ file_path);
                    ("content", "# Generated file\n\nContent will be added here.")
                  ]; 
                  rationale = description 
                }
                
            | "shell" ->
                let command = 
                  if String.contains description '"' then
                    try
                      let start = String.index description '"' + 1 in
                      let end_pos = String.index_from description start '"' in
                      String.sub description start (end_pos - start)
                    with _ -> "ls -la"
                  else "ls -la"
                in
                ToolCall { 
                  name = "shell"; 
                  args = [("command", command)]; 
                  rationale = description 
                }
                
            | "dune_build" ->
                ToolCall { 
                  name = "dune_build"; 
                  args = []; 
                  rationale = description 
                }
                
            | "dune_test" ->
                ToolCall { 
                  name = "dune_test"; 
                  args = []; 
                  rationale = description 
                }
                
            | "dune_clean" ->
                ToolCall { 
                  name = "dune_clean"; 
                  args = []; 
                  rationale = description 
                }
                
            | _ ->
                (* Unknown tool, skip this line *)
                ToolCall { 
                  name = "list_files"; 
                  args = [("dir_path", ".")]; 
                  rationale = "Unknown tool: " ^ tool_name 
                }
          in
          extract_actions (action :: acc) rest
            
        (* Also look for numbered steps without [TOOL:] but mentioning tools *)
        else if Str.string_match (Str.regexp "^[0-9]+\\..*\\(list_files\\|read_file\\|write_file\\|shell\\|dune\\).*") line_trim 0 then
          (* Try to infer the tool from the description *)
          let line_lower = String.lowercase_ascii line_trim in
          let action = 
            if String.contains line_lower 'l' && String.contains line_lower 'i' && String.contains line_lower 's' then
              ToolCall { 
                name = "list_files"; 
                args = [("dir_path", ".")]; 
                rationale = line_trim 
              }
            else if String.contains line_lower 'r' && String.contains line_lower 'e' && String.contains line_lower 'a' then
              ToolCall { 
                name = "read_file"; 
                args = [("file_path", "/workspace/README.md")]; 
                rationale = line_trim 
              }
            else
              ToolCall { 
                name = "list_files"; 
                args = [("dir_path", ".")]; 
                rationale = "Inferred: " ^ line_trim 
              }
          in
          extract_actions (action :: acc) rest
            
        else
          extract_actions acc rest
  in
  extract_actions [] lines

(** Extract context from conversation history *)
let extract_context_from_conversation conversation =
  let recent_messages = 
    let rev = List.rev conversation in
    if List.length rev > 5 then
      let rec take n = function
        | [] -> []
        | h::t -> if n = 0 then [] else h :: take (n-1) t
      in
      take 5 rev
    else 
      rev 
  in
  List.map (fun msg -> 
    if String.length msg.content > 50 then
      String.sub msg.content 0 50 ^ "..."
    else
      msg.content
  ) recent_messages

(** Generate execution plan using LLM *)
let generate_execution_plan config goal context_list =
  let planning_prompt = create_planning_prompt goal context_list in
  let+ response = Api_client.send_message config [
    { role = "user"; content = planning_prompt; events = []; timestamp = Unix.time () }
  ] in
  match response with
  | Success msg -> 
      let actions = parse_execution_plan msg.content in
      (actions, msg.content)
  | Error err -> 
      ([], "Planning failed: " ^ err)

(** Execute a single action with external tool executor *)
let execute_action tool_executor action =
  match action with
  | ToolCall { name; args; rationale } ->
      Printf.printf "🔧 Executing: %s - %s\n" name rationale;
      flush_all ();
      let tool_call = { id = "auto-" ^ string_of_float (Unix.time ()); name; args } in
      tool_executor tool_call
  | Wait { reason; duration } ->
      Printf.printf "⏳ Waiting %.1fs: %s\n" duration reason;
      flush_all ();
      let+ () = Lwt_unix.sleep duration in
      { content = "Wait completed"; success = true; error_msg = None }
  | UserInteraction { prompt; expected_response } ->
      Printf.printf "💬 %s\n" prompt;
      Printf.printf "Expected: %s\n" expected_response;
      flush_all ();
      Lwt.return { content = "User interaction logged"; success = true; error_msg = None }

(** Evaluate execution results *)
let evaluate_results actions results =
  let total_actions = List.length actions in
  let successful_results = List.filter (fun r -> r.success) results in
  let failed_results = List.filter (fun r -> not r.success) results in
  
  let success = List.length successful_results >= (total_actions / 2) in
  let failures = List.map (function
    | { success = false; error_msg = Some err; _ } -> 
        ToolExecutionFailure { tool = "unknown"; error = err }
    | _ -> 
        PlanningFailure { reason = "Unknown failure" }
  ) failed_results in
  
  (success, failures)

(** Diagnose failures and suggest adjustments *)
let diagnose_failures failures =
  List.map (function
    | ToolExecutionFailure { tool; error } ->
        Printf.sprintf "Tool %s failed: %s. Consider alternative approach." tool error
    | PlanningFailure { reason } ->
        Printf.sprintf "Planning issue: %s. Need to revise strategy." reason
    | UserExpectationMismatch { expected; actual } ->
        Printf.sprintf "Expected %s but got %s. Adjust approach." expected actual
  ) failures

(** Core cognitive loop - the heart of autonomous behavior *)
let cognitive_loop config tool_executor state conversation =
  match state with
  | Planning { goal; context } ->
      Printf.printf "🧠 Planning for goal: %s\n" goal;
      flush_all ();
      (* Extract additional context from conversation if initial context is insufficient *)
      let enhanced_context = 
        if List.length context < 3 && List.length conversation > 0 then
          context @ extract_context_from_conversation conversation
        else
          context
      in
      let+ (actions, plan_description) = generate_execution_plan config goal enhanced_context in
      Printf.printf "📋 Plan generated:\n%s\n" plan_description;
      flush_all ();
      if List.length actions > 0 then
        Executing { plan = actions; current_step = 0; results = [] }
      else
        Adjusting { 
          failures = [PlanningFailure { reason = "Could not generate actionable plan" }]; 
          new_plan = [] 
        }

  | Executing { plan; current_step; results } ->
      if current_step >= List.length plan then
        (* All steps completed, evaluate *)
        let (success, failures) = evaluate_results plan results in
        Lwt.return (Evaluating { results; success; failures })
      else
        (* Execute next step *)
        let action = List.nth plan current_step in
        Printf.printf "📋 Step %d/%d: " (current_step + 1) (List.length plan);
        let+ result = execute_action tool_executor action in
        Printf.printf "%s\n" (if result.success then "✅ Success" else "❌ Failed");
        flush_all ();
        Executing { 
          plan; 
          current_step = current_step + 1; 
          results = result :: results 
        }

  | Evaluating { results; success; failures } ->
      Printf.printf "🔍 Evaluation: %s\n" (if success then "Overall Success" else "Needs Adjustment");
      if success then
        let summary = Printf.sprintf "Completed successfully with %d results" (List.length results) in
        Lwt.return (Completed { summary; final_results = results })
      else
        let diagnostics = diagnose_failures failures in
        Printf.printf "⚠️  Issues found:\n%s\n" (String.concat "\n" diagnostics);
        Lwt.return (Adjusting { failures; new_plan = [] })

  | Adjusting { failures; new_plan = _ } ->
      Printf.printf "🔄 Adjusting strategy based on failures...\n";
      (* For now, complete with failure - TODO: implement retry logic *)
      let summary = Printf.sprintf "Failed and adjusted: %d failures" (List.length failures) in
      Lwt.return (Completed { summary; final_results = [] })

  | Completed { summary; final_results = _ } ->
      Printf.printf "🎯 Completed: %s\n" summary;
      flush_all ();
      Lwt.return state

(** Determine if we should enter autonomous mode *)
let should_enter_autonomous_mode user_input conversation =
  let input_lower = String.lowercase_ascii user_input in
  let autonomous_triggers = [
    "create"; "build"; "implement"; "develop"; "make"; "generate";
    "help me with"; "work on"; "complete"; "finish"; "project"
  ] in
  let has_autonomous_trigger = List.exists (fun trigger -> 
    try 
      ignore (Str.search_forward (Str.regexp trigger) input_lower 0); 
      true 
    with Not_found -> false
  ) autonomous_triggers in
  
  (* Also check if conversation context suggests a complex task *)
  let conversation_suggests_complexity = 
    List.length conversation > 2 && String.length user_input > 50
  in
  
  has_autonomous_trigger || conversation_suggests_complexity

(** Extract goal from user input *)
let extract_goal_from_input user_input =
  (* Simple goal extraction - TODO: make more sophisticated *)
  if String.length user_input > 100 then
    String.sub user_input 0 100 ^ "..."
  else
    user_input