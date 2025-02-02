open Cmdliner

let verbose =
  let doc = "Enable verbose logging" in
  Arg.(value & flag & info [ "v"; "verbose" ] ~doc)
;;

let setup_logging verbose = if verbose then Spice.set_log_level Spice.DEBUG
