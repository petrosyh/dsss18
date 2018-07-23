(** * Verif_stack: Stack ADT implemented by linked lists *)

(* ================================================================= *)
(** ** Here is a little C program, [stack.c] *)

(** 

#include <stddef.h>

extern void * malloc (size_t n);
extern void free (void *p);
extern void exit(int n);

struct cons {
  int value;
  struct cons *next;
};

struct stack {
  struct cons *top;
};

struct stack *newstack(void) {
  struct stack *p;
  p = (struct stack * ) malloc (sizeof (struct stack));
  if (!p) exit(1);
  p->top = NULL;
  return p;
}

void push (struct stack *p, int i) {
  struct cons *q;
  q = (struct cons * ) malloc (sizeof (struct cons));
  if (!q) exit(1);
  q->value = i;
  q->next = p->top;
  p->top = q;
}

int pop (struct stack *p) {
  struct cons *q;
  int i;
  q = p->top;
  p->top = q->next;
  i = q->value;
  free(q);
  return i;
}


 This program implements a stack ADT (abstract data type).
 - To create a new stack, [st = newstack();]
 - To push integer [i] onto the stack, [push(st,i);]
 - To pop from the stack, [i=pop(st);]

 This stack is implemented as a header node ([struct stack])
 pointing to a linked list of cons cells ([struct cons]).

 *)

(* ================================================================= *)
(** ** Let's verify! *)

Require Import VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import  stack.
Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs.  mk_varspecs prog. Defined.

(* ================================================================= *)
(** ** Malloc and free *)

(** When you use C's malloc/free library, you write [p=malloc(n);]
  to get a pointer [p] to a block of [n] bytes; when you're done
  with that block, you call [free(p)] to dispose of it.
  How does the [free] function know how many bytes to dispose?

  The answer is, the malloc/free library puts an extra "header"
  field just before address [p], so really you get this:


      +-----------+
      | header    |
      +-----------+
  p-->|  zero     |
      +-----------+
      |  one      |
      +-----------+
      |  two      |
      +-----------+

  where in this case, [header=3].

  In separation logic, we can describe this as 
  - [malloc_token p * data_at Tsh (Tstruct _mystruct noattr) (zero,one,two) p]
  where [malloc_token p] describes this picture:

      +-----------+
      | header    |
      +-----------+
  p-->

  Of course, the malloc/free library might have a different way
  of "remembering" the size that [p] points to, so its representation
  of [malloc_token] is _not necessarily_ a word at offset -1.
  Therefore, as clients of the malloc/free library, we treat [malloc_token]
  as an abstract predicate.  Now, the function-specifications of malloc 
  and free are something like this:
*)

Definition malloc_spec_example  :=
 DECLARE _malloc
 WITH t:type
 PRE [ 1%positive OF tuint ]
    PROP (0 <= sizeof t <= Int.max_unsigned;
          complete_legal_cosu_type t = true;
          natural_aligned natural_alignment t = true)
    LOCAL (temp 1%positive (Vint (Int.repr (sizeof t))))
    SEP ()
 POST [ tptr tvoid ] EX p:_,
    PROP ()
    LOCAL (temp ret_temp p)
    SEP (if eq_dec p nullval then emp
         else (malloc_token Tsh t p * data_at_ Tsh t p)).

Definition free_spec_example :=
 DECLARE _free
 WITH t: type, p:val
 PRE [ 1%positive OF tptr tvoid ]
     PROP ()
     LOCAL (temp 1%positive p)
     SEP (malloc_token Tsh t p; data_at_ Tsh t p)
 POST [ Tvoid ]
     PROP () LOCAL () SEP ().

(** If your source program says [malloc(sizeof(t))], your [forward_call] 
    should supply (as a WITH-witness) the C type [t].
    Malloc may choose to return NULL, in which case the SEP part
    of the postcondition is [emp], or it may return a pointer,
    in which case you get [data_at_ Tsh t p], and as a free bonus
    you get a [malloc_token Tsh t p].  But don't lose that [malloc_token]!
    You will need to supply it later to the [free] function when
    you dispose of the object.

    The SEP predicate [data_at_ Tsh t p] is an _uninitialized_
    structure of type [t].  It is equivalent to,
    [data_at Tsh t (default_val t) p].  The [default_val] is basically
    a struct or array full of [Vundef] values.
 *)

(* ================================================================= *)
(** ** Specification of linked lists *)
(** This is much like the linked lists in [Verif_reverse]. *)

Fixpoint listrep (il: list Z) (p: val) : mpred :=
 match il with
 | i::il' => EX y: val, 
        malloc_token Tsh (Tstruct _cons noattr) p *
        data_at Tsh (Tstruct _cons noattr) (Vint (Int.repr i),y) p * listrep il' y
 | nil => !! (p = nullval) && emp
 end.

(** As usual, we should populate the Hint databases
    [saturate_local] and [valid_pointer] *)

(** **** Exercise: 1 star (stack_listrep_properties)  *)
Lemma listrep_local_prop: forall il p, listrep il p |--
        !! (is_pointer_or_null p  /\ (p=nullval <-> il=nil)).
(** See if you can remember how to prove this; or look again
  at [Verif_reverse] to see how it's done. *)
Proof.
  intros.
  revert p. induction il; intros p.
  - unfold listrep.
    entailer!. split; auto.
  - unfold listrep; fold listrep.
    entailer.
    entailer!.
    split; intros.
    + subst p.
      eapply field_compatible_nullval; eauto.
    + inv H3.
Qed.
    
Hint Resolve listrep_local_prop : saturate_local.

Lemma listrep_valid_pointer:
  forall il p,
   listrep il p |-- valid_pointer p.
(** See if you can remember how to prove this; or look again
  at [Verif_reverse] to see how it's done. *)
Proof.
  intros.
 (** The main point is to unfold listrep. *)
 unfold listrep.
 (** Now we can prove it by case analysis on sigma; we don't even need
   induction. *)
 destruct il; simpl.
* (** The  nil case is easy: *)
  hint.
  entailer!.
* (**  The cons case *)
  (** To get past the EXistential, use either [Intros y] or, *)
  entailer!.
  (** Now this solves using the Hint database [valid_pointer], because the
     [data_at Tsh t_list (v,y) p] on the left is enough to prove the goal. *)
  auto with valid_pointer.
Qed.

Hint Resolve listrep_valid_pointer : valid_pointer.
(** [] *)

(* ================================================================= *)
(** ** Specification of stack data structure *)

(** Our stack data structure looks like this:

      +-----------+
      | token     |
      +-----------+       +---------
  p-->|  top------+---q-->| linked list...
      +-----------+       +---------

 The stack object [p] points to a header node with one field [top]
 (plus a malloc token); the _contents_ of the [top] field
 is some pointer [q] that points to a linked list.
*)


Definition stack (il: list Z) (p: val) :=
 EX q: val,
  malloc_token Tsh (Tstruct _stack noattr) p * 
  data_at Tsh (Tstruct _stack noattr) q p *
  listrep il q.

(** **** Exercise: 1 star (stack_properties)  *)

Lemma stack_local_prop: forall il p, stack il p |--  !! (isptr p).
Proof.
  intros. unfold isptr.
  unfold stack. destruct p; entailer; entailer!.
Qed.

Hint Resolve stack_local_prop : saturate_local.

Lemma stack_valid_pointer:
  forall il p,
   stack il p |-- valid_pointer p.
Proof.
  intros.
 unfold stack.
 destruct il; simpl.
* (** The  nil case is easy: *)
  hint.
  entailer!.
  entailer.
* (**  The cons case *)
  (** To get past the EXistential, use either [Intros y] or, *)
  entailer!.
  (** Now this solves using the Hint database [valid_pointer], because the
     [data_at Tsh t_list (v,y) p] on the left is enough to prove the goal. *)
  auto with valid_pointer.
Qed.

Hint Resolve stack_valid_pointer : valid_pointer.
(** [] *)

(* ================================================================= *)
(** ** Function specifications for the stack operations *)

Definition newstack_spec : ident * funspec :=
 DECLARE _newstack
 WITH tt: unit
 PRE [ ] 
    PROP () LOCAL () SEP ()
 POST [ tptr (Tstruct _stack noattr) ] 
    EX p: val, PROP ( ) LOCAL (temp ret_temp p) SEP (stack nil p).

Definition push_spec : ident * funspec :=
 DECLARE _push
 WITH p: val, i: Z, il: list Z
 PRE [ _p OF tptr (Tstruct _stack noattr), _i OF tint ] 
    PROP (Int.min_signed <= i <= Int.max_signed) 
    LOCAL (temp _p p; temp _i (Vint (Int.repr i))) 
    SEP (stack il p)
 POST [ tvoid ] 
    PROP ( ) LOCAL () SEP (stack (i::il) p).

Definition pop_spec : ident * funspec :=
 DECLARE _pop
 WITH p: val, i: Z, il: list Z
 PRE [ _p OF tptr (Tstruct _stack noattr) ] 
    PROP () 
    LOCAL (temp _p p) 
    SEP (stack (i::il) p)
 POST [ tint ] 
    PROP ( ) LOCAL (temp ret_temp (Vint (Int.repr i))) SEP (stack il p).

(** Putting all the funspecs together: *)

Definition Gprog : funspecs :=
        ltac:(with_library prog [
                   newstack_spec; push_spec; pop_spec
 ]).

(* ================================================================= *)
(** ** Proofs of the function bodies *)

(** **** Exercise: 2 stars (body_pop)  *)
Lemma body_pop: semax_body Vprog Gprog f_pop pop_spec.
Proof.
  start_function.
  
  subst POSTCONDITION MORE_COMMANDS; unfold abbreviate.
  abbreviate_semax.
  Fail forward.
  unfold stack.
  unfold listrep; fold listrep.
  Intros q.
  Intros y.
  forward.
  forward.
  forward.
  forward.
  forward_call ((Tstruct _cons noattr), q).
  forward.
  unfold stack. Exists y. entailer.
Qed.

(** [] *)

(** **** Exercise: 2 stars (body_push)  *)
Lemma body_push: semax_body Vprog Gprog f_push push_spec.
Proof.
start_function.
forward_call (Tstruct _cons noattr).
simpl; split3; auto.
split. omega.
assert (8 = Int.unsigned (Int.repr 8)). unfold Int.repr. unfold Int.unsigned. auto.
rewrite H0. eapply Int.unsigned_range_2.
Intros q.

forward_if
  (PROP ()
   LOCAL (temp _q q; temp _p p; temp _i (Vint (Int.repr i)))
   SEP (malloc_token Tsh (Tstruct _cons noattr) q * data_at_ Tsh (Tstruct _cons noattr) q;
  stack il p)).

* if_tac. subst q. entailer!. entailer!.
* if_tac. forward_call tt. contradiction. contradiction.
* if_tac. contradiction. Intros. forward. entailer. entailer!.
* Intros.
  forward. simpl.
  unfold stack.
  Intros q0.
  forward.
  forward.
  forward.
  forward.
  unfold stack. Exists q.
  cancel.
  unfold listrep. fold listrep.
  Exists q0.
  entailer!.
Qed.

(** **** Exercise: 2 stars (body_newstack)  *)
Lemma body_newstack: semax_body Vprog Gprog f_newstack newstack_spec.
Proof.
  start_function.
  forward_call (Tstruct _stack noattr).
  simpl; split3; auto.
  split. omega.
  assert (4 = Int.unsigned (Int.repr 4)). unfold Int.repr. unfold Int.unsigned. auto.
  rewrite H. eapply Int.unsigned_range_2.
  Intros p.
  forward_if
    (PROP (p <> nullval)
     LOCAL (temp _p p)
     SEP (malloc_token Tsh (Tstruct _stack noattr) p * data_at_ Tsh (Tstruct _stack noattr) p)).
* if_tac. subst p. entailer!. entailer!.
* if_tac. forward_call tt. contradiction. contradiction.
* if_tac. contradiction. Intros. forward. entailer. 
* Intros. forward. forward.
  Exists p. 
  unfold stack. unfold listrep.
  Exists nullval. entailer.
Qed.

(** [] *)
