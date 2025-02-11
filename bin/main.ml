open Core
open Cmdliner
open Common
open Parsing
open Finance_sim
open Thumper
open Model

type load_type =
  | CSV
  | JSON
  | API

let load ~verbose ~data_type ~strict =
  Common.setup_logging verbose;
  Spice.info "Hello, world!";
  match data_type with
  | CSV ->
    Spice.info "Loading CSV data";
    let _ = Parsing.parse_csv ~file:"data/test_csv/sample.csv" ~strict in
    ()
  | JSON ->
    Spice.info "Loading JSON data";
    let _ = Parsing.parse_json ~file:"data/test/sample.csv" ~strict in
    ()
  | API -> Spice.info "Loading API data"
;;

let load_type_conv =
  let parser s =
    match String.lowercase s with
    | "csv" -> Ok CSV
    | "json" -> Ok JSON
    | "api" -> Ok API
    | _ -> Error (`Msg "Invalid data")
  in
  let printer fmt = function
    | CSV -> Format.fprintf fmt "csv"
    | JSON -> Format.fprintf fmt "json"
    | API -> Format.fprintf fmt "api"
  in
  Arg.conv (parser, printer)
;;

let run_server () =
  Async.Thread_safe.block_on_async_exn (fun () -> Server.start_server 3006)
;;

let simulate ~infile ~outfile ~days ~simulations ~ticker ~strict =
  let _ = infile in
  let _ = outfile in
  let _ = days in
  let _ = simulations in
  let _ = ticker in
  let _ = strict in
  let _, ext = Filename.split_extension infile in
  match ext with
  | Some x when String.equal x "csv" || String.equal x "json" ->
    let data =
      match x with
      | "csv" -> Parsing.parse_csv ~file:infile ~strict
      | "json" -> Parsing.parse_json ~file:infile ~strict
      | _ -> failwith "Not possible!"
    in
    let items = Model.get_ticker_exn data ~ticker in
    let results =
      Finace_sim.monte_carlo_simulation
        ~starting_price:(List.hd_exn items).close_price
        ~days
        ~num_simulations:simulations
        ~prices:items
    in
    let json_results =
      `List (List.map results ~f:(fun x -> `List (List.map x ~f:(fun y -> `Float y))))
    in
    Out_channel.write_all outfile ~data:(Yojson.pretty_to_string json_results);
    `Ok ()
  | _ -> `Error (true, "Input file must be a CSV or JSON file")
;;

let () =
  let load_cmd =
    let data_type =
      let doc = "Type of data to load: csv, json, or api." in
      Arg.(required & opt (some load_type_conv) None & info [ "data-type"; "d" ] ~doc)
    in
    let strict =
      let doc = "Fail on invalid data." in
      Arg.(value & flag & info [ "strict"; "s" ] ~doc)
    in
    let load_t =
      Term.(
        const (fun verbose data_type strict -> load ~verbose ~data_type ~strict)
        $ verbose
        $ data_type
        $ strict)
    in
    Cmd.v (Cmd.info "load" ~doc:"Load data into the model") load_t
  in
  let simulate_cmd =
    let infile =
      let doc = "Input file to load. Must be a CSV or JSON file." in
      Arg.(required & opt (some string) None & info [ "input"; "i" ] ~doc)
    in
    let strict =
      let doc = "Fail on invalid data." in
      Arg.(value & flag & info [ "strict"; "s" ] ~doc)
    in
    let outfile =
      let doc = "Output file to write. Must be a JSON" in
      Arg.(required & opt (some string) None & info [ "output"; "o" ] ~doc)
    in
    let days =
      let doc = "Number of days to simulate." in
      Arg.(required & opt (some int) None & info [ "days"; "d" ] ~doc)
    in
    let simulations =
      let doc = "Number of simulations to run." in
      Arg.(required & opt (some int) None & info [ "simulations"; "n" ] ~doc)
    in
    let ticker =
      let doc = "Ticker to simulate." in
      Arg.(required & opt (some string) None & info [ "ticker"; "t" ] ~doc)
    in
    let simulat_t =
      Term.(
        ret
          (const (fun infile outfile days simulations ticker strict ->
               simulate ~infile ~outfile ~days ~simulations ~ticker ~strict)
           $ infile
           $ outfile
           $ days
           $ simulations
           $ ticker
           $ strict))
    in
    Cmd.v (Cmd.info "simulate" ~doc:"Simulate") simulat_t
  in
  (* Webserver start *)
  let serve_cmd =
    let serve_t = Term.(const run_server $ const ()) in
    Cmd.v (Cmd.info "serve" ~doc:"Start the webserver") serve_t
  in
  let group =
    Cmd.group
      (Cmd.info "finance-sim" ~version:"1.0.0" ~sdocs:"" ~exits:[])
      [ load_cmd; simulate_cmd; serve_cmd ]
  in
  exit (Cmd.eval group)
;;
