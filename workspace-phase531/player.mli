(* Module interface *)

type board = int64

val empty_board : board
val get_tile : board -> int -> int
val set_tile : board -> int -> int -> board
val print_board : board -> unit
