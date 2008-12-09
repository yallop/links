open Utility
open Types

module Env = Env.String

(** type destructors *)
exception TypeDestructionError of string

let error t = raise (TypeDestructionError t)


(** remove any top-level meta typevars and aliases from a type
    (perhaps we can use this version of concrete_type everywhere)
*)
let concrete_type t =
  let rec ct rec_names t : datatype =
    match t with
      | `Alias (_, t) -> ct rec_names t
      | `MetaTypeVar point ->
          begin
            match Unionfind.find point with
              | `Body t -> ct rec_names t
              | `Recursive (_, t) ->
                  ct rec_names t
              | _ -> t
          end
      | _ -> t
  in
    ct (StringSet.empty) t

let rec extract_row t = match concrete_type t with
  | `Record row -> row
  | `Variant row -> row
  | t ->
      failwith
        ("Internal error: attempt to extract a row from a datatype that is not a record or a variant: " 
         ^ string_of_datatype t)

let split_row name row =
  let (field_env, row_var) = fst (unwrap_row row) in
  let t =
    if StringMap.mem name field_env then
      match (StringMap.find name field_env) with
        | `Present, t -> t
        | `Absent, _ -> 
            error ("Attempt to split row "^string_of_row row ^" on absent field" ^ name)
    else
      error ("Attempt to split row "^string_of_row row ^" on absent field" ^ name)
  in
    t, (StringMap.remove name field_env, row_var)

let rec variant_at name t = match concrete_type t with
  | `ForAll (_, t) -> variant_at name t
  | `Variant row ->
      let t, _ = split_row name row in t
  | t ->
      error ("Attempt to deconstruct non-variant type "^string_of_datatype t)

let rec split_variant_type name t = match concrete_type t with
  | `ForAll (_, t) -> split_variant_type name t
  | `Variant row ->
      let t, row = split_row name row in
        `Variant (make_singleton_closed_row (name, (`Present, t))), `Variant row
  | t ->
      error ("Attempt to split non-variant type "^string_of_datatype t)

let rec project_type name t = match concrete_type t with
  | `ForAll (_, t) -> project_type name t
  | `Record row ->
      let t, _ = split_row name row in
        t
  | t -> 
      error ("Attempt to project non-record type "^string_of_datatype t)
    
let rec erase_type name t = match concrete_type t with
  | `ForAll (_, t) -> erase_type name t
  | `Record row ->
      let t, row = split_row name row in
        `Record row
  | t -> error ("Attempt to erase field from non-record type "^string_of_datatype t)

let rec return_type t = match concrete_type t with
  | `ForAll (_, t) -> return_type t
  | `Function (_, _, t) -> t
  | t -> 
      error ("Attempt to take return type of non-function: " ^ string_of_datatype t)

let rec arg_types t = match concrete_type t with
  | `ForAll (_, t) -> arg_types t
  | `Function (`Record row, _, _) ->
      extract_tuple row
  | t ->
      error ("Attempt to take arg types of non-function: " ^ string_of_datatype t)

let rec mailbox_type t = match concrete_type t with
  | `ForAll (_, t) -> mailbox_type t
  | `Function (_, mb, _) -> mb
  | t ->
      error ("Attempt to take mailbox type of non-function: " ^ string_of_datatype t)

let rec element_type t = match concrete_type t with
  | `ForAll (_, t) -> element_type t
  | `Application (l, [t])
      when Types.Abstype.Eq_t.eq l Types.list -> t
  | t ->
      error ("Attempt to take element type of non-list: " ^ string_of_datatype t)

let rec table_read_type t = match concrete_type t with
  | `ForAll (_, t) -> table_read_type t
  | `Table (r, _) -> r
  | t ->
      error ("Attempt to take read type of non-table: " ^ string_of_datatype t)

let rec table_write_type t = match concrete_type t with
  | `ForAll (_, t) -> table_write_type t
  | `Table (_, w) -> w
  | t ->
      error ("Attempt to take write type of non-table: " ^ string_of_datatype t)

let inject_type name t =
  `Variant (make_singleton_open_row (name, (`Present, t)))

let abs_type _ = assert false
let app_type _ _ = assert false

let quantifiers t = match concrete_type t with
  | `ForAll (qs, _) -> qs
  | _ -> []

let record_without t names =
  match concrete_type t with
    | `Record ((fields, row_var) as row) ->
        if is_closed_row row then
          `Record
            (StringSet.fold (fun name fields -> StringMap.remove name fields) names fields,
             row_var)
        else
          `Record
            (StringMap.mapi
               (fun name (flag, t) ->
                  if StringSet.mem name names then
                    `Absent, t
                  else
                    flag, t)
               fields,
             row_var)
    | _ -> assert false
