open Lwt.Syntax
open Types

(** Phase 8.2: Execute template-free micro-tasks with LLM generation support *)
let execute_template_free_microtasks config goal tool_executor micro_tasks =
  Printf.printf "🎯 Executing template-free microtasks for goal: %s\n" goal;
  
  (* Build context from previous results *)
  let build_context_from_results results =
    List.fold_left (fun ctx result ->
      (* Include both successful and failed results in context *)
      let content = 
        if result.success then
          result.result.content
        else
          (* For failed tasks, include error message and any output *)
          let error_msg = match result.result.error_msg with
            | Some err -> Printf.sprintf "ERROR: %s" err
            | None -> "ERROR: Unknown error"
          in
          Printf.sprintf "%s\n%s" result.result.content error_msg
      in
      (Printf.sprintf "[%s]: %s" result.task_id content) :: ctx
    ) [] results |> List.rev
  in
  
  let rec execute_tasks_sequential acc remaining =
    match remaining with
    | [] -> Lwt.return (List.rev acc)
    | task :: rest ->
        Printf.printf "🔧 Executing micro-task: %s\n" task.description;
        flush_all ();
        
        (* Build context from previous task results *)
        let context = build_context_from_results (List.rev acc) in
        
        (* Handle different action types *)
        let* result = match task.action with
          | ToolCall { name; args; rationale } ->
              Printf.printf "🔧 Executing: %s - %s\n" name rationale;
              tool_executor { id = "llm-gen-" ^ string_of_float (Unix.time ()); name; args }
              
          | LLMGeneration { prompt; target_file; expected_length } ->
              Printf.printf "🧠 LLM Generation: %s\n" target_file;
              
              (* Include context from previous tasks if available *)
              let enhanced_prompt = 
                if List.length context > 0 then
                  let context_str = String.concat "\n" context in
                  Printf.sprintf "Context from previous tasks:\n%s\n\nTask: %s" context_str prompt
                else
                  prompt
              in
              
              (* Phase 7.2: Enhanced LLM generation with function call support *)
              let rec llm_conversation_loop conversation_history =
                let* llm_response = Api_client.send_message config conversation_history in
                match llm_response with
                | Error err ->
                    Printf.printf "❌ LLM generation failed: %s\n" err;
                    Lwt.return { content = ""; success = false; error_msg = Some err }
                | Success msg ->
                    (* Check if LLM made function calls *)
                    let tool_calls = List.filter_map (function
                      | ToolCallRequest tc -> Some tc
                      | _ -> None
                    ) msg.events in
                    
                    if List.length tool_calls > 0 then (
                      (* Handle function calls and continue conversation *)
                      Printf.printf "🔧 LLM requested %d function call(s)\n" (List.length tool_calls);
                      
                      (* Execute all function calls and collect results *)
                      let* tool_results = Lwt_list.map_s (fun tc ->
                        Printf.printf "🔧 Executing: %s\n" tc.name;
                        let* result = tool_executor tc in
                        let response_event = ToolCallResponse result in
                        Lwt.return response_event
                      ) tool_calls in
                      
                      (* Continue conversation with tool results *)
                      let updated_conversation = conversation_history @ [
                        msg;  (* LLM's message with function calls *)
                        { role = "user"; content = ""; events = tool_results; timestamp = Unix.time () }  (* Tool results *)
                      ] in
                      
                      Printf.printf "🔄 Continuing LLM conversation with tool results\n";
                      llm_conversation_loop updated_conversation
                    ) else (
                      (* No function calls - process content *)
                      (* Strip markdown formatting if present *)
                      let clean_content = 
                        let content = msg.content in
                        (* Remove all markdown code blocks - more aggressive *)
                        let content = 
                          (* Remove ```language at start *)
                          let regex1 = Str.regexp "^```[a-zA-Z]*\n?" in
                          let content = try Str.replace_first regex1 "" content with _ -> content in
                          (* Remove ``` at end *)
                          let regex2 = Str.regexp "\n?```$" in
                          let content = try Str.replace_first regex2 "" content with _ -> content in
                          (* Also handle case where ``` is in the middle *)
                          let regex3 = Str.regexp "```[a-zA-Z]*\n?" in
                          let content = try Str.global_replace regex3 "" content with _ -> content in
                          let regex4 = Str.regexp "\n?```" in
                          try Str.global_replace regex4 "" content with _ -> content
                        in
                        (* Remove conversational prefixes/suffixes that LLMs often add *)
                        let content = 
                          (* Remove common prefixes like "Okay, I have written...", "OK. The tool..." *)
                          let prefix_regex = Str.regexp "^\\(OK\\|Okay\\|Alright\\|Sure\\|Here's\\|I've\\|I have\\|The tool\\)[^.!?]*\\(written\\|created\\|generated\\|made\\)[^.!?]*\\(file\\|content\\)[^.!?]*[.!?][ \n]*" in
                          let content = try Str.global_replace prefix_regex "" content with _ -> content in
                          (* Remove trailing questions like "What would you like to do next?" *)
                          let suffix_regex = Str.regexp "[ \n]+\\(What\\|Is there\\|Do you\\|Would you\\)[^.!?]*[?][ \n]*$" in
                          let content = try Str.global_replace suffix_regex "" content with _ -> content in
                          (* Remove "Error: No candidates in response" which sometimes appears *)
                          let error_regex = Str.regexp "Error: No candidates in response[ \n]*" in
                          try Str.global_replace error_regex "" content with _ -> content
                        in
                        String.trim content
                      in
                      (* Additional cleanup for dune files *)
                      let final_content = 
                        if String.ends_with ~suffix:"dune" target_file && 
                           not (String.ends_with ~suffix:"dune-project" target_file) then
                          (* Remove (lang dune X.X) from regular dune files - it should only be in dune-project *)
                          let lang_regex = Str.regexp "(lang[ \t]+dune[ \t]+[0-9.]+)[ \t\n]*" in
                          try Str.global_replace lang_regex "" clean_content with _ -> clean_content
                        else
                          clean_content
                      in
                      if String.length final_content >= expected_length then (
                        (* Use tool executor to write file *)
                        let* write_result = tool_executor { 
                          id = "write-" ^ string_of_float (Unix.time ());
                          name = "write_file"; 
                          args = [("file_path", target_file); ("content", final_content)]
                        } in
                        Printf.printf "✅ Generated %d chars to %s\n" (String.length final_content) target_file;
                        Lwt.return write_result
                      ) else (
                        Printf.printf "⚠️ Generated content too short (%d chars, expected %d+)\n" 
                          (String.length final_content) expected_length;
                        Lwt.return { content = ""; success = false; error_msg = Some "Generated content too short" }
                      )
                    )
              in
              
              (* Start conversation with enhanced prompt *)
              let initial_conversation = [
                { role = "user"; content = enhanced_prompt; events = []; timestamp = Unix.time () }
              ] in
              llm_conversation_loop initial_conversation
              
          | Wait { reason; duration } ->
              Printf.printf "⏳ Waiting %.1fs: %s\n" duration reason;
              let* () = Lwt_unix.sleep duration in
              Lwt.return { content = Printf.sprintf "Waited %.1fs" duration; success = true; error_msg = None }
              
          | UserInteraction { prompt; expected_response = _ } ->
              Printf.printf "👤 User interaction: %s\n" prompt;
              Lwt.return { content = "User interaction simulated"; success = true; error_msg = None }
        in
        
        let task_result = {
          task_id = task.id;
          success = result.success;
          result = result;
          verification_passed = result.success; (* Simple verification for now *)
          attempts = 1;
        } in
        
        if result.success then (
          Printf.printf "✅ Micro-task %s completed successfully\n" task.id;
          execute_tasks_sequential (task_result :: acc) rest
        ) else (
          Printf.printf "❌ Micro-task %s failed: %s\n" task.id 
            (Option.value result.error_msg ~default:"Unknown error");
          
          (* Check if this is a critical failure that should stop execution *)
          if task.id = "analyze_source_code" then (
            Printf.printf "🛑 Critical failure: Cannot proceed without reading source file\n";
            (* Return failure for all remaining tasks *)
            let failed_remaining = List.map (fun t -> {
              task_id = t.id;
              success = false;
              result = { content = ""; success = false; error_msg = Some "Aborted due to critical failure" };
              verification_passed = false;
              attempts = 0;
            }) rest in
            Lwt.return (List.rev ((task_result :: acc) @ failed_remaining))
          ) else
            execute_tasks_sequential (task_result :: acc) rest
        )
  in
  execute_tasks_sequential [] micro_tasks

(** Core cognitive engine for autonomous agent behavior *)

(** Create planning prompt for goal decomposition *)
let create_planning_prompt goal context_list =
  let context_str = String.concat "\n- " context_list in
  Printf.sprintf {|
I need to analyze this goal and create a step-by-step execution plan.

GOAL: %s

CONTEXT:
- %s

WORKING DIRECTORY: /workspace
Use relative file paths (e.g., "hello.ml", "dune") or absolute paths starting with /workspace/

Please create a concrete execution plan using ONLY these available tools:
- list_files (dir_path) - List files in a directory
- read_file (file_path) - Read a file's contents  
- write_file (file_path, content) - Write content to a file
- edit_file (file_path, old_string, new_string, expected_replacements) - Replace text in file
- search_files (pattern, path, file_pattern) - Search for text patterns in files
- analyze_project (path) - Analyze project structure and module dependencies
- rename_module (old_name, new_name, path) - Rename module across entire project
- shell (command) - Execute a shell command
- dune_build (target) - Build an OCaml project
- dune_test (target) - Run tests
- dune_clean () - Clean build artifacts

Generate a numbered list of steps. Each step should be one line and follow this format:
1. [TOOL: list_files] List files in current directory to understand structure
2. [TOOL: read_file] Read README.md to understand project
3. [TOOL: write_file] Create hello.ml with OCaml code

IMPORTANT: Use relative file paths like "hello.ml" NOT absolute paths like "/app/hello.ml"
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
          (try
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
                
            | "edit_file" ->
                ToolCall { 
                  name = "edit_file"; 
                  args = [
                    ("file_path", "/workspace/main.ml");
                    ("old_string", "old_code");
                    ("new_string", "new_code")
                  ]; 
                  rationale = description 
                }
                
            | "search_files" ->
                ToolCall { 
                  name = "search_files"; 
                  args = [
                    ("pattern", "function");
                    ("path", "/workspace")
                  ]; 
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
          with
          | Invalid_argument _ -> 
              Printf.printf "⚠️ Error parsing tool line: %s\n" line_trim;
              extract_actions acc rest)
            
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

(** Generate execution plan using LLM with intelligent model selection *)
let generate_execution_plan config goal context_list =
  let planning_prompt = create_planning_prompt goal context_list in
  
  (* Use enhanced API client with task-appropriate model selection *)
  let* api_result = Enhanced_api_client.call_api_robust 
    ~context:Model_selector.Debug  (* Use debug context for planning *)
    ~max_retries:3 
    config 
    planning_prompt in
  
  let response = match api_result with
    | Ok response_text -> Success { role = "assistant"; content = response_text; events = []; timestamp = Unix.time () }
    | Error error_msg -> Error error_msg
  in
  match response with
  | Success msg -> 
      (* Use LLM-driven parser for Phase 5 *)
      let* (actions, debug_info) = Llm_plan_parser.parse_execution_plan_hybrid config msg.content in
      Printf.printf "🔍 Plan parsing debug: %s\n" (String.sub debug_info 0 (min 100 (String.length debug_info)));
      Lwt.return (actions, msg.content)
  | Error err -> 
      Lwt.return ([], "Planning failed: " ^ err)

(** Execute a single action with external tool executor *)
let execute_action config goal existing_files tool_executor action =
  match action with
  | ToolCall { name; args; rationale } ->
      Printf.printf "🔧 Executing: %s - %s\n" name rationale;
      flush_all ();
      (* Smart enhancement for dune files *)
      let* enhanced_action = Dune_generator.enhance_write_file_action config action existing_files goal in
      (match enhanced_action with
       | ToolCall { name = enhanced_name; args = enhanced_args; rationale = enhanced_rationale } ->
           if enhanced_rationale <> rationale then
             Printf.printf "✨ Enhanced: %s\n" enhanced_rationale;
           let tool_call = { id = "auto-" ^ string_of_float (Unix.time ()); name = enhanced_name; args = enhanced_args } in
           tool_executor tool_call
       | _ -> 
           let tool_call = { id = "auto-" ^ string_of_float (Unix.time ()); name; args } in
           tool_executor tool_call)
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
  | LLMGeneration { prompt; target_file; expected_length } ->
      Printf.printf "🧠 LLM Generation not supported in standard execute_action\n";
      Printf.printf "Target: %s (expected %d+ chars)\n" target_file expected_length;
      Printf.printf "Prompt preview: %s\n" (String.sub prompt 0 (min 50 (String.length prompt)));
      flush_all ();
      Lwt.return { content = "LLM generation requires template-free executor"; success = false; error_msg = Some "Use template-free mode for LLM generation" }

(** Evaluate execution results *)
let evaluate_results actions (results : simple_tool_result list) =
  let total_actions = List.length actions in
  let successful_results = List.filter (fun (r : simple_tool_result) -> r.success) results in
  let failed_results = List.filter (fun (r : simple_tool_result) -> not r.success) results in
  
  let success = List.length successful_results >= (total_actions / 2) in
  let failures = List.map (fun (result : simple_tool_result) ->
    match result with
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
  let goal = match state with
    | Planning { goal; _ } -> goal
    | Executing { plan; _ } -> 
        (match plan with
         | (ToolCall { rationale; _ }) :: _ -> rationale
         | _ -> "Unknown goal")
    | _ -> "Unknown goal"
  in
  match state with
  | Planning { goal; context } ->
      Printf.printf "🧠 Planning for goal: %s\n" goal;
      flush_all ();
      
      (* Phase 8.2: Check if task should use template-free decomposition *)
      if config.force_template_free || Micro_task_decomposer.should_use_micro_decomposition goal then (
        Printf.printf "🔬 Complex task detected - using template-free decomposition strategy\n";
        flush_all ();
        
        (* Use template-free decomposer instead of hardcoded templates *)
        let* micro_tasks = Template_free_decomposer.decompose_complex_task config goal in
        Printf.printf "📋 Generated %d LLM-driven micro-tasks for execution\n" (List.length micro_tasks);
        flush_all ();
        
        (* Execute micro-tasks with enhanced LLM generation support *)
        let* micro_results = execute_template_free_microtasks config goal tool_executor micro_tasks in
        let successful_count = List.fold_left (fun acc mr -> if mr.success then acc + 1 else acc) 0 micro_results in
        let total_count = List.length micro_tasks in
        let completion_percentage = if total_count > 0 then (float_of_int successful_count) *. 100.0 /. (float_of_int total_count) else 0.0 in
        
        Printf.printf "🎯 Template-free execution completed: %d/%d tasks successful (%.1f%%)\n" 
          successful_count total_count completion_percentage;
        flush_all ();
        
        let summary = Printf.sprintf 
          "Template-free decomposition completed. %d/%d tasks successful (%.1f%% completion rate)" 
          successful_count total_count completion_percentage in
        
        (* Convert micro-task results to simple tool results for evaluation *)
        let tool_results = List.map (fun mr -> mr.result) micro_results in
        
        Lwt.return (Completed { summary; final_results = tool_results })
      ) else (
        (* Use standard planning for simple tasks *)
        Printf.printf "📋 Using standard planning for this task\n";
        flush_all ();
        (* Extract additional context from conversation if initial context is insufficient *)
        let enhanced_context = 
          if List.length context < 3 && List.length conversation > 0 then
            context @ extract_context_from_conversation conversation
          else
            context
        in
        let* (actions, plan_description) = generate_execution_plan config goal enhanced_context in
        Printf.printf "📋 Plan generated:\n%s\n" plan_description;
        flush_all ();
        if List.length actions > 0 then
          Lwt.return (Executing { plan = actions; current_step = 0; results = [] })
        else
          Lwt.return (Adjusting { 
            failures = [PlanningFailure { reason = "Could not generate actionable plan" }]; 
            new_plan = [] 
          })
      )

  | Executing { plan; current_step; results } ->
      if current_step >= List.length plan then
        (* All steps completed, evaluate *)
        let (success, failures) = evaluate_results plan results in
        Lwt.return (Evaluating { results; success; failures })
      else
        (* Execute next step *)
        let action = List.nth plan current_step in
        Printf.printf "📋 Step %d/%d: " (current_step + 1) (List.length plan);
        let+ result = execute_action config goal [] tool_executor action in
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