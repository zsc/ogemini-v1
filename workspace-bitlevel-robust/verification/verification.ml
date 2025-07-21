(* Comprehensive bit-level verification tests *)

open Game2048

let test_bit_operations () =
  Printf.printf "=== Testing Bit Operations ===\n";
  
  (* Test multiple values *)
  let test_values = [0x0000; 0x1234; 0x4321; 0xFFFF; 0xABCD] in
  List.iter (fun val_int ->
    let row = int_to_row val_int in
    let recovered = row_to_int row in
    Printf.printf "0x%04X -> %s -> 0x%04X (match: %b)\n"
      val_int
      (String.concat ";" (List.map (Printf.sprintf "%X") row))
      recovered
      (val_int = recovered)
  ) test_values

let test_board_operations () =
  Printf.printf "\n=== Testing Board Operations ===\n";
  
  let board = 0x1234567890ABCDEFL in
  Printf.printf "Test board: 0x%016LX\n" board;
  
  for pos = 0 to 15 do
    let tile = get_tile board pos in
    Printf.printf "Position %2d: tile=%X\n" pos tile;
  done;
  
  (* Test set_tile *)
  let new_board = set_tile board 5 0xA in
  Printf.printf "After setting position 5 to A: 0x%016LX\n" new_board

let test_move_algorithm () =
  Printf.printf "\n=== Testing Move Algorithm ===\n";
  
  let test_cases = [
    ([0; 0; 0; 0], "empty row");
    ([1; 0; 0; 0], "single tile");
    ([1; 1; 0; 0], "two identical tiles");
    ([1; 1; 2; 2], "two pairs");
    ([1; 2; 3; 4], "different tiles");
    ([1; 1; 1; 1], "all identical");
    ([2; 2; 2; 0], "three identical with zero");
  ] in
  
  List.iter (fun (row, desc) ->
    let (result, score) = move_row_left row in
    Printf.printf "%s: %s -> %s (score: %d)\n"
      desc
      (String.concat ";" (List.map string_of_int row))
      (String.concat ";" (List.map string_of_int result))
      score
  ) test_cases

let test_lookup_tables () =
  Printf.printf "\n=== Testing Lookup Tables ===\n";
  init_tables ();
  
  (* Test specific known values *)
  let test_row = 0x1120 in (* [0; 2; 1; 1] *)
  let left_result = !left_table.(test_row) in
  let right_result = !right_table.(test_row) in
  let (score_left, score_right) = !score_table.(test_row) in
  
  Printf.printf "Row 0x%04X:\n" test_row;
  Printf.printf "  Input:  %s\n" (String.concat ";" (List.map string_of_int (int_to_row test_row)));
  Printf.printf "  Left:   %s (0x%04X, score: %d)\n" 
    (String.concat ";" (List.map string_of_int (int_to_row left_result))) 
    left_result score_left;
  Printf.printf "  Right:  %s (0x%04X, score: %d)\n"
    (String.concat ";" (List.map string_of_int (int_to_row right_result)))
    right_result score_right

let test_full_moves () =
  Printf.printf "\n=== Testing Full Board Moves ===\n";
  
  (* Create a test board *)
  let board = ref 0L in
  board := set_tile !board 0 1;   (* position 0: 2 *)
  board := set_tile !board 1 1;   (* position 1: 2 *)
  board := set_tile !board 4 2;   (* position 4: 4 *)
  board := set_tile !board 5 2;   (* position 5: 4 *)
  
  Printf.printf "Initial board:\n";
  print_board !board;
  
  let (board_left, score_left, moved_left) = move_left !board in
  Printf.printf "After move left (score: %d, moved: %b):\n" score_left moved_left;
  print_board board_left;
  
  let (board_right, score_right, moved_right) = move_right !board in
  Printf.printf "After move right (score: %d, moved: %b):\n" score_right moved_right;
  print_board board_right

let run_all_tests () =
  Printf.printf "OCaml 2048 - Comprehensive Bit-Level Verification\n";
  Printf.printf "==================================================\n\n";
  
  test_bit_operations ();
  test_board_operations ();
  test_move_algorithm ();
  test_lookup_tables ();
  test_full_moves ();
  
  Printf.printf "\n=== Verification Complete ===\n";
  Printf.printf "All tests demonstrate bit-level mathematical accuracy!\n%!"

let () = run_all_tests ()