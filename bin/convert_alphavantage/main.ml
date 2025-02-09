open Core
open Cmdliner
open Model

let fix_equals_arg file =
  if String.length file > 0 && Char.equal file.[0] '='
  then String.sub file ~pos:1 ~len:(String.length file - 1)
  else file
;;

let validate_args file output =
  let check_extension filename =
    match Filename.split_extension filename with
    | _, Some ext when String.equal ext "json" -> Ok ()
    | _ -> Error (`Msg (Printf.sprintf "File %s must have a .json extension" filename))
  in
  match check_extension file, check_extension output with
  | Ok (), Ok () -> Ok ()
  | Error (`Msg err), _ | _, Error (`Msg err) -> Error (`Msg err)
;;

let parse_alphavantage_json_file filepath =
  try
    let data = In_channel.read_all filepath in
    let json = Yojson.Safe.from_string data in
    Ok json
  with
  | Sys_error err -> Error (`Msg (Printf.sprintf "Error reading file: %s" err))
  | Yojson.Json_error err -> Error (`Msg (Printf.sprintf "Error parsing JSON: %s" err))
;;

let kv_to_entry kv =
  let key, value = kv in
  { Model.date = Parsing.date_string_to_ptime key
  ; open_price =
      Yojson.Safe.Util.member "1. open" value
      |> Yojson.Safe.Util.to_string
      |> Float.of_string
  ; high_price =
      Yojson.Safe.Util.member "2. high" value
      |> Yojson.Safe.Util.to_string
      |> Float.of_string
  ; low_price =
      Yojson.Safe.Util.member "3. low" value
      |> Yojson.Safe.Util.to_string
      |> Float.of_string
  ; close_price =
      Yojson.Safe.Util.member "4. close" value
      |> Yojson.Safe.Util.to_string
      |> Float.of_string
  ; volume =
      Yojson.Safe.Util.member "5. volume" value
      |> Yojson.Safe.Util.to_string
      |> Float.of_string
  }
;;

let main file_raw output_raw =
  let file = fix_equals_arg file_raw in
  let output = fix_equals_arg output_raw in
  match validate_args file output with
  | Error (`Msg err) -> `Error (true, err)
  | Ok _ ->
    (match parse_alphavantage_json_file file with
     | Error (`Msg err) -> `Error (true, err)
     | Ok json ->
       Spice.infof "Converting %s to %s" file output;
       let data =
         json
         |> Yojson.Safe.Util.member "Time Series (Daily)"
         |> Yojson.Safe.Util.to_assoc
       in
       Spice.infof "Processing %d items" (data |> List.length);
       let result = data |> List.map ~f:kv_to_entry in
       let ticker =
         json
         |> Yojson.Safe.Util.member "Meta Data"
         |> Yojson.Safe.Util.member "2. Symbol"
         |> Yojson.Safe.Util.to_string
       in
       let m = Model.new_state () in
       Hashtbl.set m ~key:ticker ~data:result;
       let output_JSON = Model.t_to_yojson m |> Yojson.Safe.pretty_to_string in
       Out_channel.write_all output ~data:output_JSON;
       `Ok ())
;;

let () =
  let file =
    let doc = "File to convert" in
    Arg.(required (opt (some string) None & info [ "f"; "file" ] ~doc ~docv:"FILE"))
  in
  let output =
    let doc = "Ouput file" in
    Arg.(required (opt (some string) None & info [ "o"; "output" ] ~doc ~docv:"OUTPUT"))
  in
  let cmd_t = Term.(ret (const main $ file $ output)) in
  let cmd = Cmd.v (Cmd.info "convert_alphavantage") cmd_t in
  exit (Cmd.eval cmd)
;;
