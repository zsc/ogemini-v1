```ocaml
let () =
  Alcotest.run "My project" [
    ("group 1", [
        Alcotest.test_case "test 1" `Quick (fun () -> Alcotest.(check int) "test" 1 1);
      ]);
  ]
```