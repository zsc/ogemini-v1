open Lwt.Syntax
open Types

(** Simple heuristic to detect if tools are needed *)
let needs_tools text =
  let text_lower = String.lowercase_ascii text in
  let tool_keywords = [
    "file"; "read"; "write"; "create"; "build"; "dune"; "shell"; "run"; 
    "execute"; "compile"; "test"; "directory"; "folder"; "project"
  ] in
  List.exists (fun keyword -> 
    String.length text_lower >= String.length keyword &&
    try 
      ignore (Str.search_forward (Str.regexp keyword) text_lower 0); 
      true 
    with Not_found -> false
  ) tool_keywords

(** Build JSON request for Gemini API with optional tool support *)
let build_request_json text config =
  let base_content = [
    ("contents", `List [
      `Assoc [
        ("parts", `List [
          `Assoc [("text", `String text)]
        ])
      ]
    ])
  ] in
  
  let base_request = 
    if needs_tools text then
      (* Add tool declarations for complex tasks *)
      base_content @ [
      ("tools", `List [
      `Assoc [
        ("function_declarations", `List [
          (* Read file tool *)
          `Assoc [
            ("name", `String "read_file");
            ("description", `String "Reads and returns the content of a specified file from the local filesystem. Always use absolute paths.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("file_path", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The absolute path to the file to read")
                ])
              ]);
              ("required", `List [`String "file_path"])
            ])
          ];
          (* Write file tool *)
          `Assoc [
            ("name", `String "write_file");
            ("description", `String "Writes content to a specified file. Creates directories if needed. Always use absolute paths.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("file_path", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The absolute path to the file to write")
                ]);
                ("content", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The content to write to the file")
                ])
              ]);
              ("required", `List [`String "file_path"; `String "content"])
            ])
          ];
          (* List files tool *)
          `Assoc [
            ("name", `String "list_files");
            ("description", `String "Lists files and directories in the specified directory. Shows directories with trailing '/'.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("dir_path", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The directory path to list (defaults to current directory if empty)")
                ])
              ]);
              ("required", `List [])
            ])
          ];
          (* Shell command tool *)
          `Assoc [
            ("name", `String "shell");
            ("description", `String "Execute safe shell commands. Only whitelisted commands are allowed (ls, cat, git, dune, etc). Dangerous commands like rm, sudo are blocked.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("command", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The shell command to execute (must be from safe whitelist)")
                ])
              ]);
              ("required", `List [`String "command"])
            ])
          ];
          (* Dune build tool *)
          `Assoc [
            ("name", `String "dune_build");
            ("description", `String "Build OCaml projects using dune. Can specify optional target.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("target", `Assoc [
                  ("type", `String "string");
                  ("description", `String "Optional build target (e.g., './bin/main.exe')")
                ])
              ]);
              ("required", `List [])
            ])
          ];
          (* Dune test tool *)
          `Assoc [
            ("name", `String "dune_test");
            ("description", `String "Run tests using dune. Can specify optional target.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("target", `Assoc [
                  ("type", `String "string");
                  ("description", `String "Optional test target")
                ])
              ]);
              ("required", `List [])
            ])
          ];
          (* Dune clean tool *)
          `Assoc [
            ("name", `String "dune_clean");
            ("description", `String "Clean build artifacts using dune clean. This removes all compiled files.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc []);
              ("required", `List [])
            ])
          ];
          (* Edit file tool *)
          `Assoc [
            ("name", `String "edit_file");
            ("description", `String "Replace specific text in a file with new text. Requires exact string matching. Use for precise text replacement and refactoring.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("file_path", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The absolute path to the file to edit")
                ]);
                ("old_string", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The exact text to find and replace (must match exactly)")
                ]);
                ("new_string", `Assoc [
                  ("type", `String "string");
                  ("description", `String "The text to replace the old_string with")
                ]);
                ("expected_replacements", `Assoc [
                  ("type", `String "integer");
                  ("description", `String "Optional: Number of replacements expected (defaults to 1)")
                ])
              ]);
              ("required", `List [`String "file_path"; `String "old_string"; `String "new_string"])
            ])
          ];
          (* Search files tool *)
          `Assoc [
            ("name", `String "search_files");
            ("description", `String "Search for text patterns in files using regular expressions. Returns matching lines with file paths and line numbers.");
            ("parameters", `Assoc [
              ("type", `String "object");
              ("properties", `Assoc [
                ("pattern", `Assoc [
                  ("type", `String "string");
                  ("description", `String "Regular expression pattern to search for")
                ]);
                ("path", `Assoc [
                  ("type", `String "string");
                  ("description", `String "Directory path to search in (defaults to current directory)")
                ]);
                ("file_pattern", `Assoc [
                  ("type", `String "string");
                  ("description", `String "Optional: File pattern to filter search (e.g., '*.ml', '*.{ts,tsx}')")
                ])
              ]);
              ("required", `List [`String "pattern"])
            ])
          ]
        ])
      ]
    ])]
    else
      (* Simple request without tools for basic Q&A *)
      base_content
  in
  
  if config.enable_thinking then
    let generation_config = ("generationConfig", `Assoc [
      ("thinkingConfig", `Assoc [
        ("thinkingBudget", `Int 20000)  (* Enable thinking with budget *)
      ])
    ]) in
    `Assoc (base_request @ [generation_config])
  else
    `Assoc base_request

(** Send HTTP request to Gemini API *)
let send_http_request config json_body =
  let uri = Printf.sprintf "%s/%s:generateContent" config.api_endpoint config.model in
  
  let body_string = Yojson.Safe.to_string json_body in
  Printf.printf "🌐 Calling Gemini API: %s\n" config.model;
  Printf.printf "📤 Request: %s\n" (String.sub body_string 0 (min 100 (String.length body_string)));
  
  (* Simple synchronous HTTP call - will be replaced with Cohttp later *)
  (* Use temporary file to avoid shell escaping issues with JSON *)
  let temp_file = Filename.temp_file "ogemini_request" ".json" in
  let* () = Lwt_io.with_file ~mode:Lwt_io.Output temp_file (fun oc -> 
    Lwt_io.write oc body_string) in
  let cmd = Printf.sprintf 
    {|curl -s "%s" -H "x-goog-api-key: %s" -H "Content-Type: application/json" -X POST --data-binary @%s|}
    uri config.api_key temp_file in
  
  let* result = Lwt_process.pread ("sh", [| "sh"; "-c"; cmd |]) in
  (* Clean up temp file *)
  (try Sys.remove temp_file with _ -> ());
  Lwt.return result

(** Parse tool calls from Gemini API response *)
let parse_tool_calls json =
  let extract_tool_calls parts =
    List.filter_map (function
      | `Assoc part_fields ->
          (match List.assoc_opt "functionCall" part_fields with
          | Some (`Assoc func_fields) ->
              let name = match List.assoc_opt "name" func_fields with
                | Some (`String n) -> n
                | _ -> ""
              in
              let args = match List.assoc_opt "args" func_fields with
                | Some (`Assoc arg_fields) ->
                    List.filter_map (function
                      | (key, `String value) -> Some (key, value)
                      | _ -> None
                    ) arg_fields
                | _ -> []
              in
              if name <> "" then
                Some { 
                  id = "tool_" ^ string_of_int (Random.int 1000); 
                  name; 
                  args 
                }
              else None
          | _ -> None)
      | _ -> None
    ) parts
  in
  
  match json with
  | `Assoc fields ->
      (match List.assoc_opt "candidates" fields with
      | Some (`List [candidate]) ->
          (match candidate with
          | `Assoc candidate_fields ->
              (match List.assoc_opt "content" candidate_fields with
              | Some (`Assoc content_fields) ->
                  (match List.assoc_opt "parts" content_fields with
                  | Some (`List parts) -> extract_tool_calls parts
                  | _ -> [])
              | _ -> [])
          | _ -> [])
      | _ -> [])
  | _ -> []

(** Parse Gemini API response with thinking and tool support *)
let parse_api_response response_text =
  try
    let json = Yojson.Safe.from_string response_text in
    match json with
    | `Assoc fields ->
        (match List.assoc_opt "candidates" fields with
        | Some (`List [candidate]) ->
            (match candidate with
            | `Assoc candidate_fields ->
                (* Extract thinking parts if present *)
                let thinking_text = 
                  match List.assoc_opt "thinking" candidate_fields with
                  | Some (`Assoc thinking_fields) ->
                      (match List.assoc_opt "parts" thinking_fields with
                      | Some (`List thinking_parts) ->
                          let thinking_texts = List.filter_map (function
                            | `Assoc part_fields ->
                                (match List.assoc_opt "text" part_fields with
                                | Some (`String text) -> Some text
                                | _ -> None)
                            | _ -> None
                          ) thinking_parts in
                          Some (String.concat "\n" thinking_texts)
                      | _ -> None)
                  | _ -> None
                in
                
                (* Check for tool calls *)
                let tool_calls = parse_tool_calls json in
                
                (* Extract main content *)
                let content_text =
                  match List.assoc_opt "content" candidate_fields with
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
                      | _ -> 
                          if List.length tool_calls > 0 then
                            (* If we have tool calls but no text, return empty string *)
                            ""
                          else "Error: No parts in content")
                  | _ -> 
                      if List.length tool_calls > 0 then ""
                      else "Error: No content in response"
                in
                
                (* Combine thinking, content, and tool calls *)
                let full_content = match thinking_text with
                  | Some thinking -> thinking ^ "\n---\n" ^ content_text
                  | None -> content_text
                in
                
                (* Return tool calls info if present *)
                (full_content, tool_calls)
                
            | _ -> ("Error: Invalid candidate format", []))
        | _ -> ("Error: No candidates in response", []))
    | _ -> ("Error: Invalid JSON response format", [])
  with
  | Yojson.Json_error msg -> (Printf.sprintf "JSON parse error: %s" msg, [])
  | e -> (Printf.sprintf "Parse error: %s" (Printexc.to_string e), [])

(** Send message to Gemini API *)
let send_message config conversation =
  (* For MVP, just send the last user message *)
  let last_message = match List.rev conversation with
    | msg :: _ when msg.role = "user" -> msg.content
    | _ -> "Hello"
  in
  
  let json_body = build_request_json last_message config in
  let* response_text = send_http_request config json_body in
  
  Printf.printf "📥 Full Response: %s\n" response_text;
  
  let (content, tool_calls) = parse_api_response response_text in
  
  (* Create events from content and tool calls *)
  let content_events = Event_parser.parse_response content in
  let tool_events = List.map (fun tc -> ToolCallRequest tc) tool_calls in
  let all_events = content_events @ tool_events in
  
  let message = Event_parser.create_message "assistant" content all_events in
  
  Lwt.return (Success message)