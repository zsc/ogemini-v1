```ocaml
type player =
  | X
  | O

type cell =
  | Empty
  | Occupied of player

type row = cell * cell * cell

type board = row * row * row

type game = {
  board : board;
  turn : player;
}

let is_row_won (row : row) (player : player) : bool =
  let (c1, c2, c3) = row in
  match (c1, c2, c3) with
  | (Occupied p1, Occupied p2, Occupied p3) when p1 = player && p2 = player && p3 = player -> true
  | _ -> false

let is_won (game : game) (player : player) : bool =
  let (row1, row2, row3) = game.board in
  (* Check rows *)
  if is_row_won row1 player || is_row_won row2 player || is_row_won row3 player then
    true
  else
    (* Check columns *)
    let (c11, c12, c13) = row1 in
    let (c21, c22, c23) = row2 in
    let (c31, c32, c33) = row3 in
    if (match (c11, c21, c31) with
        | (Occupied p1, Occupied p2, Occupied p3) when p1 = player && p2 = player && p3 = player -> true
        | _ -> false)
    then true
    else if (match (c12, c22, c32) with
             | (Occupied p1, Occupied p2, Occupied p3) when p1 = player && p2 = player && p3 = player -> true
             | _ -> false)
    then true
    else if (match (c13, c23, c33) with
             | (Occupied p1, Occupied p2, Occupied p3) when p1 = player && p2 = player && p3 = player -> true
             | _ -> false)
    then true
    else
      (* Check diagonals *)
      if (match (c11, c22, c33) with
          | (Occupied p1, Occupied p2, Occupied p3) when p1 = player && p2 = player && p3 = player -> true
          | _ -> false)
      then true
      else if (match (c13, c22, c31) with
               | (Occupied p1, Occupied p2, Occupied p3) when p1 = player && p2 = player && p3 = player -> true
               | _ -> false)
      then true
      else false
```