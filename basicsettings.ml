(**
 Whether to run the interactive loop
 (default is true)
*)
let interacting = Settings.add_bool ("interacting", true, `System)

(** [true] if we're in web mode *)
let web_mode = Settings.add_bool ("web_mode", false, `System)

(** Set this to [true] to print types when printing results. *)
let printing_types = Settings.add_bool ("printing_types", true, `User)

(** Name of the file containing the prelude code. *)
let prelude_file = Settings.add_string ("prelude", "prelude.links", `System)

(** The banner *)
let welcome_note = Settings.add_string ("welcome_note", 
"  _     _ __    _ _  __  ___
 / |   | |  \\  | | |/ / / ._\\
 | |   | | , \\ | |   /  \\  \\
 | |___| | |\\ \\  | |\\ \\ _\\  \\
 |_____|_|_| \\___|_| \\_|____/
Welcome to Links version 0.4 (Crostorfyn)", `System)

(** Allow impure top-level definitions *)
let allow_impure_defs = Settings.add_bool("allow_impure_defs", false, `User)

(** JS stuff *)
(* needs to go here as long as we have two different JS compilers *)
module Js =
struct
  let optimise = Settings.add_bool("optimise_javascript", true, `User)
  let elim_dead_defs = Settings.add_bool("elim_dead_defs", false, `User)
  let lib_url = Settings.add_string("jsliburl", "lib/", `User)
  let pp = Settings.add_bool("js_pretty_print", true, `User)
end

(* Caveat: don't [Open basicsettings] because the above module
   conflicts with the Js module from js.ml*)

(* Installed preprocessor *)
let pp = Settings.add_string("preprocessor", "", `System)

(* whether to use the new IR in the frontend *)
let ir = Settings.add_bool("ir", false, `User)

(* Whether to print the IR rather than run it *)
let pretty_print_ir = Settings.add_bool("pretty_print_ir", false, `User)

(* default database settings *)
let database_driver = Settings.add_string("database_driver", "", `User)
let database_args = Settings.add_string("database_args", "", `User)

(** Set this to [true] to print the body and environment of a
    function. When [false], functions are simply printed as "fun" *)
let printing_functions = Settings.add_bool ("printing_functions", false, `User)

(* caching *)
let cache_directory = 
  Settings.add_string ("cache_directory", "", `User)
let use_cache = Settings.add_bool("use_cache", true, `System)
let make_cache = Settings.add_bool("make_cache", true, `System)
