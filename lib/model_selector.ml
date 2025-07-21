(* Intelligent model selection based on task complexity *)

type model_tier = 
  | Fast of string      (* gemini-2.0-flash *)
  | Balanced of string  (* gemini-2.5-flash *)
  | Premium of string   (* gemini-2.5-pro *)

type task_complexity =
  | Simple      (* File ops, basic Q&A, simple refactoring *)
  | Medium      (* Multi-file coordination, compile errors, project analysis *)
  | Complex     (* Algorithm translation, bit-level precision, architecture design *)

type execution_context =
  | Development  (* Use fast models for rapid iteration *)
  | Debug       (* Use balanced models for debugging *)
  | Benchmark   (* Use premium models for final verification *)

(* Model configuration *)
let get_model_config tier = match tier with
  | Fast model -> (model, 1.0)      (* ~1s latency *)
  | Balanced model -> (model, 3.0)  (* ~3s latency *)
  | Premium model -> (model, 10.0)  (* ~10s latency *)

let available_models = [
  Fast "gemini-2.0-flash";
  Balanced "gemini-2.5-flash";
  Premium "gemini-2.5-pro";
]

(* Task complexity classification *)
let classify_task_complexity (task_description : string) : task_complexity =
  let lower_desc = String.lowercase_ascii task_description in
  
  (* Complex task keywords *)
  let complex_keywords = [
    "algorithm"; "translation"; "bit-level"; "bit-accurate"; "mathematical equivalence";
    "implement.*2048"; "lookup table"; "position.*operation"; "architecture design";
    "complex.*logic"; "verify.*accuracy"; "translate.*python.*ocaml";
  ] in
  
  (* Medium task keywords *)
  let medium_keywords = [
    "multi-file"; "coordination"; "compile.*error"; "project.*analysis";
    "refactor"; "dependency"; "module.*structure"; "build.*system";
    "test.*suite"; "integration"; "debug"; "analyze.*project";
    "dependencies"; "multiple.*files";
  ] in
  
  let contains_any keywords text =
    List.exists (fun keyword ->
      let regex = Str.regexp keyword in
      try ignore (Str.search_forward regex text 0); true
      with Not_found -> false
    ) keywords
  in
  
  if contains_any complex_keywords lower_desc then Complex
  else if contains_any medium_keywords lower_desc then Medium
  else Simple  (* Default to Simple for basic tasks *)

(* Model selection logic *)
let select_model 
    ?(context = Development) 
    ?(previous_failures = 0) 
    (task_complexity : task_complexity) : model_tier =
  
  match context, task_complexity, previous_failures with
  (* Development context - prioritize speed *)
  | Development, Simple, _ -> Fast "gemini-2.0-flash"
  | Development, Medium, 0 -> Fast "gemini-2.0-flash"
  | Development, Medium, _ -> Balanced "gemini-2.5-flash"
  | Development, Complex, 0 -> Balanced "gemini-2.5-flash"
  | Development, Complex, _ -> Premium "gemini-2.5-pro"
  
  (* Debug context - balanced approach *)
  | Debug, Simple, _ -> Fast "gemini-2.0-flash"
  | Debug, Medium, _ -> Balanced "gemini-2.5-flash"
  | Debug, Complex, _ -> Premium "gemini-2.5-pro"
  
  (* Benchmark context - maximum quality *)
  | Benchmark, _, _ -> Premium "gemini-2.5-pro"

(* Adaptive retry with model escalation *)
let escalate_model (current_tier : model_tier) : model_tier option =
  match current_tier with
  | Fast _ -> Some (Balanced "gemini-2.5-flash")
  | Balanced _ -> Some (Premium "gemini-2.5-pro")
  | Premium _ -> None  (* Already at highest tier *)

(* Retry delay calculation for 429 errors *)
let calculate_retry_delay (attempt : int) : float =
  let base_delay = 1.0 in
  let max_delay = 60.0 in
  min max_delay (base_delay *. (Float.pow 2.0 (Float.of_int attempt)))

(* Model selection with retry strategy *)
type retry_strategy = {
  max_attempts: int;
  escalate_on_failure: bool;
  exponential_backoff: bool;
}

let default_retry_strategy = {
  max_attempts = 5;
  escalate_on_failure = true;
  exponential_backoff = true;
}

let select_with_retry 
    ?(strategy = default_retry_strategy)
    ?(context = Development)
    (task_description : string) : model_tier * retry_strategy =
  
  let complexity = classify_task_complexity task_description in
  let initial_model = select_model ~context complexity in
  (initial_model, strategy)

(* Diagnostic information *)
let explain_selection 
    (task_description : string) 
    (selected_model : model_tier) 
    (context : execution_context) : string =
  
  let complexity = classify_task_complexity task_description in
  let (model_name, latency) = get_model_config selected_model in
  
  Printf.sprintf 
    "🤖 Model Selection:\n\
     📋 Task: %s\n\
     🧠 Complexity: %s\n\
     🎯 Context: %s\n\
     ⚡ Selected: %s (latency: %.1fs)\n\
     💡 Rationale: %s"
    (String.sub task_description 0 (min 60 (String.length task_description)))
    (match complexity with Simple -> "Simple" | Medium -> "Medium" | Complex -> "Complex")
    (match context with Development -> "Development" | Debug -> "Debug" | Benchmark -> "Benchmark")
    model_name
    latency
    (match selected_model with
     | Fast _ -> "Fast iteration, development speed prioritized"
     | Balanced _ -> "Balanced quality-speed tradeoff for debugging"
     | Premium _ -> "Maximum quality for complex/benchmark tasks")

(* Integration with existing API client *)
let get_selected_model_name (tier : model_tier) : string =
  let (model_name, _) = get_model_config tier in
  model_name