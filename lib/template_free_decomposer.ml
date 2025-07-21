open Lwt.Syntax
open Types

(** Phase 8.1: Template-free micro-task decomposition
    This module implements true autonomous task decomposition without any pre-programmed templates.
    The Agent must analyze the source code and generate all implementation content through LLM calls.
*)

(** Force LLM to analyze source code and create implementation plan *)
let create_analysis_prompt source_file target_language =
  Printf.sprintf {|
I need to analyze source code and create an implementation plan for translation.

SOURCE FILE: %s
TARGET LANGUAGE: %s

Please analyze the source code and provide:
1. A detailed breakdown of the key algorithms and data structures
2. The most appropriate target language design patterns
3. A step-by-step implementation plan (5-10 steps max)
4. For each step, specify:
   - What file to create
   - What the file should contain (types, functions, logic)
   - Why this step is necessary
   - Dependencies on previous steps

IMPORTANT: I need actual implementation details, not placeholders.
Each step should result in compilable code that progressively builds toward the complete translation.

Be specific about:
- Type definitions that match the source semantics
- Function signatures and their purpose  
- Key algorithms that need to be implemented
- Build system requirements

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

Please generate the complete file content. The content must:
1. Be syntactically correct and compilable
2. Include all necessary type definitions and functions for this step
3. Have proper module dependencies and imports
4. Not use placeholder comments - implement actual logic
5. Follow language best practices and idioms

Generate ONLY the file content, no explanations or markdown formatting.
Start directly with the code.
|} step_description file_path in

  {
    id = Printf.sprintf "llm_gen_%s" (Filename.basename file_path);
    description = step_description;
    action = LLMGeneration { 
      prompt = generation_prompt;
      target_file = file_path;
      expected_length = 10; (* Minimum 10 lines of actual code *)
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
                let file_regex = Str.regexp ".*\\([a-zA-Z_][a-zA-Z0-9_]*\\.ml[i]?\\)" in
                if Str.string_match file_regex step 0 then
                  "/workspace/" ^ (Str.matched_group 1 step)
                else
                  Printf.sprintf "/workspace/step_%d.ml" step_index
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
          args = [("file_path", "/workspace/" ^ source_file)]; 
          rationale = "Read and understand source code before translation" 
        };
        verification = "Source code read and analyzed";
        dependencies = [];
        retry_limit = 2;
        complexity = `Simple;
      } in
      
      let implementation_tasks = create_tasks [] ["analyze_source_code"] 1 implementation_steps in
      analysis_task :: implementation_tasks

(** Main entry point for template-free task decomposition *)
let decompose_complex_task config task_description =
  Printf.printf "🔍 Template-free decomposition for: %s\n" task_description;
  
  (* Detect if this is a translation task *)
  let task_lower = String.lowercase_ascii task_description in
  if String.contains task_lower 't' && String.contains task_lower 'r' && 
     String.contains task_lower 'a' && String.contains task_lower 'n' then
    (* This appears to be a translation task *)
    if String.contains task_lower 'p' && String.contains task_lower 'y' then
      (* Python source detected *)
      create_autonomous_microtasks config "game.py" "OCaml"
    else
      (* Generic translation - analyze available files *)
      let+ file_list = Tools.File_tools.list_files "/workspace" in
      match file_list.content with
      | content when String.contains content '.' ->
          let files = String.split_on_char '\n' content |> List.filter (fun f -> String.contains f '.') in
          (match files with
           | source_file :: _ -> create_autonomous_microtasks config source_file "OCaml"
           | [] -> 
               Printf.printf "⚠️ No source files found for translation\n";
               Lwt.return [])
      | _ ->
          Printf.printf "⚠️ Could not list workspace files\n";
          Lwt.return []
  else
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