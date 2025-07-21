(* OCaml 2048 Game - Bit-level accurate implementation *)

type board = int64
type row = int

(* Lookup tables - to be populated *)
let left_table = ref (Array.make 65536 0)
let right_table = ref (Array.make 65536 0) 
let score_table = ref (Array.make 65536 (0, 0))
let transpose_table = ref (Array.make 65536 0L)
let initialized = ref false

(* Core bit manipulation functions *)
let int_to_row (x : int) : int list =
  [(x lsr (4*0)) land 0xF; 
   (x lsr (4*1)) land 0xF;
   (x lsr (4*2)) land 0xF; 
   (x lsr (4*3)) land 0xF]

let row_to_int (row : int list) : int =
  match row with
  | [a; b; c; d] -> 
    (a lsl (4*0)) lor (b lsl (4*1)) lor (c lsl (4*2)) lor (d lsl (4*3))
  | _ -> failwith "row must have exactly 4 elements"

let get_tile (board : board) (pos : int) : int =
  Int64.to_int (Int64.logand (Int64.shift_right board (4 * pos)) 0xFL)

let set_tile (board : board) (pos : int) (value : int) : board =
  let mask = Int64.shift_left 0xFL (4 * pos) in
  let cleared = Int64.logand board (Int64.lognot mask) in
  let new_val = Int64.shift_left (Int64.of_int value) (4 * pos) in
  Int64.logor cleared new_val

(* Core game algorithm - move row left with merging *)
let move_row_left (row : int list) : int list * int =
  (* Remove zeros *)
  let non_zero = List.filter (fun x -> x <> 0) row in
  
  (* Merge adjacent equal tiles *)
  let rec merge_tiles acc score = function
    | [] -> (List.rev acc, score)
    | [x] -> (List.rev (x :: acc), score)
    | x :: y :: rest when x = y ->
        let merged_tile = x + 1 in
        let tile_score = 1 lsl merged_tile in
        merge_tiles (merged_tile :: acc) (score + tile_score) rest
    | x :: rest ->
        merge_tiles (x :: acc) score rest
  in
  
  let (merged, score) = merge_tiles [] 0 non_zero in
  (* Pad with zeros to make length 4 *)
  let padded = merged @ (List.init (4 - List.length merged) (fun _ -> 0)) in
  (padded, score)

(* Initialize lookup tables *)
let init_tables () =
  if not !initialized then begin
    initialized := true;
    
    for i = 0 to 65535 do
      let row = int_to_row i in
      
      (* Left move *)
      let (left_result, score_left) = move_row_left row in
      let left_int = row_to_int left_result in
      !left_table.(i) <- left_int;
      
      (* Right move (reverse, move left, reverse) *)
      let row_rev = List.rev row in
      let (right_result_rev, score_right) = move_row_left row_rev in
      let right_result = List.rev right_result_rev in
      let right_int = row_to_int right_result in
      !right_table.(i) <- right_int;
      
      (* Store scores *)
      !score_table.(i) <- (score_left, score_right);
      
      (* Transpose calculation *)
      let c0, c1, c2, c3 = match row with
        | [a; b; c; d] -> (a, b, c, d)
        | _ -> failwith "row must have exactly 4 elements" in
      let transposed = Int64.logor 
        (Int64.logor 
          (Int64.shift_left (Int64.of_int c0) (4*0))
          (Int64.shift_left (Int64.of_int c1) (4*4)))
        (Int64.logor
          (Int64.shift_left (Int64.of_int c2) (4*8))
          (Int64.shift_left (Int64.of_int c3) (4*12))) in
      !transpose_table.(i) <- transposed;
    done
  end

(* Game operations *)
let move_left (board : board) : board * int * bool =
  init_tables ();
  let new_board = ref 0L in
  let total_score = ref 0 in
  let moved = ref false in
  
  for r = 0 to 3 do
    let row_int = Int64.to_int (Int64.logand (Int64.shift_right board (16*r)) 0xFFFFL) in
    let new_row = !left_table.(row_int) in
    let score = fst !score_table.(row_int) in
    
    if new_row <> row_int then moved := true;
    
    new_board := Int64.logor !new_board (Int64.shift_left (Int64.of_int new_row) (16*r));
    total_score := !total_score + score;
  done;
  
  (!new_board, !total_score, !moved)

let move_right (board : board) : board * int * bool =
  init_tables ();
  let new_board = ref 0L in
  let total_score = ref 0 in
  let moved = ref false in
  
  for r = 0 to 3 do
    let row_int = Int64.to_int (Int64.logand (Int64.shift_right board (16*r)) 0xFFFFL) in
    let new_row = !right_table.(row_int) in
    let score = snd !score_table.(row_int) in
    
    if new_row <> row_int then moved := true;
    
    new_board := Int64.logor !new_board (Int64.shift_left (Int64.of_int new_row) (16*r));
    total_score := !total_score + score;
  done;
  
  (!new_board, !total_score, !moved)

(* Transpose board for up/down moves *)
let transpose (board : board) : board =
  init_tables ();
  let result = ref 0L in
  
  for i = 0 to 3 do
    let row_int = Int64.to_int (Int64.logand (Int64.shift_right board (16*i)) 0xFFFFL) in
    let transposed_col = !transpose_table.(row_int) in
    result := Int64.logor !result transposed_col;
  done;
  
  !result

let move_up (board : board) : board * int * bool =
  let transposed = transpose board in
  let (moved_board, score, moved) = move_left transposed in
  (transpose moved_board, score, moved)

let move_down (board : board) : board * int * bool =
  let transposed = transpose board in
  let (moved_board, score, moved) = move_right transposed in
  (transpose moved_board, score, moved)

(* Random tile addition *)
let add_random_tile (board : board) : board =
  let empty_positions = ref [] in
  for i = 0 to 15 do
    if get_tile board i = 0 then
      empty_positions := i :: !empty_positions;
  done;
  
  match !empty_positions with
  | [] -> board  (* No empty positions *)
  | positions ->
    let pos = List.nth positions (Random.int (List.length positions)) in
    let value = if Random.float 1.0 < 0.9 then 1 else 2 in
    set_tile board pos value

(* Initialize new game *)
let reset_board () : board =
  Random.self_init ();
  let board = 0L in
  let board = add_random_tile board in
  add_random_tile board

(* Display functions *)
let print_board (board : board) =
  Printf.printf "Board:\n";
  for r = 0 to 3 do
    for c = 0 to 3 do
      let pos = r * 4 + c in
      let tile_val = get_tile board pos in
      let display_val = if tile_val = 0 then 0 else 1 lsl tile_val in
      Printf.printf "%4d " display_val;
    done;
    Printf.printf "\n";
  done;
  Printf.printf "\n%!"

(* Test mathematical equivalence *)
let test_equivalence () =
  Printf.printf "Testing mathematical equivalence...\n";
  
  (* Test int_to_row and row_to_int *)
  let test_val = 0x1234 in
  let row = int_to_row test_val in
  let recovered = row_to_int row in
  Printf.printf "int_to_row/row_to_int test: %04x -> %s -> %04x (match: %b)\n"
    test_val 
    (String.concat ";" (List.map string_of_int row))
    recovered 
    (test_val = recovered);
  
  (* Test move_row_left *)
  let test_row = [1; 1; 2; 0] in
  let (result, score) = move_row_left test_row in
  Printf.printf "move_row_left [1;1;2;0] -> %s, score=%d\n"
    (String.concat ";" (List.map string_of_int result))
    score;
  
  Printf.printf "Equivalence testing complete.\n\n%!"