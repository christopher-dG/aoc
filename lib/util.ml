let read_lines path = path |> In_channel.read_lines

let read_ints path = path |> read_lines |> List.map ~f:int_of_string

let input_file day =
  let open Filename in
  let rec parent path n =
    if Int.equal n 0 then path else parent (dirname path) (n - 1)
  in
  let txt = concat "input" (sprintf "%d.txt" day) in
  let cwd = Unix.getcwd () in
  let depth = if String.contains cwd '_' then 5 else 2 in
  let this = to_absolute_exn __FILE__ ~relative_to:cwd in
  let root = parent this depth in
  concat root txt
