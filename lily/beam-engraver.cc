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
#include "beaming-pattern.hh"
#include "context.hh"
#include "directional-element-interface.hh"
#include "drul-array.hh"
#include "duration.hh"
#include "engraver.hh"
#include "international.hh"
#include "item.hh"
#include "rest.hh"
#include "spanner.hh"
#include "stream-event.hh"
#include "stem.hh"
#include "template-engraver-for-beams.hh"
#include "unpure-pure-container.hh"
#include "warn.hh"

#include "translator.icc"

#include <utility>

class Beam_engraver : public Template_engraver_for_beams
{
public:
  TRANSLATOR_DECLARATIONS (Beam_engraver);

protected:
  Stream_event *start_ev_ = nullptr;

  Spanner *beam_ = nullptr;
  Stream_event *prev_start_ev_ = nullptr;

  Stream_event *stop_ev_ = nullptr;

  Direction forced_direction_ = CENTER;

  void acknowledge_stem (Grob_info_t<Item>);
  void acknowledge_rest (Grob_info);
  void listen_beam (Stream_event *);

  void typeset_beam ();
  void set_melisma (bool);

  void stop_translation_timestep ();
  void start_translation_timestep ();
  void finalize () override;

  void process_music ();

  virtual bool valid_start_point () const;
  virtual bool valid_end_point () const;
};

/*
  Hmm. this isn't necessary, since grace beams and normal beams are
  always nested.
*/
bool
Beam_engraver::valid_start_point () const
{
  return now_mom ().grace_part_ == Rational (0);
}

bool
Beam_engraver::valid_end_point () const
{
  return valid_start_point ();
}

Beam_engraver::Beam_engraver (Context *c)
  : Template_engraver_for_beams (c)
{
}

void
Beam_engraver::listen_beam (Stream_event *ev)
{
  Direction d = from_scm<Direction> (get_property (ev, "span-direction"));

  if (d == START && valid_start_point ())
    {
      assign_event_once (start_ev_, ev);

      Direction updown = from_scm<Direction> (get_property (ev, "direction"));
      if (updown)
        forced_direction_ = updown;
    }
  else if (d == STOP && valid_end_point ())
    assign_event_once (stop_ev_, ev);
}

void
Beam_engraver::set_melisma (bool ml)
{
  SCM b = get_property (this, "autoBeaming");
  if (!from_scm<bool> (b))
    set_property (context (), "beamMelismaBusy", ml ? SCM_BOOL_T : SCM_BOOL_F);
}

void
Beam_engraver::process_music ()
{

  if (start_ev_)
    {
      if (beam_)
        {
          start_ev_->warning (_ ("already have a beam"));
          return;
        }

      set_melisma (true);
      prev_start_ev_ = start_ev_;
      beam_ = make_spanner ("Beam", start_ev_->self_scm ());

      begin_beam ();
    }

  typeset_beam ();
  if (stop_ev_ && beam_)
    {
      announce_end_grob (beam_, stop_ev_->self_scm ());
    }
}

void
Beam_engraver::typeset_beam ()
{
  if (finished_beam_)
    {
      Grob *stem = finished_beam_->get_bound (RIGHT);
      if (!stem)
        {
          stem = finished_beam_->get_bound (LEFT);
          if (stem)
            finished_beam_->set_bound (RIGHT, stem);
        }

      if (stem && forced_direction_)
        set_grob_direction (stem, forced_direction_);

      forced_direction_ = CENTER;

      Template_engraver_for_beams::typeset_beam ();
    }
}

void
Beam_engraver::start_translation_timestep ()
{

  start_ev_ = nullptr;

  if (beam_)
    set_melisma (true);
}

void
Beam_engraver::stop_translation_timestep ()
{
  if (stop_ev_)
    {
      finished_beam_ = beam_;
      finished_beam_pattern_ = std::move (beam_pattern_);
      finished_beaming_options_ = beaming_options_;

      stop_ev_ = nullptr;
      beam_ = nullptr;
      typeset_beam ();
      set_melisma (false);
    }
}

void
Beam_engraver::finalize ()
{
  Template_engraver_for_beams::finalize ();
  typeset_beam ();
  if (beam_)
    {
      prev_start_ev_->warning (_ ("unterminated beam"));

      /*
        we don't typeset it, (we used to, but it was commented
        out. Reason unknown) */
      beam_->suicide ();
      beam_pattern_.reset ();
    }
}

void
Beam_engraver::acknowledge_rest (Grob_info info)
{
  if (beam_
      && !scm_is_number (get_property_data (info.grob (), "staff-position")))
    chain_offset_callback (info.grob (),
                           Unpure_pure_container::make_smob (
                             Beam::rest_collision_callback_proc,
                             Beam::pure_rest_collision_callback_proc),
                           Y_AXIS);
}

void
Beam_engraver::acknowledge_stem (Grob_info_t<Item> info)
{
  if (!beam_)
    return;

  if (!valid_start_point ())
    return;

  // It's suboptimal that we don't support callbacks returning ##f,
  // but this makes beams have no effect on "stems" reliably in
  // TabStaff when \tabFullNotation is switched off: the real stencil
  // callback for beams is called quite late in the process, and we
  // don't want to trigger it early.
  if (scm_is_false (get_property_data (beam_, "stencil")))
    return;

  auto *const stem = info.grob ();
  if (Stem::get_beam (stem))
    return;

  Stream_event *ev = info.ultimate_event_cause ();
  if (!ev->in_event_class ("rhythmic-event"))
    {
      info.grob ()->warning (_ ("stem must have Rhythmic structure"));
      return;
    }

  Duration const &stem_duration
    = *unsmob<Duration> (get_property (ev, "duration"));
  int const durlog = stem_duration.duration_log ();
  if (durlog <= 2)
    {
      ev->warning (_ ("stem does not fit in beam"));
      prev_start_ev_->warning (_ ("beam was started here"));
      /*
        don't return, since

        [r4 c8] can just as well be modern notation.
      */
    }

  if (forced_direction_)
    set_grob_direction (stem, forced_direction_);

  set_property (stem, "duration-log", to_scm (durlog));
  last_added_moment_ = now_mom ();
  add_stem (stem, stem_duration);
  Beam::add_stem (beam_, stem);
}

void
Beam_engraver::boot ()
{
  ADD_LISTENER (beam);
  ADD_ACKNOWLEDGER (stem);
  ADD_ACKNOWLEDGER (rest);
}

ADD_TRANSLATOR (Beam_engraver,
                /* doc */
                R"(
Handle @code{Beam} events by engraving beams.  If omitted, then notes are
printed with flags instead of beams.
                )",

                /* create */
                R"(
Beam
                )",

                /* read */
                R"(
beamMelismaBusy
beatBase
beatStructure
subdivideBeams
                )",

                /* write */
                R"(
                )");

class Grace_beam_engraver final : public Beam_engraver
{
public:
  TRANSLATOR_DECLARATIONS (Grace_beam_engraver);

protected:
  bool valid_start_point () const override;
  bool valid_end_point () const override;
};

Grace_beam_engraver::Grace_beam_engraver (Context *c)
  : Beam_engraver (c)
{
}

bool
Grace_beam_engraver::valid_start_point () const
{
  return !Beam_engraver::valid_start_point ();
}

bool
Grace_beam_engraver::valid_end_point () const
{
  return beam_ && valid_start_point ();
}

void
Grace_beam_engraver::boot ()
{
  ADD_LISTENER (beam);
  ADD_ACKNOWLEDGER (stem);
  ADD_ACKNOWLEDGER (rest);
}

ADD_TRANSLATOR (Grace_beam_engraver,
                /* doc */
                R"(
Handle @code{Beam} events by engraving beams.  If omitted, then notes are
printed with flags instead of beams.  Only engraves beams when we are at grace
points in time.
                )",

                /* create */
                R"(
Beam
                )",

                /* read */
                R"(
beamMelismaBusy
beatBase
beatStructure
subdivideBeams
                )",

                /* write */
                R"(

                )");
