open Lwt.Infix
open Ogemini.Types
open Ogemini

(** Simple tool execution *)
let execute_tool_call tool_call =
  match tool_call.name with
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
  | _ ->
      Lwt.return { content = ""; success = false; error_msg = Some ("Unknown tool: " ^ tool_call.name) }

(** Extract tool calls from events *)
let extract_tool_calls events =
  List.filter_map (function
    | ToolCallRequest tool_call -> Some tool_call
    | _ -> None
  ) events

(** Process tool calls with user confirmation *)
let rec process_tool_calls config conversation tool_calls =
  match tool_calls with
  | [] -> Lwt.return conversation
  | tool_call :: remaining ->
      Printf.printf "\n";
      
      (* Auto-execute all tools in secure container *)
      Printf.printf "⚡ Executing %s...\n" tool_call.name;
      execute_tool_call tool_call >>= fun result ->
      let response_event = ToolCallResponse result in
      Ui.handle_events [response_event];
      
      (* Add tool response to conversation *)
      let tool_msg = Event_parser.create_message "assistant" 
                    result.content [response_event] in
      let new_conv = Ui.add_message conversation tool_msg in
      process_tool_calls config new_conv remaining

(** Enhanced chat loop with tool support *)
let rec chat_loop config conversation =
  match Ui.read_input () with
  | None | Some "exit" | Some "quit" -> 
      Printf.printf "👋 Goodbye!\n";
      Lwt.return ()
  | Some input ->
      (* Create user message *)
      let user_msg = Ui.create_user_message input in
      let new_conv = Ui.add_message conversation user_msg in
      
      (* Send to API and get response *)
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
              process_tool_calls config conv_with_ai tool_calls >>= fun final_conv ->
              chat_loop config final_conv
            ) else (
              chat_loop config conv_with_ai
            )
        | Error err ->
            Ui.handle_error err;
            chat_loop config new_conv
      )

(** Main program *)
let main () =
  (* Initialize configuration *)
  match Config.init_config () with
  | Config.ConfigError err ->
      Printf.printf "❌ Configuration error: %s\n" err;
      Printf.printf "Please set GEMINI_API_KEY environment variable or create .env file.\n";
      Printf.printf "Current working directory: %s\n" (Sys.getcwd ());
      Printf.printf ".env file exists: %b\n" (Sys.file_exists ".env");
      exit 1  (* Exit immediately instead of continuing *)
  | Config.ConfigOk config ->
      (* Start the chat *)
      Ui.print_welcome ();
      Printf.printf "✅ Using model: %s\n" config.model;
      Printf.printf "✅ API key loaded: %s\n" (String.sub config.api_key 0 (min 10 (String.length config.api_key)) ^ "...");
      Printf.printf "💭 Thinking mode: %s\n\n" (if config.enable_thinking then "enabled" else "disabled");
      
      chat_loop config [] >>= fun () ->
      Lwt.return_unit

(** Entry point *)
let () = Lwt_main.run (main ())