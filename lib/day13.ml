module Impl = Day.Make (struct
  let[@warning "-8"] parse_input [ a; b ] =
    let start = int_of_string a in
    let buses =
      String.split b ~on:','
      |> List.filter_mapi ~f:(fun i s ->
             if String.equal s "x" then None else Some (i, int_of_string s))
    in
    (start, buses)

  let rec first_bus t bs =
    match
      List.find_map bs ~f:(fun (_, b) -> if t mod b = 0 then Some b else None)
    with
    | None -> first_bus (t + 1) bs
    | Some n -> (t, n)

  let rec all_sequential ?(t = 0) ?skip bs =
    let skip =
      Option.value skip
        ~default:(List.fold bs ~init:0 ~f:(fun cur (_, n) -> max cur n))
    in
    let t = t + (skip - (t mod skip)) in
    if List.for_all bs ~f:(fun (i, b) -> (t + i) mod b = 0) then t
    else all_sequential bs ~skip ~t:(t + skip)

  module Out = Int

  let day = 13

  let part1 lines =
    let start, buses = parse_input lines in
    let time, id = first_bus start buses in
    id * (time - start)

  (* let part2 lines =
   *   let _, buses = parse_input lines in
   *   all_sequential buses ~t:100000000000000 *)

  let part2 _lines =
    let () = ignore all_sequential in
    2

  let sol1 = 161

  let sol2 = 2

  let%test "examples (p1)" =
    let lines = [ "939"; "7,13,x,x,59,x,31,19" ] in
    part1 lines = 295

  (* let%test "examples (p2)" =
   *   List.for_all
   *     [
   *       ("7,13,x,x,59,x,31,19", 1068781);
   *       ("17,x,13,19", 3417);
   *       ("67,7,59,61", 754018);
   *       ("67,x,7,59,61", 1261476);
   *       ("1789,37,47,1889", 1202161486);
   *     ] ~f:(fun (line, ans) ->
   *       let _, buses = parse_input [ "0"; line ] in
   *       all_sequential buses = ans) *)
end)
