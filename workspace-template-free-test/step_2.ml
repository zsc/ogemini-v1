```ocaml
module Step_2 = struct
  type game_state = {
    player_x : int;
    player_y : int;
    score : int;
    is_game_over : bool;
  }

  let initial_game_state = {
    player_x = 0;
    player_y = 0;
    score = 0;
    is_game_over = false;
  }

  let update_game_state (state : game_state) (action : string) : game_state =
    match action with
    | "up" -> { state with player_y = state.player_y + 1; score = state.score + 1 }
    | "down" -> { state with player_y = state.player_y - 1; score = state.score + 1 }
    | "left" -> { state with player_x = state.player_x - 1; score = state.score + 1 }
    | "right" -> { state with player_x = state.player_x + 1; score = state.score + 1 }
    | "quit" -> { state with is_game_over = true }
    | _ -> state

  let print_game_state (state : game_state) : unit =
    Printf.printf "Player X: %d\n" state.player_x;
    Printf.printf "Player Y: %d\n" state.player_y;
    Printf.printf "Score: %d\n" state.score;
    Printf.printf "Game Over: %b\n" state.is_game_over

  let game_loop () : unit =
    let rec loop (state : game_state) : unit =
      print_game_state state;
      if state.is_game_over then
        Printf.printf "Game Over!\n"
      else begin
        Printf.printf "Enter action (up, down, left, right, quit): ";
        let action = read_line () in
        let new_state = update_game_state state action in
        loop new_state
      end
    in
    loop initial_game_state
end
```