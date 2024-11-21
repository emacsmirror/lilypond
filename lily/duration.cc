/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1997--2023 Jan Nieuwenhuizen <janneke@gnu.org>
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

#include "duration.hh"

#include "misc.hh"
#include "lily-proto.hh"

int
Duration::compare (Duration const &left, Duration const &right)
{
  return Rational::compare (Rational (left), Rational (right));
}

Duration::Duration ()
{
  durlog_ = 0;
  dots_ = 0;
  factor_ = Rational (1, 1);
}

Duration::Duration (int log, int d)
{
  durlog_ = log;
  dots_ = d;
  factor_ = Rational (1, 1);
}

Duration::Duration (Rational r, bool scale)
{
  factor_ = Rational (1, 1);

  if (r.num () == 0)
    {
      durlog_ = 0;
      dots_ = 0;
    }
  else
    {
      /* we want to find the integer k for which 2q/p > 2^k >= q/p.
         It's simple to check that k' = \floor \log q - \floor \log p
         satisfies the left inequality and is within a factor of 2 of
         satistying the right one. Therefore either k = k' or k = k'+1 */

      auto p = r.num ();
      auto q = r.den ();
      int k = intlog2 (q) - intlog2 (p);
      if (shift_left (p, k) < q)
        k++;

      assert (shift_left (p, k) >= q && shift_left (p, (k - 1)) < q);

      /* If we were to write out log (p/q) in base 2, then the position of the
         first non-zero bit (ie. k in our notation) would be the durlog
         and the number of consecutive 1s after that bit would be the number of
         dots.
         Depending on the sign of k we shift p or q so that no digits are lost
         by shifting right.
         */
      if (k >= 0)
        p <<= k;
      else
        q <<= -k;
      p -= q;
      dots_ = 0;
      while ((p *= 2) >= q)
        {
          p -= q;
          dots_++;
        }

      /* we only go up to 64th notes */
      if (k > 6)
        {
          durlog_ = 6;
          dots_ = 0;
        }
      else
        durlog_ = k;

      if (scale || k > 6)
        factor_ = r / Rational (*this);
    }
}

Duration
Duration::compressed (Rational m) const
{
  Duration d (*this);
  d.factor_ *= m;
  return d;
}

Duration::operator Rational () const
{
  Rational mom (1 << std::abs (durlog_));

  if (durlog_ > 0)
    mom = Rational (1) / mom;

  Rational delta = mom;
  for (int i = 0; i < dots_; i++)
    {
      delta /= Rational (2);
      mom += delta;
    }

  return mom * factor_;
}

std::string
Duration::to_string () const
{
  std::string s;

  if (durlog_ < 0)
    s = "log = " + std::to_string (durlog_);
  else
    s = std::to_string (1 << durlog_);

  if (dots_ > 0)
    s += std::string (dots_, '.');
  if (factor_ != 1)
    s += "*" + factor_.to_string ();
  return s;
}

const char *const Duration::type_p_name_ = "ly:duration?";

int
Duration::print_smob (SCM port, scm_print_state *) const
{
  scm_puts ("#<Duration ", port);
  scm_display (to_scm (to_string ()), port);
  scm_puts (" >", port);

  return 1;
}

SCM
Duration::equal_p (SCM a, SCM b)
{
  Duration *p = unsmob<Duration> (a);
  Duration *q = unsmob<Duration> (b);

  bool eq = p->dots_ == q->dots_ && p->durlog_ == q->durlog_
            && p->factor_ == q->factor_;

  return eq ? SCM_BOOL_T : SCM_BOOL_F;
}

int
Duration::duration_log () const
{
  return durlog_;
}

int
Duration::dot_count () const
{
  return dots_;
}
