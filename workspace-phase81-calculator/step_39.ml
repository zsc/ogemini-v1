```ocaml
let add_test () =
  Alcotest.(check int) "add" 5 (Calculator.add 2 3);
  Alcotest.(check int) "add negative" (-1) (Calculator.add (-2) 1)

let subtract_test () =
  Alcotest.(check int) "subtract" 1 (Calculator.subtract 3 2);
  Alcotest.(check int) "subtract negative" (-3) (Calculator.subtract (-1) 2)

let multiply_test () =
  Alcotest.(check int) "multiply" 6 (Calculator.multiply 2 3);
  Alcotest.(check int) "multiply negative" (-2) (Calculator.multiply (-1) 2)

let clear_test () =
  let calc = Calculator.create () in
  Calculator.add calc 5;
  Calculator.clear calc;
  Alcotest.(check int) "clear" 0 (Calculator.get_result calc)

let get_result_test () =
  let calc = Calculator.create () in
  Calculator.add calc 5;
  Alcotest.(check int) "get_result" 5 (Calculator.get_result calc)

let () =
  Alcotest.run "Calculator Tests" [
    "add", [
      Alcotest.test_case "Add positive numbers" `Quick add_test;
    ];
    "subtract", [
      Alcotest.test_case "Subtract positive numbers" `Quick subtract_test;
    ];
    "multiply", [
      Alcotest.test_case "Multiply positive numbers" `Quick multiply_test;
    ];
    "clear", [
      Alcotest.test_case "Clear result" `Quick clear_test;
    ];
    "get_result", [
      Alcotest.test_case "Get result" `Quick get_result_test;
    ];
  ]
```