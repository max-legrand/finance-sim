open Core
open Cmdliner
open Common
open Parsing

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
    let _ = Parsing.parse_json ~file:"data/test_json/sample.json" ~strict in
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
  let group =
    Cmd.group (Cmd.info "finance-sim" ~version:"1.0.0" ~sdocs:"" ~exits:[]) [ load_cmd ]
  in
  exit (Cmd.eval group)
;;
