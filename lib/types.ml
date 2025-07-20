(** Core data types for OGemini *)

(** Configuration *)
type config = {
  api_key : string;
  api_endpoint : string;
  model : string;
  enable_thinking : bool;
}

(** Thought summary from AI thinking process *)
type thought_summary = {
  subject : string;
  description : string;
}

(** Event types - corresponds to gemini-cli's event system *)
type event_type =
  | Content of string
  | ToolCallRequest of string
  | ToolCallResponse of string
  | Thought of thought_summary
  | LoopDetected of string
  | Error of string

(** Message in conversation *)
type message = {
  role : string; (* "user" | "assistant" | "system" *)
  content : string;
  events : event_type list;
  timestamp : float;
}

(** Conversation history *)
type conversation = message list

(** Loop detection state - based on gemini-cli's three detection methods *)
type loop_state = {
  recent_tool_calls : string list;
  recent_content : string list;
  tool_loop_count : int;
  content_loop_count : int;
}

(** Continuation state for smart conversation control *)
type continuation_state =
  | UserSpeaksNext
  | AssistantContinues
  | Finished

(** API response *)
type response =
  | Success of message
  | Error of string