open Core
open Model

let date_string_to_ptime date_str =
  let year, month, date =
    match String.split_on_chars date_str ~on:[ '-' ] with
    | [ year; month; day ] -> year, month, day
    | _ -> failwithf "Invalid date format! %s" date_str ()
  in
  let date =
    match Ptime.of_date (Int.of_string year, Int.of_string month, Int.of_string date) with
    | Some date -> date
    | None -> failwith "Invalid date format!"
  in
  date
;;

module Parsing = struct
  (** Parse a CSV line into an entry *)
  let parse_csv_line line : string * Model.price =
    match String.split_on_chars line ~on:[ ',' ] with
    | [ ticker; date_str; open_str; high_str; low_str; close_str; volume_str ] ->
      let date = date_string_to_ptime date_str in
      (try
         ( ticker
         , { date
           ; open_price = Float.of_string open_str
           ; high_price = Float.of_string high_str
           ; low_price = Float.of_string low_str
           ; close_price = Float.of_string close_str
           ; volume = Float.of_string volume_str
           } )
       with
       | Invalid_argument msg -> failwithf "Invalid CSV line! Invalid float: %s" msg ()
       | e -> failwithf "Invalid CSV line! %s" (Exn.to_string e) ())
    | _ -> failwith "Invalid CSV line!"
  [@@private]
  ;;

  (**
       Parse a CSV file with stock data into entries. 
       CSV format is expected to be:

        `Ticker, Date, Open, High, Low, Close, Volume`
  *)
  let parse_csv ~file ~strict =
    let state : Model.t = Model.new_state () in
    let data = In_channel.read_all file in
    String.split_lines data
    |> List.iteri ~f:(fun idx line ->
      if idx <> 0
      then (
        try
          let ticker, price = parse_csv_line line in
          Model.add_entry state ~ticker ~price
        with
        | Failure msg -> if strict then failwith msg else Spice.warnf "%s" msg)
      else if not (String.equal line "Ticker,Date,Open,High,Low,Close,Volume")
      then
        failwithf
          "Invalid CSV header! Expected: `Ticker,Date,Open,High,Low,Close,Volume`, got: \
           %s"
          line
          ()
      else ());
    state
  ;;

  let get_string key json_object =
    json_object |> Yojson.Safe.Util.member key |> Yojson.Safe.Util.to_string
  ;;

  let get_float key json_object =
    json_object |> Yojson.Safe.Util.member key |> Yojson.Safe.Util.to_float
  ;;

  let json_value_to_entry value =
    try
      let date_string = value |> get_string "date" in
      let date = date_string_to_ptime date_string in
      let open_price = get_float "open_price" value in
      let close_price = get_float "close_price" value in
      let low_price = get_float "low_price" value in
      let high_price = get_float "high_price" value in
      let volume = get_float "volume" value in
      { Model.date; open_price; close_price; low_price; high_price; volume }
    with
    | Failure msg -> failwith msg
  ;;

  let parse_value value =
    match value with
    | `List items -> items |> List.map ~f:json_value_to_entry
    | _ -> failwith "Expected a list of JSON objects!"
  ;;

  (** Parse a JSON file with stock data into entries. *)
  let parse_json ~file ~strict =
    let state : Model.t = Model.new_state () in
    let data = In_channel.read_all file in
    let _json = data |> Yojson.Safe.from_string in
    (match _json with
     | `Assoc items ->
       items
       |> List.iter ~f:(fun kv ->
         let key, json_value = kv in
         Hashtbl.add state ~key ~data:[] |> ignore;
         let value = parse_value json_value in
         List.iter value ~f:(fun price ->
           try Model.add_entry state ~ticker:key ~price with
           | Failure msg -> if strict then failwith msg else Spice.warnf "Invalid JSON!"
           | e ->
             if strict
             then failwith (Exn.to_string e)
             else Spice.warnf "%s" (Exn.to_string e)))
     | _ -> failwith "Invalid JSON!");
    state
  ;;
end
