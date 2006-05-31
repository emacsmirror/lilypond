/*   
  output-property-engraver.cc -- implement Output_property_engraver
  
  source file of the GNU LilyPond music typesetter
  
  (c) 2000--2006 Han-Wen Nienhuys <hanwen@xs4all.nl>
  
 */

#include "engraver.hh"
#include "grob.hh"
#include "context.hh"

#include "translator.icc"


class Output_property_engraver : public Engraver
{
  TRANSLATOR_DECLARATIONS (Output_property_engraver);
protected:
  vector<Music*> props_;
  DECLARE_ACKNOWLEDGER (grob)

  void stop_translation_timestep ();
  virtual bool try_music (Music*);
};


bool
Output_property_engraver::try_music (Music* m)
{
  if (m->is_mus_type ("layout-instruction"))
    {
      /*
	UGH. Only swallow the output property event in the context
	it was intended for. This is inelegant but not inefficient.
      */
      if (context ()->is_alias (m->get_property ("context-type")))
        {
          props_.push_back (m);
          return true;
        }
    }
  return false;
}

void
Output_property_engraver::acknowledge_grob (Grob_info inf)
{
  for (vsize i = props_.size (); i--;)
    {
      Music *o = props_[i];
      Context *d = inf.context ();
      SCM proc = o->get_property ("procedure");
      scm_call_3 (proc,
		  inf.grob ()->self_scm (),
		  d->self_scm (), 
		  context ()->self_scm ());
    }
}

void
Output_property_engraver::stop_translation_timestep ()
{
  props_.clear ();
}

Output_property_engraver::Output_property_engraver ()
{
}

ADD_ACKNOWLEDGER (Output_property_engraver,grob);
ADD_TRANSLATOR (Output_property_engraver,

		/* doc */
		"Apply a procedure to any grob acknowledged. ",
		
		/* create */
		"",
		
		/* accept */
		"layout-instruction",
		
		/* read */
		"",
		
		/* write */
		"");
