/*
  bar-number-grav.cc -- implement Bar_number_engraver

  source file of the GNU LilyPond music typesetter

  (c)  1997--1999 Han-Wen Nienhuys <hanwen@cs.uu.nl>
*/

#include "bar-number-engraver.hh"
#include "timing-translator.hh"
#include "timing-engraver.hh"
#include "engraver-group-engraver.hh"
#include "text-item.hh"

ADD_THIS_TRANSLATOR (Bar_number_engraver);

Bar_number_engraver::Bar_number_engraver()
{
  axis_ = Y_AXIS;
  type_ = "barNumber";
  visibility_lambda_
    = ly_eval_str ("postbreak-only-visibility");
}

void
Bar_number_engraver::do_process_requests ()
{
  Translator *tr = daddy_grav_l ()->get_simple_translator ("Timing_engraver");
  Timing_translator *time = dynamic_cast<Timing_translator*>(tr);

  // todo include (&&!time->cadenza_b_ )
  SCM bn = get_property("currentBarNumber",0);

  if (gh_number_p (bn) &&
      !time->measure_position () && now_mom () > Moment (0))
    {
      create_items (0);

      // guh.
      text_p_->set_elt_property ("text",
				 ly_str02scm (to_str (gh_scm2int (bn)).ch_C()));
				 
    }
}
