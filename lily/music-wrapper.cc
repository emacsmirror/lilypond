/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1998--2023 Han-Wen Nienhuys <hanwen@xs4all.nl>

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

#include "music-wrapper.hh"

#include "music.hh"

MAKE_SCHEME_CALLBACK (Music_wrapper, start_callback,
                      "ly:music-wrapper::start-callback", 1);
SCM
Music_wrapper::start_callback (SCM m)
{
  auto *const me = LY_ASSERT_SMOB (Music, m, 1);
  Music *elt = unsmob<Music> (get_property (me, "element"));
  return to_scm (elt ? elt->start_mom () : Moment (0));
}

MAKE_SCHEME_CALLBACK (Music_wrapper, length_callback,
                      "ly:music-wrapper::length-callback", 1);
SCM
Music_wrapper::length_callback (SCM m)
{
  auto *const me = LY_ASSERT_SMOB (Music, m, 1);
  Music *elt = unsmob<Music> (get_property (me, "element"));
  return to_scm (elt ? elt->get_length () : Moment (0));
}
