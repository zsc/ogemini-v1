```ocaml
(executable
 (name calculator_app)
 (libraries r)
 (modules main))

(test
 (name calculator_test)
 (libraries r alcotest)
 (modules test_calculator))
```