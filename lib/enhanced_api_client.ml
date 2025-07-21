(* Enhanced API client with intelligent model selection and robust retry logic *)

open Lwt.Syntax
open Types
open Model_selector

(* Retry state for tracking failures *)
type retry_state = {
  attempt: int;
  current_model: model_tier;
  last_error: string option;
  total_wait_time: float;
}

(* Enhanced API call result *)
type api_call_result =
  | Success of string * model_tier * float  (* response, model_used, duration *)
  | RateLimited of float                    (* retry_after_seconds *)
  | ApiError of string                      (* error_message *)
  | QuotaExhausted                         (* no more retries possible *)

(* Parse 429 response to extract retry delay *)
let parse_retry_delay (error_response : string) : float option =
  try
    let json = Yojson.Basic.from_string error_response in
    match json with
    | `Assoc fields ->
        let extract_retry_delay fields =
          let rec find_retry_delay = function
            | [] -> None
            | ("error", `Assoc error_fields) :: _ ->
                (match List.assoc_opt "details" error_fields with
                | Some (`List details) ->
                    List.fold_left (fun acc detail ->
                      match acc, detail with
                      | None, `Assoc detail_fields ->
                          (match List.assoc_opt "retryDelay" detail_fields with
                          | Some (`String delay_str) ->
                              (* Parse "35s" format *)
                              (try
                                let len = String.length delay_str in
                                if len > 1 && delay_str.[len-1] = 's' then
                                  Some (float_of_string (String.sub delay_str 0 (len-1)))
                                else None
                              with _ -> None)
                          | _ -> None)
                      | acc, _ -> acc
                    ) None details
                | _ -> None)
            | _ :: rest -> find_retry_delay rest
          in
          find_retry_delay fields
        in
        extract_retry_delay fields
    | _ -> None
  with _ -> None

(* Make API call with specific model *)
let call_api_with_model (config : config) (model_name : string) (text : string) : api_call_result Lwt.t =
  let start_time = Unix.gettimeofday () in
  let model_config = Config.config_with_model config model_name in
  
  (* Create a simple conversation with the text *)
  let conversation = [{ role = "user"; content = text; events = []; timestamp = Unix.time () }] in
  let* result = Api_client.send_message model_config conversation in
  let duration = Unix.gettimeofday () -. start_time in
  
  match result with
  | Success msg -> 
      Printf.printf "✅ API Success: %s (%.2fs)\n" model_name duration;
      Lwt.return (Success (msg.content, Fast model_name, duration))
  | Error error_msg ->
      Printf.printf "❌ API Error: %s - %s (%.2fs)\n" model_name error_msg duration;
      (* Check if it's a 429 rate limit error *)
      if String.contains error_msg '4' && String.contains error_msg '2' && String.contains error_msg '9' then
        match parse_retry_delay error_msg with
        | Some delay -> Lwt.return (RateLimited delay)
        | None -> Lwt.return (RateLimited (calculate_retry_delay 1))
      else
        Lwt.return (ApiError error_msg)

(* Exponential backoff sleep *)
let sleep_with_backoff (seconds : float) : unit Lwt.t =
  Printf.printf "⏳ Waiting %.1fs before retry...\n%!" seconds;
  Lwt_unix.sleep seconds

(* Enhanced API call with retries and model escalation *)
let call_api_enhanced 
    ?(context = Development)
    ?(max_retries = 5)
    (config : config) 
    (task_description : string) : api_call_result Lwt.t =
  
  let complexity = classify_task_complexity task_description in
  let initial_model = select_model ~context complexity in
  
  Printf.printf "%s\n" (explain_selection task_description initial_model context);
  
  let rec retry_loop state =
    if state.attempt >= max_retries then
      Lwt.return QuotaExhausted
    else
      let model_name = get_selected_model_name state.current_model in
      Printf.printf "🔄 Attempt %d/%d with %s\n%!" (state.attempt + 1) max_retries model_name;
      
      let* result = call_api_with_model config model_name task_description in
      
      match result with
      | Success (response, model_used, duration) ->
          Printf.printf "🎉 Success after %d attempts\n%!" (state.attempt + 1);
          Lwt.return (Success (response, model_used, duration))
      
      | RateLimited retry_delay ->
          Printf.printf "⚠️ Rate limited, waiting %.1fs\n%!" retry_delay;
          let* () = sleep_with_backoff retry_delay in
          
          (* Try model escalation if enabled *)
          let next_model = match escalate_model state.current_model with
            | Some better_model -> 
                Printf.printf "⬆️ Escalating to %s\n%!" (get_selected_model_name better_model);
                better_model
            | None -> state.current_model
          in
          
          retry_loop {
            attempt = state.attempt + 1;
            current_model = next_model;
            last_error = Some "Rate limited";
            total_wait_time = state.total_wait_time +. retry_delay;
          }
      
      | ApiError error_msg ->
          Printf.printf "💥 API Error: %s\n%!" error_msg;
          
          (* Try model escalation for API errors too *)
          let next_model = match escalate_model state.current_model with
            | Some better_model ->
                Printf.printf "⬆️ Escalating to %s after API error\n%!" (get_selected_model_name better_model);
                better_model
            | None -> state.current_model
          in
          
          let* () = sleep_with_backoff (calculate_retry_delay state.attempt) in
          retry_loop {
            attempt = state.attempt + 1;
            current_model = next_model;
            last_error = Some error_msg;
            total_wait_time = state.total_wait_time +. (calculate_retry_delay state.attempt);
          }
      
      | QuotaExhausted ->
          Lwt.return QuotaExhausted
  in
  
  let initial_state = {
    attempt = 0;
    current_model = initial_model;
    last_error = None;
    total_wait_time = 0.0;
  } in
  
  retry_loop initial_state

(* Convenience wrapper that returns string result *)
let call_api_robust 
    ?(context = Development)
    ?(max_retries = 5)
    (config : config) 
    (task_description : string) : (string, string) result Lwt.t =
  
  let* result = call_api_enhanced ~context ~max_retries config task_description in
  
  match result with
  | Success (response, model_used, duration) ->
      let model_name = get_selected_model_name model_used in
      Printf.printf "✅ Enhanced API Success: %s (%.2fs)\n%!" model_name duration;
      Lwt.return (Result.Ok response)
  | RateLimited _ ->
      Lwt.return (Result.Error "Rate limited after maximum retries")
  | ApiError error_msg ->
      Lwt.return (Result.Error error_msg)
  | QuotaExhausted ->
      Lwt.return (Result.Error "Quota exhausted after maximum retries")

(* Test function for model selection *)
let test_model_selection () =
  let test_cases = [
    "list files in current directory";
    "implement complex 2048 bit-level algorithm translation from Python to OCaml";
    "analyze project structure and dependencies";
    "create simple hello world project";
    "verify mathematical equivalence of lookup tables";
  ] in
  
  Printf.printf "🧪 Testing Model Selection:\n\n";
  List.iter (fun task ->
    let complexity = classify_task_complexity task in
    let model = select_model ~context:Development complexity in
    let explanation = explain_selection task model Development in
    Printf.printf "%s\n\n" explanation;
  ) test_cases