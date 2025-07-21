(** Core data types for OGemini *)

(** Configuration *)
type config = {
  api_key : string;
  api_endpoint : string;
  model : string;
  enable_thinking : bool;
  force_template_free : bool; (* Phase 7.1: Force template-free mode for testing *)
}

(** Thought summary from AI thinking process *)
type thought_summary = {
  subject : string;
  description : string;
}

(** Phase 2.1: Simplified Tool System Data Structures *)

(** Simplified tool result *)
type simple_tool_result = {
  content : string;                        (* Return content *)
  success : bool;                          (* Whether successful *)
  error_msg : string option;               (* Error message if any *)
}

(** Tool specification *)
type tool_spec = {
  name : string;
  description : string;
  parameters : (string * string) list;     (* Parameter name and description pairs *)
}

(** Tool call information *)
type tool_call = {
  id : string;
  name : string;
  args : (string * string) list;           (* Parameter key-value pairs *)
}

(** Simplified confirmation type - only approve/reject *)
type simple_confirmation =
  | Approve
  | Reject

(** Action types for micro-tasks *)
type action = 
  | ToolCall of { name: string; args: (string * string) list; rationale: string }
  | LLMGeneration of { prompt: string; target_file: string; expected_length: int }
  | Wait of { reason: string; duration: float }
  | UserInteraction of { prompt: string; expected_response: string }

(** Event types - corresponds to gemini-cli's event system *)
type event_type =
  | Content of string
  | ToolCallRequest of tool_call
  | ToolCallResponse of simple_tool_result
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

(** Phase 2.2: Enhanced Tool System Data Structures *)

(* For now, keeping simple_tool_result and adding timing info via printf *)

(** Phase 4: Autonomous Agent Cognitive Architecture *)

(** Execution strategy for tool orchestration *)
type execution_strategy = 
  | Sequential of action list
  | Parallel of action list  
  | Conditional of { 
      condition: simple_tool_result -> bool; 
      if_true: action list; 
      if_false: action list; 
    }

(** Failure modes for error analysis *)
type failure_mode = 
  | ToolExecutionFailure of { tool: string; error: string }
  | PlanningFailure of { reason: string }
  | UserExpectationMismatch of { expected: string; actual: string }

(** Cognitive state machine states *)
type cognitive_state = 
  | Planning of { 
      goal: string; 
      context: string list; 
    }
  | Executing of { 
      plan: action list; 
      current_step: int; 
      results: simple_tool_result list;
    }
  | Evaluating of { 
      results: simple_tool_result list; 
      success: bool; 
      failures: failure_mode list;
    }
  | Adjusting of { 
      failures: failure_mode list; 
      new_plan: action list; 
    }
  | Completed of { 
      summary: string; 
      final_results: simple_tool_result list;
    }

(** Conversation modes for autonomous behavior *)
type conversation_mode = 
  | UserDriven     (* Traditional reactive mode - wait for user *)
  | AgentDriven    (* Autonomous mode - agent drives the conversation *)
  | Collaborative  (* Interactive mode - mixed initiative *)

(** Extended continuation state with cognitive awareness *)
type autonomous_continuation_state =
  | UserSpeaksNext
  | AssistantContinues  
  | AgentExecutesPlan of cognitive_state  (* New: autonomous execution *)
  | AgentNeedsGuidance of string          (* New: agent needs help *)
  | Finished

(** Phase 7.2: Micro-task decomposition types *)

(** Task complexity classification *)
type task_complexity = [`Simple | `Medium | `Complex]

(** Micro-task definition with verification criteria *)
type micro_task = {
  id: string;
  description: string;
  action: action;
  verification: string;
  dependencies: string list;
  retry_limit: int;
  complexity: task_complexity;
}

(** Micro-task execution result *)
type micro_task_result = {
  task_id: string;
  success: bool;
  result: simple_tool_result;
  verification_passed: bool;
  attempts: int;
}

(** Task decomposition mode *)
type decomposition_mode = 
  | StandardExecution  (* Use existing cognitive engine *)
  | MicroTaskMode of micro_task list  (* Use micro-task decomposition *)