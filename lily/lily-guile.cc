/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1998--2023 Jan Nieuwenhuizen <janneke@gnu.org>
  Han-Wen Nienhuys <hanwen@xs4all.nl>

  LilyPond is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  LilyPond is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with LilyPond.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "lily-guile.hh"

#include "bezier.hh"
#include "dimensions.hh"
#include "direction.hh"
#include "file-path.hh"
#include "international.hh"
#include "ly-scm-list.hh"
#include "main.hh"
#include "memory.hh"
#include "misc.hh"
#include "offset.hh"
#include "pitch.hh"
#include "skyline.hh"
#include "skyline-pair.hh"
#include "std-vector.hh"
#include "string-convert.hh"
#include "source-file.hh"
#include "unpure-pure-container.hh"
#include "warn.hh"
#include "lily-imports.hh"

#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring> /* strdup, strchr */
#include <functional>

/*
  symbols/strings.
 */
std::string
ly_scm_write_string (SCM s)
{
  SCM port
    = scm_mkstrport (SCM_INUM0, scm_make_string (SCM_INUM0, SCM_UNDEFINED),
                     SCM_OPN | SCM_WRTNG, "ly_write2string");
  scm_write (s, port);
  return from_scm<std::string> (scm_strport_to_string (port));
}

std::string
ly_symbol2string (SCM s)
{
  /*
    Ugh. this is not very efficient.
  */
  return from_scm<std::string> (scm_symbol_to_string (s));
}

std::string
robust_symbol2string (SCM sym, const std::string &str)
{
  return scm_is_symbol (sym) ? ly_symbol2string (sym) : str;
}

extern "C"
{
  // maybe gdb 5.0 becomes quicker if it doesn't do fancy C++ typing?
  void ly_display_scm (SCM s)
  {
    scm_display (s, scm_current_output_port ());
    scm_newline (scm_current_output_port ());
  }
};

/*
  STRINGS
 */
std::string
scm_conversions<std::string>::from_scm (SCM str)
{
  assert (scm_is_string (str));

  // Guile 1.8 with -lmcheck barfs because realloc with sz==0 returns
  // NULL.
  if (scm_c_string_length (str) == 0)
    {
      return std::string ();
    }

  std::string result;
  size_t len;
  unique_stdlib_ptr<char> c_string (scm_to_utf8_stringn (str, &len));
  if (len)
    {
      result.assign (c_string.get (), len);
    }
  return result;
}

unique_stdlib_ptr<char>
ly_scm2str0 (SCM str)
{
  return unique_stdlib_ptr<char> (scm_to_utf8_string (str));
}

/*
  PAIRS
*/
SCM
index_get_cell (SCM s, Direction d)
{
  assert (d);
  return (d == LEFT) ? scm_car (s) : scm_cdr (s);
}

SCM
index_set_cell (SCM s, Direction d, SCM v)
{
  if (d == LEFT)
    scm_set_car_x (s, v);
  else if (d == RIGHT)
    scm_set_cdr_x (s, v);
  return s;
}

bool
is_number_pair (SCM p)
{
  return scm_is_pair (p) && scm_is_number (scm_car (p))
         && scm_is_number (scm_cdr (p));
}

/*
  OFFSET
*/
Offset
scm_conversions<Offset>::from_scm (SCM s)
{
  return Offset (::from_scm<Real> (scm_car (s)),
                 ::from_scm<Real> (scm_cdr (s)));
}

SCM
scm_conversions<Offset>::to_scm (const Offset &i)
{
  return scm_cons (::to_scm (i[X_AXIS]), ::to_scm (i[Y_AXIS]));
}

/*
  ALIST
*/
SCM
ly_alist_vals (SCM alist)
{
  SCM x = SCM_EOL;
  for (SCM p = alist; scm_is_pair (p); p = scm_cdr (p))
    x = scm_cons (scm_cdar (p), x);
  return x;
}

/*
  LISTS
 */

/* Return I-th element, or last elt L. If I < 0, then we take the first
   element.

   PRE: length (L) > 0  */
SCM
robust_list_ref (int i, SCM l)
{
  while (i-- > 0 && scm_is_pair (scm_cdr (l)))
    l = scm_cdr (l);
  return scm_car (l);
}

SCM
ly_deep_copy (SCM src)
{
  if (scm_is_pair (src))
    {
      SCM res = SCM_EOL;
      do
        {
          res = scm_cons (ly_deep_copy (scm_car (src)), res);
          src = scm_cdr (src);
        }
      while (scm_is_pair (src));
      // Oh, come on, Guile.  Why do you require the second argument
      // of scm_reverse_x to be a proper list?  That makes no sense.
      // return scm_reverse_x (res, ly_deep_copy (src));
      SCM last_cons = res;
      res = scm_reverse_x (res, SCM_EOL);
      scm_set_cdr_x (last_cons, ly_deep_copy (src));
      return res;
    }
  if (scm_is_vector (src))
    {
      vsize len = scm_c_vector_length (src);
      SCM nv = scm_c_make_vector (len, SCM_UNDEFINED);
      for (vsize i = 0; i < len; i++)
        {
          scm_c_vector_set_x (nv, i, ly_deep_copy (scm_c_vector_ref (src, i)));
        }
      return nv;
    }
  return src;
}

std::string
print_scm_val (SCM val)
{
  std::string realval = ly_scm_write_string (val);
  if (realval.length () > 200)
    realval = realval.substr (0, 100) + "\n :\n :\n"
              + realval.substr (realval.length () - 100);
  return realval;
}

static bool
internal_type_check (SCM sym, SCM val, SCM type_symbol)
{
  if (!scm_is_symbol (sym))
    return false;

  SCM type = scm_object_property (sym, type_symbol);

  if (!ly_is_procedure (type))
    {
      warning (_f ("the property '%s' does not exist (perhaps a typing error)",
                   ly_symbol2string (sym).c_str ()));
      return false;
    }

  if (SCM_UNBNDP (val)) // for an unset, it is enough that the property exists
    return true;

  // '(), #f and *unspecified* always succeed.
  if (scm_is_null (val) || scm_is_false (val)
      || scm_is_eq (val, SCM_UNSPECIFIED))
    return true;

  if (scm_is_eq (type_symbol, ly_symbol2scm ("backend-type?")))
    {
      // A callback always succeeds for a grob property since it is not the
      // eventual value the property will have, but just the function that
      // computes it.
      if (ly_is_procedure (val))
        return true;
      // For an unpure-pure container, both the pure part and the unpure part
      // should have the right type.
      if (auto *upc = unsmob<Unpure_pure_container> (val))
        {
          return (
            type_check_assignment (sym, upc->unpure_part (), type_symbol)
            && type_check_assignment (sym, upc->pure_part (), type_symbol));
        }
    }

  if (scm_is_false (ly_call (type, val)))
    {
      SCM type_name = Lily::type_name (type);

      warning (_f (
        "the property '%s' must be of type '%s', ignoring invalid value '%s'",
        ly_symbol2string (sym).c_str (),
        from_scm<std::string> (type_name).c_str (),
        print_scm_val (val).c_str ()));
      return false;
    }
  return true;
}

bool
type_check_assignment (SCM sym, SCM val, SCM type_symbol)
{
  // If undefined, some internal function caused it...should never happen.
  assert (!SCM_UNBNDP (val));
  return internal_type_check (sym, val, type_symbol);
}

bool
type_check_unset (SCM sym, SCM type_symbol)
{
  return internal_type_check (sym, SCM_UNDEFINED, type_symbol);
}

/*
  display stuff without using stack
*/
SCM
display_list (SCM s)
{
  SCM p = scm_current_output_port ();

  scm_puts ("(", p);
  for (; scm_is_pair (s); s = scm_cdr (s))
    {
      scm_display (scm_car (s), p);
      scm_puts (" ", p);
    }
  scm_puts (")", p);
  return SCM_UNSPECIFIED;
}

// Needed as complement to int_list_to_slice since scm_c_memq refuses
// to work with dotted lists.

SCM
ly_memv (SCM v, SCM l)
{
  for (; scm_is_pair (l); l = scm_cdr (l))
    if (scm_is_true (scm_eqv_p (v, scm_car (l))))
      return l;
  return SCM_BOOL_F;
}

Slice
int_list_to_slice (SCM l)
{
  Slice s;
  s.set_empty ();
  for (; scm_is_pair (l); l = scm_cdr (l))
    if (scm_is_number (scm_car (l)))
      s.add_point (from_scm<int> (scm_car (l)));
  return s;
}

SCM
ly_with_fluid (SCM fluid, SCM val, std::function<SCM ()> const &fn)
{
  using Fn = std::function<SCM ()>;

  auto trampoline = [] (void *vp_fn) {
    auto &fn = *static_cast<Fn const *> (vp_fn);
    return fn ();
  };

  return scm_c_with_fluid (fluid, val, trampoline, const_cast<Fn *> (&fn));
}

SCM
scm_conversions<Rational>::to_scm (const Rational &r)
{
  if (isinf (r))
    {
      if (r > Rational (0))
        return scm_inf ();

      return scm_difference (scm_inf (), SCM_UNDEFINED);
    }

  return scm_divide (::to_scm (r.numerator ()), ::to_scm (r.denominator ()));
}

Rational
scm_conversions<Rational>::from_scm (SCM r)
{
  if (scm_is_true (scm_inf_p (r)))
    {
      if (scm_is_true (scm_positive_p (r)))
        {
          return Rational::infinity ();
        }
      else
        {
          return -Rational::infinity ();
        }
    }

  return Rational (scm_to_int64 (scm_numerator (r)),
                   scm_to_int64 (scm_denominator (r)));
}

bool
scm_conversions<Rational>::is_scm (SCM n)
{
  return (scm_is_real (n)
          && (scm_is_true (scm_exact_p (n)) || scm_is_true (scm_inf_p (n))));
}

bool
scm_conversions<Bezier>::is_scm (SCM s)
{
  for (int i = 0; i < 4; i++)
    {
      if (!scm_is_pair (s))
        return false;
      SCM next = scm_car (s);
      if (!scm_is_pair (next) || !::is_scm<Real> (scm_car (next))
          || !::is_scm<Real> (scm_cdr (next)))
        return false;
      s = scm_cdr (s);
    }
  return scm_is_null (s);
}

Bezier
scm_conversions<Bezier>::from_scm (SCM s)
{
  return Bezier (as_ly_scm_list (s));
}

SCM
scm_conversions<Bezier>::to_scm (const Bezier &b)
{
  SCM result = SCM_EOL;
  for (int i : {3, 2, 1, 0})
    result = scm_cons (::to_scm (b.control_[i]), result);
  return result;
}

bool
scm_conversions<Skyline_pair>::is_scm (SCM s)
{
  return scm_is_pair (s) && unsmob<Skyline> (scm_car (s))
         && unsmob<Skyline> (scm_cdr (s));
}

Skyline_pair
scm_conversions<Skyline_pair>::from_scm (SCM s)
{
  if (!scm_is_pair (s))
    return Skyline_pair ();
  Skyline *left = unsmob<Skyline> (scm_car (s));
  if (!left)
    return Skyline_pair ();
  Skyline *right = unsmob<Skyline> (scm_cdr (s));
  if (!right)
    return Skyline_pair ();
  if (left->sky () != DOWN)
    {
      scm_misc_error (
        __FUNCTION__,
        "direction of first skyline in skyline pair must be DOWN/LEFT",
        SCM_EOL);
    }
  if (right->sky () != UP)
    {
      scm_misc_error (
        __FUNCTION__,
        "direction of second skyline in skyline pair must be UP/RIGHT",
        SCM_EOL);
    }
  return Skyline_pair (*left, *right);
}

SCM
scm_conversions<Skyline_pair>::to_scm (const Skyline_pair &skyp)
{
  return scm_cons (skyp[LEFT].smobbed_copy (), skyp[RIGHT].smobbed_copy ());
}

SCM
ly_hash2alist (SCM tab)
{
  return Lily::hash_table_to_alist (tab);
}

/*
  C++ interfacing.
 */

std::string
mangle_cxx_identifier (const char *cxx_id)
{
  std::string mangled_id (cxx_id);
  if (mangled_id.substr (0, 3) == "ly_")
    mangled_id.replace (0, 3, "ly:");
  else
    {
      mangled_id = String_convert::to_lower (mangled_id);
      mangled_id = "ly:" + mangled_id;
    }
  if (mangled_id.substr (mangled_id.length () - 2) == "_p")
    mangled_id.replace (mangled_id.length () - 2, 2, "?");
  else if (mangled_id.substr (mangled_id.length () - 2) == "_x")
    mangled_id.replace (mangled_id.length () - 2, 2, "!");

  replace_all (&mangled_id, "_less?", "<?");
  replace_all (&mangled_id, "_2_", "->");
  replace_all (&mangled_id, "__", "::");
  replace_all (&mangled_id, '_', '-');

  return mangled_id;
}

SCM
ly_string_array_to_scm (const std::vector<std::string> &a)
{
  SCM s = SCM_EOL;
  for (auto it = a.rbegin (); it != a.rend (); it++)
    {
      const std::string &part = *it;
      if (!part.empty ())
        s = scm_cons (ly_symbol2scm (part), s);
    }
  return s;
}

/* SYMBOLS is a whitespace separated list.  */
SCM
parse_symbol_list (char const *symbols)
{
  while (isspace (*symbols))
    symbols++;
  std::string s = symbols;
  replace_all (&s, '\n', ' ');
  replace_all (&s, '\t', ' ');
  replace_all (&s, "  ", " ");
  return ly_string_array_to_scm (string_split (s, ' '));
}

/* GDB debugging. */
struct ly_t_double_cell
{
  SCM a;
  SCM b;
  SCM c;
  SCM d;
};

/* inserts at front, removing duplicates */
SCM
ly_assoc_prepend_x (SCM alist, SCM key, SCM val)
{
  return scm_acons (key, val, scm_assoc_remove_x (alist, key));
}

SCM
ly_alist_copy (SCM alist)
{
  SCM l = SCM_EOL;
  SCM *tail = &l;
  for (; scm_is_pair (alist); alist = scm_cdr (alist))
    {
      *tail = scm_acons (scm_caar (alist), scm_cdar (alist), *tail);
      tail = SCM_CDRLOC (*tail);
    }
  return l;
}
