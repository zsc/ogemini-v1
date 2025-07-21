open Ogemini.Types
open Ogemini.Micro_task_decomposer

let test_microtask_detection () =
  Printf.printf "🧪 Testing micro-task decomposition detection:\n";
  
  let test_cases = [
    ("Create a simple hello world project", "Should NOT trigger micro-decomposition");
    ("Translate the Python 2048 game to OCaml", "Should trigger micro-decomposition");
    ("Implement a complex algorithm", "Should trigger micro-decomposition");
    ("Create project with build system", "Should trigger micro-decomposition");
    ("Simple file operation", "Should NOT trigger micro-decomposition");
  ] in
  
  List.iter (fun (goal, expectation) ->
    let should_decompose = should_use_micro_decomposition goal in
    Printf.printf "  📋 '%s' → %s (%s)\n" 
      goal 
      (if should_decompose then "✅ MICRO-TASK MODE" else "📋 STANDARD MODE")
      expectation
  ) test_cases;
  
  Printf.printf "\n🔬 Testing micro-task creation for OCaml project:\n";
  let micro_tasks = create_ocaml_project_microtasks "test_project" `Executable in
  Printf.printf "  📊 Generated %d micro-tasks:\n" (List.length micro_tasks);
  List.iteri (fun i task ->
    Printf.printf "    %d. %s (deps: [%s])\n" 
      (i+1) 
      task.description 
      (String.concat "; " task.dependencies)
  ) micro_tasks;

  Printf.printf "\n🎮 Testing micro-task creation for OCaml 2048 project:\n";
  let ocaml_2048_tasks = create_ocaml_2048_microtasks () in
  Printf.printf "  📊 Generated %d micro-tasks:\n" (List.length ocaml_2048_tasks);
  List.iteri (fun i task ->
    Printf.printf "    %d. %s (complexity: %s, deps: [%s])\n" 
      (i+1) 
      task.description
      (match task.complexity with `Simple -> "Simple" | `Medium -> "Medium" | `Complex -> "Complex")
      (String.concat "; " task.dependencies)
  ) ocaml_2048_tasks

let () = test_microtask_detection ()