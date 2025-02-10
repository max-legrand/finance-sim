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
  log_returns
;;

(** Compute the mean of a list of log returns *)
let mean_log_return (log_returns : float list) =
  (log_returns |> List.fold ~init:0.0 ~f:( +. ))
  /. (List.length log_returns |> Float.of_int)
;;

(** Compute the standard deviation of a list of log returns *)
let get_volatility (log_returns : float list) =
  let average = mean_log_return log_returns in
  let sums =
    List.fold log_returns ~init:0.0 ~f:(fun acc item -> acc +. ((item -. average) ** 2.0))
  in
  let sd = sqrt (sums /. Float.of_int (List.length log_returns - 1)) in
  sd
;;

let pi = 3.141592653

let box_muller_transform () =
  let u = Random.float 1.0 in
  let v = Random.float 1.0 in
  let z = sqrt (-2.0 *. log u) *. Float.cos (2.0 *. pi *. v) in
  z
;;

let compute_next_price (current : float) e_return volatility time days =
  let brownian = box_muller_transform () in
  let exponent =
    ((e_return -. ((volatility ** 2.0) /. 2.0)) *. (Float.of_int time /. Float.of_int days)
    )
    +. (volatility *. brownian)
  in
  let next = current *. exp exponent in
  next
;;

let monte_carlo_simulation
    ~(starting_price : float)
    ~(days : int)
    ~(num_simulations : int)
    ~(prices : Model.price list)
  : float list list
  =
  let log_returns = compute_log_returns prices in
  let mean_return = mean_log_return log_returns in
  let volatility = get_volatility log_returns in
  let rec loop iter (results : float list list) =
    if iter = num_simulations
    then List.rev results
    else (
      let previous = ref starting_price in
      let simulated_prices =
        List.init days ~f:(fun day ->
            if day = 0
            then !previous
            else (
              let current = compute_next_price !previous mean_return volatility day days in
              previous := current;
              current))
      in
      loop (iter + 1) (simulated_prices :: results))
  in
  loop 0 []
;;
