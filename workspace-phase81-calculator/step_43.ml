```ocaml
(* step_43.ml *)
open OUnit2
open R

let test_add _ =
  let calc = make () in
  assert_equal 5 (add calc 5);
  assert_equal 10 (add calc 5);
  clear calc;
  assert_equal 5 (add calc 5)

let test_subtract _ =
  let calc = make () in
  add calc 10;
  assert_equal 5 (subtract calc 5);
  assert_equal 0 (subtract calc 5);
  clear calc;
  add calc 10;
  assert_equal 5 (subtract calc 5)

let test_multiply _ =
  let calc = make () in
  add calc 5;
  assert_equal 15 (multiply calc 3);
  assert_equal 0 (clear calc);
  add calc 5;
  assert_equal 15 (multiply calc 3)

let test_clear _ =
  let calc = make () in
  add calc 5;
  clear calc;
  assert_equal 0 (get_result calc);
  add calc 10;
  clear calc;
  assert_equal 0 (get_result calc)

let test_get_result _ =
  let calc = make () in
  assert_equal 0 (get_result calc);
  add calc 5;
  assert_equal 5 (get_result calc);
  subtract calc 2;
  assert_equal 3 (get_result calc)

let suite =
  "calculator_tests" >::: [
    "test_add" >:: test_add;
    "test_subtract" >:: test_subtract;
    "test_multiply" >:: test_multiply;
    "test_clear" >:: test_clear;
    "test_get_result" >:: test_get_result;
  ]

let () =
  run_test_tt_main suite
```