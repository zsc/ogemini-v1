open Lwt.Syntax
open Types

(** Phase 7.2: Micro-task decomposition for complex task reliability *)

(** Complex task templates for common scenarios *)
type task_template = 
  | OCamlProjectCreation of { name: string; project_type: [`Executable | `Library | `Game] }
  | AlgorithmTranslation of { source_lang: string; target_lang: string; algorithm_name: string }
  | BuildAndTest of { project_path: string }

(** Create micro-tasks for OCaml project creation *)
let create_ocaml_project_microtasks name project_type =
  let base_tasks = [
    {
      id = "setup_workspace";
      description = "List and analyze current workspace structure";
      action = ToolCall { 
        name = "list_files"; 
        args = [("dir_path", "/workspace")]; 
        rationale = "Understand current workspace state" 
      };
      verification = "Directory listing shows clean workspace";
      dependencies = [];
      retry_limit = 2;
      complexity = `Simple;
    };
    {
      id = "create_dune_project";
      description = Printf.sprintf "Create dune-project file for %s" name;
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/dune-project");
          ("content", Printf.sprintf "(lang dune 3.0)\n\n(name %s)\n\n(package\n (name %s)\n (depends ocaml dune))" name name)
        ]; 
        rationale = "Establish project configuration" 
      };
      verification = "dune-project file exists with correct content";
      dependencies = ["setup_workspace"];
      retry_limit = 3;
      complexity = `Simple;
    };
  ] in
  
  let project_specific_tasks = match project_type with
    | `Executable -> [
        {
          id = "create_main_ml";
          description = Printf.sprintf "Create main.ml for %s executable" name;
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/main.ml");
              ("content", "(* Main executable for " ^ name ^ " *)\n\nlet () =\n  print_endline \"Hello from " ^ name ^ "!\"")
            ]; 
            rationale = "Create executable entry point" 
          };
          verification = "main.ml file exists with valid OCaml syntax";
          dependencies = ["create_dune_project"];
          retry_limit = 3;
          complexity = `Simple;
        };
        {
          id = "create_executable_dune";
          description = "Create dune file for executable";
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/dune");
              ("content", Printf.sprintf "(executable\n (public_name %s)\n (name main))" name)
            ]; 
            rationale = "Configure executable build" 
          };
          verification = "dune file exists with executable configuration";
          dependencies = ["create_main_ml"];
          retry_limit = 3;
          complexity = `Simple;
        };
      ]
    | `Library -> [
        {
          id = "create_lib_ml";
          description = Printf.sprintf "Create %s.ml library module" name;
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", Printf.sprintf "/workspace/%s.ml" name);
              ("content", Printf.sprintf "(* %s library module *)\n\nlet hello () =\n  Printf.printf \"Hello from %s library!\\n\"" name name)
            ]; 
            rationale = "Create library module" 
          };
          verification = Printf.sprintf "%s.ml file exists with valid OCaml syntax" name;
          dependencies = ["create_dune_project"];
          retry_limit = 3;
          complexity = `Simple;
        };
        {
          id = "create_library_dune";
          description = "Create dune file for library";
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/dune");
              ("content", Printf.sprintf "(library\n (public_name %s)\n (name %s))" name name)
            ]; 
            rationale = "Configure library build" 
          };
          verification = "dune file exists with library configuration";
          dependencies = ["create_lib_ml"];
          retry_limit = 3;
          complexity = `Simple;
        };
      ]
    | `Game -> [
        {
          id = "create_game_types";
          description = "Create game type definitions";
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/types.ml");
              ("content", "(* Game type definitions *)\n\ntype game_state = {\n  score: int;\n  board: int array array;\n  game_over: bool;\n}\n\ntype direction = Up | Down | Left | Right")
            ]; 
            rationale = "Define core game data structures" 
          };
          verification = "types.ml file exists with game type definitions";
          dependencies = ["create_dune_project"];
          retry_limit = 3;
          complexity = `Medium;
        };
        {
          id = "create_game_logic";
          description = "Create basic game logic module";
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/game.ml");
              ("content", "(* Game logic module *)\nopen Types\n\nlet create_game () =\n  { score = 0; board = Array.make_matrix 4 4 0; game_over = false }\n\nlet print_game game =\n  Printf.printf \"Score: %d\\n\" game.score")
            ]; 
            rationale = "Implement core game functionality" 
          };
          verification = "game.ml file exists with basic game functions";
          dependencies = ["create_game_types"];
          retry_limit = 3;
          complexity = `Medium;
        };
        {
          id = "create_main_game";
          description = "Create main game executable";
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/main.ml");
              ("content", "(* Main game executable *)\nopen Game\n\nlet () =\n  let game = create_game () in\n  print_game game;\n  print_endline \"Game started!\"")
            ]; 
            rationale = "Create game entry point" 
          };
          verification = "main.ml file exists with game initialization";
          dependencies = ["create_game_logic"];
          retry_limit = 3;
          complexity = `Simple;
        };
        {
          id = "create_game_dune";
          description = "Create dune file for game";
          action = ToolCall { 
            name = "write_file"; 
            args = [
              ("file_path", "/workspace/dune");
              ("content", Printf.sprintf "(executable\n (public_name %s)\n (name main)\n (modules main game types))" name)
            ]; 
            rationale = "Configure game build with all modules" 
          };
          verification = "dune file exists with all game modules";
          dependencies = ["create_main_game"];
          retry_limit = 3;
          complexity = `Simple;
        };
      ]
  in
  
  let build_tasks = [
    {
      id = "verify_build";
      description = "Build project and verify compilation";
      action = ToolCall { 
        name = "dune_build"; 
        args = []; 
        rationale = "Verify project compiles successfully" 
      };
      verification = "Project builds without errors";
      dependencies = (match project_type with
        | `Executable -> ["create_executable_dune"]
        | `Library -> ["create_library_dune"] 
        | `Game -> ["create_game_dune"]);
      retry_limit = 2;
      complexity = `Medium;
    };
  ] in
  
  base_tasks @ project_specific_tasks @ build_tasks

(** Create micro-tasks for OCaml 2048 translation *)
let create_ocaml_2048_microtasks () =
  [
    {
      id = "analyze_python_source";
      description = "Read and analyze Python 2048 source code";
      action = ToolCall { 
        name = "read_file"; 
        args = [("file_path", "/workspace/game.py")]; 
        rationale = "Understand source algorithm structure" 
      };
      verification = "Python source code read and understood";
      dependencies = [];
      retry_limit = 2;
      complexity = `Simple;
    };
    {
      id = "create_board_types";
      description = "Create OCaml type definitions for game board";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/board.ml");
          ("content", "(* Board representation for 2048 game *)\n\n(* Use 64-bit integer for bit-level board representation *)\ntype board = int64\n\n(* Individual tile values (0 = empty, 1 = tile with value 2, 2 = tile with value 4, etc.) *)\ntype tile = int\n\n(* Direction for moves *)\ntype direction = Up | Down | Left | Right")
        ]; 
        rationale = "Define core data structures matching Python logic" 
      };
      verification = "board.ml file exists with type definitions";
      dependencies = ["analyze_python_source"];
      retry_limit = 3;
      complexity = `Simple;
    };
    {
      id = "implement_tile_operations";
      description = "Implement basic tile get/set operations";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/tile_ops.ml");
          ("content", "(* Tile operations for bit-level board manipulation *)\nopen Board\n\n(* Get tile value at position (0-15) *)\nlet get_tile (board : board) (pos : int) : tile =\n  Int64.to_int (Int64.logand (Int64.shift_right board (4 * pos)) 0xFL)\n\n(* Set tile value at position *)\nlet set_tile (board : board) (pos : int) (value : tile) : board =\n  let mask = Int64.shift_left 0xFL (4 * pos) in\n  let cleared = Int64.logand board (Int64.lognot mask) in\n  let new_val = Int64.shift_left (Int64.of_int value) (4 * pos) in\n  Int64.logor cleared new_val")
        ]; 
        rationale = "Implement atomic tile operations" 
      };
      verification = "tile_ops.ml file exists with get/set functions";
      dependencies = ["create_board_types"];
      retry_limit = 3;
      complexity = `Medium;
    };
    {
      id = "implement_row_operations";
      description = "Implement single row move and merge logic";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/row_ops.ml");
          ("content", "(* Row operations for 2048 game moves *)\nopen Board\nopen Tile_ops\n\n(* Convert 16-bit row to list of tiles *)\nlet row_to_list (row : int) : tile list =\n  [get_tile (Int64.of_int row) 0; get_tile (Int64.of_int row) 1; \n   get_tile (Int64.of_int row) 2; get_tile (Int64.of_int row) 3]\n\n(* Move row left and return (new_row, score_gained) *)\nlet move_row_left (row : tile list) : tile list * int =\n  let rec compress acc = function\n    | [] -> List.rev acc\n    | 0 :: rest -> compress acc rest\n    | x :: rest -> compress (x :: acc) rest\n  in\n  let compressed = compress [] row in\n  (* Placeholder - implement merge logic *)\n  (compressed @ [0; 0; 0; 0] |> List.take 4, 0)")
        ]; 
        rationale = "Implement core move logic for single row" 
      };
      verification = "row_ops.ml file exists with row movement functions";
      dependencies = ["implement_tile_operations"];
      retry_limit = 3;
      complexity = `Complex;
    };
    {
      id = "create_game_module";
      description = "Create main game module with move functions";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/game2048.ml");
          ("content", "(* Main 2048 game module *)\nopen Board\nopen Tile_ops\nopen Row_ops\n\n(* Initialize empty board *)\nlet empty_board : board = 0L\n\n(* Add random tile to board *)\nlet add_random_tile (board : board) : board =\n  (* Placeholder - implement random tile placement *)\n  board\n\n(* Move board in given direction *)\nlet move_board (board : board) (dir : direction) : board * int =\n  (* Placeholder - implement full board moves *)\n  (board, 0)")
        ]; 
        rationale = "Create main game interface" 
      };
      verification = "game2048.ml file exists with game functions";
      dependencies = ["implement_row_operations"];
      retry_limit = 3;
      complexity = `Medium;
    };
    {
      id = "create_main_executable";
      description = "Create main.ml executable for the game";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/main.ml");
          ("content", "(* OCaml 2048 Game *)\nopen Game2048\n\nlet () =\n  print_endline \"OCaml 2048 Game\";\n  let board = empty_board in\n  Printf.printf \"Initial board: %Ld\\n\" board;\n  print_endline \"Game initialized successfully!\"")
        ]; 
        rationale = "Create executable entry point" 
      };
      verification = "main.ml file exists with game initialization";
      dependencies = ["create_game_module"];
      retry_limit = 3;
      complexity = `Simple;
    };
    {
      id = "create_build_config";
      description = "Create dune configuration files";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/dune-project");
          ("content", "(lang dune 3.0)\n\n(name ocaml_2048)\n\n(package\n (name ocaml_2048)\n (depends ocaml dune))")
        ]; 
        rationale = "Configure project build system" 
      };
      verification = "dune-project file exists";
      dependencies = ["create_main_executable"];
      retry_limit = 3;
      complexity = `Simple;
    };
    {
      id = "create_executable_dune";
      description = "Create dune file for executable";
      action = ToolCall { 
        name = "write_file"; 
        args = [
          ("file_path", "/workspace/dune");
          ("content", "(executable\n (public_name ocaml_2048)\n (name main)\n (modules main game2048 row_ops tile_ops board))")
        ]; 
        rationale = "Configure executable with all modules" 
      };
      verification = "dune file exists with all modules";
      dependencies = ["create_build_config"];
      retry_limit = 3;
      complexity = `Simple;
    };
    {
      id = "verify_compilation";
      description = "Build and verify the project compiles";
      action = ToolCall { 
        name = "dune_build"; 
        args = []; 
        rationale = "Ensure project compiles successfully" 
      };
      verification = "Project builds without compilation errors";
      dependencies = ["create_executable_dune"];
      retry_limit = 2;
      complexity = `Medium;
    };
    {
      id = "test_execution";
      description = "Run the compiled game to verify it works";
      action = ToolCall { 
        name = "shell"; 
        args = [("command", "cd /workspace && ./_build/default/main.exe")]; 
        rationale = "Verify game executable runs successfully" 
      };
      verification = "Game runs and produces expected output";
      dependencies = ["verify_compilation"];
      retry_limit = 2;
      complexity = `Simple;
    };
  ]

(** Check if a task is ready to execute (all dependencies completed) *)
let is_task_ready completed_tasks task =
  List.for_all (fun dep_id ->
    List.exists (fun result -> result.task_id = dep_id && result.success) completed_tasks
  ) task.dependencies

(** Find next executable tasks *)
let get_ready_tasks all_tasks completed_tasks =
  List.filter (fun task ->
    not (List.exists (fun result -> result.task_id = task.id) completed_tasks) &&
    is_task_ready completed_tasks task
  ) all_tasks

(** Execute a single micro-task with retries *)
let execute_micro_task config goal existing_files tool_executor (execute_action_fn : 'a -> string -> 'b list -> 'c -> action -> Types.simple_tool_result Lwt.t) task =
  let rec attempt_task attempts_left =
    if attempts_left <= 0 then
      Lwt.return ({
        task_id = task.id;
        success = false;
        result = ({ content = "Max retries exceeded"; success = false; error_msg = Some "Too many failed attempts" } : Types.simple_tool_result);
        verification_passed = false;
        attempts = task.retry_limit;
      } : micro_task_result)
    else
      let* action_result = execute_action_fn config goal existing_files tool_executor task.action in
      let verification_passed = action_result.success in (* Simple verification for now *)
      
      if action_result.success && verification_passed then
        Lwt.return ({
          task_id = task.id;
          success = true;
          result = action_result;
          verification_passed = true;
          attempts = task.retry_limit - attempts_left + 1;
        } : micro_task_result)
      else (
        Printf.printf "⚠️ Micro-task %s failed (attempts left: %d), retrying...\n" task.id (attempts_left - 1);
        flush_all ();
        attempt_task (attempts_left - 1)
      )
  in
  attempt_task task.retry_limit

(** Execute micro-tasks with dependency resolution *)
let execute_micro_tasks config goal existing_files tool_executor (execute_action_fn : 'a -> string -> 'b list -> 'c -> action -> Types.simple_tool_result Lwt.t) tasks =
  let rec execute_loop completed_tasks =
    let ready_tasks = get_ready_tasks tasks completed_tasks in
    match ready_tasks with
    | [] ->
        let remaining_tasks = List.filter (fun task ->
          not (List.exists (fun result -> result.task_id = task.id) completed_tasks)
        ) tasks in
        if remaining_tasks = [] then
          Lwt.return completed_tasks (* All tasks completed *)
        else (
          Printf.printf "❌ No more tasks can proceed. Remaining tasks have unmet dependencies.\n";
          flush_all ();
          Lwt.return completed_tasks (* Deadlock - return what we have *)
        )
    | next_task :: _ ->
        Printf.printf "🔧 Executing micro-task: %s\n" next_task.description;
        flush_all ();
        let* task_result = execute_micro_task config goal existing_files tool_executor execute_action_fn next_task in
        let updated_completed = task_result :: completed_tasks in
        
        if task_result.success then (
          Printf.printf "✅ Micro-task %s completed successfully\n" next_task.id;
          flush_all ();
          execute_loop updated_completed
        ) else (
          Printf.printf "❌ Micro-task %s failed after %d attempts\n" next_task.id task_result.attempts;
          flush_all ();
          (* Continue with other tasks that might still be executable *)
          execute_loop updated_completed
        )
  in
  execute_loop []

(** Determine if a task should use micro-decomposition *)
let should_use_micro_decomposition goal =
  let goal_lower = String.lowercase_ascii goal in
  (* Detect complex tasks that benefit from micro-decomposition *)
  let contains_substring s substr =
    try
      ignore (Str.search_forward (Str.regexp_string substr) s 0);
      true
    with Not_found -> false
  in
  List.exists (fun keyword ->
    contains_substring goal_lower keyword
  ) [
    "translate"; "implement"; "create project"; "build"; "2048"; 
    "algorithm"; "complex"; "multi-step"; "end-to-end"
  ]

(** Create micro-tasks based on task type detection *)
let create_micro_tasks_for_goal goal =
  let goal_lower = String.lowercase_ascii goal in
  
  let contains_substring s substr =
    try
      ignore (Str.search_forward (Str.regexp_string substr) s 0);
      true
    with Not_found -> false
  in
  if contains_substring goal_lower "2048" || contains_substring goal_lower "translate" then
    create_ocaml_2048_microtasks ()
  else if contains_substring goal_lower "create" && contains_substring goal_lower "project" then
    if contains_substring goal_lower "game" then
      create_ocaml_project_microtasks "game_project" `Game
    else if contains_substring goal_lower "library" then
      create_ocaml_project_microtasks "my_lib" `Library
    else
      create_ocaml_project_microtasks "my_project" `Executable
  else
    (* Default to simple project creation *)
    create_ocaml_project_microtasks "default_project" `Executable

(** Calculate completion percentage *)
let calculate_progress completed_tasks total_tasks =
  let successful_tasks = List.filter (fun result -> result.success) completed_tasks in
  let completion_percentage = 
    if total_tasks = 0 then 100.0
    else (float_of_int (List.length successful_tasks)) /. (float_of_int total_tasks) *. 100.0
  in
  (List.length successful_tasks, total_tasks, completion_percentage)