open Ogemini.Types
open Ogemini.Llm_plan_parser

let test_response = {|TOOL_CALL: list_files
PARAMS: dir_path=/workspace/
RATIONALE: Understand the project structure by listing files in the current directory.

TOOL_CALL: write_file
PARAMS: file_path=/workspace/hello.ml, content=print_endline "Hello, World!"
RATIONALE: Create `hello.ml` with the content `print_endline "Hello, World!"`.

TOOL_CALL: write_file
PARAMS: file_path=/workspace/dune, content=(executable (name hello))
RATIONALE: Create a `dune` file with the content `(executable (name hello))`.

TOOL_CALL: dune_build
PARAMS: target=./bin/hello.exe
RATIONALE: Build the project.

TOOL_CALL: shell
PARAMS: command=./_build/default/hello.exe
RATIONALE: Execute the program using `./_build/default/hello.exe`.|}

let () =
  Printf.printf "Testing LLM plan parser locally...\n";
  let actions = parse_llm_extracted_tools test_response in
  Printf.printf "Extracted %d actions:\n" (List.length actions);
  List.iteri (fun i action ->
    match action with
    | ToolCall { name; args; rationale } ->
        Printf.printf "%d. %s: %s\n" (i+1) name rationale;
        List.iter (fun (k, v) -> Printf.printf "   %s=%s\n" k v) args
    | _ -> Printf.printf "%d. Other action\n" (i+1)
  ) actions