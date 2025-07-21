open Lwt.Infix
open Ogemini.Types
open Ogemini

(** Enhanced main program with autonomous agent capabilities *)

(** Execute tool call - same as before but with better logging *)
let execute_tool_call tool_call =
  Printf.printf "🔧 %s: " tool_call.name;
  flush_all ();
  let start_time = Unix.time () in
  
  let execute_result = match tool_call.name with
  | "read_file" ->
      let file_path = List.assoc_opt "file_path" tool_call.args |> Option.value ~default:"" in
      if file_path = "" then
        Lwt.return { content = ""; success = false; error_msg = Some "Missing file_path" }
      else
        Tools.File_tools.read_file file_path
  | "write_file" ->
      let file_path = List.assoc_opt "file_path" tool_call.args |> Option.value ~default:"" in
      let content = List.assoc_opt "content" tool_call.args |> Option.value ~default:"" in
      if file_path = "" then
        Lwt.return { content = ""; success = false; error_msg = Some "Missing file_path" }
      else
        Tools.File_tools.write_file file_path content
  | "list_files" ->
      let dir_path = List.assoc_opt "dir_path" tool_call.args |> Option.value ~default:"." in
      Tools.File_tools.list_files dir_path
  | "shell" ->
      let command = List.assoc_opt "command" tool_call.args |> Option.value ~default:"" in
      if command = "" then
        Lwt.return { content = ""; success = false; error_msg = Some "Missing command" }
      else
        Tools.Shell_tools.execute_shell command
  | "dune_build" ->
      let target = List.assoc_opt "target" tool_call.args in
      Tools.Build_tools.dune_build target
  | "dune_test" ->
      let target = List.assoc_opt "target" tool_call.args in
      Tools.Build_tools.dune_test target
  | "dune_clean" ->
      Tools.Build_tools.dune_clean ()
  | "edit_file" ->
      Tools.Edit_tools.tool_edit_file tool_call.args
  | "search_files" ->
      Tools.Search_tools.tool_search_files tool_call.args
  | "analyze_project" ->
      Tools.Project_tools.tool_analyze_project tool_call.args
  | "rename_module" ->
      Tools.Project_tools.tool_rename_module tool_call.args
  | _ ->
      Lwt.return { content = ""; success = false; error_msg = Some ("Unknown tool: " ^ tool_call.name) }
  in
  
  execute_result >>= fun result ->
  let duration = Unix.time () -. start_time in
  Printf.printf "%s (%.2fs)\n" 
    (if result.success then "✅" else "❌") duration;
  flush_all ();
  Lwt.return result

(** Extract tool calls from events *)
let extract_tool_calls events =
  List.filter_map (function
    | ToolCallRequest tool_call -> Some tool_call
    | _ -> None
  ) events

(** Process tool calls in autonomous mode *)
let rec process_tool_calls_autonomous config conversation tool_calls =
  match tool_calls with
  | [] -> Lwt.return conversation
  | tool_call :: remaining ->
      Printf.printf "\n";
      execute_tool_call tool_call >>= fun result ->
      let response_event = ToolCallResponse result in
      Ui.handle_events [response_event];
      
      let tool_msg = Event_parser.create_message "assistant" 
                    result.content [response_event] in
      let new_conv = Ui.add_message conversation tool_msg in
      process_tool_calls_autonomous config new_conv remaining

(** Enhanced chat loop with autonomous agent capabilities *)
let rec autonomous_chat_loop config conversation cognitive_state_opt =
  (* Check if agent should continue autonomously *)
  match cognitive_state_opt with
  | Some cognitive_state ->
      (* Agent-driven mode: continue autonomous execution *)
      Printf.printf "\n🤖 ";
      let status = Conversation_manager.generate_status_update cognitive_state in
      Printf.printf "%s\n" status;
      flush_all ();
      
      Conversation_manager.handle_autonomous_continuation config execute_tool_call cognitive_state conversation >>= fun (new_state_opt, continuation) ->
      
      begin match continuation with
      | AgentExecutesPlan new_state ->
          (* Continue autonomous execution *)
          autonomous_chat_loop config conversation (Some new_state)
          
      | UserSpeaksNext ->
          (* Return control to user *)
          let transition_msg = Conversation_manager.generate_transition_message new_state_opt in
          Printf.printf "\n%s\n\n" transition_msg;
          autonomous_chat_loop config conversation None
          
      | AgentNeedsGuidance guidance ->
          (* Agent needs user help *)
          Printf.printf "\n🆘 I need guidance: %s\n" guidance;
          Printf.printf "Please provide direction or say 'continue' to let me try again.\n\n";
          autonomous_chat_loop config conversation None
          
      | _ ->
          (* Fallback to user input *)
          autonomous_chat_loop config conversation None
      end
      
  | None ->
      (* User-driven mode: wait for user input *)
      match Ui.read_input () with
      | None | Some "exit" | Some "quit" -> 
          Printf.printf "👋 Goodbye!\n";
          Lwt.return ()
      | Some input ->
          (* Check if user wants to interrupt autonomous mode *)
          let cleaned_state = Conversation_manager.handle_user_interruption cognitive_state_opt input in
          
          (* Create user message *)
          let user_msg = Ui.create_user_message input in
          let new_conv = Ui.add_message conversation user_msg in
          
          (* Determine if this should trigger autonomous mode, but only if not interrupted *)
          let should_go_autonomous = 
            cleaned_state = None && Conversation_manager.requires_autonomous_handling input conversation 
          in
          
          if should_go_autonomous then (
            (* Enter autonomous mode *)
            let goal = Cognitive_engine.extract_goal_from_input input in
            let explanation = Conversation_manager.explain_autonomous_mode_entry goal in
            Printf.printf "%s\n" explanation;
            flush_all ();
            
            let initial_state = Conversation_manager.initiate_autonomous_planning input conversation in
            autonomous_chat_loop config new_conv (Some initial_state)
          ) else (
            (* Normal reactive mode *)
            Printf.printf "🤔 Thinking...\n";
            flush_all ();
            Api_client.send_message config new_conv >>= (function
              | Success ai_msg ->
                  Ui.handle_events ai_msg.events;
                  let conv_with_ai = Ui.add_message new_conv ai_msg in
                  let tool_calls = extract_tool_calls ai_msg.events in
                  if List.length tool_calls > 0 then (
                    Printf.printf "🔧 Processing %d tool call(s)...\n" (List.length tool_calls);
                    flush_all ();
                    process_tool_calls_autonomous config conv_with_ai tool_calls >>= fun final_conv ->
                    autonomous_chat_loop config final_conv None
                  ) else (
                    autonomous_chat_loop config conv_with_ai None
                  )
              | Error err ->
                  Ui.handle_error err;
                  autonomous_chat_loop config new_conv None
            )
          )

(** Enhanced welcome message *)
let print_autonomous_welcome () =
  Printf.printf {|
🤖 OGemini - Autonomous Agent Mode

Features:
• 🧠 Autonomous planning and execution
• 🔄 Multi-step task orchestration  
• 🛠️ Smart tool coordination
• 💬 Collaborative dialogue

I can work autonomously on complex tasks like:
- Building and testing projects
- Creating and organizing files
- Analyzing code and documentation
- Multi-step development workflows

Just describe your goal and I'll break it down into actionable steps!

|};
  flush_all ()

(** Print help message *)
let print_help () =
  Printf.printf {|OGemini Autonomous Agent

USAGE:
    main_autonomous.exe [OPTIONS]

OPTIONS:
    --help, -h     Show this help message
    --version, -v  Show version information

DESCRIPTION:
    Starts the autonomous agent mode with interactive chat loop.
    The agent can autonomously plan and execute complex tasks.

EXAMPLES:
    main_autonomous.exe           # Start interactive mode
    main_autonomous.exe --help    # Show this help

|};
  exit 0

(** Print version information *)
let print_version () =
  Printf.printf "OGemini Autonomous Agent v1.0.0\n";
  exit 0

(** Parse command line arguments *)
let parse_args () =
  let parse_args_list args =
    match args with
    | [] -> ()
    | "--help" :: _ | "-h" :: _ -> print_help ()
    | "--version" :: _ | "-v" :: _ -> print_version ()
    | arg :: _ ->
        Printf.printf "Unknown option: %s\n" arg;
        Printf.printf "Use --help for usage information.\n";
        exit 1
  in
  parse_args_list (List.tl (Array.to_list Sys.argv))

(** Main program with autonomous capabilities *)
let main () =
  (* Parse command line arguments first *)
  parse_args ();
  
  match Config.init_config () with
  | Config.ConfigError err ->
      Printf.printf "❌ Configuration error: %s\n" err;
      Printf.printf "Please set GEMINI_API_KEY environment variable or create .env file.\n";
      Printf.printf "Current working directory: %s\n" (Sys.getcwd ());
      Printf.printf ".env file exists: %b\n" (Sys.file_exists ".env");
      exit 1
  | Config.ConfigOk config ->
      print_autonomous_welcome ();
      Printf.printf "✅ Using model: %s\n" config.model;
      Printf.printf "✅ API key loaded: %s\n" (String.sub config.api_key 0 (min 10 (String.length config.api_key)) ^ "...");
      Printf.printf "💭 Thinking mode: %s\n" (if config.enable_thinking then "enabled" else "disabled");
      Printf.printf "🧠 Autonomous mode: enabled\n\n";
      
      autonomous_chat_loop config [] None >>= fun () ->
      Lwt.return_unit

(** Entry point *)
let () = Lwt_main.run (main ())