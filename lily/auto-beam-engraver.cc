/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1999--2023 Jan Nieuwenhuizen <janneke@gnu.org>

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

#include "beaming-pattern.hh"
#include "beam.hh"
#include "context.hh"
#include "context-handle.hh"
#include "duration.hh"
#include "engraver.hh"
#include "grob-properties.hh"
#include "item.hh"
#include "rest.hh"
#include "spanner.hh"
#include "stream-event.hh"
#include "stem.hh"
#include "template-engraver-for-beams.hh"
#include "warn.hh"

#include "translator.icc"

#include <utility>

class Auto_beam_engraver : public Template_engraver_for_beams
{
public:
  TRANSLATOR_DECLARATIONS (Auto_beam_engraver);

protected:
  void start_translation_timestep ();
  void stop_translation_timestep ();
  void process_acknowledged ();

  void process_music ();
  void finalize () override;
  void derived_mark () const override;

  void acknowledge_rest (Grob_info);
  void acknowledge_beam (Grob_info);
  void acknowledge_breathing_sign (Grob_info);
  void acknowledge_stem (Grob_info_t<Item>);
  void listen_beam_forbid (Stream_event *);

private:
  virtual bool test_moment (Direction, Moment const &, Rational const &) const;
  bool busy () const;
  void consider_begin (Rational const &);
  void consider_end (Rational const &);
  Spanner *create_beam ();
  void begin_beam ();
  void end_beam ();
  void handle_current_stem (Item *stem);
  void junk_beam ();
  virtual bool is_same_grace_state (Moment const &, Moment const &) const;
  void recheck_beam ();
  void typeset_beam ();

  Stream_event *forbid_ = nullptr;
  Moment measure_position_at_start_of_timestep_;
  bool force_end_ = false;
  bool considered_bar_ = false;
  /*
    shortest_dur_ is the shortest note in the beam.
  */
  Rational shortest_dur_ {1, 4};
  // This engraver is designed to operate in Voice context, so we expect only
  // one stem per timestep.
  Item *current_stem_ = nullptr;
  std::vector<Item *> stems_;

  unsigned process_acknowledged_count_ = 0;
  /*
    Projected ending of the  beam we're working on.
  */
  Moment extend_mom_ {-1};
  /*
    Handle on the starting staff keeps it alive until beam is complete
  */
  Context_handle beam_start_context_;
  // global time when beam started
  Moment beam_start_moment_ = Moment::infinity ();

  // We act as if beam were created, and start a grouping anyway.
  SCM beam_settings_ = SCM_EOL;
};

void
Auto_beam_engraver::derived_mark () const
{
  Template_engraver_for_beams::derived_mark ();
  scm_gc_mark (beam_settings_);
}

void
Auto_beam_engraver::start_translation_timestep ()
{
  measure_position_at_start_of_timestep_ = measure_position (context ());
}

void
Auto_beam_engraver::process_music ()
{

  auto now = now_mom ();

  /*
    don't beam over skips
  */
  if (busy () && extend_mom_ < now)
    end_beam ();
}

Auto_beam_engraver::Auto_beam_engraver (Context *c)
  : Template_engraver_for_beams (c)
{
}

void
Auto_beam_engraver::listen_beam_forbid (Stream_event *ev)
{
  assign_event_once (forbid_, ev);
  force_end_ = true;
}

bool
Auto_beam_engraver::test_moment (Direction dir, Moment const &test_mom,
                                 Rational const &dur) const
{
  // TODO: Scale test_mom to accumulate tuplet ratios
  return scm_is_true (ly_call (get_property (this, "autoBeamCheck"),
                               context ()->self_scm (), to_scm (dir),
                               to_scm (test_mom), to_scm (Moment (dur))));
}

bool
Auto_beam_engraver::busy () const
{
  return beam_start_moment_ < Moment::infinity ();
}

void
Auto_beam_engraver::consider_begin (Rational const &dur)
{
  if (!busy () && !forbid_
      && from_scm<bool> (get_property (this, "autoBeaming"))
      && test_moment (START, measure_position (context ()), dur))
    begin_beam ();
}

void
Auto_beam_engraver::consider_end (Rational const &dur)
{
  // Allow an autobeam to end when necessary: don't check for autoBeaming.
  //
  // measurePosition might have changed, e.g., at a transition between volta
  // alternatives.  Base this decision on the previous value.
  if (busy ()
      && test_moment (STOP, measure_position_at_start_of_timestep_, dur))
    {
      end_beam ();
    }
}

Spanner *
Auto_beam_engraver::create_beam ()
{
  if (from_scm<bool> (get_property (this, "skipTypesetting")))
    return nullptr;

  for (const auto &stem : stems_)
    if (Stem::get_beam (stem))
      return nullptr;

  /*
    Can't use make_spanner () because we have to use
    beam_settings_.
  */
  Spanner *beam = new Spanner (beam_settings_);

  for (const auto &stem : stems_)
    Beam::add_stem (beam, stem);

  Grob_info i = make_grob_info (beam, stems_[0]->self_scm ());
  announce_grob (i, beam_start_context_.get ());

  return beam;
}

void
Auto_beam_engraver::begin_beam ()
{
  if (busy () || beam_pattern_)
    {
      programming_error ("already have autobeam");
      return;
    }

  stems_.clear ();

  beam_start_context_ = context ()->get_parent ();
  beam_start_moment_ = now_mom ();
  Template_engraver_for_beams::begin_beam ();
  beam_settings_
    = Grob_property_info (context (), ly_symbol2scm ("Beam")).updated ();
}

void
Auto_beam_engraver::junk_beam ()
{
  if (!busy ())
    return;

  beam_start_context_ = nullptr;
  beam_start_moment_ = Moment::infinity ();
  stems_.clear ();
  beam_pattern_.reset ();
  beam_settings_ = SCM_EOL;

  shortest_dur_ = Rational (1, 4);
}

bool
Auto_beam_engraver::is_same_grace_state (Moment const &start,
                                         Moment const &now) const
{
  return static_cast<bool> (start.grace_part_)
         == static_cast<bool> (now.grace_part_);
}

void
Auto_beam_engraver::end_beam ()
{
  if (stems_.size () < 2)
    junk_beam ();
  else
    {
      finished_beam_ = create_beam ();

      if (finished_beam_)
        {
          Grob_info i = make_grob_info (finished_beam_, SCM_EOL);

          announce_end_grob (i, beam_start_context_.get ());
          finished_beam_pattern_ = std::move (beam_pattern_);
          finished_beaming_options_ = beaming_options_;
        }

      beam_start_moment_ = Moment::infinity ();
      stems_.clear ();
      beam_pattern_.reset ();
      beam_settings_ = SCM_EOL;
    }

  beam_start_context_ = nullptr;
  shortest_dur_ = Rational (1, 4);
}

void
Auto_beam_engraver::typeset_beam ()
{
  if (finished_beam_)
    {
      if (!finished_beam_->get_bound (RIGHT))
        finished_beam_->set_bound (RIGHT, finished_beam_->get_bound (LEFT));

      Template_engraver_for_beams::typeset_beam ();
    }
}

void
Auto_beam_engraver::stop_translation_timestep ()
{
  typeset_beam ();
  process_acknowledged_count_ = 0;
  forbid_ = nullptr;
  considered_bar_ = false;
}

void
Auto_beam_engraver::finalize ()
{
  /* finished beams may be typeset */
  typeset_beam ();
  /* but unfinished may need another announce/acknowledge pass */
  if (busy ())
    junk_beam ();
}

void
Auto_beam_engraver::acknowledge_beam (Grob_info /* info */)
{
  force_end_ = true;
}

void
Auto_beam_engraver::acknowledge_breathing_sign (Grob_info /* info */)
{
  force_end_ = true;
}

void
Auto_beam_engraver::acknowledge_rest (Grob_info /* info */)
{
  force_end_ = true;
}

void
Auto_beam_engraver::acknowledge_stem (Grob_info_t<Item> info)
{
  current_stem_ = info.grob ();
}

void
Auto_beam_engraver::handle_current_stem (Item *stem)
{
  auto *const ev = stem->ultimate_event_cause ();
  if (!ev->in_event_class ("rhythmic-event"))
    {
      programming_error ("stem must have rhythmic structure");
      return;
    }

  /*
    Don't (start) auto-beam over empty stems (skips or rests) or stems
    that already have beam
  */
  if (!Stem::head_count (stem) || Stem::get_beam (stem))
    {
      if (busy ())
        end_beam ();
      return;
    }

  Duration const &stem_duration
    = *unsmob<Duration> (get_property (ev, "duration"));

  if (stem_duration.duration_log () <= 2)
    {
      if (busy ())
        end_beam ();
      return;
    }

  /*
    ignore interspersed grace notes.
  */
  auto const now = now_mom ();
  if (!is_same_grace_state (beam_start_moment_, now))
    return;

  const auto dur = Rational (stem_duration);
  bool recheck_needed = false;

  if (dur < shortest_dur_)
    {
      /* new shortest moment, so store it and set recheck_needed */
      shortest_dur_ = dur;
      recheck_needed = true;
    }

  /* end should be based on shortest_dur_, begin should be
     based on current duration  */
  consider_end (shortest_dur_);
  consider_begin (dur);

  if (!busy ())
    return;

  last_added_moment_ = now;
  add_stem (stem, stem_duration);

  stems_.push_back (stem);
  extend_mom_ = std::max (extend_mom_, now) + get_event_length (ev, now);
  if (recheck_needed)
    recheck_beam ();
}

void
Auto_beam_engraver::recheck_beam ()
{
  /*
    Recheck the beam after the shortest duration has changed
    If shorter duration has created a new break, typeset the
    first part of the beam and reset the current beam to just
    the last part of the beam
  */

  for (vsize i = 0; (i + 1) < stems_.size (); /*in body*/)
    {
      const bool found_end = test_moment (
        STOP,
        Moment (beam_pattern_->end_moment (i) - beam_pattern_->start_moment (0)
                + beam_pattern_->measure_offset_),
        shortest_dur_);
      if (!found_end)
        i++;
      else
        {
          /*
            Save the current beam settings and shortest_dur_
            Necessary because end_beam destroys them
          */
          const auto saved_shortest_dur = shortest_dur_;
          const auto saved_beam_settings = beam_settings_;

          /* Eliminate (and save) the items no longer part of the first beam */

          auto new_grouping = beam_pattern_->split_pattern (
            i, beaming_options_.measure_length_);
          std::vector<Item *> new_stems (stems_.begin () + (i + 1),
                                         stems_.end ());
          stems_.resize (i + 1);

          end_beam ();
          typeset_beam ();

          /* now recreate the unbeamed data structures */
          stems_ = new_stems;
          beam_pattern_ = std::move (new_grouping);
          shortest_dur_ = saved_shortest_dur;
          beam_settings_ = saved_beam_settings;
          beam_start_moment_ = now_mom ();

          i = 0;
        }
    }
}

void
Auto_beam_engraver::process_acknowledged ()
{
  // This engraver can't observe bar lines with acknowledge_bar_line ()
  // because the Bar_engraver operates in Staff context.
  // process_acknowledged () can be called more than once, but
  // currentBarLine won't change.
  if (!considered_bar_)
    {
      considered_bar_ = true;

      if (!force_end_ && busy ())
        {
          if (unsmob<Grob> (get_property (this, "currentBarLine")))
            force_end_ = true;
        }
    }

  if (force_end_)
    {
      force_end_ = false;

      if (busy ())
        end_beam ();
    }

  if (current_stem_)
    {
      handle_current_stem (current_stem_);
      current_stem_ = nullptr;
    }

  auto now = now_mom ();
  if (extend_mom_ > now)
    return;

  if (busy ())
    {
      if (!process_acknowledged_count_)
        {
          consider_end (shortest_dur_);
        }
      else if (process_acknowledged_count_ > 1)
        {
          if ((extend_mom_ < now)
              || ((extend_mom_ == now) && (last_added_moment_ != now)))
            end_beam ();
          else if (stems_.empty ())
            junk_beam ();
        }
    }

  process_acknowledged_count_++;
}

void
Auto_beam_engraver::boot ()
{
  ADD_LISTENER (beam_forbid);
  ADD_ACKNOWLEDGER (stem);
  ADD_ACKNOWLEDGER (beam);
  ADD_ACKNOWLEDGER (breathing_sign);
  ADD_ACKNOWLEDGER (rest);
}

ADD_TRANSLATOR (Auto_beam_engraver,
                /* doc */
                R"(
Generate beams based on measure characteristics and observed Stems.  Uses
@code{beatBase}, @code{beatStructure}, @code{beamExceptions},
@code{measureLength}, and @code{measurePosition} to decide when to start and
stop a beam.  Overriding beaming is done through @ref{Stem_engraver} properties
@code{stemLeftBeamCount} and @code{stemRightBeamCount}.
                )",

                /* create */
                R"(
Beam
                )",

                /* read */
                R"(
autoBeaming
beamExceptions
beamHalfMeasure
beatBase
beatStructure
subdivideBeams
                )",

                /* write */
                R"(

                )");

class Grace_auto_beam_engraver final : public Auto_beam_engraver
{
  TRANSLATOR_DECLARATIONS (Grace_auto_beam_engraver);

private:
  // Full starting time of last grace group.  grace_part_ is zero ->
  // test_moment is false, last_grace_position_ not considered.
  Moment last_grace_start_ {-Rational::infinity ()};
  Moment last_grace_position_; // Measure position of same
  void process_music ();
  bool is_same_grace_state (Moment const &, Moment const &) const override;
  bool test_moment (Direction, Moment const &, Rational const &) const override;
};

Grace_auto_beam_engraver::Grace_auto_beam_engraver (Context *c)
  : Auto_beam_engraver (c)
{
}

bool
Grace_auto_beam_engraver::is_same_grace_state (Moment const &,
                                               Moment const &) const
{
  // This is for ignoring interspersed grace notes in main note
  // beaming.  We never want to ignore something inside of grace note
  // beaming, so return true.
  return true;
}

void
Grace_auto_beam_engraver::process_music ()
{
  auto now = now_mom ();
  // Update last_grace_start_ and last_grace_position_ only when the
  // main time advances.
  if (now.main_part_ > last_grace_start_.main_part_)
    {
      last_grace_start_ = now;
      last_grace_position_ = measure_position (context ());
    }

  Auto_beam_engraver::process_music ();
}

bool
Grace_auto_beam_engraver::test_moment (Direction dir, Moment const &test_mom,
                                       Rational const &) const
{
  // If no grace group started this main moment, we have no business
  // beaming.  Same if we have left the original main time step.
  if (!last_grace_start_.grace_part_
      || last_grace_position_.main_part_ != test_mom.main_part_)
    return false;
  // Autobeam start only when at the start of the grace group.
  if (dir == START)
    return last_grace_position_ == test_mom;
  // Autobeam end only when the grace part is finished.
  return !test_mom.grace_part_;
}

void
Grace_auto_beam_engraver::boot ()
{
  ADD_LISTENER (beam_forbid);
  ADD_ACKNOWLEDGER (stem);
  ADD_ACKNOWLEDGER (beam);
  ADD_ACKNOWLEDGER (breathing_sign);
  ADD_ACKNOWLEDGER (rest);
}

ADD_TRANSLATOR (Grace_auto_beam_engraver,
                /* doc */
                R"(
Generates one autobeam group across an entire grace phrase.  As usual, any
manual beaming or @code{\noBeam} will block autobeaming, just like setting the
context property @samp{autoBeaming} to @code{##f}.
                )",

                /* create */
                R"(
Beam
                )",

                /* read */
                R"(
autoBeaming
                )",

                /* write */
                R"(

                )");
