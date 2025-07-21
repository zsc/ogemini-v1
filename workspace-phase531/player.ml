(* Game module - 2048 game logic *)

(* Board representation as 64-bit integer *)
type board = int64

(* Basic board operations *)
let empty_board : board = 0L

let get_tile (board : board) (pos : int) : int =
  Int64.to_int (Int64.logand (Int64.shift_right board (4 * pos)) 0xFL)

let set_tile (board : board) (pos : int) (value : int) : board =
  let mask = Int64.shift_left 0xFL (4 * pos) in
  let cleared = Int64.logand board (Int64.lognot mask) in
  let new_val = Int64.shift_left (Int64.of_int value) (4 * pos) in
  Int64.logor cleared new_val

let print_board (board : board) : unit =
  Printf.printf "Board: %Ld\n" board
