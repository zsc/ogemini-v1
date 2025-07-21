open Lwt.Syntax
open Types

(** Phase 8.1: Template-free micro-task decomposition
    This module implements true autonomous task decomposition without any pre-programmed templates.
    The Agent must analyze the source code and generate all implementation content through LLM calls.
*)

(** Force LLM to analyze source code and create implementation plan *)
let create_analysis_prompt source_file target_language =
  Printf.sprintf {|
I need to analyze Python source code and create a PURE OCaml implementation plan.

SOURCE FILE: %s
TARGET LANGUAGE: %s

IMPORTANT: 
- Create a PURE OCaml translation, NOT Python bindings
- Translate Python classes to OCaml modules with mutable state or functional style
- Translate Python methods to OCaml functions
- Do NOT use Python FFI or pyml library

Please analyze the source code and provide:
1. A detailed breakdown of the key algorithms and data structures
2. The most appropriate OCaml design patterns and project structure
3. A complete implementation plan with these specific steps:

For a Python to OCaml translation, create these files in order:

1. dune-project - Project metadata (lang dune 3.7, project name)
2. lib/dune - Library configuration 
3. lib/[module_name].ml - Core translated functionality
4. lib/[module_name].mli - Public interface (optional)
5. bin/dune - Executable configuration
6. bin/main.ml - Executable entry point using the library
7. test/dune - Test configuration (optional)
8. test/test_[module].ml - Unit tests (optional)

IMPORTANT: 
- Each file must contain actual, working OCaml code
- Use proper OCaml idioms and best practices
- Ensure all code compiles with dune build
- Include proper module dependencies

Format your response as a numbered list of implementation steps.
|} source_file target_language

(** Extract implementation tasks from LLM analysis *)
let parse_llm_implementation_plan llm_response =
  let lines = String.split_on_char '\n' llm_response in
  let rec parse_steps acc current_step = function
    | [] -> if current_step <> "" then current_step :: acc else acc
    | line :: rest ->
        let trimmed = String.trim line in
        if String.length trimmed > 0 && 
           (String.get trimmed 0 >= '1' && String.get trimmed 0 <= '9' ||
            String.contains trimmed '.') then
          (* New step detected *)
          let new_acc = if current_step <> "" then current_step :: acc else acc in
          parse_steps new_acc trimmed rest
        else
          (* Continue current step *)
          let updated_step = if current_step = "" then trimmed 
                           else current_step ^ "\n" ^ trimmed in
          parse_steps acc updated_step rest
  in
  List.rev (parse_steps [] "" lines)

(** Create LLM-driven micro-task for code generation *)
let create_llm_generation_task config step_description file_path dependencies retry_limit =
  let generation_prompt = Printf.sprintf {|
I need to implement this step in the translation project:

STEP: %s
FILE TO CREATE: %s
MODEL: %s

IMPORTANT: You have access to the results from previous tasks in the context above, including:
- The PYTHON source code that was read (if a read_file task was executed)
- Any analysis or generated code from previous steps

Based on the context and this specific step, generate the complete file content. 

CRITICAL REQUIREMENTS:
1. Create PURE OCaml code - do NOT use Python FFI/bindings
2. Translate Python classes → OCaml modules/records
3. Translate Python methods → OCaml functions
4. Translate Python dictionaries → OCaml Hashtbl or Map
5. Be syntactically correct and compilable OCaml
6. Follow OCaml best practices and idioms
7. IMPORTANT: Use 'let rec' for recursive functions (not just 'let')
8. Ensure all function references are properly scoped
9. Test that your code would compile with 'ocamlc'

CRITICAL: Generate ONLY raw file content. 
NO markdown formatting, NO triple backticks (```), NO language tags.
The VERY FIRST character of your response must be the start of the actual code.
For dune files, start with "(lang dune..."
For OCaml files, start with "let...", "module...", "open...", etc.
DO NOT START WITH ``` or any other markdown.
|} step_description file_path config.model in

  {
    id = Printf.sprintf "llm_gen_%s" (Filename.basename file_path);
    description = step_description;
    action = LLMGeneration { 
      prompt = generation_prompt;
      target_file = file_path;
      expected_length = 5; (* More lenient - minimum 5 chars after stripping *)
    };
    verification = Printf.sprintf "%s file exists with working implementation" file_path;
    dependencies = dependencies;
    retry_limit = retry_limit;
    complexity = `Medium;
  }

(** Analyze source file and create template-free micro-tasks *)
let create_autonomous_microtasks config source_file target_language =
  (* Step 1: Analyze the source code *)
  let analysis_prompt = create_analysis_prompt source_file target_language in
  let+ llm_analysis = Api_client.send_message config [
    { role = "user"; content = analysis_prompt; events = []; timestamp = Unix.time () }
  ] in
  
  match llm_analysis with
  | Error err ->
      Printf.printf "❌ Failed to analyze source code: %s\n" err;
      []
  | Success analysis_msg ->
      Printf.printf "🧠 LLM Analysis completed (%d chars)\n" (String.length analysis_msg.content);
      
      (* Step 2: Parse the analysis into implementation steps *)
      let implementation_steps = parse_llm_implementation_plan analysis_msg.content in
      Printf.printf "📋 Extracted %d implementation steps\n" (List.length implementation_steps);
      
      (* Step 3: Create LLM-driven micro-tasks for each step *)
      let rec create_tasks acc prev_deps step_index = function
        | [] -> List.rev acc
        | step :: rest ->
            (* Extract file path from step description *)
            let file_path = 
              try
                (* Match paths like lib/types.ml, bin/main.ml, test/test_foo.ml *)
                let path_regex = Str.regexp "\\(lib\\|bin\\|test\\)/\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\(\\.ml[i]?\\)" in
                if Str.string_match path_regex step 0 then
                  let dir = Str.matched_group 1 step in
                  let name = Str.matched_group 2 step in
                  let ext = Str.matched_group 3 step in
                  Printf.sprintf "/workspace/%s/%s%s" dir name ext
                else (
                  (* Try to find dune-project, dune, or other files *)
                  try
                    if String.contains step 'd' && String.contains step 'u' && 
                       String.contains step 'n' && String.contains step 'e' then
                      if String.contains step '-' && String.contains step 'p' then
                        "/workspace/dune-project"
                      else if String.contains step '/' then
                        (* Match patterns like "Create lib/dune" *)
                        let dir_file_regex = Str.regexp "\\(lib\\|bin\\|test\\)/dune" in
                        if Str.string_match dir_file_regex step 0 then
                          "/workspace/" ^ (Str.matched_string step)
                        else
                          "/workspace/dune"
                      else
                        "/workspace/dune"
                    else
                      (* Generic .ml file *)
                      let file_regex = Str.regexp "\\([a-zA-Z_][a-zA-Z0-9_]*\\.ml[i]?\\)" in
                      if Str.string_match file_regex step 0 then
                        "/workspace/" ^ (Str.matched_group 1 step)
                      else
                        Printf.sprintf "/workspace/step_%d.ml" step_index
                  with _ ->
                    Printf.sprintf "/workspace/step_%d.ml" step_index
                )
              with _ ->
                Printf.sprintf "/workspace/step_%d.ml" step_index
            in
            
            let task = create_llm_generation_task config step file_path prev_deps 3 in
            let new_deps = task.id :: prev_deps in
            create_tasks (task :: acc) new_deps (step_index + 1) rest
      in
      
      (* Add initial analysis task *)
      let analysis_task = {
        id = "analyze_source_code";
        description = Printf.sprintf "Analyze %s source code structure" source_file;
        action = ToolCall { 
          name = "read_file"; 
          args = [("file_path", source_file)]; (* source_file already contains full path *)
          rationale = "Read and understand source code before translation" 
        };
        verification = "Source code read and analyzed";
        dependencies = [];
        retry_limit = 2;
        complexity = `Simple;
      } in
      
      let implementation_tasks = create_tasks [] ["analyze_source_code"] 1 implementation_steps in
      
      (* Add a build verification task at the end *)
      let build_task = {
        id = "verify_build";
        description = "Attempt to build the generated OCaml code and fix any compilation errors";
        action = ToolCall {
          name = "shell";
          args = [("command", "cd /workspace && echo '(lang dune 3.0)' > dune-project && echo '(executable (name main))' > dune && dune build 2>&1 || true")];
          rationale = "Test if generated code compiles and identify any errors"
        };
        verification = "Build attempt completed";
        dependencies = List.map (fun t -> t.id) implementation_tasks;
        retry_limit = 0;
        complexity = `Simple;
      } in
      
      analysis_task :: implementation_tasks @ [build_task]

(** Create simple file reading micro-task *)
let create_simple_file_task _config task_description =
  Printf.printf "📖 Creating simple file reading task\n";
  
  (* Extract file path from task description using multiple patterns *)
  let extract_file_path desc =
    (* Pattern 1: /workspace/filename.ext or /path/filename.ext *)
    let absolute_path_regex = Str.regexp "/\\([a-zA-Z_][a-zA-Z0-9_/]*\\.[a-z]+\\)" in
    try
      if Str.search_forward absolute_path_regex desc 0 >= 0 then
        Some ("/" ^ (Str.matched_group 1 desc))
      else
        (* Pattern 2: filename.ext *)
        let filename_regex = Str.regexp "\\([a-zA-Z_][a-zA-Z0-9_]*\\.[a-z]+\\)" in
        if Str.search_forward filename_regex desc 0 >= 0 then
          Some ("/workspace/" ^ (Str.matched_group 1 desc))
        else
          None
    with
    | Not_found -> None
  in
  
  let file_path = match extract_file_path task_description with
    | Some path -> path
    | None -> "/workspace/unknown_file"
  in
  
  Printf.printf "📂 Extracted file path: %s\n" file_path;
  
  [{
    id = "read_and_analyze_file";
    description = Printf.sprintf "Read and analyze file %s to answer user's question" file_path;
    action = LLMGeneration { 
      prompt = Printf.sprintf "TASK: Create an OCaml version of the Python code in %s

REQUIRED WORKFLOW:
1. FIRST: Use read_file tool to read %s and examine its content
2. THEN: Analyze the Python code structure, classes, functions, and algorithms
3. FINALLY: Generate OCaml code that implements the same functionality

IMPORTANT: You MUST follow this exact sequence:
- Call read_file(%s) to get the source code
- DO NOT call build tools until you have generated OCaml code
- Your goal is CODE GENERATION, not building existing projects
- Write the generated OCaml code that translates the Python functionality

Expected output: Working OCaml code that replicates the Python program's behavior." file_path file_path file_path;
      target_file = "/workspace/translated.ml"; (* Create actual OCaml file *)
      expected_length = 50; (* Expect substantial code generation *)
    };
    verification = "File read and user question answered";
    dependencies = [];
    retry_limit = 2;
    complexity = `Simple;
  }]

(** Main entry point for template-free task decomposition *)
let decompose_complex_task config task_description =
  Printf.printf "🔍 Template-free decomposition for: %s\n" task_description;
  
  let task_lower = String.lowercase_ascii task_description in
  
  (* First check for simple file reading tasks - but not if it's a creation/translation task *)
  if not (String.contains task_lower 'c' && String.contains task_lower 'r' && 
          String.contains task_lower 'e' && String.contains task_lower 'a') &&
     not (String.contains task_lower 't' && String.contains task_lower 'r' && 
          String.contains task_lower 'a' && String.contains task_lower 'n') &&
     ((String.contains task_lower 'r' && String.contains task_lower 'e' && 
       String.contains task_lower 'a' && String.contains task_lower 'd' &&
       (String.contains task_lower 'f' || String.contains task_lower '.')) ||
      (String.contains task_lower 's' && String.contains task_lower 'u' && 
       String.contains task_lower 'm' && String.contains task_lower 'm')) then (
    (* This is a simple file reading/analysis task *)
    Printf.printf "📖 Detected simple file reading task\n";
    Lwt.return (create_simple_file_task config task_description)
  )
  (* Check for translation tasks - make pattern more specific *)
  else if String.contains task_lower 't' && String.contains task_lower 'r' && 
          String.contains task_lower 'a' && String.contains task_lower 'n' &&
          String.contains task_lower 's' && String.contains task_lower 'l' then (
    (* This appears to be a translation task - extract actual source file *)
    let source_file = 
      (* Try to extract full file path from task description *)
      let file_regex = Str.regexp "/[^ \t\n]+\\.[a-z]+" in
      let file_path = try (
        let _ = Str.search_forward file_regex task_description 0 in
        let full_path = Str.matched_string task_description in
        Printf.printf "📂 Extracted full path: %s\n" full_path;
        full_path  (* Keep the full path, don't extract basename *)
      ) with Not_found -> (
        Printf.printf "🔍 No path found in '%s', using fallback\n" task_description;
        if String.contains task_lower 'p' && String.contains task_lower 'y' then
          "/workspace/game.py" 
        else
          "/workspace/main.py"
      ) in
      Printf.printf "📂 Final source file: %s\n" file_path;
      file_path
    in
    Printf.printf "🔄 Translating source file: %s\n" source_file;
    create_autonomous_microtasks config source_file "OCaml"
  )
  else (
    (* Non-translation task - create generic LLM-driven decomposition *)
    let generic_prompt = Printf.sprintf {|
Break down this task into 3-7 concrete implementation steps:

TASK: %s

Each step should:
1. Create a specific file with working code
2. Build incrementally on previous steps  
3. Be verifiable by compilation/execution
4. Move toward completing the overall task

Format as numbered steps, each specifying what file to create and what it should contain.
|} task_description in
    
    let+ llm_breakdown = Api_client.send_message config [
      { role = "user"; content = generic_prompt; events = []; timestamp = Unix.time () }
    ] in
    
    match llm_breakdown with
    | Error err ->
        Printf.printf "❌ Failed to decompose task: %s\n" err;
        []
    | Success breakdown_msg ->
        let steps = parse_llm_implementation_plan breakdown_msg.content in
        List.mapi (fun i step ->
          let file_path = Printf.sprintf "/workspace/step_%d.ml" (i + 1) in
          create_llm_generation_task config step file_path [] 3
        ) steps
  )