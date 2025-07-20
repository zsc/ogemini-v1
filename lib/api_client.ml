open Lwt.Syntax
open Types

(** Build JSON request for Gemini API *)
let build_request_json text =
  `Assoc [
    ("contents", `List [
      `Assoc [
        ("parts", `List [
          `Assoc [("text", `String text)]
        ])
      ]
    ])
  ]

(** Send HTTP request to Gemini API *)
let send_http_request config json_body =
  let uri = Printf.sprintf "%s/%s:generateContent" config.api_endpoint config.model in
  
  let body_string = Yojson.Safe.to_string json_body in
  Printf.printf "🌐 Calling Gemini API: %s\n" config.model;
  Printf.printf "📤 Request: %s\n" (String.sub body_string 0 (min 100 (String.length body_string)));
  
  (* Simple synchronous HTTP call - will be replaced with Cohttp later *)
  let cmd = Printf.sprintf 
    {|curl -s "%s" -H "x-goog-api-key: %s" -H "Content-Type: application/json" -X POST --data-raw '%s'|}
    uri config.api_key body_string in
  
  let* result = Lwt_process.pread ("sh", [| "sh"; "-c"; cmd |]) in
  Lwt.return result

(** Parse Gemini API response *)
let parse_api_response response_text =
  try
    let json = Yojson.Safe.from_string response_text in
    match json with
    | `Assoc fields ->
        (match List.assoc_opt "candidates" fields with
        | Some (`List [candidate]) ->
            (match candidate with
            | `Assoc candidate_fields ->
                (match List.assoc_opt "content" candidate_fields with
                | Some (`Assoc content_fields) ->
                    (match List.assoc_opt "parts" content_fields with
                    | Some (`List parts) ->
                        let texts = List.filter_map (function
                          | `Assoc part_fields ->
                              (match List.assoc_opt "text" part_fields with
                              | Some (`String text) -> Some text
                              | _ -> None)
                          | _ -> None
                        ) parts in
                        String.concat "\n" texts
                    | _ -> "Error: No parts in response")
                | _ -> "Error: No content in response")
            | _ -> "Error: Invalid candidate format")
        | _ -> "Error: No candidates in response")
    | _ -> "Error: Invalid JSON response format"
  with
  | Yojson.Json_error msg -> Printf.sprintf "JSON parse error: %s" msg
  | e -> Printf.sprintf "Parse error: %s" (Printexc.to_string e)

(** Send message to Gemini API *)
let send_message config conversation =
  (* For MVP, just send the last user message *)
  let last_message = match List.rev conversation with
    | msg :: _ when msg.role = "user" -> msg.content
    | _ -> "Hello"
  in
  
  let json_body = build_request_json last_message in
  let* response_text = send_http_request config json_body in
  
  Printf.printf "📥 Response: %s\n" (String.sub response_text 0 (min 200 (String.length response_text)));
  
  let content = parse_api_response response_text in
  let events = Event_parser.parse_response content in
  let message = Event_parser.create_message "assistant" content events in
  
  Lwt.return (Success message)