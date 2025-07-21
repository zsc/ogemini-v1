(* Game2048 module - Core game logic *)
open Types

(* Extract a 4-bit tile value from a specific position in the board *)
let get_tile (board : board) (pos : int) : tile =
  Int64.to_int (Int64.logand (Int64.shift_right board (4 * pos)) 0xFL)

(* Set a tile value at a specific position in the board *)
let set_tile (board : board) (pos : int) (value : tile) : board =
  let mask = Int64.shift_left 0xFL (4 * pos) in
  let cleared_board = Int64.logand board (Int64.lognot mask) in
  let new_value = Int64.shift_left (Int64.of_int value) (4 * pos) in
  Int64.logor cleared_board new_value

(* Initialize empty board *)
let empty_board : board = 0L

(* Get board as 4x4 array of actual tile values (for display) *)
let board_to_array (board : board) : int array array =
  let arr = Array.make_matrix 4 4 0 in
  for i = 0 to 15 do
    let row = i / 4 in
    let col = i mod 4 in
    let tile_val = get_tile board i in
    arr.(row).(col) <- if tile_val = 0 then 0 else 1 lsl tile_val
  done;
  arr