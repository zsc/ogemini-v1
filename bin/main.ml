open Lwt.Syntax
open Ogemini.Types
open Ogemini

(** Simple chat loop for MVP *)
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
      let* response = Api_client.send_message config new_conv in
      
      (match response with
      | Success ai_msg ->
          (* Display AI response *)
          Ui.handle_events ai_msg.events;
          let final_conv = Ui.add_message new_conv ai_msg in
          chat_loop config final_conv
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
      
      let* () = chat_loop config [] in
      Lwt.return_unit

(** Entry point *)
let () = Lwt_main.run (main ())