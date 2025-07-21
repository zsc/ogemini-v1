let factorial n =
  let rec fact acc n =
    if n < 0 then
      None
    else if n = 0 then
      Some acc
    else
      fact (acc * n) (n - 1)
  in
  fact 1 n

let () =
  for i = 0 to 9 do
    match factorial i with
    | Some result -> Printf.printf "factorial(%d) = %d\n" i result
    | None -> Printf.printf "factorial(%d) = None\n" i
  done