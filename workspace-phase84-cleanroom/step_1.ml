let rec fibonacci n =
  if n <= 0 then
    0
  else if n = 1 then
    1
  else
    fibonacci (n - 1) + fibonacci (n - 2)

let () =
  for i = 0 to 9 do
    Printf.printf "fib(%d) = %d\n" i (fibonacci i)
  done