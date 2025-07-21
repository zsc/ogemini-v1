```ocaml
module Game = struct
  type color = Red | Green | Blue

  type move =
    | Place of color * int * int  (* color, row, col *)
    | Pass

  type player = Player1 | Player2

  type game_state = {
    board : color option array array;
    current_player : player;
    move_count : int;
    board_size : int;
  }

  let create_game board_size = {
    board = Array.make_matrix board_size board_size None;
    current_player = Player1;
    move_count = 0;
    board_size = board_size;
  }

  let switch_player game =
    match game.current_player with
    | Player1 -> { game with current_player = Player2 }
    | Player2 -> { game with current_player = Player1 }

  let is_valid_move game move =
    match move with
    | Place (color, row, col) ->
      if row < 0 || row >= game.board_size || col < 0 || col >= game.board_size then
        false
      else
        game.board.(row).(col) = None
    | Pass -> true

  let apply_move game move =
    match move with
    | Place (color, row, col) ->
      if not (is_valid_move game move) then
        None
      else
        let new_board = Array.map Array.copy game.board in
        new_board.(row).(col) <- Some color;
        Some { game with board = new_board; current_player = switch_player game; move_count = game.move_count + 1 }
    | Pass ->
      Some { game with current_player = switch_player game; move_count = game.move_count + 1 }

  let get_winner game =
    (* Placeholder implementation - replace with actual win condition logic *)
    if game.move_count > game.board_size * game.board_size then
      Some Player1 (* Arbitrary winner if board is full *)
    else
      None

  let game_over game =
    match get_winner game with
    | Some _ -> true
    | None -> false

  let print_board game =
    for row = 0 to game.board_size - 1 do
      for col = 0 to game.board_size - 1 do
        match game.board.(row).(col) with
        | Some Red -> print_string "R "
        | Some Green -> print_string "G "
        | Some Blue -> print_string "B "
        | None -> print_string ". "
      done;
      print_newline ()
    done

end
```