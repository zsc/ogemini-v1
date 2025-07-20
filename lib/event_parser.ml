open Types

(** Parse thought content in **Subject** Description format or numbered steps *)
let parse_thought text =
  (* First try **Subject** Description format *)
  let thought_pattern = Re.Perl.compile_pat {|\*\*(.*?)\*\*(.*)|} in
  match Re.exec_opt thought_pattern text with
  | Some result ->
      let subject = String.trim (Re.Group.get result 1) in
      let description = String.trim (Re.Group.get result 2) in
      Some { subject; description }
  | None ->
      (* Try numbered step format like "1. step description" *)
      let step_pattern = Re.Perl.compile_pat {|^(\d+)\.\s+(.+)|} in
      match Re.exec_opt step_pattern text with
      | Some result ->
          let step_num = String.trim (Re.Group.get result 1) in
          let description = String.trim (Re.Group.get result 2) in
          Some { subject = "Step " ^ step_num; description }
      | None -> None

(** Parse API response text into events *)
let parse_response text =
  let lines = String.split_on_char '\n' text in
  let events = ref [] in
  
  List.iter (fun line ->
    let trimmed = String.trim line in
    if String.length trimmed > 0 then
      (* Try to parse as thought first *)
      match parse_thought trimmed with
      | Some thought -> 
          events := (Thought thought) :: !events
      | None ->
          (* Otherwise treat as content *)
          events := (Content trimmed) :: !events
  ) lines;
  
  List.rev !events

(** Format events for display *)
let format_events events =
  let format_event = function
    | Content text -> text
    | Thought thought -> Printf.sprintf "💭 %s: %s" thought.subject thought.description
    | ToolCallRequest tool_call -> 
        Printf.sprintf "🔧 Tool request: %s" tool_call.name
    | ToolCallResponse result -> 
        Printf.sprintf "✅ Tool response: %s" result.content
    | LoopDetected reason -> Printf.sprintf "🔄 Loop detected: %s" reason
    | Error err -> Printf.sprintf "❌ Error: %s" err
  in
  String.concat "\n" (List.map format_event events)

(** Process streaming response chunks *)
let process_event_stream chunk =
  (* Simple implementation - parse each chunk as complete text *)
  parse_response chunk

(** Create message from events *)
let create_message role content events =
  {
    role;
    content;
    events;
    timestamp = Unix.time ();
  }