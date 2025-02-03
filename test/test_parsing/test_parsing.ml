open Parsing

let test_valid () =
  let _value = Parsing.parse_csv ~file:"data/sample.csv" ~strict:false in
  ()
;;

let () =
  Spice.info "Testing parsing module";
  test_valid ()
;;
