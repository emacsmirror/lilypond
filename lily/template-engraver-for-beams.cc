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

#include "beam.hh"
#include "item.hh"
#include "lily-guile.hh"
#include "lily-guile-macros.hh"
#include "rational.hh"
#include "stem.hh"
#include "template-engraver-for-beams.hh"
#include "tuplet-description.hh"

void
Template_engraver_for_beams::derived_mark () const
{
  beaming_options_.gc_mark ();
  finished_beaming_options_.gc_mark ();
  if (beam_pattern_)
    beam_pattern_->gc_mark ();
  if (finished_beam_pattern_)
    finished_beam_pattern_->gc_mark ();
}

void
Template_engraver_for_beams::begin_beam ()
{
  auto beam_start_position
    = from_scm (get_property (this, "measurePosition"), Moment (0));

  beaming_options_.from_context (context ());
  if (beam_start_position.grace_part_)
    beam_start_position.main_part_ = beam_start_position.grace_part_;
  beam_pattern_ = std::make_unique<Beaming_pattern> (
    measure_position (context (), beam_start_position,
                      beaming_options_.measure_length_)
      .main_part_);
}

void
Template_engraver_for_beams::typeset_beam ()
{
  if (finished_beam_)
    {
      finished_beam_pattern_->beamify (finished_beaming_options_);

      Beam::set_beaming (finished_beam_, finished_beam_pattern_.get ());
      finished_beam_ = nullptr;

      finished_beam_pattern_.reset ();
    }
}

void
Template_engraver_for_beams::add_stem (Item *stem, Duration const &dur)
{
  beam_pattern_->add_stem (last_added_moment_.grace_part_
                             ? last_added_moment_.grace_part_
                             : last_added_moment_.main_part_,
                           Stem::is_invisible (stem), dur,
                           unsmob<Tuplet_description> (get_property (
                             context (), "currentTupletDescription")));
}
