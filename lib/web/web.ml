open Core
open Finance_sim
open Model
open Parsing
open Thumper_lwt
open Lwt

let get_stock_data ~ticker file_path =
  let file_data = Yojson.Safe.from_file file_path in
  match file_data with
  | `Assoc a ->
    let stock = a |> List.find_exn ~f:(fun x -> String.equal (fst x) ticker) in
    let data = List.rev (snd stock |> Yojson.Safe.Util.to_list) in
    let body_data =
      a
      |> List.map ~f:(fun item ->
        if String.equal (fst item) ticker then ticker, `List data else item)
    in
    `Assoc body_data |> Yojson.Safe.to_string
  | _ -> raise (Invalid_argument "Invalid data format")
;;

let serve_data (req : Server.request) conn =
  try
    let body = get_stock_data ~ticker:"IBM" "data/ibm.json" in
    let headers = [ "Content-Type", "application/json; charset=utf-8" ] in
    let status = Thumper__Response.S200_OK in
    let _ =
      Server.write_response status body conn ~headers ~request_headers:req.headers ()
    in
    return status
  with
  | e ->
    Spice.errorf "Error fetching data: %s" (Exn.to_string e);
    Server.server_error req conn
;;

let simulate (req : Server.request) oc =
  (* Get the body of the request *)
  let body = req.body in
  let json = Yojson.Safe.from_string body in
  let num_simulations =
    json |> Yojson.Safe.Util.member "num_simulations" |> Yojson.Safe.Util.to_int
  in
  let days = json |> Yojson.Safe.Util.member "num_days" |> Yojson.Safe.Util.to_int in
  let infile = "data/ibm.json" in
  let ticker = "IBM" in
  let data = Parsing.parse_json ~file:infile ~strict:true in
  let items = Model.get_ticker_exn data ~ticker in
  let first_item = List.hd_exn items in
  let starting_price = first_item.close_price in
  let sim_results =
    Finace_sim.monte_carlo_simulation ~starting_price ~days ~num_simulations ~prices:items
  in
  let string_stream =
    Lwt_stream.map
      (fun result ->
         let rev = List.rev result in
         (`List (List.map rev ~f:(fun x -> `Float x)) |> Yojson.Safe.to_string) ^ "\n")
      sim_results
  in
  Server.stream "text/plain" string_stream oc
;;
