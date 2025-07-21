```ocaml
let rec play_game () =
  print_string "Enter a number: ";
  try
    let input = read_line () in
    let number = int_of_string input in
    Printf.printf "You entered: %d\n" number;
    play_game ()
  with Failure _ ->
    print_endline "Invalid input. Please enter a number.";
    play_game ()

let () = play_game ()
```