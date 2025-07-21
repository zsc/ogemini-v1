(* Main program for OCaml 2048 game *)

open Game2048

let print_help () =
  Printf.printf "OCaml 2048 Game - Bit-level accurate implementation\n";
  Printf.printf "Commands: w/a/s/d (move), q (quit), t (test), h (help)\n\n%!"

let rec game_loop board score =
  print_board board;
  Printf.printf "Score: %d\n" score;
  Printf.printf "Enter command (w/a/s/d/q/t/h): %!";
  
  let input = read_line () in
  match String.trim (String.lowercase_ascii input) with
  | "q" | "quit" -> 
    Printf.printf "Thanks for playing!\n"
  | "h" | "help" ->
    print_help ();
    game_loop board score
  | "t" | "test" ->
    test_equivalence ();
    game_loop board score
  | "w" | "up" ->
    let (new_board, gained_score, moved) = move_up board in
    if moved then
      let final_board = add_random_tile new_board in
      game_loop final_board (score + gained_score)
    else begin
      Printf.printf "No move possible up!\n";
      game_loop board score
    end
  | "s" | "down" ->
    let (new_board, gained_score, moved) = move_down board in
    if moved then
      let final_board = add_random_tile new_board in
      game_loop final_board (score + gained_score)
    else begin
      Printf.printf "No move possible down!\n";
      game_loop board score
    end
  | "a" | "left" ->
    let (new_board, gained_score, moved) = move_left board in
    if moved then
      let final_board = add_random_tile new_board in
      game_loop final_board (score + gained_score)
    else begin
      Printf.printf "No move possible left!\n";
      game_loop board score
    end
  | "d" | "right" ->
    let (new_board, gained_score, moved) = move_right board in
    if moved then
      let final_board = add_random_tile new_board in
      game_loop final_board (score + gained_score)
    else begin
      Printf.printf "No move possible right!\n";
      game_loop board score
    end
  | _ ->
    Printf.printf "Invalid command. Type 'h' for help.\n";
    game_loop board score

let () =
  Printf.printf "OCaml 2048 Game Starting...\n\n";
  test_equivalence ();
  print_help ();
  let initial_board = reset_board () in
  game_loop initial_board 0