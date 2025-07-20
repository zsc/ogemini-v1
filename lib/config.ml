open Types

(** Default configuration values *)
let default_config = {
  api_key = "";
  api_endpoint = "https://generativelanguage.googleapis.com/v1beta/models";
  model = "gemini-2.5-flash";
  enable_thinking = false;
}

(** Load API key from environment variable *)
let get_api_key () =
  try
    Sys.getenv "GEMINI_API_KEY"
  with Not_found ->
    failwith "GEMINI_API_KEY environment variable not set"

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