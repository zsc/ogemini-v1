```ocaml
open Step_25

let handle_input input =
  match input with
  | "north" | "n" -> Move North
  | "south" | "s" -> Move South
  | "east" | "e" -> Move East
  | "west" | "w" -> Move West
  | "look" | "l" -> Look
  | "quit" | "q" -> Quit
  | _ -> Invalid_command

let rec game_loop state =
  print_endline (describe_location state);
  print_string "> ";
  flush stdout;
  let input = read_line () in
  let action = handle_input input in
  match action with
  | Move direction ->
    (match next_location state direction with
     | Some new_location -> game_loop { state with current_location = new_location }
     | None ->
       print_endline "You cannot go that way.";
       game_loop state)
  | Look ->
    print_endline (describe_location state);
    game_loop state
  | Quit ->
    print_endline "Goodbye!";
    ()
  | Invalid_command ->
    print_endline "Invalid command. Try again.";
    game_loop state

let start_game = game_loop initial_game_state
```