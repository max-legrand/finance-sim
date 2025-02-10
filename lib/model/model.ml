open Core

module Model = struct
  let ptime_to_yojson ptime =
    let y, m, d = Ptime.to_date ptime in
    `String (Printf.sprintf "%04d-%02d-%02d" y m d)
  ;;

  let ptime_of_yojson json =
    match json with
    | `String s ->
      (match String.split s ~on:'-' with
       | [ year; month; day ] ->
         let ptime =
           Ptime.of_date (Int.of_string year, Int.of_string month, Int.of_string day)
         in
         Ok ptime
       | _ -> Error "Invalid date format")
    | _ -> Error "Expected a string"
  ;;

  type price =
    { date : Ptime.t
    ; open_price : float
    ; high_price : float
    ; low_price : float
    ; close_price : float
    ; volume : float
    }

  let pp_price ppf price =
    Format.fprintf
      ppf
      "{ date = %a; open_price = %f; high_price = %f; low_price = %f; close_price = %f; \
       volume = %f }"
      Ptime.pp
      price.date
      price.open_price
      price.high_price
      price.low_price
      price.close_price
      price.volume
  ;;

  let price_equal p1 p2 =
    if
      Ptime.equal p1.date p2.date
      && Float.equal p1.open_price p2.open_price
      && Float.equal p1.high_price p2.high_price
      && Float.equal p1.low_price p2.low_price
      && Float.equal p1.close_price p2.close_price
      && Float.equal p1.volume p2.volume
    then true
    else (
      Spice.debugf
        "p1=%s | p2=%s"
        (Format.asprintf "%a" pp_price p1)
        (Format.asprintf "%a" pp_price p2);
      false)
  ;;

  type t = (string, price list) Hashtbl.t

  let new_state ?(size = 100) () : t = Hashtbl.create ~size (module String)

  let add_entry (state : t) ~ticker ~price =
    Hashtbl.update state ticker ~f:(fun prices ->
        match prices with
        | Some p -> List.append p [ price ]
        | None -> [ price ])
  ;;

  let equal s1 s2 =
    if Hashtbl.length s1 <> Hashtbl.length s2
    then (
      Spice.debugf "s1_len=%d | s2_len=%d" (Hashtbl.length s1) (Hashtbl.length s2);
      false)
    else
      (* Check the keys *)
      Hashtbl.for_alli s1 ~f:(fun ~key ~data ->
          match Hashtbl.find s2 key with
          | None -> false
          | Some data' ->
            if
              (* Check that the data matches *)
              List.length data <> List.length data'
            then (
              Spice.debugf
                "Ticker: %s - l1_len=%d | l2_len=%d"
                key
                (List.length data)
                (List.length data');
              false)
            else List.for_all2_exn ~f:price_equal data data')
  ;;

  let get_ticker_exn t ~ticker = Hashtbl.find_exn t ticker

  let ptime_to_yojson price =
    `Assoc
      [ "date", ptime_to_yojson price.date
      ; "open_price", `Float price.open_price
      ; "high_price", `Float price.high_price
      ; "low_price", `Float price.low_price
      ; "close_price", `Float price.close_price
      ; "volume", `Float price.volume
      ]
  ;;

  let t_to_yojson t =
    `Assoc
      (Hashtbl.fold t ~init:[] ~f:(fun ~key ~data acc ->
           (key, `List (data |> List.map ~f:ptime_to_yojson)) :: acc))
  ;;
end
