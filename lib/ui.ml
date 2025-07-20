open Types

(** Print welcome message *)
let print_welcome () =
  Printf.printf "\n🚀 OGemini - OCaml AI Assistant (Phase 1 MVP)\n";
  Printf.printf "====================================================\n";
  Printf.printf "Type your message, or 'exit'/'quit' to exit.\n\n"

(** Read user input *)
let read_input () =
  Printf.printf "👤 You: ";
  flush_all ();
  try
    let input = read_line () in
    let trimmed = String.trim input in
    if String.length trimmed = 0 then None
    else Some trimmed
  with
  | End_of_file -> None

(** Print thought with special styling *)
let handle_thought thought =
  Printf.printf "🤔 \027[2m%s\027[0m\n" thought.subject;
  Printf.printf "   \027[3m%s\027[0m\n\n" thought.description

(** Print content with typing effect *)
let handle_content content =
  Printf.printf "🤖 Assistant: ";
  flush_all ();
  let chars = List.of_seq (String.to_seq content) in
  List.iter (fun c ->
    Printf.printf "%c" c;
    flush_all ();
    Unix.sleepf 0.01
  ) chars;
  Printf.printf "\n\n"

(** Handle error display *)
let handle_error error =
  Printf.printf "❌ Error: %s\n\n" error

(** Process and display events *)
let handle_events events =
  List.iter (function
    | Content content -> handle_content content
    | Thought thought -> handle_thought thought
    | ToolCallRequest req -> Printf.printf "🔧 Tool request: %s\n" req
    | ToolCallResponse resp -> Printf.printf "✅ Tool response: %s\n" resp
    | LoopDetected reason -> Printf.printf "🔄 Loop detected: %s\n" reason
    | Error err -> handle_error err
  ) events

(** Create user message *)
let create_user_message input =
  Event_parser.create_message "user" input [Content input]

(** Add message to conversation *)
let add_message conversation message =
  message :: conversation