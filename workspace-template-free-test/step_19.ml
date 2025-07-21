```ocaml
open Step_18

let validate_input input =
  try
    let move =
      match String.lowercase_ascii input with
      | "north" -> North
      | "south" -> South
      | "east" -> East
      | "west" -> West
      | _ -> raise (Invalid_argument "Invalid direction")
    in
    Ok move
  with
  | Invalid_argument msg -> Error msg

let rec game_loop state =
  print_endline (describe_location state.current_location);
  print_string "> ";
  flush stdout;
  match read_line () with
  | input ->
    match validate_input input with
    | Ok move ->
      let new_state = move_player state move in
      if new_state.current_location = state.current_location then (
        print_endline "You cannot go that way.";
        game_loop state
      ) else if new_state.has_won then (
        print_endline "Congratulations, you have won!";
        ()
      ) else
        game_loop new_state
    | Error msg ->
      print_endline msg;
      game_loop state

let start_game =
  let initial_state = {
    current_location = Location.starting_location;
    has_won = false;
  } in
  game_loop initial_state
```