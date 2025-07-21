```ocaml
let is_numeric str =
  try
    let _ = float_of_string str in
    true
  with _ ->
    false

let safe_float_of_string str =
  if is_numeric str then
    Some (float_of_string str)
  else
    None

let process_input input =
  match safe_float_of_string input with
  | Some num ->
    Printf.printf "Input is a valid number: %f\n" num
  | None ->
    Printf.printf "Invalid input: Not a number\n"

let () =
  print_string "Enter a value: ";
  let input = read_line () in
  process_input input
```