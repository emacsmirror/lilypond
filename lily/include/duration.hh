/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1997--2023 Jan Nieuwenhuizen <janneke@gnu.org>

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

#ifndef DURATION_HH
#define DURATION_HH

#include "smobs.hh"

#include "rational.hh"

/**
   A musical duration.
*/
struct Duration : public Simple_smob<Duration>
{
  static SCM equal_p (SCM, SCM);
  int print_smob (SCM, scm_print_state *) const;
  static const char *const type_p_name_;
  Duration ();
  Duration (int, int);
  Duration (Rational num_whole_notes, bool scale);
  explicit Duration (Rational num_whole_notes)
    : Duration (num_whole_notes, true)
  {
  }

  // Convert the Duration to the equivalent number of whole notes.
  explicit operator Rational () const;
  std::string to_string () const;

  Duration compressed (Rational) const;
  Rational factor () const { return factor_; }
  int duration_log () const;
  int dot_count () const;

  static int compare (Duration const &, Duration const &);

  DECLARE_SCHEME_CALLBACK (less_p, (SCM a, SCM b));

private:
  /// Logarithm of the base duration.
  int durlog_;
  int dots_;

  Rational factor_;
};

INSTANTIATE_COMPARE (Duration, Duration::compare);

#endif // DURATION_HH
