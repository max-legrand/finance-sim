open Model
open Core

let compute_log_return (current : Model.price) (prev : Model.price) =
  log (current.close_price /. prev.close_price)
;;

let compute_log_returns (data : Model.price list) =
  let log_returns =
    List.filter_mapi data ~f:(fun idx item ->
        if idx = 0
        then None
        else Some (compute_log_return item (List.nth_exn data (idx - 1))))
  in
  List.iter log_returns ~f:(fun log_return -> Spice.debugf "Log return: %f" log_return);
  log_returns
;;

(** Compute the mean of a list of log returns *)
let mean_log_return (log_returns : float list) =
  (log_returns |> List.fold ~init:0.0 ~f:(fun acc item -> acc +. item))
  /. (List.length log_returns |> Float.of_int)
;;

(** Compute the standard deviation of a list of log returns *)
let get_volatility (log_returns : float list) =
  let average = mean_log_return log_returns in
  let sums =
    List.fold log_returns ~init:0.0 ~f:(fun acc item -> acc +. ((item -. average) ** 2.0))
  in
  let sd = sqrt (sums /. Float.of_int (List.length log_returns)) in
  sd
;;

let e = 2.718281828459045235360287471352
let compute_next_price current e_return volatility = ()
