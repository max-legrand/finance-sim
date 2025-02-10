open Model

val monte_carlo_simulation
  :  starting_price:float
  -> days:int
  -> num_simulations:int
  -> prices:Model.price list
  -> float list list
