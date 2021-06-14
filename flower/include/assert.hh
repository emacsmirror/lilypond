/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 2021 Daniel Eble <dan@faithful.be>

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

#ifndef ASSERT_HH
#define ASSERT_HH

#include <cassert>

// assert (true) is not guaranteed to be constexpr until C++17.  This works
// around it.
//
// In C++11 constexpr functions, this must be used with a comma:
//
//     return constexpr_assert (p), ...;
//
#define constexpr_assert(p) ((p) ? void () : assert (p))

#endif // ASSERT_HH