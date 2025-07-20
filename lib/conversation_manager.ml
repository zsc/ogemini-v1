open Lwt.Syntax
open Types

(** Conversation manager for autonomous agent behavior *)

(** Analyze user input to determine conversation mode *)
let analyze_conversation_mode user_input conversation =
  let input_lower = String.lowercase_ascii user_input in
  let input_words = String.split_on_char ' ' input_lower in
  
  (* High-autonomy triggers - clear goals that require multi-step execution *)
  let autonomous_triggers = [
    "create"; "build"; "implement"; "develop"; "make"; "generate"; 
    "complete"; "finish"; "setup"; "configure"; "install";
    "help me"; "work on"; "project"; "translate"; "convert"
  ] in
  
  (* Collaborative triggers - requests for guidance or discussion *)
  let collaborative_triggers = [
    "how"; "what"; "why"; "explain"; "show"; "demonstrate"; 
    "teach"; "guide"; "help"; "advice"; "suggest"; "recommend"
  ] in
  
  (* User-driven triggers - simple requests or questions *)
  let _user_driven_triggers = [
    "read"; "list"; "check"; "status"; "tell me"; "display"; "show me"
  ] in
  
  let has_trigger triggers = List.exists (fun trigger ->
    List.exists (String.equal trigger) input_words
  ) triggers in
  
  let input_length = String.length user_input in
  let conversation_length = List.length conversation in
  
  if has_trigger autonomous_triggers && input_length > 30 then
    AgentDriven
  else if has_trigger collaborative_triggers || (input_length > 50 && conversation_length < 3) then
    Collaborative  
  else
    UserDriven

(** Detect if user wants to interrupt autonomous mode *)
let detect_user_interruption user_input =
  let input_lower = String.lowercase_ascii user_input in
  let interruption_signals = [
    "stop"; "halt"; "pause"; "wait"; "hold"; "interrupt"; 
    "cancel"; "abort"; "quit"; "exit"; "break"
  ] in
  List.exists (fun signal -> 
    try 
      ignore (Str.search_forward (Str.regexp signal) input_lower 0); 
      true 
    with Not_found -> false
  ) interruption_signals

(** Determine next speaker based on cognitive state and conversation context *)
let determine_next_speaker _config conversation cognitive_state_opt =
  match cognitive_state_opt with
  | Some (Executing { plan; current_step; _ }) when current_step < List.length plan ->
      (* Agent is actively executing a plan *)
      let remaining_steps = List.length plan - current_step in
      Printf.printf "🔄 Agent has %d remaining steps to execute\n" remaining_steps;
      flush_all ();
      Lwt.return (AgentExecutesPlan (Executing { plan; current_step; results = [] }))
      
  | Some (Planning { goal; _ }) ->
      (* Agent is planning and should continue *)
      Lwt.return (AgentExecutesPlan (Planning { goal; context = [] }))
      
  | Some (Evaluating { success = false; failures; _ }) ->
      (* Agent needs to adjust strategy *)
      Lwt.return (AgentNeedsGuidance ("Encountered failures: " ^ 
        String.concat "; " (List.map (function
          | ToolExecutionFailure { tool; error } -> tool ^ " failed: " ^ error
          | PlanningFailure { reason } -> "Planning: " ^ reason  
          | UserExpectationMismatch { expected; actual } -> "Expected " ^ expected ^ ", got " ^ actual
        ) failures)))
        
  | Some (Completed _) ->
      (* Agent completed its task, return control to user *)
      Lwt.return UserSpeaksNext
      
  | Some (Adjusting _) ->
      (* Agent is adjusting, should continue *)
      Lwt.return (AgentExecutesPlan (Adjusting { failures = []; new_plan = [] }))
      
  | Some (Evaluating { success = true; _ }) ->
      (* Agent successfully evaluated, may continue *)
      Lwt.return AssistantContinues
      
  | Some (Executing _) ->
      (* Default for executing state not covered by guard *)
      Lwt.return (AgentExecutesPlan (Executing { plan = []; current_step = 0; results = [] }))
      
  | None ->
      (* No cognitive state, normal conversation flow *)
      if List.length conversation = 0 then
        Lwt.return UserSpeaksNext
      else
        let last_msg = List.hd (List.rev conversation) in
        if last_msg.role = "user" then
          Lwt.return AssistantContinues
        else
          Lwt.return UserSpeaksNext

(** Check if the agent should continue autonomously *)
let should_continue_autonomously cognitive_state conversation =
  match cognitive_state with
  | Planning _ | Executing _ | Evaluating _ | Adjusting _ -> 
      (* Continue unless conversation shows user interruption *)
      let last_user_msg = List.find_opt (fun msg -> msg.role = "user") (List.rev conversation) in
      begin match last_user_msg with
      | Some msg when detect_user_interruption msg.content -> Lwt.return false
      | _ -> Lwt.return true
      end
  | Completed _ ->
      Lwt.return false

(** Generate status update for current cognitive state *)
let generate_status_update = function
  | Planning { goal; context } ->
      Printf.sprintf "🧠 Planning: Working on '%s' with %d context items" 
        goal (List.length context)
        
  | Executing { plan; current_step; results } ->
      let progress = if List.length plan > 0 then 
        (current_step * 100) / List.length plan else 0 in
      Printf.sprintf "⚡ Executing: Step %d/%d (%d%%) - %d results so far" 
        current_step (List.length plan) progress (List.length results)
        
  | Evaluating { results; success; failures } ->
      Printf.sprintf "🔍 Evaluating: %d results, %s, %d issues" 
        (List.length results) 
        (if success then "successful" else "needs work")
        (List.length failures)
        
  | Adjusting { failures; new_plan } ->
      Printf.sprintf "🔄 Adjusting: Addressing %d failures, %d new actions planned" 
        (List.length failures) (List.length new_plan)
        
  | Completed { summary; final_results } ->
      Printf.sprintf "🎯 Completed: %s (%d final results)" 
        summary (List.length final_results)

(** Convert user goal into cognitive planning state *)
let initiate_autonomous_planning user_input conversation =
  let goal = Cognitive_engine.extract_goal_from_input user_input in
  let context = Cognitive_engine.extract_context_from_conversation conversation in
  Planning { goal; context }

(** Handle autonomous continuation logic *)
let handle_autonomous_continuation config tool_executor cognitive_state conversation =
  let* next_state = Cognitive_engine.cognitive_loop config tool_executor cognitive_state conversation in
  
  (* Display status update *)
  let status = generate_status_update next_state in
  Printf.printf "%s\n" status;
  flush_all ();
  
  (* Check if we should continue or hand back to user *)
  let+ should_continue = should_continue_autonomously next_state conversation in
  if should_continue then
    (Some next_state, AgentExecutesPlan next_state)
  else
    (None, UserSpeaksNext)

(** Create autonomous message for conversation history *)
let create_autonomous_message cognitive_state results_opt =
  let content = generate_status_update cognitive_state in
  let events = match results_opt with
    | Some results -> List.map (fun r -> ToolCallResponse r) results
    | None -> []
  in
  {
    role = "assistant";
    content;
    events;
    timestamp = Unix.time ();
  }

(** Handle user interruption gracefully *)
let handle_user_interruption cognitive_state_opt user_input =
  match cognitive_state_opt with
  | Some state ->
      let status = generate_status_update state in
      Printf.printf "⏸️  Autonomous mode interrupted by user\n";
      Printf.printf "Previous state: %s\n" status;
      Printf.printf "User said: %s\n" user_input;
      flush_all ();
      None (* Clear cognitive state *)
  | None ->
      None

(** Determine if input requires autonomous handling *)
let requires_autonomous_handling user_input conversation =
  let mode = analyze_conversation_mode user_input conversation in
  match mode with
  | AgentDriven -> true
  | Collaborative -> String.length user_input > 50 (* Long collaborative requests might need autonomy *)
  | UserDriven -> false

(** Generate helpful autonomous mode explanation *)
let explain_autonomous_mode_entry goal =
  Printf.sprintf {|
🤖 Entering Autonomous Mode

I understand you want me to: %s

I'll work autonomously to break this down into steps and execute them. 
You can say "stop" or "pause" at any time to interrupt.

Let me start by planning...
|} goal

(** Generate transition message when returning to user mode *)
let generate_transition_message cognitive_state_opt =
  match cognitive_state_opt with
  | Some (Completed { summary; _ }) ->
      Printf.sprintf "✅ Autonomous execution completed: %s\n\nHow can I help you further?" summary
  | Some state ->
      let status = generate_status_update state in
      Printf.sprintf "⏸️  Autonomous mode paused: %s\n\nWhat would you like to do next?" status
  | None ->
      "Ready for your next request!"