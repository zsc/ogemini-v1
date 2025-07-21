(* Core data types for 2048 game *)

(* Board representation: 64-bit integer where each 4 bits represents one tile *)
type board = int64

(* Individual tile value (log2 representation: 0=empty, 1=2, 2=4, 3=8, etc.) *)
type tile = int

(* Game move directions *)
type direction = Left | Right | Up | Down

(* Game result after a move *)
type move_result = {
  new_board: board;
  score_gained: int;
  moved: bool;
}