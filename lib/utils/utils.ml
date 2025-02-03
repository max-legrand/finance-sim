open Core

let check_exists path =
  try
    ignore (Core_unix.stat path);
    true
  with
  | _ -> false
;;

let concat_chain new_val base = Filename.concat base new_val
