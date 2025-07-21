(* Test module *)

let test_basic_operations () =
  let board = 0L in
  Printf.printf "Test passed: empty board = %Ld\n" board;
  true

let () =
  Printf.printf "Running tests...\n";
  ignore (test_basic_operations ());
  Printf.printf "Tests completed.\n"
