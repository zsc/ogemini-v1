(* Note: Not opening Types since we define our own error types *)

(** Types for build error analysis *)
type error_type = 
  | FileNotFound of string
  | ModuleNameMismatch of { expected: string; found: string }
  | SyntaxError of { line: int; column: int; message: string }
  | TypeMismatch of string
  | DependencyError of string
  | UnknownError of string

type build_error = {
  error_type: error_type;
  file: string option;
  suggestion: string;
}

(** Parse dune build error output *)
let parse_dune_error error_output =
  let lines = String.split_on_char '\n' error_output in
  let rec analyze_lines = function
    | [] -> { error_type = UnknownError "No specific error found"; file = None; suggestion = "Check dune build output" }
    | line :: rest ->
        let line_trim = String.trim line in
        
        (* Module name mismatch - common with dune executables *)
        if Str.string_match (Str.regexp ".*Module \"\\([^\"]+\\)\" doesn't exist.*") line_trim 0 then (
          try
            let module_name = Str.matched_group 1 line_trim in
            { 
              error_type = ModuleNameMismatch { expected = module_name; found = "" }; 
              file = None; 
              suggestion = Printf.sprintf "Create %s.ml or rename existing file to match dune executable name" (String.lowercase_ascii module_name) 
            }
          with Invalid_argument _ ->
            { error_type = UnknownError line_trim; file = None; suggestion = "Check module names" }
        )
        
        (* File not found patterns *)
        else if Str.string_match (Str.regexp ".*doesn't exist.*") line_trim 0 then
          { error_type = FileNotFound line_trim; file = None; suggestion = "Create the missing file" }
        
        (* Syntax errors *)
        else if Str.string_match (Str.regexp ".*line \\([0-9]+\\).*column \\([0-9]+\\).*") line_trim 0 then (
          try
            let line_num = int_of_string (Str.matched_group 1 line_trim) in
            let col_num = int_of_string (Str.matched_group 2 line_trim) in
            { 
              error_type = SyntaxError { line = line_num; column = col_num; message = line_trim }; 
              file = None; 
              suggestion = "Fix syntax error at the specified location" 
            }
          with Invalid_argument _ | Failure _ ->
            analyze_lines rest
        )
        
        (* Continue analyzing *)
        else analyze_lines rest
  in
  analyze_lines lines

(** Generate fix suggestions for build errors *)
let suggest_fix error =
  match error.error_type with
  | FileNotFound file ->
      Printf.sprintf "Create missing file: %s" file
      
  | ModuleNameMismatch { expected; found = _ } ->
      Printf.sprintf "Rename your ML file to %s.ml to match the dune executable name" (String.lowercase_ascii expected)
      
  | SyntaxError { line; column; message } ->
      Printf.sprintf "Fix syntax error at line %d, column %d: %s" line column message
      
  | TypeMismatch msg ->
      Printf.sprintf "Fix type error: %s" msg
      
  | DependencyError dep ->
      Printf.sprintf "Add missing dependency: %s" dep
      
  | UnknownError msg ->
      Printf.sprintf "Unknown error: %s" msg

(** Attempt to auto-fix simple build errors *)
let auto_fix_error error existing_files =
  match error.error_type with
  | ModuleNameMismatch { expected; found = _ } ->
      (* Look for ML files that could be renamed *)
      let ml_files = List.filter (fun file -> 
        String.length file > 3 && 
        String.sub file (String.length file - 3) 3 = ".ml"
      ) existing_files in
      
      (match ml_files with
      | [single_ml] ->
          let expected_name = String.lowercase_ascii expected ^ ".ml" in
          Some (Printf.sprintf "mv %s %s" single_ml expected_name)
      | _ -> None
      )
      
  | _ -> None

(** Main build error analysis function *)
let analyze_build_error error_output existing_files =
  let error = parse_dune_error error_output in
  let suggestion = suggest_fix error in
  let auto_fix = auto_fix_error error existing_files in
  
  Printf.printf "🔍 Build Error Analysis:\n";
  Printf.printf "   Type: %s\n" suggestion;
  
  (match auto_fix with
  | Some fix_cmd ->
      Printf.printf "   Auto-fix available: %s\n" fix_cmd;
      Some fix_cmd
  | None ->
      Printf.printf "   Manual fix required: %s\n" suggestion;
      None
  )