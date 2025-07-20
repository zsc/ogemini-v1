open Lwt.Syntax
open Lwt.Infix
open Types

(** Tool orchestrator for autonomous multi-step execution *)

(** Execute a list of actions sequentially *)
let execute_sequential_strategy tool_executor actions =
  let rec execute_step acc = function
    | [] -> Lwt.return (List.rev acc)
    | action :: remaining ->
        Cognitive_engine.execute_action tool_executor action >>= fun result ->
        Printf.printf "Sequential step result: %s\n" 
          (if result.success then "✅" else "❌ " ^ Option.value result.error_msg ~default:"unknown error");
        flush_all ();
        execute_step (result :: acc) remaining
  in
  execute_step [] actions

(** Execute a list of actions in parallel *)
let execute_parallel_strategy tool_executor actions =
  let action_promises = List.map (Cognitive_engine.execute_action tool_executor) actions in
  let+ results = Lwt.all action_promises in
  Printf.printf "Parallel execution completed: %d results\n" (List.length results);
  flush_all ();
  results

(** Execute conditional strategy *)
let execute_conditional_strategy tool_executor condition if_true if_false trigger_result =
  let chosen_actions = 
    if condition trigger_result then (
      Printf.printf "🔀 Condition TRUE - executing primary branch\n";
      if_true
    ) else (
      Printf.printf "🔀 Condition FALSE - executing alternative branch\n"; 
      if_false
    )
  in
  flush_all ();
  execute_sequential_strategy tool_executor chosen_actions

(** Main strategy executor *)
let execute_strategy tool_executor strategy =
  match strategy with
  | Sequential actions ->
      Printf.printf "🔄 Executing %d actions sequentially...\n" (List.length actions);
      flush_all ();
      execute_sequential_strategy tool_executor actions
      
  | Parallel actions ->
      Printf.printf "⚡ Executing %d actions in parallel...\n" (List.length actions);
      flush_all ();
      execute_parallel_strategy tool_executor actions
      
  | Conditional { condition; if_true; if_false } ->
      Printf.printf "🤔 Executing conditional strategy - need trigger result\n";
      flush_all ();
      (* For conditional, we need a trigger result first *)
      let trigger_action = ToolCall { 
        name = "list_files"; 
        args = [("dir_path", "/workspace")]; 
        rationale = "Trigger action for conditional execution" 
      } in
      Cognitive_engine.execute_action tool_executor trigger_action >>= fun trigger_result ->
      execute_conditional_strategy tool_executor condition if_true if_false trigger_result >>= fun conditional_results ->
      Lwt.return (trigger_result :: conditional_results)

(** Adaptive retry logic for failed actions *)
let adaptive_retry action result =
  match action, result with
  | ToolCall { name = "read_file"; args; rationale }, { success = false; error_msg = Some err; _ } 
    when Str.string_match (Str.regexp ".*No such file.*") err 0 ->
      (* File doesn't exist, try listing directory first *)
      let original_path = List.assoc_opt "file_path" args |> Option.value ~default:"/workspace" in
      let dir_path = Filename.dirname original_path in
      Printf.printf "🔍 File not found, will list directory %s (original: %s)\n" dir_path rationale;
      Some (ToolCall { 
        name = "list_files"; 
        args = [("dir_path", dir_path)]; 
        rationale = Printf.sprintf "List files in %s to find alternatives after read failure: %s" dir_path err 
      })
      
  | ToolCall { name = "write_file"; args; rationale }, { success = false; error_msg = Some err; _ } ->
      (* Write failed, try creating directory first *)
      let file_path = List.assoc_opt "file_path" args |> Option.value ~default:"/workspace/output" in
      let dir_path = Filename.dirname file_path in
      Printf.printf "📁 Write failed, will create directory %s (original: %s)\n" dir_path rationale;
      Some (ToolCall { 
        name = "shell"; 
        args = [("command", Printf.sprintf "mkdir -p %s" dir_path)]; 
        rationale = Printf.sprintf "Create directory %s before write retry: %s" dir_path err 
      })
      
  | ToolCall { name = "dune_build"; args; rationale }, { success = false; error_msg = Some err; _ } ->
      (* Build failed, try cleaning first *)
      let target = List.assoc_opt "target" args |> Option.map (fun t -> " target: " ^ t) |> Option.value ~default:"" in
      Printf.printf "🔨 Build failed%s, will clean first (original: %s)\n" target rationale;
      Some (ToolCall { 
        name = "dune_clean"; 
        args = []; 
        rationale = Printf.sprintf "Clean before build retry%s: %s" target err 
      })
      
  | _ -> None (* No retry strategy available *)

(** Smart execution strategy selector based on action types *)
let select_optimal_strategy actions =
  let has_dependencies = List.exists (function
    | ToolCall { name = "write_file"; _ } -> true
    | ToolCall { name = "dune_build"; _ } -> true
    | _ -> false
  ) actions in
  
  let has_file_operations = List.exists (function
    | ToolCall { name = "read_file"; _ } -> true
    | ToolCall { name = "list_files"; _ } -> true
    | _ -> false
  ) actions in
  
  if has_dependencies then
    Sequential actions  (* Dependencies require sequential execution *)
  else if has_file_operations && List.length actions > 3 then
    Parallel actions    (* Independent file operations can be parallel *)
  else
    Sequential actions  (* Default to sequential for safety *)

(** Create execution strategy from goal analysis *)
let create_strategy_from_goal goal context_list =
  let goal_lower = String.lowercase_ascii goal in
  
  (* Log context for debugging *)
  if List.length context_list > 0 then (
    Printf.printf "📝 Context for planning (%d items):\n" (List.length context_list);
    List.iteri (fun i ctx -> Printf.printf "  %d. %s\n" (i+1) ctx) context_list;
    flush_all ()
  );
  
  if Str.string_match (Str.regexp ".*\\(build\\|compile\\).*") goal_lower 0 then
    (* Build-focused strategy *)
    Sequential [
      ToolCall { name = "list_files"; args = [("dir_path", "/workspace")]; rationale = "Survey project structure" };
      ToolCall { name = "read_file"; args = [("file_path", "/workspace/dune-project")]; rationale = "Check build configuration" };
      ToolCall { name = "dune_clean"; args = []; rationale = "Clean previous build artifacts" };
      ToolCall { name = "dune_build"; args = []; rationale = "Build the project" };
      ToolCall { name = "dune_test"; args = []; rationale = "Run tests to verify build" };
    ]
    
  else if Str.string_match (Str.regexp ".*\\(read\\|analyze\\).*") goal_lower 0 then
    (* Analysis-focused strategy *)
    Parallel [
      ToolCall { name = "list_files"; args = [("dir_path", "/workspace")]; rationale = "List all files" };
      ToolCall { name = "read_file"; args = [("file_path", "/workspace/README.md")]; rationale = "Read documentation" };
      ToolCall { name = "read_file"; args = [("file_path", "/workspace/CLAUDE.md")]; rationale = "Read project instructions" };
    ]
    
  else if Str.string_match (Str.regexp ".*\\(create\\|write\\).*") goal_lower 0 then
    (* Creation-focused strategy *)
    Sequential [
      ToolCall { name = "list_files"; args = [("dir_path", "/workspace")]; rationale = "Check existing structure" };
      ToolCall { name = "write_file"; args = [("file_path", "/workspace/output.txt"); ("content", "Initial content")]; rationale = "Create initial file" };
      ToolCall { name = "dune_build"; args = []; rationale = "Verify structure builds" };
    ]
    
  else
    (* Default exploration strategy *)
    Sequential [
      ToolCall { name = "list_files"; args = [("dir_path", "/workspace")]; rationale = "Explore workspace" };
      ToolCall { name = "shell"; args = [("command", "pwd")]; rationale = "Check current location" };
    ]

(** Execute strategy with retry logic *)
let execute_strategy_with_retry tool_executor strategy max_retries =
  let rec attempt retry_count =
    if retry_count >= max_retries then
      Lwt.return []
    else
      execute_strategy tool_executor strategy >>= fun results ->
      let failed_results = List.filter (fun r -> not r.success) results in
      if List.length failed_results = 0 then
        Lwt.return results
      else (
        Printf.printf "⚠️  %d failures, attempting retry %d/%d\n" 
          (List.length failed_results) (retry_count + 1) max_retries;
        flush_all ();
        attempt (retry_count + 1)
      )
  in
  attempt 0

(** Monitor execution progress *)
let monitor_execution_progress actions results =
  let completed = List.length results in
  let total = List.length actions in
  let success_count = List.length (List.filter (fun r -> r.success) results) in
  let progress_pct = if total > 0 then (completed * 100) / total else 0 in
  
  Printf.printf "📊 Progress: %d/%d (%d%%) | ✅ %d successes\n" 
    completed total progress_pct success_count;
  flush_all ()

(** Generate execution summary *)
let generate_execution_summary actions results =
  let total_actions = List.length actions in
  let total_results = List.length results in
  let successful = List.filter (fun r -> r.success) results in
  let failed = List.filter (fun r -> not r.success) results in
  
  let summary = Printf.sprintf 
    "Execution Summary: %d/%d actions completed | ✅ %d successes | ❌ %d failures"
    total_results total_actions (List.length successful) (List.length failed) in
    
  let detailed_results = List.mapi (fun i result ->
    let action_desc = if i < List.length actions then
      match List.nth actions i with
      | ToolCall { name; rationale; _ } -> Printf.sprintf "%s: %s" name rationale
      | Wait { reason; _ } -> Printf.sprintf "Wait: %s" reason  
      | UserInteraction { prompt; _ } -> Printf.sprintf "User: %s" prompt
    else
      "Unknown action"
    in
    Printf.sprintf "  %d. %s → %s" (i+1) action_desc 
      (if result.success then "✅" else "❌ " ^ Option.value result.error_msg ~default:"failed")
  ) results in
  
  summary ^ "\n" ^ String.concat "\n" detailed_results