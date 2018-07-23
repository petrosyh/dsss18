(** * Hashfun: Functional model of hash tables *)

(** ** This C program, [hash.c], implements a hash table with
   external chaining.  See http://www.cs.princeton.edu/~appel/HashTables.pdf
   for an introduction to hash tables.  *)

(** 

#include <stddef.h>

extern void * malloc (size_t n);
extern void exit(int n);
extern size_t strlen(const char *str);
extern char *strcpy(char *dest, const char *src);
extern int strcmp(const char *str1, const char *str2);

unsigned int hash (char *s) {
  unsigned int n=0;
  unsigned int i=0;
  int c=s[i];
  while (c) {
    n = n*65599u+(unsigned)c;
    i++;
    c=s[i];
  }
  return n;
}

struct cell {
  char *key;
  unsigned int count;
  struct cell *next;
};

enum {N = 109};

struct hashtable {
  struct cell *buckets[N];
};

char *copy_string (char *s) {
  int i,n = strlen(s)+1;
  char *p = malloc(n);
  if (!p) exit(1);
  strcpy(p,s);
  return p;
}

struct hashtable *new_table (void) {
  int i;
  struct hashtable *p = (struct hashtable * )malloc(sizeof(struct hashtable));
  if (!p) exit(1);
  for (i=0; i<N; i++) p->buckets[i]=NULL;
  return p;
}  

struct cell *new_cell (char *key, int count, struct cell *next) {
  struct cell *p = (struct cell * )malloc(sizeof(struct cell));
  if (!p) exit(1);
  p->key = copy_string(key);
  p->count = count;
  p->next = next;
  return p;
}

unsigned int get (struct hashtable *table, char *s) {
  unsigned int h = hash(s);
  unsigned int b = h % N;
  struct cell *p = table->buckets[b];
  while (p) {
    if (strcmp(p->key, s)==0)
      return p->count;
    p=p->next;
  }
  return 0;
}

void incr_list (struct cell **r0, char *s) {
  struct cell *p, **r;
  for(r=r0; ; r=&p->next) {
    p = *r;
    if (!p) {
      *r = new_cell(s,1,NULL);
      return;
    }
    if (strcmp(p->key, s)==0) {
      p->count++;
      return;
    }
  }
}  

void incr (struct hashtable *table, char *s) {
  unsigned int h = hash(s);
  unsigned int b = h % N;
  incr_list (& table->buckets[b], s);
}
*)

(* ================================================================= *)
(** ** A functional model *)

(** Before we prove the C program correct, we write a functional
 program that models its behavior as closely as possible.  
 The functional program won't be (average) constant time per access,
 like the C program, because it takes linear time to get the nth
 element of a list, while the C program can subscript an array in
 constant time.  But we are not worried about the execution time
 of the functional program; only that it serve as a model
 for specifying the C program. *)


Require Import VST.floyd.functional_base.

Definition string := list byte.
Instance EqDec_string: EqDec string := list_eq_dec Byte.eq_dec. 

Fixpoint hashfun_aux (h: Z) (s: string) : Z :=
 match s with
 | nil => h
 | c :: s' =>
      hashfun_aux ((h * 65599 + Byte.signed c) mod Int.modulus) s'
end.

Definition hashfun (s: string) := hashfun_aux 0 s.

Definition hashtable_contents := list (list (string * Z)).

Definition N := 109.
Lemma N_eq : N = 109. 
Proof. reflexivity. Qed.
Hint Rewrite N_eq : rep_omega.
Global Opaque N.

Definition empty_table : hashtable_contents :=
  list_repeat (Z.to_nat N) nil.

Fixpoint list_get (s: string) (al: list (string * Z)) : Z :=
  match al with
 | (k,i) :: al' => if eq_dec s k then i else list_get s al'
 | nil => 0
 end.

Fixpoint list_incr (s: string) (al: list (string * Z))
              :  list (string * Z) :=
  match al with
 | (k,i) :: al' => if eq_dec s k 
                      then (k, i +1)::al'
                      else (k,i)::list_incr s al'
 | nil => (s, 1)::nil
 end.

Definition hashtable_get  (s: string) (contents: hashtable_contents) : Z :=
  list_get s (Znth (hashfun s mod (Zlength contents)) contents).

Definition hashtable_incr (s: string) (contents: hashtable_contents)
                      : hashtable_contents :=
  let h := hashfun s mod (Zlength contents)
  in let al := Znth h contents
  in upd_Znth h contents (list_incr s al).

(** **** Exercise: 2 stars (hashfun_inrange)  *)
Lemma hashfun_inrange: forall s, 0 <= hashfun s <= Int.max_unsigned.
Proof.
  unfold hashfun. unfold hashfun_aux.
  induction s.
  - assert (0 = Int.unsigned (Int.zero)). unfold Int.unsigned. auto.
    rewrite H. apply Int.unsigned_range_2.
  - 
    unfold Int.max_unsigned. unfold Int.modulus. unfold Int.wordsize.
    unfold two_power_nat. 
    admit. 
(* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 1 star (hashfun_get_unfold)  *)
Lemma hashtable_get_unfold:
 forall sigma (cts: list (list (string * Z) * val)),
 hashtable_get sigma (map fst cts) =
  list_get sigma (Znth (hashfun sigma mod (Zlength cts)) (map fst cts)).
Proof.
(* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 2 stars (Zlength_hashtable_incr)  *)
Lemma Zlength_hashtable_incr:
 forall sigma cts, 
      0 < Zlength cts -> 
      Zlength (hashtable_incr sigma cts) = Zlength cts.
Proof.
(* FILL IN HERE *) Admitted.
Hint Rewrite Zlength_hashtable_incr using list_solve : sublist.
(** [] *)

(** **** Exercise: 3 stars (hashfun_snoc)  *)
Lemma hashfun_snoc:
  forall sigma h lo i,
    0 <= lo ->
    lo <= i < Zlength sigma ->
  Int.repr (hashfun_aux h (sublist lo (i + 1) sigma)) =
  Int.repr (hashfun_aux h (sublist lo i sigma) * 65599 + Byte.signed (Znth i sigma)).
Proof.
(* FILL IN HERE *) Admitted.
(** [] *)

(* ================================================================= *)
(** ** Functional model satisfies the high-level specification *)

(** The purpose of a hash table is to implement a finite mapping,
  (a finite function) from keys to values.  We claim that the
  functional model ([empty_table, hashtable_get, hashtable_incr])
  correctly implements the appropriate operations on the abstract
  data type of finite functions.

  We formalize that statement by defining a Module Type: *)

Module Type COUNT_TABLE.
 Parameter table: Type.
 Parameter key : Type.
 Parameter empty: table.
 Parameter get: key -> table -> Z.
 Parameter incr: key -> table -> table.
 Axiom gempty: forall k,   (* get-empty *)
       get k empty = 0.
 Axiom gss: forall k t,      (* get-set-same *)
      get k (incr k t) = 1+(get k t).
 Axiom gso: forall j k t,    (* get-set-other *)
      j <> k -> get j (incr k t) = get j t.
End COUNT_TABLE.

(** This means:  in any [Module] that satisfies this [Module Type],
   there's a type [table] of count-tables,
   and operators [empty], [get], [set] that satisfy the axioms
   [gempty], [gss], and [gso]. *)
  
(* ----------------------------------------------------------------- *)
(** *** A "reference" implementation of COUNT_TABLE *)

(** **** Exercise: 2 stars (FunTable)  *)
(**  It's easy to make a slow implementation of [COUNT_TABLE], using functions. *)

Module FunTable <: COUNT_TABLE.
 Definition table: Type := nat -> Z.
 Definition key : Type := nat.
 Definition empty: table := fun k => 0.
 Definition get (k: key) (t: table) : Z := t k.
 Definition incr (k: key) (t: table) : table :=
    fun k' => if Nat.eqb k' k then 1 + t k' else t k'.
 Lemma gempty: forall k,  get k empty = 0.
 Proof. intros. unfold empty. auto. Qed.
 Lemma gss: forall k t,  get k (incr k t) = 1+(get k t).
 Proof. intros. unfold incr. simpl.
(* FILL IN HERE *) Admitted.
 Lemma gso: forall j k t,  j <> k -> get j (incr k t) = get j t.
(* FILL IN HERE *) Admitted.
End FunTable.
(** [] *)

(* ----------------------------------------------------------------- *)
(** *** Demonstration that hash tables implement COUNT_TABLE *)

(** **** Exercise: 3 stars (IntHashTable)  *)
(**  Now we make a "fast" implementation using hash tables.  We
  put "fast" in quotes because, unlike the imperative implementation,
 the purely functional implementation takes linear time, not constant time,
 to select the the i'th bucket.  That is, [Znth i al] takes time proportional to [i].
 But that is no problem, because we are not using [hashtable_get] and
 [hashtable_incr] as our real implementation; they are serving as the 
 _functional model_ of the fast implementation in C.  *)

Module IntHashTable <: COUNT_TABLE.
 Definition hashtable_invariant (cts: hashtable_contents) : Prop :=
  Zlength cts = N /\
  forall i, 0 <= i < N ->
             list_norepet (map fst (Znth i cts))
             /\ Forall (fun s => hashfun s mod N = i) (map fst (Znth i cts)).
 Definition table := sig hashtable_invariant.
 Definition key := string.

 Lemma empty_invariant: hashtable_invariant empty_table.
 Proof.
(* FILL IN HERE *) Admitted.

Lemma incr_invariant: forall k cts, hashtable_invariant cts -> hashtable_invariant (hashtable_incr k cts).
Proof.
(* FILL IN HERE *) Admitted.

 Definition empty : table := exist _ _ empty_invariant.
 Definition get : key -> table -> Z := fun k tbl => hashtable_get k (proj1_sig tbl).
 Definition incr : key -> table -> table := 
       fun k tbl => exist _ _ (incr_invariant k _ (proj2_sig tbl)).


 Theorem gempty: forall k, get k empty = 0.
 Proof.
(* FILL IN HERE *) Admitted.

 Theorem gss: forall k t,  get k (incr k t) =  1 + (get k t).
 Proof.
(* FILL IN HERE *) Admitted.

 Theorem gso: forall j k t,    (* get-set-other *)
      j <> k -> get j (incr k t) = get j t.
Proof.
(* FILL IN HERE *) Admitted.
(** [] *)

End IntHashTable.
