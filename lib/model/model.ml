module Model = struct
  type price =
    { date : Ptime.t
    ; open_price : float
    ; high_price : float
    ; low_price : float
    ; close_price : float
    ; volume : float
    }

  type t = (string, price list) Hashtbl.t

  let new_state ?(size = 100) () : t = Hashtbl.create size

  let add_entry state ~ticker ~price =
    match Hashtbl.find_opt state ticker with
    | Some prices -> Hashtbl.replace state ticker (price :: prices)
    | None -> Hashtbl.add state ticker [ price ]
  ;;
end
