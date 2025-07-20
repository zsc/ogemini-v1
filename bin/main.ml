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
      
      (* Check if tool requires confirmation *)
      if tool_call.name = "write_file" then (
        Ui.confirm_tool_execution tool_call >>= fun confirmation ->
        (match confirmation with
        | Approve ->
            Printf.printf "✅ Executing tool...\n";
            execute_tool_call tool_call >>= fun result ->
            let response_event = ToolCallResponse result in
            Ui.handle_events [response_event];
            
            (* Add tool response to conversation *)
            let tool_msg = Event_parser.create_message "assistant" 
                          result.content [response_event] in
            let new_conv = Ui.add_message conversation tool_msg in
            process_tool_calls config new_conv remaining
        | Reject ->
            Printf.printf "❌ Tool execution cancelled by user.\n";
            process_tool_calls config conversation remaining)
      ) else (
        (* Execute without confirmation *)
        Printf.printf "⚡ Auto-executing safe tool...\n";
        execute_tool_call tool_call >>= fun result ->
        let response_event = ToolCallResponse result in
        Ui.handle_events [response_event];
        
        (* Add tool response to conversation *)
        let tool_msg = Event_parser.create_message "assistant" 
                      result.content [response_event] in
        let new_conv = Ui.add_message conversation tool_msg in
        process_tool_calls config new_conv remaining
      )

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
      Api_client.send_message config new_conv >>= fun response ->
      
      (match response with
      | Success ai_msg ->
          (* Display AI response *)
          Ui.handle_events ai_msg.events;
          let conv_with_ai = Ui.add_message new_conv ai_msg in
          
          (* Check for tool calls *)
          let tool_calls = extract_tool_calls ai_msg.events in
          if List.length tool_calls > 0 then
            (* Process tool calls *)
            process_tool_calls config conv_with_ai tool_calls >>= fun final_conv ->
            chat_loop config final_conv
          else
            (* No tool calls, continue normal conversation *)
            chat_loop config conv_with_ai
      | Error err ->
          Ui.handle_error err;
          chat_loop config new_conv)

(** Main program *)
let main () =
  (* Initialize configuration *)
  match Config.init_config () with
  | Config.ConfigError err ->
      Printf.printf "❌ Configuration error: %s\n" err;
      Printf.printf "Please set GEMINI_API_KEY environment variable.\n";
      Lwt.return_unit
  | Config.ConfigOk config ->
      (* Start the chat *)
      Ui.print_welcome ();
      Printf.printf "✅ Using model: %s\n" config.model;
      Printf.printf "💭 Thinking mode: %s\n\n" (if config.enable_thinking then "enabled" else "disabled");
      
      chat_loop config [] >>= fun () ->
      Lwt.return_unit

(** Entry point *)
let () = Lwt_main.run (main ())