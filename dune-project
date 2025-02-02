(lang dune 3.16)

(name finance_sim)

(generate_opam_files true)

(source
 (github max-legrand/finance-sim))

(authors "Maxwell Legrand")

(maintainers "Maxwell Legrand")

(package
 (name finance_sim)
 (depends
   ocaml dune lwt stdio base cmdliner core core_unix ptime
 )
)
; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
