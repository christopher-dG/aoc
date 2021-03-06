(* TODO: How to put signatures in an interface file? *)
module type Day = sig
  module Out : sig
    type t

    val equal : t -> t -> bool
  end

  val day : int

  val part1 : string list -> Out.t

  val part2 : string list -> Out.t

  val sol1 : Out.t

  val sol2 : Out.t
end

module Make (D : Day) = struct
  let lines =
    let rec find_input_file dir =
      let open Filename in
      let git = concat dir ".git" in
      let inputs = concat dir "input" in
      if Sys.is_directory_exn git then concat inputs (sprintf "%02d.txt" D.day)
      else find_input_file (dirname dir)
    in
    Unix.getcwd () |> find_input_file |> In_channel.read_lines

  let part1 = D.part1

  let part2 = D.part2

  let%test_module "input" =
    ( module struct
      let ( = ) = D.Out.equal

      let%test "p1" = D.part1 lines = D.sol1

      let%test "p2" = D.part2 lines = D.sol2
    end )

  let%bench_module ("Day"[@name_suffix sprintf "%02d" D.day]) =
    ( module struct
      let%bench "p1" = part1 lines

      let%bench "p2" = part2 lines
    end )
end
