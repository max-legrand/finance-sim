open Alcotest
open Finance_sim
open Core
open Parsing
open Utils

let test_get_log_return () =
  let file = Core_unix.getcwd () |> concat_chain "../../../data/ibm.json" in
  let value = Parsing.parse_json ~file ~strict:false in
  let ibm = Hashtbl.find_exn value "IBM" in
  let results =
    Lwt_main.run
      (Finace_sim.monte_carlo_simulation
         ~starting_price:(List.last_exn ibm).close_price
         ~days:100
         ~num_simulations:10000
         ~prices:ibm
       |> Lwt_stream.to_list)
  in
  Spice.infof "Results_length: %d" (List.length results);
  (* CWD for testing runs in the `_build/default/test` folder *)
  let cwd = Core_unix.getcwd () in
  Spice.infof "CWD: %s" cwd;
  let working_dir = Filename.concat cwd "../../.." in
  let output_file = Filename.concat working_dir "sim_test.json" in
  let json_results =
    `List (List.map results ~f:(fun x -> `List (List.map x ~f:(fun y -> `Float y))))
  in
  Out_channel.write_all output_file ~data:(Yojson.pretty_to_string json_results);
  ()
;;

let () =
  Spice.set_log_level Spice.DEBUG;
  run
    ~verbose:true
    "Finance Sim"
    [ "fsim", [ test_case "get log return" `Quick test_get_log_return ] ]
;;
