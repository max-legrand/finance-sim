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

  (* Placeholder for the model *)
  let self : t option ref = ref None [@@private]

  let init ?(size = 100) () =
    match !self with
    | None -> self := Some (Hashtbl.create size)
    | Some _ -> ()
  ;;

  let get_state () =
    match !self with
    | None ->
      init ();
      !self |> Option.get
    | Some self -> self
  ;;

  let add_entry ~ticker ~price =
    let state = get_state () in
    match Hashtbl.find_opt state ticker with
    | Some prices -> Hashtbl.replace state ticker (price :: prices)
    | None -> Hashtbl.add state ticker [ price ]
  ;;
end
