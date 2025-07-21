(* Main entry point for 2048 game *)

let print_board board =
  let arr = Game.board_to_array board in
  Printf.printf "\n";
  for i = 0 to 3 do
    for j = 0 to 3 do
      Printf.printf "%4d " arr.(i).(j)
    done;
    Printf.printf "\n"
  done;
  Printf.printf "\n"

let () =
  Printf.printf "OCaml 2048 - Core Types and Functions Test\n";
  let board = Game.empty_board in
  let board_with_tile = Game.set_tile board 0 1 in  (* Set a "2" tile at position 0 *)
  let board_with_two_tiles = Game.set_tile board_with_tile 15 2 in  (* Set a "4" tile at position 15 *)
  print_board board_with_two_tiles;
  Printf.printf "Tile at position 0: %d\n" (Game.get_tile board_with_two_tiles 0);
  Printf.printf "Tile at position 15: %d\n" (Game.get_tile board_with_two_tiles 15)