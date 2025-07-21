(* Main entry point for 2048 game *)

let () =
  let board = ref 0L in
  Printf.printf "OCaml 2048 Game\n";
  Printf.printf "Initial board: %Ld\n" !board;
  Printf.printf "Game initialized successfully!\n"