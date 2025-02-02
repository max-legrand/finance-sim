open Core
open Model

module Parsing = struct
  (** Parse a CSV line into an entry *)
  let __parse_csv_line line : string * Model.price =
    Spice.debugf "Parsing CSV line %s" line;
    match String.split_on_chars line ~on:[ ',' ] with
    | [ ticker; date_str; open_str; high_str; low_str; close_str; volume_str ] ->
      let year, month, date =
        match String.split_on_chars date_str ~on:[ '-' ] with
        | [ year; month; day ] -> year, month, day
        | _ -> failwithf "Invalid date format! %s" date_str ()
      in
      let date =
        match
          Ptime.of_date (Int.of_string year, Int.of_string month, Int.of_string date)
        with
        | Some date -> date
        | None -> failwith "Invalid date format!"
      in
      ( ticker
      , { date
        ; open_price = Float.of_string open_str
        ; high_price = Float.of_string high_str
        ; low_price = Float.of_string low_str
        ; close_price = Float.of_string close_str
        ; volume = Float.of_string volume_str
        } )
    | _ -> failwith "Invalid CSV line!"
  ;;

  (**
       Parse a CSV file with stock data into entries. 
       CSV format is expected to be:

        `Ticker, Date, Open, High, Low, Close, Volume`
  *)
  let parse_csv file =
    Spice.debugf "Parsing CSV file %s" file;
    let data = In_channel.read_all file in
    String.split_lines data
    |> List.iteri ~f:(fun idx line ->
        if idx <> 0
        then (
          let ticker, price = __parse_csv_line line in
          Model.add_entry ~ticker ~price));
    ()
  ;;
end
