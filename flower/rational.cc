/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1997--2023 Han-Wen Nienhuys <hanwen@xs4all.nl>

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

#include "rational.hh"

#include "real.hh"

#include <cassert>
#include <cmath>
#include <cstdlib>
#include <numeric>
#include <string>
#include <utility>

Rational::operator double () const
{
  if (sign_ == -1 || sign_ == 1 || sign_ == 0)
    {
      return static_cast<double> (sign_) * static_cast<double> (num_)
             / static_cast<double> (den_);
    }
  if (sign_ == -2)
    return -HUGE_VAL;
  else if (sign_ == 2)
    return HUGE_VAL;
  else
    assert (false);

  return 0.0;
}

int64_t
Rational::trunc_int () const
{
  uint64_t i = num_ / den_;
  return static_cast<int64_t> (i) * sign_;
}

Rational
Rational::trunc_rat () const
{
  if (!isfinite (*this))
    return *this;
  return Rational ((num_ - (num_ % den_)) * sign_, den_);
}

Rational::Rational (int64_t n, int64_t d)
{
  // use sign of n when d=0
  sign_ = sign (n) * (std::signbit (d) ? -1 : 1);
  num_ = static_cast<uint64_t> (std::abs (n));
  den_ = static_cast<uint64_t> (std::abs (d));
  normalize ();
}

Rational::Rational (long long n)
{
  sign_ = sign (n);
  num_ = static_cast<uint64_t> (std::abs (n));
  den_ = 1;
}

Rational::Rational (unsigned long long n)
{
  sign_ = sign (n);
  num_ = n;
  den_ = 1;
}

Rational
Rational::div_rat (Rational div) const
{
  Rational r (*this);
  r /= div;
  return r.trunc_rat ();
}

Rational
Rational::mod_rat (Rational div) const
{
  Rational r (*this);
  if (!isinf (div))
    r = (r / div - r.div_rat (div)) * div;
  return r;
}

Rational
euclidean_remainder (Rational dividend, Rational divisor)
{
  if (isfinite (divisor))
    {
      divisor = !signbit (divisor) ? divisor : -divisor; // abs
      auto remainder = dividend.mod_rat (divisor);
      if (remainder < 0)
        remainder += divisor;
      return remainder;
    }

  return Rational::nan ();
}

void
Rational::normalize ()
{
  if (den_)
    {
      if (!sign_)
        {
          den_ = 1;
          num_ = 0;
        }
      else if (!num_)
        {
          sign_ = 0;
          den_ = 1;
        }
      else
        {
          const auto g = std::gcd (num_, den_);
          num_ /= g;
          den_ /= g;
        }
    }
  else if (num_)
    {
      *this = std::signbit (sign_) ? -infinity () : infinity ();
    }
  else // NaN mustn't keep sign 0
    {
      if (!sign_)
        sign_ = 1;
    }
}

int
Rational::compare (Rational const &r, Rational const &s)
{
  if (r.sign_ < s.sign_)
    return -1;
  else if (r.sign_ > s.sign_)
    return 1;
  else if (isinf (r)) // here s is also infinite with the same sign
    return 0;
  else if (r.sign_ == 0) // here s.sign_ is also zero
    return 0;

  uint64_t left = r.num_ * s.den_;
  uint64_t right = s.num_ * r.den_;
  if (left < right)
    {
      return -r.sign_;
    }
  else if (left > right)
    {
      return r.sign_;
    }

  return 0;
}

int
compare (Rational const &r, Rational const &s)
{
  return Rational::compare (r, s);
}

Rational &
Rational::operator%= (Rational r) &
{
  *this = mod_rat (r);
  return *this;
}

Rational &
Rational::operator+= (Rational r) &
{
  if (isnan (*this))
    ;
  else if (isnan (r))
    *this = r;
  else if (r.sign_ == 0)
    ;
  else if (sign_ == 0)
    *this = r;
  else if (isinf (*this))
    {
      if (sign_ == -r.sign_)
        *this = Rational::nan ();
    }
  else if (isinf (r))
    *this = r;
  else
    {
      const auto lcm = std::lcm (r.den_, den_);
      int64_t n
        = sign_ * num_ * (lcm / den_) + r.sign_ * r.num_ * (lcm / r.den_);
      int64_t d = lcm;
      sign_ = sign (n) * sign (d);
      num_ = static_cast<uint64_t> (std::abs (n));
      den_ = static_cast<uint64_t> (std::abs (d));
      normalize ();
    }
  return *this;
}

/*
  copied from libg++ 2.8.0
*/
Rational::Rational (double x)
{
  if (x != 0.0)
    {
      if (std::isinf (x))
        {
          *this = std::signbit (x) ? -infinity () : infinity ();
          return;
        }
      else if (std::isnan (x))
        {
          *this = nan ();
          return;
        }

      sign_ = sign (x);
      x *= sign_;

      int expt;
      double mantissa = frexp (x, &expt);

      const int FACT = 1 << 20;

      /*
        Thanks to Afie for this too simple  idea.

        do not blindly substitute by libg++ code, since that uses
        arbitrary-size integers.  The rationals would overflow too
        easily.
      */

      num_ = static_cast<uint64_t> (mantissa * FACT);
      den_ = static_cast<uint64_t> (FACT);
      normalize ();
      if (expt < 0)
        den_ <<= -expt;
      else
        num_ <<= expt;
      normalize ();
    }
  else
    {
      num_ = 0;
      den_ = 1;
      sign_ = 0;
      normalize ();
    }
}

Rational &
Rational::operator*= (Rational r) &
{
  sign_ *= sign (r.sign_);
  if (isinf (r))
    {
      sign_ = sign (sign_) * 2;
      goto exit_func;
    }

  num_ *= r.num_;
  den_ *= r.den_;

  normalize ();
exit_func:
  return *this;
}

Rational &
Rational::operator/= (Rational r) &
{
  if (isinf (r))
    {
      r = {};
    }
  else
    {
      std::swap (r.num_, r.den_);
      if (!r.den_)
        {
          if (!r.sign_)
            r.sign_ = 1; // NaN mustn't have sign = 0
        }
    }

  return *this *= r;
}

void
Rational::negate ()
{
  sign_ *= -1;
}

Rational &
Rational::operator-= (Rational r) &
{
  r.negate ();
  return (*this += r);
}

std::string
Rational::to_string () const
{
  if (isinf (*this))
    {
      return std::string (sign_ > 0 ? "" : "-") + "infinity";
    }

  if (isnan (*this))
    {
      return std::string (sign_ > 0 ? "" : "-") + "nan";
    }

  std::string s = std::to_string (num ());
  if (den () != 1 && num ())
    s += "/" + std::to_string (den ());
  return s;
}
