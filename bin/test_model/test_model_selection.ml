(* Test program for model selection functionality *)

open Ogemini.Model_selector

let test_model_selection () =
  Printf.printf "🧪 Testing Enhanced Model Selection System\n\n";
  
  let test_cases = [
    ("list files in current directory", "Simple file operation");
    ("implement complex 2048 bit-level algorithm translation from Python to OCaml with lookup tables", "Complex algorithm translation"); 
    ("analyze project structure and module dependencies across multiple files", "Medium complexity analysis");
    ("create simple hello world project with dune configuration", "Simple project creation");
    ("verify mathematical equivalence of 65536 lookup table entries with bit-level precision", "Complex verification task");
    ("refactor code to use better variable names", "Medium complexity refactoring");
    ("what is OCaml", "Simple question");
  ] in
  
  List.iteri (fun i (task, description) ->
    Printf.printf "--- Test Case %d: %s ---\n" (i+1) description;
    Printf.printf "Task: %s\n" task;
    
    let complexity = classify_task_complexity task in
    Printf.printf "Classified complexity: %s\n" 
      (match complexity with Simple -> "Simple" | Medium -> "Medium" | Complex -> "Complex");
    
    let dev_model = select_model ~context:Development complexity in
    let debug_model = select_model ~context:Debug complexity in 
    let benchmark_model = select_model ~context:Benchmark complexity in
    
    Printf.printf "Model Selection:\n";
    Printf.printf "  Development: %s\n" (get_selected_model_name dev_model);
    Printf.printf "  Debug: %s\n" (get_selected_model_name debug_model);
    Printf.printf "  Benchmark: %s\n" (get_selected_model_name benchmark_model);
    
    let explanation = explain_selection task dev_model Development in
    Printf.printf "\nDetailed Analysis (Development context):\n%s\n\n" explanation;
  ) test_cases;
  
  Printf.printf "🎯 Model Selection Strategy Summary:\n";
  Printf.printf "- Simple tasks → gemini-2.0-flash (fast iteration)\n";
  Printf.printf "- Medium tasks → gemini-2.5-flash in debug (balanced quality)\n";
  Printf.printf "- Complex tasks → gemini-2.5-pro in benchmark (maximum quality)\n";
  Printf.printf "- 429 errors → exponential backoff + model escalation\n";
  Printf.printf "- Max retries with intelligent fallback strategies\n\n";
  
  Printf.printf "✅ Model selection system ready for Phase 6 deployment!\n"

let () = test_model_selection ()