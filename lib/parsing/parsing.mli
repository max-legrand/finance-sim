open Model

module Parsing : sig
  (** Parse a CSV file with stock data into entries. 
      CSV format is expected to be:

      `Ticker, Date, Open, High, Low, Close, Volume`
  *)
  val parse_csv : file:string -> strict:bool -> Model.t

  val parse_json : file:string -> strict:bool -> Model.t
end

val date_string_to_ptime : string -> Ptime.t
