open Alcotest
open Core
open Parsing
open Model
open Utils

let test_csv_valid () =
  (* CWD for testing runs in the `_build/default/test_csv/<module>` folder *)
  let file = Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/sample.csv" in
  let value = Parsing.parse_csv ~file ~strict:false in
  let expected : Model.t =
    Hashtbl.of_alist_exn
      (module String)
      [ ( "AAPL"
        , [ { Model.date = Ptime.of_date (2024, 2, 1) |> Option.value_exn
            ; open_price = 161.67
            ; high_price = 162.25
            ; low_price = 159.75
            ; close_price = 160.00
            ; volume = 50000000.0
            }
          ; { Model.date = Ptime.of_date (2024, 2, 2) |> Option.value_exn
            ; open_price = 160.0
            ; high_price = 160.50
            ; low_price = 159.75
            ; close_price = 159.99
            ; volume = 48000000.0
            }
          ] )
      ]
  in
  let valid = Model.equal value expected in
  Alcotest.check bool "Hashtables should be equal" true valid
;;

let test_csv_invalid_header () =
  let file =
    Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/invalid_header.csv"
  in
  try
    let _value = Parsing.parse_csv ~file ~strict:true in
    Alcotest.fail "Should have failed!"
  with
  | Failure msg ->
    Alcotest.check
      string
      "Should have failed with invalid header"
      msg
      "Invalid CSV header! Expected: `Ticker,Date,Open,High,Low,Close,Volume`, got: \
       Extra,Ticker,Date,Open,High,Low,Close,Volume"
;;

let test_csv_invalid_data () =
  let file =
    Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/invalid_data.csv"
  in
  try
    let _value = Parsing.parse_csv ~file ~strict:true in
    Alcotest.fail "Should have failed!"
  with
  | e ->
    Alcotest.check
      string
      "Should have failed with Float conversion error"
      {|(Failure "Invalid CSV line! Invalid float: Float.of_string a")|}
      (Exn.to_string e)
;;

let test_csv_invalid_date () =
  let file =
    Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/invalid_date.csv"
  in
  try
    let _value = Parsing.parse_csv ~file ~strict:true in
    Alcotest.fail "Should have failed!"
  with
  | e ->
    Alcotest.check
      string
      "Should have failed with invalid date"
      {|(Failure "Invalid date format!")|}
      (Exn.to_string e)
;;

let test_csv_empty_file () =
  let file = Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/empty.csv" in
  let value = Parsing.parse_csv ~file ~strict:true in
  let expected : Model.t = Model.new_state () in
  let valid = Model.equal value expected in
  Alcotest.check bool "Hashtables should be equal" true valid
;;

let test_csv_extra_column () =
  let file =
    Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/extra_column.csv"
  in
  try
    let _value = Parsing.parse_csv ~file ~strict:true in
    Alcotest.fail "Should have failed!"
  with
  | e ->
    Alcotest.check
      string
      "Should have failed with invalid CSV line"
      {|(Failure "Invalid CSV line!")|}
      (Exn.to_string e)
;;

let test_missing_column () =
  let file =
    Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/missing_column.csv"
  in
  try
    let _value = Parsing.parse_csv ~file ~strict:true in
    Alcotest.fail "Should have failed!"
  with
  | e ->
    Alcotest.check
      string
      "Should have failed with invalid CSV line"
      {|(Failure "Invalid CSV line!")|}
      (Exn.to_string e)
;;

let test_large_file () =
  (* CWD for testing runs in the `_build/default/test_csv/<module>` folder *)
  let file = Core_unix.getcwd () |> concat_chain "../../../../data/test_csv/large.csv" in
  let value = Parsing.parse_csv ~file ~strict:false in
  let expected : Model.t = Model.new_state () in
  let base_date = Ptime.of_date (2024, 2, 1) |> Option.value_exn in
  let base_volume = 40000000 in
  for i = 0 to 616 do
    let span =
      match Ptime.Span.of_d_ps (i, 0L) with
      | Some span -> span
      | None -> failwith "Invalid date span!"
    in
    let date =
      match Ptime.add_span base_date span with
      | None -> failwith "Invalid date addition!"
      | Some d -> d
    in
    Model.add_entry
      expected
      ~ticker:"AAPL"
      ~price:
        { date
        ; open_price = 160.0
        ; high_price = 160.5
        ; low_price = 159.75
        ; close_price = 160.0
        ; volume = Float.of_int (base_volume + (1000000 * i))
        }
  done;
  let valid = Model.equal value expected in
  Alcotest.check bool "Hashtables should be equal" true valid
;;

let () =
  Spice.set_log_level Spice.DEBUG;
  run
    ~verbose:true
    "Parsing"
    [ ( "CSV"
      , [ test_case "valid CSV" `Quick test_csv_valid
        ; test_case "invalid header" `Quick test_csv_invalid_header
        ; test_case "invalid data" `Quick test_csv_invalid_data
        ; test_case "invalid date" `Quick test_csv_invalid_date
        ; test_case "empty file" `Quick test_csv_empty_file
        ; test_case "extra column" `Quick test_csv_extra_column
        ; test_case "missing column" `Quick test_missing_column
        ; test_case "large file" `Quick test_large_file
        ] )
    ]
;;
