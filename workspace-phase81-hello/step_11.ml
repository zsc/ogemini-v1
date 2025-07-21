```ocaml
let rec print_list = function
  | [] -> ()
  | e::l -> print_int e ; print_string " " ; print_list l

let solve (input : int list) : int list =
  let rec aux acc input =
    match input with
    | [] -> acc
    | x :: xs ->
      let new_acc = x :: acc in
      aux new_acc xs
  in
  let reversed_list = aux [] input in
  reversed_list

let main () : unit =
  let input_line = input_line stdin in
  let input_numbers_str = String.split_on_char ' ' input_line in
  let input_numbers = List.map int_of_string input_numbers_str in

  let result = solve input_numbers in
  print_list result;
  print_newline ()

let () = main ()
```