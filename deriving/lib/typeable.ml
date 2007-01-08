(** A type is viewed as the application of type constructors to zero
    or more type arguments.  We provide equality and ordering
    operations on types.  The ordering is unspecified, but consistent
    within a process, i.e. sufficient for use in Map etc.

    This might be considered to break abstraction, since it exposes
    the fact that two types are the same, even if that fact has been
    hidden by type abstraction (modules etc.).  This is considered a
    good thing, since it assists with the intended use, which is to
    maximise value sharing.
*)

(* Abstract type for type tags. *)
module Tag : 
sig
  type tag
  val fresh : unit -> tag
end =
struct
  type tag = int
  let fresh = 
    let current = ref 0 in
      fun () -> incr current; !current
end

(* Type of type representations *)
type typeRep = TypeRep of (Tag.tag * typeRep list)


module TypeRep =
struct
  type t = typeRep
  let compare : t -> t -> int = compare
end

(* Signature for type representations *)
module type Typeable =
sig
  type a
  val typeRep : TypeRep.t
end

module Typeable_unit : Typeable with type a = unit = struct type a = unit let typeRep = TypeRep (Tag.fresh(), []) end
module Typeable_2 (S1:Typeable)(S2:Typeable)
  : Typeable with type a = S1.a * S2.a
    = struct type a = S1.a * S2.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep])
    end
module Typeable_3 (S1:Typeable)(S2:Typeable)(S3:Typeable)
  : Typeable with type a = S1.a * S2.a * S3.a
    = struct type a = S1.a * S2.a * S3.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep])
    end
module Typeable_4 (S1:Typeable)(S2:Typeable)(S3:Typeable)(S4:Typeable)
  : Typeable with type a = S1.a * S2.a * S3.a * S4.a
    = struct type a = S1.a * S2.a * S3.a * S4.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep;
                                                  S4.typeRep])
    end
module Typeable_5 (S1:Typeable)(S2:Typeable)(S3:Typeable)(S4:Typeable)(S5:Typeable)
  : Typeable with type a = S1.a * S2.a * S3.a * S4.a * S5.a
    = struct type a = S1.a * S2.a * S3.a * S4.a * S5.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep;
                                                  S4.typeRep; S5.typeRep])
    end
module Typeable_6 (S1:Typeable)(S2:Typeable)(S3:Typeable)(S4:Typeable)(S5:Typeable)(S6:Typeable)
  : Typeable with type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a
    = struct type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep;
                                                  S4.typeRep; S5.typeRep; S6.typeRep])

    end
module Typeable_7 (S1:Typeable)(S2:Typeable)(S3:Typeable)(S4:Typeable)(S5:Typeable)(S6:Typeable)(S7:Typeable)
  : Typeable with type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a * S7.a
    = struct type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a * S7.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep;
                                                  S4.typeRep; S5.typeRep; S6.typeRep;
                                                  S7.typeRep])
    end
module Typeable_8 (S1:Typeable)(S2:Typeable)(S3:Typeable)(S4:Typeable)(S5:Typeable)(S6:Typeable)(S7:Typeable)(S8 :Typeable)
  : Typeable with type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a * S7.a * S8.a
    = struct type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a * S7.a * S8.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep;
                                                  S4.typeRep; S5.typeRep; S6.typeRep;
                                                  S7.typeRep; S8.typeRep])
    end
module Typeable_9 (S1:Typeable)(S2:Typeable)(S3:Typeable)(S4:Typeable)(S5:Typeable)(S6:Typeable)(S7:Typeable)(S8 :Typeable)(S9:Typeable) 
  : Typeable with type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a * S7.a * S8.a * S9.a
    = struct type a = S1.a * S2.a * S3.a * S4.a * S5.a * S6.a * S7.a * S8.a * S9.a
             let typeRep = TypeRep (Tag.fresh(), [S1.typeRep; S2.typeRep; S3.typeRep;
                                                  S4.typeRep; S5.typeRep; S6.typeRep;
                                                  S7.typeRep; S8.typeRep; S9.typeRep])
    end

module Typeable_list (A:Typeable) : Typeable with type a = A.a list
  = struct type a = A.a list
           let typeRep = TypeRep (Tag.fresh(), [A.typeRep])
  end

module Primitive_typeable (T : sig type t end)
  : Typeable with type a = T.t 
  = 
struct 
  type a = T.t
  let typeRep = TypeRep (Tag.fresh(), [])
end

module Typeable_int = Primitive_typeable(struct type t = int end)
module Typeable_float = Primitive_typeable(struct type t = int end)
module Typeable_bool = Primitive_typeable(struct type t = int end)
module Typeable_string = Primitive_typeable(struct type t = int end)
