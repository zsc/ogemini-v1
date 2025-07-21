```ocaml
let () =
  print_endline "Now reading the python file..."

let read_python_file file_path =
  let file = open_in file_path in
  let rec read_lines acc =
    try
      let line = input_line file in
      read_lines (line :: acc)
    with End_of_file ->
      close_in file;
      List.rev acc
  in
  read_lines []

let () =
  let file_path = "/workspace/step_1.ml" in
  let lines = read_python_file file_path in
  List.iter print_endline lines
```