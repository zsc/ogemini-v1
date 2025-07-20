open Types

(** Default configuration values *)
let default_config = {
  api_key = "";
  api_endpoint = "https://generativelanguage.googleapis.com/v1beta/models";
  model = "gemini-2.0-flash";  (* Use 2.0-flash for faster responses *)
  enable_thinking = false;     (* Disable thinking for speed *)
}

(** Read .env file and extract API key *)
let read_env_file () =
  try
    if Sys.file_exists ".env" then (
      let ic = open_in ".env" in
      let rec read_lines acc =
        try
          let line = input_line ic in
          let trimmed = String.trim line in
          if String.length trimmed > 0 && not (String.starts_with ~prefix:"#" trimmed) then
            if String.contains trimmed '=' then
              let parts = String.split_on_char '=' trimmed in
              match parts with
              | key :: value_parts ->
                  let key = String.trim key in
                  let value = String.trim (String.concat "=" value_parts) in
                  (key, value) :: acc
              | _ -> read_lines acc
            else read_lines acc
          else read_lines acc
        with End_of_file ->
          close_in ic;
          acc
      in
      Some (read_lines [])
    ) else None
  with _ -> None

(** Load API key from environment variable or .env file *)
let get_api_key () =
  (* First try environment variable *)
  try
    let env_key = Sys.getenv "GEMINI_API_KEY" in
    if String.length env_key > 0 then (
      Printf.eprintf "DEBUG: Found API key in environment (%d chars)\n" (String.length env_key);
      env_key
    ) else raise Not_found
  with Not_found ->
    (* Then try .env file *)
    Printf.eprintf "DEBUG: Trying .env file at %s\n" (Sys.getcwd ());
    match read_env_file () with
    | Some env_vars ->
        Printf.eprintf "DEBUG: Found %d variables in .env file\n" (List.length env_vars);
        List.iter (fun (k, v) -> 
          Printf.eprintf "DEBUG: .env var: %s = %s (%d chars)\n" k (String.sub v 0 (min 10 (String.length v)) ^ "...") (String.length v)
        ) env_vars;
        (match List.assoc_opt "GEMINI_API_KEY" env_vars with
        | Some key when String.length key > 0 -> 
            Printf.eprintf "DEBUG: Using API key from .env file (%d chars)\n" (String.length key);
            key
        | Some _ -> 
            Printf.eprintf "DEBUG: Found empty API key in .env file\n";
            failwith "GEMINI_API_KEY is empty in .env file"
        | None -> 
            Printf.eprintf "DEBUG: GEMINI_API_KEY not found in .env file\n";
            failwith "GEMINI_API_KEY not found in environment variable or .env file")
    | None ->
        Printf.eprintf "DEBUG: Could not read .env file\n";
        failwith "GEMINI_API_KEY not found in environment variable or .env file"

(** Create configuration from environment *)
let load_config () =
  let api_key = get_api_key () in
  { default_config with api_key }

(** Configuration result type *)
type config_result = 
  | ConfigOk of config
  | ConfigError of string

(** Validate configuration *)
let validate_config config =
  if String.length config.api_key = 0 then
    ConfigError "API key is required"
  else if String.length config.api_key < 30 then
    ConfigError (Printf.sprintf "API key too short (got %d chars, expected ~39)" (String.length config.api_key))
  else if String.length config.api_key > 50 then
    ConfigError (Printf.sprintf "API key too long (got %d chars, expected ~39)" (String.length config.api_key))
  else if not (String.for_all (function 'A'..'Z' | 'a'..'z' | '0'..'9' | '-' | '_' -> true | _ -> false) config.api_key) then
    ConfigError "API key contains invalid characters"
  else if String.length config.api_endpoint = 0 then
    ConfigError "API endpoint is required"
  else if String.length config.model = 0 then
    ConfigError "Model name is required"
  else
    ConfigOk config

(** Load and validate configuration *)
let init_config () =
  try
    let config = load_config () in
    validate_config config
  with
  | Failure msg -> ConfigError msg
  | e -> ConfigError (Printexc.to_string e)