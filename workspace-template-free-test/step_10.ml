```ocaml
type game_state = {
  board : string list;
  player : string;
  won : bool;
  draw : bool;
}

let check_win (board : string list) (player : string) : bool =
  let win_patterns =
    [
      [ 0; 1; 2 ];
      [ 3; 4; 5 ];
      [ 6; 7; 8 ];
      [ 0; 3; 6 ];
      [ 1; 4; 7 ];
      [ 2; 5; 8 ];
      [ 0; 4; 8 ];
      [ 2; 4; 6 ];
    ]
  in
  List.exists
    (fun pattern ->
      List.for_all (fun i -> List.nth board i = player) pattern)
    win_patterns

let check_draw (board : string list) : bool =
  List.for_all (fun s -> s <> "") board

let make_move (board : string list) (player : string) (position : int) :
    string list option =
  if position < 0 || position > 8 then None
  else
    match List.nth board position with
    | "" ->
        let new_board =
          List.mapi
            (fun i x -> if i = position then player else x)
            board
        in
        Some new_board
    | _ -> None

let string_of_board (board : string list) : string =
  let row_separator = "-----------\n" in
  let cell_separator = " | " in
  let row_strings =
    [
      String.concat cell_separator (List.sub board 0 3);
      String.concat cell_separator (List.sub board 3 3);
      String.concat cell_separator (List.sub board 6 3);
    ]
  in
  String.concat row_separator row_strings

let game_step (t : game_state) : game_state * string =
  if t.won then (t, "You already won!")
  else if t.draw then (t, "It's a draw!")
  else (t, "Game is still in progress.")
```