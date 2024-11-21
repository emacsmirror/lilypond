/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 2001--2023  Han-Wen Nienhuys <hanwen@xs4all.nl>
                  Erik Sandberg <mandolaerik@gmail.com>

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

#include "callback.hh"
#include "context.hh"
#include "input.hh"
#include "music.hh"
#include "sequential-iterator.hh"
#include "lily-imports.hh"

class Percent_repeat_iterator final : public Sequential_iterator
{
public:
  OVERRIDE_CLASS_NAME (Percent_repeat_iterator);
  DECLARE_SCHEME_CALLBACK (constructor, ());
  Percent_repeat_iterator () = default;

protected:
  void create_contexts () override;
  void derived_mark () const override;
  void next_element () override;

private:
  int done_count_ = 0;
  int rep_count_ = 0;
  Moment body_length_;
  SCM event_type_ = SCM_UNDEFINED;
  SCM slash_count_ = SCM_UNDEFINED;
};

IMPLEMENT_CTOR_CALLBACK (Percent_repeat_iterator);

void
Percent_repeat_iterator::derived_mark () const
{
  scm_gc_mark (event_type_);
  scm_gc_mark (slash_count_);
  Sequential_iterator::derived_mark ();
}

void
Percent_repeat_iterator::create_contexts ()
{
  auto *mus = get_music ();
  if (auto *body = unsmob<Music> (get_property (mus, "element")))
    body_length_ = body->get_length ();
  rep_count_ = from_scm<int> (get_property (mus, "repeat-count"));

  Sequential_iterator::create_contexts ();

  descend_to_bottom_context ();
}

// Arrive here for the first time after the original percent expression is
// completed, and then after each placeholder element.  At this point of time,
// we can determine what kind of percent expression we are dealing with and
// provide the respective music expressions for the remaining repeats.
void
Percent_repeat_iterator::next_element ()
{
  Sequential_iterator::next_element ();

  ++done_count_;
  if (done_count_ < rep_count_)
    {
      Music *mus = get_music ();
      if (done_count_ == 1)
        {
          const auto mlen = measure_length (get_context ());
          if (body_length_.main_part_ == mlen)
            event_type_ = ly_symbol2scm ("PercentEvent");
          else if (body_length_.main_part_ == (mlen * 2))
            event_type_ = ly_symbol2scm ("DoublePercentEvent");
          else
            {
              if (auto *body = unsmob<Music> (get_property (mus, "element")))
                {
                  slash_count_
                    = Lily::calc_repeat_slash_count (body->self_scm ());
                }
              event_type_ = ly_symbol2scm ("RepeatSlashEvent");
            }
        }

      Music *percent = make_music_by_name (event_type_);
      percent->set_spot (*mus->origin ());
      set_property (percent, "length", to_scm (body_length_));
      set_property (percent, "repeat-count", to_scm (done_count_ + 1));
      if (!SCM_UNBNDP (slash_count_))
        set_property (percent, "slash-count", slash_count_);
      report_event (percent);
      percent->unprotect ();
    }
}
