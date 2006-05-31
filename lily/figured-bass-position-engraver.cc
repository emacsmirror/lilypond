/*
  figured-bass-position-engraver.cc -- implement Figured_bass_engraver

  source file of the GNU LilyPond music typesetter

  (c) 2005--2006 Han-Wen Nienhuys <hanwen@xs4all.nl>

*/

#include "engraver.hh"

#include "context.hh"
#include "music.hh"
#include "spanner.hh"
#include "side-position-interface.hh"
#include "translator.icc"
#include "axis-group-interface.hh"

class Figured_bass_position_engraver : public Engraver
{
  TRANSLATOR_DECLARATIONS(Figured_bass_position_engraver);

  Spanner *bass_figure_alignment_;
  Spanner *positioner_;
  vector<Grob*> note_columns_;

protected:
  DECLARE_ACKNOWLEDGER (note_column);
  DECLARE_ACKNOWLEDGER (bass_figure_alignment);
  DECLARE_END_ACKNOWLEDGER (bass_figure_alignment);

  virtual void finalize ();
  void start_spanner ();
  void stop_spanner ();
  void stop_translation_timestep ();
};

Figured_bass_position_engraver::Figured_bass_position_engraver ()
{
  positioner_ = 0;
  bass_figure_alignment_ = 0;
}

void
Figured_bass_position_engraver::start_spanner ()
{
  assert (!positioner_);

  positioner_ = make_spanner("BassFigureAlignmentPositioning", bass_figure_alignment_->self_scm ());
  positioner_->set_bound (LEFT, bass_figure_alignment_->get_bound (LEFT));
  Axis_group_interface::add_element (positioner_, bass_figure_alignment_);
}

void
Figured_bass_position_engraver::stop_spanner ()
{
  if (positioner_ && !positioner_->get_bound (RIGHT))
    {
      positioner_->set_bound (RIGHT, bass_figure_alignment_->get_bound (RIGHT));
    }
  
  positioner_ = 0;
  bass_figure_alignment_ = 0;
}

void
Figured_bass_position_engraver::finalize () 
{
  stop_spanner ();
}

void
Figured_bass_position_engraver::acknowledge_note_column (Grob_info info)
{
  note_columns_.push_back (info.grob ());
}

void
Figured_bass_position_engraver::stop_translation_timestep ()
{
  if (positioner_)
    {
      for (vsize i = 0; i < note_columns_.size (); i++)
	Side_position_interface::add_support (positioner_, note_columns_[i]);
    }

  note_columns_.clear ();
}

void
Figured_bass_position_engraver::acknowledge_end_bass_figure_alignment (Grob_info info)
{
  (void)info;
  stop_spanner ();
}

void
Figured_bass_position_engraver::acknowledge_bass_figure_alignment (Grob_info info)
{
  bass_figure_alignment_ = dynamic_cast<Spanner*> (info.grob ());
  start_spanner ();
}


ADD_ACKNOWLEDGER(Figured_bass_position_engraver,note_column);
ADD_ACKNOWLEDGER(Figured_bass_position_engraver,bass_figure_alignment);
ADD_END_ACKNOWLEDGER(Figured_bass_position_engraver,bass_figure_alignment);

ADD_TRANSLATOR (Figured_bass_position_engraver,
		/* doc */
		"Position figured bass alignments over notes.",
		
		/* create */
		"BassFigureAlignmentPositioning ",

		/* accept */ "",

		/* read */
		" ",
		/* write */ "");
