open Utility
open Types

let show_recursion = Settings.add_bool("show_recursion", false, `User)

(*
  instantiation environment:
    for stopping cycles during instantiation
*)
type inst_type_env = meta_type_var IntMap.t
type inst_row_env = meta_row_var IntMap.t
type inst_env = inst_type_env * inst_row_env

let instantiate_datatype : (datatype IntMap.t * row_var IntMap.t) -> datatype -> datatype =
  fun (tenv, renv) ->
    let rec inst : inst_env -> datatype -> datatype = fun rec_env datatype ->
      let rec_type_env, rec_row_env = rec_env in
	match datatype with
	  | `Not_typed -> failwith "Internal error: `Not_typed' passed to `instantiate'"
	  | `Primitive _  -> datatype
	  | `MetaTypeVar point ->
	      let t = Unionfind.find point in
		(match t with
		   | `Flexible var
		   | `Rigid var ->
		       if IntMap.mem var tenv then
			 IntMap.find var tenv
		       else
			 datatype
		   | `Recursive (var, t) ->
		       Debug.if_set (show_recursion) (fun () -> "rec (instantiate)1: " ^(string_of_int var));

		       if IntMap.mem var rec_type_env then
			 (`MetaTypeVar (IntMap.find var rec_type_env))
		       else
			 (
			   let var' = Types.fresh_raw_variable () in
			   let point' = Unionfind.fresh (`Flexible var') in
			   let t' = inst (IntMap.add var point' rec_type_env, rec_row_env) t in
			   let _ = Unionfind.change point' (`Recursive (var', t')) in
			     `MetaTypeVar point'
			 )
		   | `Body t -> inst rec_env t)
	  | `Function (f, m, t) -> `Function (inst rec_env f, inst rec_env m, inst rec_env t)
	  | `Record row -> `Record (inst_row rec_env row)
	  | `Variant row ->  `Variant (inst_row rec_env row)
	  | `Table (r, w) -> `Table (inst rec_env r, inst rec_env w)
	  | `Application (n, elem_type) ->
	      `Application (n, List.map (inst rec_env) elem_type)
    and inst_row : inst_env -> row -> row = fun rec_env row ->
      let field_env, row_var = flatten_row row in
	
      let is_closed =
        match Unionfind.find row_var with
          | `Closed -> true
          | _ -> false in

      let field_env' = StringMap.fold
	(fun label field_spec field_env' ->
	   match field_spec with
	     | `Present t -> StringMap.add label (`Present (inst rec_env t)) field_env'
	     | `Absent ->
		 if is_closed then field_env'
		 else StringMap.add label `Absent field_env'
	) field_env StringMap.empty in
      let row_var' = inst_row_var rec_env row_var
      in
	field_env', row_var'
          (* precondition: row_var has been flattened *)
    and inst_row_var : inst_env -> row_var -> row_var = fun (rec_type_env, rec_row_env) row_var ->
      match row_var with
	| point ->
	    begin
              match Unionfind.find point with
	        | `Closed -> row_var
                | `Flexible var
                | `Rigid var ->
		    if IntMap.mem var renv then
		      IntMap.find var renv
		    else
		      row_var
	        | `Recursive (var, rec_row) ->
		    if IntMap.mem var rec_row_env then
		      IntMap.find var rec_row_env
		    else
		      begin
		        let var' = Types.fresh_raw_variable () in
		        let point' = Unionfind.fresh (`Flexible var') in
		        let rec_row' = inst_row (rec_type_env, IntMap.add var point' rec_row_env) rec_row in
		        let _ = Unionfind.change point' (`Recursive (var', rec_row')) in
			  point'
		      end
	        | `Body _ -> assert(false)
            end
    in
      inst (IntMap.empty, IntMap.empty)


let instantiate_alias (vars, alias) ts =
  let _, tenv =
    List.fold_left (fun (ts, tenv) tv ->
                      match ts, tv with
                        | (t::ts), `TypeVar var ->
                            ts, IntMap.add var t tenv
                        | _ -> assert false) (ts, IntMap.empty) vars
  in
    instantiate_datatype (tenv, IntMap.empty) (Types.freshen_mailboxes alias)