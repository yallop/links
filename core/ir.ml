(*pp deriving *)
(** Monadic IR *)


open Utility

type scope = Var.scope
  deriving (Show)
(* term variables *)
type var = Var.var
  deriving (Show, Eq, Typeable, Pickle, Dump)
type var_info = Var.var_info
  deriving (Show)
type binder = Var.binder
  deriving (Show)

(* type variables *)
type tyvar = Types.quantifier
  deriving (Show)
type tyarg = Types.type_arg
  deriving (Show)

type name = string
  deriving (Show)

type name_set = Utility.stringset
  deriving (Show)
type 'a name_map = 'a Utility.stringmap
  deriving (Show)

type 'a var_map = 'a Utility.intmap
  deriving (Show)

type language = string
  deriving (Show)

let var_of_binder (x, _) = x

type constant = Constant.constant
  deriving (Show)

type location = Sugartypes.location
  deriving (Show)

type value =
  [ `Constant of constant
  | `Variable of var
  | `Extend of (value name_map * value option)
  | `Project of (name * value)
  | `Erase of (name_set * value)
  | `Inject of (name * value * Types.datatype)

  | `TAbs of tyvar list * value
  | `TApp of value * tyarg list

  | `XmlNode of (name * value name_map * value list)
  | `ApplyPure of (value * value list)

  | `Closure of var * value

  | `Coerce of (value * Types.datatype)
  ]
and tail_computation =
  [ `Return of (value)
  | `Apply of (value * value list)
  (* | `ApplyClosure of (value * value list) *)

  | `Special of special

  | `Case of (value * (binder * computation) name_map * (binder * computation) option)
  | `If of (value * computation * computation)
  ]
and fun_def = binder * (tyvar list * binder list * computation) * binder option * location
and binding =
  [ `Let of binder * (tyvar list * tail_computation)
  | `Fun of fun_def
  | `Rec of fun_def list
  | `Alien of (binder * name * language)
  | `Module of (string * binding list option) ]
and special =
  [ `Wrong of Types.datatype
  | `Database of value
  | `Table of (value * value * value * (Types.datatype * Types.datatype * Types.datatype))
  | `Query of (value * value) option * computation * Types.datatype
  | `Update of (binder * value) * computation option * computation
  | `Delete of (binder * value) * computation option
  | `CallCC of (value)
  | `Select of (name * value)
  | `Choice of (value * (binder * computation) name_map)
  | `Handle of handler
  | `DoOperation of (name * value list * Types.datatype) ]
and computation = binding list * tail_computation
and effect_case = binder * binder * computation
and handler = {
    ih_comp: computation;
    ih_cases: effect_case name_map;
    ih_return: binder * computation;
    ih_depth: handler_depth;
}
and handler_depth = [`Deep of (binder * value) list | `Shallow]
  deriving (Show)

let binding_scope : binding -> scope =
  function
  | `Let (b, _)
  | `Fun (b, _, _, _)
  | `Rec ((b, _, _, _)::_)
  | `Alien (b, _, _) -> Var.scope_of_binder b
  | `Rec []
  | `Module _ -> assert false

let binder_of_fun_def (fb, _, _, _) = fb

let tapp (v, tyargs) =
  match tyargs with
    | [] -> v
    | _ -> `TApp (v, tyargs)

let letm (b, tc) = `Let (b, ([], tc))
let letmv (b, v) = letm (b, `Return v)
(*let letv (b, v) = `Let (b, `Return v)*)

let rec is_atom =
  function
    | `Constant (`Bool _)
    | `Constant (`Int _)
    | `Constant (`Char _)
    | `Constant (`Float _)
    | `Variable _ -> true
(*
  This can only be an atom if
  Erase is just an upcast, and our language
  is properly parametric.
*)
(*    | `Erase (_, v) *)
    | `Coerce (v, _) -> is_atom v
    | _ -> false

let with_bindings bs' (bs, tc) = (bs' @ bs, tc)

type program = computation
  deriving (Show)

let string_of_var = string_of_int

let string_of_value _ = "[VALUE]"
let string_of_tail_computation _ = "[TAIL_COMPUTATION]"
let string_of_binding _ = "[BINDING]"
let string_of_special _ = "[SPECIAL]"
let string_of_computation _ = "[COMPUTATION]"
let string_of_program _ = "[PROGRAM]"

(** Traversal with type reconstruction

    Essentially this is a map-fold operation over the IR datatypes
    that also constructs the type as it goes along (using type
    annotations on binders).
*)
module type TRANSFORM =
sig
  type environment = Types.datatype Env.Int.t

  class visitor : environment ->
  object ('self_type)
    val tyenv : environment

    method lookup_type : var -> Types.datatype
    method constant : constant -> (constant * Types.datatype * 'self_type)
    method optionu :
      'a.
      ('self_type -> 'a -> ('a * 'self_type)) ->
      'a option -> 'a option * 'self_type
    method option :
      'a.
      ('self_type -> 'a -> ('a * Types.datatype * 'self_type)) ->
      'a option -> 'a option * Types.datatype option * 'self_type
    method list :
      'a.
      ('self_type -> 'a -> ('a * Types.datatype * 'self_type)) ->
      'a list -> 'a list * Types.datatype list * 'self_type
    method name_map :
      'a.
      ('self_type -> 'a -> ('a * Types.datatype * 'self_type)) ->
      'a name_map -> 'a name_map * Types.datatype name_map * 'self_type
    method var_map :
      'a.
      ('self_type -> 'a -> ('a * Types.datatype * 'self_type)) ->
      'a var_map -> 'a var_map * Types.datatype var_map * 'self_type
    method var : var -> (var * Types.datatype * 'self_type)
    (* method closure_var : var -> (var * Types.datatype * 'self_type) *)
    method value : value -> (value * Types.datatype * 'self_type)

    method tail_computation :
      tail_computation -> (tail_computation * Types.datatype * 'self_type)
    method special : special -> (special * Types.datatype * 'self_type)
    method bindings : binding list -> (binding list * 'self_type)
    method computation : computation -> (computation * Types.datatype * 'self_type)
    method binding : binding -> (binding * 'self_type)
    method binder : binder -> (binder * 'self_type)
    (* method closure_binder : binder -> (binder * 'self_type) *)

    method program : program -> (program * Types.datatype * 'self_type)

    method get_type_environment : environment
  end
end

module Transform : TRANSFORM =
struct
  open Types
  open TypeUtils

  type environment = datatype Env.Int.t

  let info_type (t, _, _) = t

  let deconstruct f t = f t

  module Env = Env.Int

  class visitor (tyenv : environment) =
  object ((o : 'self_type))
    val tyenv = tyenv
    (* val cenv = Env.empty *)

    method lookup_type : var -> datatype = fun var ->
      Env.lookup tyenv var

    (* method private lookup_closure_type : var -> datatype = fun var -> *)
    (*   Env.lookup cenv var *)

    method constant : constant -> (constant * datatype * 'self_type) = fun c ->
      match c with
        | `Bool _ -> c, bool_type, o
        | `Int _ -> c, int_type, o
        | `Char _ -> c, char_type, o
        | `String _ -> c, string_type, o
        | `Float _ -> c, float_type, o

    method optionu :
      'a.
      ('self_type -> 'a -> ('a * 'self_type)) ->
      'a option -> 'a option * 'self_type =
      fun f v ->
        match v with
          | None -> None, o
          | Some v ->
              let v, o = f o v in
                Some v, o

    method option :
      'a.
      ('self_type -> 'a -> ('a * datatype * 'self_type)) ->
      'a option -> 'a option * datatype option * 'self_type =
      fun f v ->
        match v with
          | None -> None, None, o
          | Some v ->
              let v, t, o = f o v in
                Some v, Some t, o

    method list :
      'a.
      ('self_type -> 'a -> ('a * datatype * 'self_type)) ->
      'a list -> 'a list * datatype list * 'self_type =
      fun f v ->
        let vs, ts, o =
          List.fold_left
            (fun (vs, ts, o) v ->
               let (v, t, o) = f o v in
                 v::vs, t::ts, o)
            ([], [], o)
            v
        in
          List.rev vs, List.rev ts, o

    method name_map :
      'a.
      ('self_type -> 'a -> ('a * datatype * 'self_type)) ->
      'a name_map -> 'a name_map * datatype name_map * 'self_type =
      fun f vmap ->
        StringMap.fold
          (fun name v (vmap, tmap, o) ->
             let (v, t, o) = f o v in
               (StringMap.add name v vmap,
                StringMap.add name t tmap,
                o))
          vmap
          (StringMap.empty, StringMap.empty, o)

    method var_map :
      'a.
      ('self_type -> 'a -> ('a * datatype * 'self_type)) ->
      'a var_map -> 'a var_map * datatype var_map * 'self_type =
      fun f vmap ->
        IntMap.fold
          (fun name v (vmap, tmap, o) ->
             let (v, t, o) = f o v in
               (IntMap.add name v vmap,
                IntMap.add name t tmap,
                o))
          vmap
          (IntMap.empty, IntMap.empty, o)

    method var : var -> (var * datatype * 'self_type) =
      fun var -> (var, o#lookup_type var, o)

    (* method closure_var : var -> (var * datatype * 'self_type) = *)
    (*   fun var -> (var, o#lookup_closure_type var, o) *)

    method value : value -> (value * datatype * 'self_type) =
      function
        | `Constant c -> let (c, t, o) = o#constant c in `Constant c, t, o
        | `Variable x -> let (x, t, o) = o#var x in `Variable x, t, o
        (* | `ClosureVar x -> let (x, t, o) = o#closure_var x in `ClosureVar x, t, o *)
        | `Extend (fields, base) ->
            let (fields, field_types, o) = o#name_map (fun o -> o#value) fields in
            let (base, base_type, o) = o#option (fun o -> o#value) base in

            let t =
              match base_type with
                | None -> make_record_type field_types
                | Some t ->
                    begin
                      match TypeUtils.concrete_type t with
                        | `Record row ->
                            `Record (extend_row field_types row)
                        | _ -> assert false
                    end
            in
              `Extend (fields, base), t, o
        | `Project (name, v) ->
            let (v, vt, o) = o#value v in
              `Project (name, v), deconstruct (project_type name) vt, o
        | `Erase (names, v) ->
            let (v, vt, o) = o#value v in
            let t = deconstruct (erase_type names) vt in
              `Erase (names, v), t, o
        | `Inject (name, v, t) ->
            let v, _vt, o = o#value v in
              `Inject (name, v, t), t, o
        | `TAbs (tyvars, v) ->
            let v, t, o = o#value v in
            let t = Types.for_all (tyvars, t) in
              `TAbs (tyvars, v), t, o
        | `TApp (v, ts) ->
            let v, t, o = o#value v in
              begin try
                let t = Instantiate.apply_type t ts in
                  `TApp (v, ts), t, o
              with
                  Instantiate.ArityMismatch ->
                    prerr_endline ("Arity mismatch in type application (Ir.Transform)");
                    prerr_endline ("expression: "^Show_value.show (`TApp (v, ts)));
                    prerr_endline ("type: "^Types.string_of_datatype t);
                    prerr_endline ("tyargs: "^String.concat "," (List.map (fun t -> Types.string_of_type_arg t) ts));
                    failwith "fatal internal error"
              end
        | `XmlNode (tag, attributes, children) ->
            let (attributes, _, o) = o#name_map (fun o -> o#value) attributes in
            let (children  , _, o) = o#list (fun o -> o#value) children in

              (*
                let _ = assert (StringMap.for_all (fun t -> t=string_type) attribute_types) in
                let _ = assert (List.for_all (fun t -> t=xml_type) children_types) in
              *)
              `XmlNode (tag, attributes, children), xml_type, o
        | `ApplyPure (f, args) ->
            let (f, ft, o) = o#value f in
            let (args, _, o) = o#list (fun o -> o#value) args in
              (* TODO: check arg types match *)
              `ApplyPure (f, args), deconstruct return_type ft, o
        | `Closure (f, z) ->
            let (f, t, o) = o#var f in
            let (z, _, o) = o#value z in
              (* TODO: check that closure environment types match expectations for f *)
              `Closure (f, z), t, o
        | `Coerce (v, t) ->
            let v, _, o = o#value v in
            (* TODO: check that vt <: t *)
              `Coerce (v, t), t, o

    method tail_computation :
      tail_computation -> (tail_computation * datatype * 'self_type) =
      function
          (* TODO: type checking *)
        | `Return v ->
            let v, t, o = o#value v in
              `Return v, t, o
        | `Apply (f, args) ->
            let f, ft, o = o#value f in
            let args, _, o = o#list (fun o -> o#value) args in
              (* TODO: check arg types match *)
              `Apply (f, args), deconstruct return_type ft, o
        (* | `ApplyClosure (f, args) -> *)
        (*     let f, ft, o = o#value f in *)
        (*     let args, arg_types, o = o#list (fun o -> o#value) args in *)
        (*     (\* TODO: check arg types match *\) *)
        (*     (\* TOOD: add closure type *\) *)
        (*       `ApplyClosure (f, args), deconstruct return_type ft, o *)
        | `Special special ->
            let special, t, o = o#special special in
              `Special special, t, o

        | `Case (v, cases, default) ->
            let v, _, o = o#value v in
            let cases, case_types, o =
              o#name_map
                (fun o (b, c) ->
                   let b, o = o#binder b in
                   let c, t, o = o#computation c in
                     (b, c), t, o) cases in
            let default, default_type, o =
              o#option (fun o (b, c) ->
                          let b, o = o#binder b in
                          let c, t, o = o#computation c in
                            (b, c), t, o) default in
            let t =
              if not (StringMap.is_empty case_types) then
                (StringMap.to_alist ->- List.hd ->- snd) case_types
              else
                val_of default_type
            in
              `Case (v, cases, default), t, o
        | `If (v, left, right) ->
            let v, _, o = o#value v in
            let left, t, o = o#computation left in
            let right, _, o = o#computation right in
              `If (v, left, right), t, o

    method special : special -> (special * datatype * 'self_type) =
      function
        | `Wrong t -> `Wrong t, t, o
        | `Database v ->
            let v, _, o = o#value v in
              `Database v, `Primitive `DB, o
        | `Table (db, table_name, keys, tt) ->
            let db, _, o = o#value db in
            let keys, _, o = o#value keys in
            let table_name, _, o = o#value table_name in
              `Table (db, table_name, keys, tt), `Table tt, o
        | `Query (range, e, _) ->
            let range, o =
              o#optionu
                (fun o (limit, offset) ->
                   let limit, _, o = o#value limit in
                   let offset, _, o = o#value offset in
                     (limit, offset), o)
                range in
            let e, t, o = o#computation e in
              `Query (range, e, t), t, o
        | `Update ((x, source), where, body) ->
            let source, _, o = o#value source in
            let x, o = o#binder x in
            let where, _, o = o#option (fun o -> o#computation) where in
            let body, _, o = o#computation body in
              `Update ((x, source), where, body), Types.unit_type, o
        | `Delete ((x, source), where) ->
            let source, _, o = o#value source in
            let x, o = o#binder x in
            let where, _, o = o#option (fun o -> o#computation) where in
              `Delete ((x, source), where), Types.unit_type, o
        | `CallCC v ->
            let v, t, o = o#value v in
              `CallCC v, deconstruct return_type t, o
        | `Select (l, v) ->
           let v, t, o = o#value v in
           `Select (l, v), t, o
        | `Choice (v, bs) ->
           let v, _, o = o#value v in
           let bs, branch_types, o =
             o#name_map (fun o (b, c) ->
                         let b, o = o#binder b in
                         let c, t, o = o#computation c in
                         (b, c), t, o) bs in
           let t = (StringMap.to_alist ->- List.hd ->- snd) branch_types in
           `Choice (v, bs), t, o
	| `Handle ({ ih_comp; ih_cases; ih_return; ih_depth }) ->
	   let (comp, _, o) = o#computation ih_comp in
           (* TODO FIXME traverse parameters *)
           let (depth, o) =
             match ih_depth with
             | `Deep params ->
                let (o, bindings) =
                  List.fold_left
                    (fun (o, bvs) (b,v) ->
                      let (b, o) = o#binder b in
                      let (v, _, o) = o#value v in
                      (o, (b,v) :: bvs))
                    (o, []) params
                in
                `Deep (List.rev bindings), o
             | `Shallow -> `Shallow, o
           in
	   let (cases, _branch_types, o) =
	     o#name_map
               (fun o (x, resume, c) ->
                 let (x, o) = o#binder x in
		 let (resume, o) = o#binder resume in
		 let (c, t, o) = o#computation c in
		 (x, resume, c), t, o)
	       ih_cases
	   in
           let (return, t, o) =
             let (b, o) = o#binder (fst ih_return) in
             let (comp, t, o) = o#computation (snd ih_return) in
             (b, comp), t, o
           in
	   `Handle { ih_comp = comp; ih_cases = cases; ih_return = return; ih_depth = depth}, t, o
	| `DoOperation (name, vs, t) ->
	   let (vs, _, o) = o#list (fun o -> o#value) vs in
	   (`DoOperation (name, vs, t), t, o)

   method bindings : binding list -> (binding list * 'self_type) =
      fun bs ->
        let bs, o =
          List.fold_left
            (fun (bs, o) b ->
               let (b, o) = o#binding b in
                 (b::bs, o))
            ([], o)
            bs
        in
          List.rev bs, o

    method computation : computation -> (computation * datatype * 'self_type) =
      fun (bs, tc) ->
        let bs, o = o#bindings bs in
        let tc, t, o = o#tail_computation tc in
          (bs, tc), t, o

    method binding : binding -> (binding * 'self_type) =
      function
        | `Let (x, (tyvars, tc)) ->
            let x, o = o#binder x in
            let tc, _, o = o#tail_computation tc in
              `Let (x, (tyvars, tc)), o
        | `Fun (f, (tyvars, xs, body), z, location) ->
            let xs, body, z, o =
              let (z, o) = o#optionu (fun o -> o#binder) z in
              let (xs, o) =
                List.fold_right
                  (fun x (xs, o) ->
                     let x, o = o#binder x in
                       (x::xs, o))
                  xs
                  ([], o) in
              let body, _, o = o#computation body in
                xs, body, z, o in
            let f, o = o#binder f in
              (* TODO: check that xs and body match up with f *)
              `Fun (f, (tyvars, xs, body), z, location), o
        | `Rec defs ->
            (* it's important to traverse the function binders first in
               order to make sure they're in scope for all of the
               function bodies *)
            let _, o =
              List.fold_right
                (fun (f, _, _, _) (fs, o) ->
                   let f, o = o#binder f in
                     (f::fs, o))
                defs
                ([], o) in

            let defs, o =
              List.fold_left
                (fun (defs, (o : 'self_type)) (f, (tyvars, xs, body), z, location) ->
                   let (z, o) = o#optionu (fun o -> o#binder) z in
                   let xs, o =
                     List.fold_right
                       (fun x (xs, o) ->
                          let (x, o) = o#binder x in
                            (x::xs, o))
                       xs
                       ([], o) in
                  let body, _, o = o#computation body in
                    (f, (tyvars, xs, body), z, location)::defs, o)
                ([], o)
                defs in
            let defs = List.rev defs in
              `Rec defs, o
        | `Alien (x, name, language) ->
            let x, o = o#binder x in
              `Alien (x, name, language), o
        | `Module (name, defs) ->
            let defs, o =
              match defs with
                | None -> None, o
                | Some defs ->
                    let defs, o = o#bindings defs
                    in
                      Some defs, o
            in
              `Module (name, defs), o

    method binder : binder -> (binder * 'self_type) =
      fun (var, info) ->
        let tyenv = Env.bind tyenv (var, info_type info) in
          (var, info), {< tyenv=tyenv >}

    method program : program -> (program * datatype * 'self_type) = o#computation

    method get_type_environment : environment = tyenv
  end
end

module type ITER =
sig
  type environment = Types.datatype Env.Int.t

  class visitor : environment ->
  object ('self_type)
    val tyenv : environment

    method lookup_type : var -> Types.datatype
    method constant : constant -> 'self_type
    method option :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a option -> 'self_type
    method list :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a list -> 'self_type
    method name_map :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a name_map -> 'self_type
    method var_map :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a var_map -> 'self_type
    method var : var -> 'self_type
    method value : value -> 'self_type

    method tail_computation : tail_computation -> 'self_type
    method special : special -> 'self_type
    method bindings : binding list -> 'self_type
    method computation : computation -> 'self_type
    method binding : binding -> 'self_type
    method binder : binder -> 'self_type

    method program : program -> 'self_type

    method get_type_environment : environment
  end
end

module Iter : ITER =
struct
  open Types

  type environment = datatype Env.Int.t

  let info_type (t, _, _) = t

  module Env = Env.Int

  class visitor (tyenv : environment) =
  object ((o : 'self_type))
    val tyenv = tyenv
    (* val cenv = Env.empty *)

    method lookup_type : var -> datatype = fun var ->
      Env.lookup tyenv var

    method constant : constant -> 'self_type
      = fun _ -> o

    method option :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a option -> 'self_type =
      fun f v ->
        match v with
        | None -> o
        | Some v -> f o v

    method list :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a list -> 'self_type =
      fun f v ->
        List.fold_left f o v

    method name_map :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a name_map -> 'self_type =
      fun f vmap ->
        StringMap.fold
          (fun _ v o -> f o v)
          vmap o

    method var_map :
      'a.
      ('self_type -> 'a -> 'self_type) ->
      'a var_map -> 'self_type =
      fun f vmap ->
        IntMap.fold
          (fun _name v o -> f o v)
          vmap o

    method var : var -> 'self_type =
      fun _ -> o

    method value : value -> 'self_type =
      function
        | `Constant c -> o#constant c
        | `Variable x -> o#var x
        | `Extend (fields, base) ->
            let o = o#name_map (fun o -> o#value) fields in
            o#option (fun o -> o#value) base
        | `Project (_, v) ->
            o#value v
        | `Erase (_, v) ->
            o#value v
        | `Inject (_, v, _) ->
            o#value v
        | `TAbs (_tyvars, v) ->
            o#value v
        | `TApp (v, _ts) ->
            o#value v
        | `XmlNode (_tag, attributes, children) ->
            let o = o#name_map (fun o -> o#value) attributes in
            o#list (fun o -> o#value) children
        | `ApplyPure (f, args) ->
            let o = o#value f in
            o#list (fun o -> o#value) args
        | `Closure (f, z) ->
            let o = o#var f in
            o#value z
        | `Coerce (v, _t) ->
           o#value v

    method tail_computation : tail_computation -> 'self_type =
      function
        | `Return v -> o#value v
        | `Apply (f, args) ->
           let o = o#value f in
           o#list (fun o -> o#value) args
        | `Special special -> o#special special
        | `Case (v, cases, default) ->
            let o = o#value v in
            let o =
              o#name_map
                (fun o (b, c) ->
                   let o = o#binder b in
                   o#computation c)
                cases
            in
            o#option
              (fun o (b, c) ->
                let o = o#binder b in
                o#computation c)
              default
        | `If (v, left, right) ->
            let o = o#value v in
            let o = o#computation left in
            o#computation right

    method special : special -> 'self_type =
      function
        | `Wrong _t -> o
        | `Database v -> o#value v
        | `Table (db, table_name, keys, _tt) ->
            let o = o#value db in
            let o = o#value keys in
            o#value table_name
        | `Query (range, e, _) ->
            let o =
              o#option
                (fun o (limit, offset) ->
                   let o = o#value limit in
                   o#value offset)
                range
            in
            o#computation e
        | `Update ((x, source), where, body) ->
            let o = o#value source in
            let o = o#binder x in
            let o = o#option (fun o -> o#computation) where in
            o#computation body
        | `Delete ((x, source), where) ->
            let o = o#value source in
            let o = o#binder x in
            o#option (fun o -> o#computation) where
        | `CallCC v -> o#value v
        | `Select (_l, v) -> o#value v
        | `Choice (v, bs) ->
           let o = o#value v in
           o#name_map
             (fun o (b, c) ->
               let o = o#binder b in
               o#computation c)
             bs
	| `Handle ({ ih_comp; ih_cases; ih_return; ih_depth }) ->
	   let o = o#computation ih_comp in
           let o =
             match ih_depth with
             | `Deep params ->
                List.fold_left
                    (fun o (b,v) ->
                      let o = o#binder b in
                      o#value v)
                  o params
             | _ -> o
           in
	   let o =
	     o#name_map
               (fun o (x, resume, c) ->
                 let o = o#binder x in
		 let o = o#binder resume in
		 o#computation c)
	       ih_cases
	   in
           let o = o#binder (fst ih_return) in
           o#computation (snd ih_return)
	| `DoOperation (_name, vs, _t) ->
           o#list (fun o -> o#value) vs

   method bindings : binding list -> 'self_type =
      fun bs ->
        List.fold_left
          (fun o b -> o#binding b)
          o bs

    method computation : computation -> 'self_type =
      fun (bs, tc) ->
        let o = o#bindings bs in
        o#tail_computation tc

    method binding : binding -> 'self_type =
      function
        | `Let (x, (_tyvars, tc)) ->
            let o = o#binder x in
            o#tail_computation tc
        | `Fun (f, (_tyvars, xs, body), z, _location) ->
           let o = o#option (fun o -> o#binder) z in
           let o =
             List.fold_right
               (fun x o -> o#binder x)
               xs o
           in
           let o = o#computation body in
           o#binder f
        | `Rec defs ->
            let o =
              List.fold_right
                (fun (f, _, _, _) o -> o#binder f)
                defs o
            in
            List.fold_left
              (fun (o : 'self_type) (_, (_, xs, body), z, _) ->
                let o = o#option (fun o -> o#binder) z in
                let o =
                  List.fold_right
                    (fun x o -> o#binder x)
                    xs o
                in
                o#computation body)
              o defs
        | `Alien (x, _name, _language) -> o#binder x
        | `Module (_name, defs) ->
           o#option (fun o -> o#bindings) defs

    method binder : binder -> 'self_type =
      fun (var, info) ->
        let tyenv = Env.bind tyenv (var, info_type info) in
        {< tyenv=tyenv >}

    method program : program -> 'self_type = o#computation

    method get_type_environment : environment = tyenv
  end
end

module Inline =
struct
  let rec is_inlineable_value =
    function
      | v when is_atom v -> true
      | `Project (_, v)
      | `Erase (_, v)
      | `Inject (_, v, _)
      | `TAbs (_, v)
      | `TApp (v, _) -> is_inlineable_value v
      | _ -> false

  let inliner tyenv env =
  object (o)
    inherit Transform.visitor(tyenv) as super

    val env = env

    method with_env env =
      {< env = env >}

    method! value =
      function
        | `Variable var when IntMap.mem var env -> IntMap.find var env, o#lookup_type var, o
        | v -> super#value v

    method! bindings =
      function
        | b :: bs ->
            let b, o = o#binding b in
              begin
                match b with
                  | `Let ((x, (_, _, `Local)), (tyvars, `Return v)) when is_inlineable_value v ->
                      let v =
                        match tyvars with
                          | [] -> v
                          | tyvars -> `TAbs (tyvars, v)
                      in
                        (o#with_env (IntMap.add x (fst3 (o#value v)) env))#bindings bs
                  | _ ->
                      let bs, o = o#bindings bs in
                        b :: bs, o
              end
        | [] -> [], o
  end

  let program typing_env p =
    fst3 ((inliner typing_env IntMap.empty)#computation p)
end

(*
  Eliminate dead functions and value bindings.

  Currently this is rather basic. It only does one pass, and it only
  eliminates variables in the following situations:

    - never used anywhere
    - only used recursively, but not mutually recursively
    - only used mutually recursively, and all the other mutually
    recursive bindings are only used mutually recursively

  If we partition mutually recursive bindings into strongly connected
  components beforehand then this will help eliminate more recursive
  bindings.

  A much more effective approach is to use one of Appel and Jim's
  algorithms described in `Shrinking lambda reductions in linear
  time'.

  They describe three algorithms. All of them eliminate all dead
  variables (as well as inlining linear variables, though that aspect
  is neither here nor there really).

  The naive algorithm gathers a census of variable counts, uses it to
  perform inlining, and is applied repeatedly until there are no dead
  variables left.

  The improved algorithm does the same, but updates the census as it
  goes along (e.g. whenever it deletes a function it passes over the
  body of the function and adjusts the census to take account of any
  uses of variables that have just been deleted).

  Both the naive algorithm and the improved algorithm are quadratic in
  the worst case, though the improved algorithm works quite well in
  practice. The improved algorithm is used in SML/NJ and MLton, and it
  used to be used in SML.NET. Appel and Jim suggest just bounding the
  number of times the improved algorithm is iterated rather than
  trying to run it exhaustively. In all but pathological cases this
  gets rid of most dead functions.

  The graphical algorithm depends on a graphical representation of
  terms (connecting definitions to uses of variables). It takes linear
  time and is the algorithm now used in SML.NET. It is extremely fast
  in practice and eliminates all dead variables in one
  pass. Unfortunately our terms are represented as trees, so we cannot
  use this algorithm here.
*)
module ElimDeadDefs =
struct
  let show_rec_uses = Basicsettings.Ir.show_rec_uses

  let counter tyenv =
  object (o : 'self_type)
    inherit Transform.visitor(tyenv) as super

    val env = IntMap.empty
    val rec_env = IntMap.empty
    val mutrec_env = IntMap.empty

    method private with_env env =
      {< env = env >}

    method with_envs (env, rec_env, mutrec_env) =
      {< env = env; rec_env = rec_env; mutrec_env = mutrec_env >}

    method init (x, _) =
      o#with_env (IntMap.add x 0 env)

    method initrec (x, _) =
      o#with_envs (IntMap.add x 0 env, IntMap.add x (0, false) rec_env, IntMap.add x (0, true) mutrec_env)

    method set_rec_status f (r,m) =
      let (count, _) = IntMap.find f rec_env in
      let rec_env = IntMap.add f (count, r) rec_env in
      let (count, _) = IntMap.find f mutrec_env in
      let mutrec_env = IntMap.add f (count, m) mutrec_env in
        o#with_envs (env, rec_env, mutrec_env)

    method set_rec f =
      o#set_rec_status f (true, false)

    method set_mutrec f =
      o#set_rec_status f (false, true)

    method set_nonrec f =
      o#set_rec_status f (false, false)

    method set_nonrecs fs =
      IntSet.fold (fun f o -> o#set_nonrec f) fs o

    method inc x =
      if IntMap.mem x rec_env then
        let count = IntMap.find x env
        and rcount, ractive = IntMap.find x rec_env
        and mcount, mactive = IntMap.find x mutrec_env in
        let envs =
          match ractive, mactive with
            | false, false -> IntMap.add x (count+1) env, rec_env, mutrec_env
            | true, false -> env, IntMap.add x (rcount+1, ractive) rec_env, mutrec_env
            | false, true -> env, rec_env, IntMap.add x (mcount+1, mactive) mutrec_env
            | true, true -> assert false
        in
          o#with_envs envs
      else if IntMap.mem x env then
        o#with_env (IntMap.add x ((IntMap.find x env)+1) env)
      else
        o#with_env (IntMap.add x 1 env)

    method! var =
      fun x ->
        if IntMap.mem x env then
          x, o#lookup_type x, o#inc x
        else
          super#var x

    method! binding b =
      match b with
        | `Let (x, (_, `Return _)) ->
            let b, o = super#binding b in
              b, o#init x
        | `Fun (f, _, _, _) ->
            let b, o = super#binding b in
              b, o#init f
        | `Rec defs ->
            let fs, o =
              List.fold_right
                (fun (f, _, _, _) (fs, o) ->
                   let f, o = o#binder f in
                     (IntSet.add (var_of_binder f) fs, o#initrec f))
                defs
                (IntSet.empty, o) in

            let defs, o =
              List.fold_left
                (fun (defs, (o : 'self_type)) (f, (tyvars, xs, body), z, location) ->
                   let z, o = o#optionu (fun o -> o#binder) z in
                   let xs, o =
                     List.fold_right
                       (fun x (xs, o) ->
                          let (x, o) = o#binder x in
                            (x::xs, o))
                       xs
                       ([], o) in
                   let o = o#set_rec (var_of_binder f) in
                   let body, _, o = o#computation body in
                   let o = o#set_mutrec (var_of_binder f) in
                     (f, (tyvars, xs, body), z, location)::defs, o)
                ([], o)
                defs in
            let o = o#set_nonrecs fs in
            let defs = List.rev defs in
              `Rec defs, o
        | _ ->
            super#binding b

    method get_envs () = (env, rec_env, mutrec_env)
  end

  let eliminator tyenv (env, rec_env, mutrec_env) =
  object (o)
    inherit Transform.visitor(tyenv)

    val env = env
    val rec_env = rec_env
    val mutrec_env = mutrec_env

    method is_dead x =
      IntMap.mem x env && (IntMap.find x env = 0)

    method is_dead_rec f =
      IntMap.mem f env && (IntMap.find f env = 0
          && (not (IntMap.mem f mutrec_env) || fst (IntMap.find f mutrec_env) = 0))

    method! bindings =
      function
        | b :: bs ->
            begin
              let b, o = o#binding b in
                match b with
                  | `Let ((x, _), (_tyvars, _)) when o#is_dead x ->
                      o#bindings bs
                  | `Fun ((f, _), _, _, _) when o#is_dead f ->
                      o#bindings bs
                  | `Rec defs ->
                      Debug.if_set show_rec_uses (fun () -> "Rec block:");
                      let fs, defs =
                        List.fold_left
                          (fun (fs, defs) (((f, (_, name, _)), _, _, _) as def) ->
                             Debug.if_set show_rec_uses
                               (fun () ->
                                  "  (" ^ name ^ ") non-rec uses: "^string_of_int (IntMap.find f env)^
                                    ", rec uses: "^string_of_int (fst (IntMap.find f rec_env))^
                                    ", mut-rec uses: "^string_of_int (fst (IntMap.find f mutrec_env)));
                             if o#is_dead_rec f then fs, defs
                             else
                               IntSet.add f fs, def :: defs)
                          (IntSet.empty, [])
                          defs in

                      (*
                         If none of the mutually recursive bindings appear elsewhere
                         then we can delete them all.
                      *)
                      let defs =
                        if IntSet.for_all o#is_dead fs then []
                        else
                          List.rev defs
                      in
                        begin
                          match defs with
                            | [] -> o#bindings bs
                            | defs ->
                                let bs, o = o#bindings bs in
                                  `Rec defs :: bs, o
                        end
                  | _ ->
                      let bs, o = o#bindings bs in
                        b :: bs, o
            end
        | [] -> [], o
  end

  let count tyenv p =
    let _, _, o = (counter tyenv)#computation p in
      o#get_envs()

  let program tyenv p =
    let envs = count tyenv p in
    let p, _, _ = (eliminator tyenv envs)#computation p in
      p
end

type eval_fun_def = var_info * (var list * computation) * Var.var option * location
  deriving (Show)

(* Eta expand DOs in tail position *)
module EtaTailDos =
struct

  let expander tyenv env =
  object (o)
    inherit Transform.visitor(tyenv) as _super

    val env = env

    method with_env env =
      {< env = env >}

    method! computation (bs, tc) =
        match tc with
        | (`Special (`DoOperation (_,_,t))) as tc ->
           let v = gensym ~prefix:"_v" () in
           let vb = Var.fresh_binder (Var.make_local_info (t, v)) in
           let b = `Let (vb, ([], tc)) in
           let tc = `Return (`Variable (Var.var_of_binder vb)) in
           let bs',o = o#bindings (bs @ [b]) in
           let tc',dt,o = o#tail_computation tc in
           (bs',tc'),dt,o
        | _ ->
           let bs',o = o#bindings bs in
           let tc',dt,o = o#tail_computation tc in
           (bs', tc'), dt, o
  end

  let program typing_env p =
    fst3 ((expander typing_env IntMap.empty)#computation p)
end

(* Computes a map from vars to names; useful for debugging. *)
module NameMap =
struct
  type name_map = string IntMap.t
    deriving (Show)

  let compute tyenv prog =
    ((object (o)
      inherit Iter.visitor(tyenv)

      val nenv = IntMap.empty
      method add var name =
        {< nenv = IntMap.add var name nenv >}
      method get_nenv = nenv

      method! binder (var, (_, name, _)) =
        o#add var name
     end)#program prog)#get_nenv
end

(* Tree shaking includes "live code", i.e. code that will be run
   directly or indirectly by the module's main
   computation. Though, we are somewhat conservative with regard
   to let bindings. *)
module TreeShaking =
struct

  type usage_map = IntSet.t IntMap.t
    deriving (Show)

  (* Computes a map from functions to a set of variables used in their
     bodies *)
  let usage_map tyenv =
    object (o)
      inherit Iter.visitor(tyenv) as super

      val scope_owner = (-1)
      method with_scope_owner owner =
        {< scope_owner = owner >}

      val usage_map : IntSet.t IntMap.t = IntMap.(add (-1) IntSet.empty empty)
      method get_usage_map = usage_map

      method use (user : Var.var) (usee : Var.var) =
        (* Printf.printf "%d uses %d\n%!" user usee; *)
        let usees =
          try
            IntMap.find user usage_map
          with
          | NotFound _ -> IntSet.empty
        in
        let usees = IntSet.add usee usees in
        {< usage_map = IntMap.add user usees usage_map >}

      method init v =
        {< usage_map = IntMap.add v IntSet.empty usage_map >}

      method! var var =
        o#use scope_owner var

      method! binding = function
      | `Fun (b, (_, _, comp), _, _) ->
         let o = o#binder b in
         let v = Var.var_of_binder b in
         let so = scope_owner in
         let o = o#init v in
         let o = o#with_scope_owner v in
         let o = o#computation comp in
         o#with_scope_owner so
      | `Rec fundefs ->
         (* initialise all scopes *)
         let o =
           List.fold_left
             (fun o (f, _, _, _) ->
               let o = o#binder f in
               let v = Var.var_of_binder f in
               o#init v)
             o fundefs
         in
        (* visit the scopes one by one *)
         List.fold_left
           (fun o (f, (_, _, comp), _, _) ->
             let v = Var.var_of_binder f in
             let so = scope_owner in
             let o = o#with_scope_owner v in
             let o = o#computation comp in
             o#with_scope_owner so)
           o fundefs
      | `Alien (b, _, _) ->
         let o = o#binder b in
         let v = Var.var_of_binder b in
         o#init v
      | e -> super#binding e

    end

  (* Computes the set of variables used directly by the top-level tail
     computation (i.e. the "main" computation) *)
  let code_used_directly_by_main tyenv =
    object (o)
      inherit Iter.visitor(tyenv)

      val uses = IntSet.empty
      method use var = {< uses = IntSet.add var uses >}
      method get_uses = uses

      method! program (_, tc) =
        o#tail_computation tc

      method! var var = o#use var
    end

  (* Eliminates function which are not used directly or indirectly by
     the main computation. *)
  let eliminator tyenv reachable =
    object (o)
      inherit Transform.visitor(tyenv) as super

      method is_reachable b =
        let v = Var.var_of_binder b in
        IntSet.mem v reachable

      (* method is_global b = *)
      (*   let (_, _, loc) = Var.info_of_binder b in *)
      (*   loc = `Global *)

      method! bindings bs =
        let bs =
          List.fold_left
            (fun bs ->
              function
              | `Fun (fb, _, _, _) when not (o#is_reachable fb) -> bs
              | `Rec fundefs ->
                 let fundefs' =
                   List.filter (fun (fb, _, _, _) -> o#is_reachable fb) fundefs
                 in
                 if fundefs' = []
                 then bs
                 else (`Rec fundefs') :: bs
              | b -> b :: bs)
            [] bs
        in
        super#bindings (List.rev bs)
    end

  let program tyenv prog =
    let usage_map =
      let o = (usage_map tyenv)#program prog in
      o#get_usage_map
    in
    let main_uses =
      let o = (code_used_directly_by_main tyenv)#program prog in
      o#get_uses
    in
    (* Printf.printf "Main_uses: %s\n%!" (IntSet.Show_t.show main_uses); *)
    (* Printf.printf "Usage map: %s\n%!" (Show_usage_map.show usage_map); *)
    (* All reachable definitions from main (i.e. live code) are
       computed as the least fix point *)
    let rec lfp main_uses usage_map =
      let live' =
        IntSet.fold
          (fun v live ->
            try
              (* Printf.printf "Intermediate live set: %s\n%!" (IntSet.Show_t.show live); *)
              IntSet.union (IntMap.find v usage_map) live
            with
              NotFound _ (* occurs when v is primitive *) -> IntSet.add v live)
          main_uses main_uses
      in
      if IntSet.cardinal live' > IntSet.cardinal main_uses
      then lfp live' usage_map
      else live'
    in
    let liveset = lfp main_uses usage_map in
    (* Printf.printf "Live: %s\n%!" (IntSet.Show_t.show liveset); *)
    let (prog, _, _) = (eliminator tyenv liveset)#program prog in
    (* let liveness_map = ProcedureFragmentation.liveness tyenv prog in *)
    (* Printf.printf "Liveness: %s\n%!" (ProcedureFragmentation.Show_liveness_map.show liveness_map); *)
    prog
end
