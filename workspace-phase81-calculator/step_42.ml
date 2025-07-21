```ocaml
let () =
  (* Test the calculator functions *)
  let calc = Calculator.create () in
  assert (Calculator.get_result calc = 0);
  Calculator.add calc 5;
  assert (Calculator.get_result calc = 5);
  Calculator.multiply calc 3;
  assert (Calculator.get_result calc = 15);
  Calculator.subtract calc 2;
  assert (Calculator.get_result calc = 13);
  Calculator.clear calc;
  assert (Calculator.get_result calc = 0);

  print_endline "All tests passed!"
```