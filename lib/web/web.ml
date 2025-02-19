open Core
open Finance_sim
open Model
open Parsing
open Thumper_lwt
open Lwt

let serve_test (req : Server.request) conn =
  let file_data = Yojson.Safe.from_file "data/ibm.json" in
  let body = Yojson.Safe.to_string file_data in
  let headers = [ "Content-Type", "application/json; charset=utf-8" ] in
  let status = Thumper__Response.S200_OK in
  let _ =
    Server.write_response status body conn ~headers ~request_headers:req.headers ()
  in
  return status
;;

let process_request (_req : Server.request) oc =
  let infile = "data/ibm.json" in
  let ticker = "IBM" in
  let strict = true in
  let days = 100 in
  let simulations = 10000 in
  let data = Parsing.parse_json ~file:infile ~strict in
  let items = Model.get_ticker_exn data ~ticker in
  let starting_price = (List.last_exn items).close_price in
  let sim_results =
    Finace_sim.monte_carlo_simulation
      ~starting_price
      ~days
      ~num_simulations:simulations
      ~prices:items
  in
  let string_stream =
    Lwt_stream.map
      (fun result ->
         (`List (List.map result ~f:(fun x -> `Float x)) |> Yojson.Safe.to_string) ^ "\n")
      sim_results
  in
  Server.stream "text/plain" string_stream oc
;;

let request (req : Server.request) oc =
  (* Get the body of the request *)
  let body = req.body in
  let json = Yojson.Safe.from_string body in
  let num_simulations =
    json |> Yojson.Safe.Util.member "num_simulations" |> Yojson.Safe.Util.to_int
  in
  let status = Thumper__Response.S200_OK in
  let _ =
    Server.write_response
      status
      (Printf.sprintf "%d" num_simulations)
      oc
      ~request_headers:req.headers
      ()
  in
  return status
;;
