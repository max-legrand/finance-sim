open Alcotest
open Finance_sim
open Core
open Parsing
open Utils

let test_get_log_return () =
  let file = Core_unix.getcwd () |> concat_chain "../../../data/ibm.json" in
  let value = Parsing.parse_json ~file ~strict:false in
  let ibm = Hashtbl.find_exn value "IBM" in
  Finace_sim.compute_log_returns ibm |> ignore
;;

let () =
  Spice.set_log_level Spice.DEBUG;
  run
    ~verbose:true
    "Finance Sim"
    [ "fsim", [ test_case "get log return" `Quick test_get_log_return ] ]
;;
