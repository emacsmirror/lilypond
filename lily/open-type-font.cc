/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 2004--2023 Han-Wen Nienhuys <hanwen@xs4all.nl>

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

#include "open-type-font.hh"
#include "freetype.hh"
#include "zlib.h"

#include FT_FONT_FORMATS_H
#include FT_TRUETYPE_TABLES_H
#include FT_TRUETYPE_TAGS_H

#include "dimensions.hh"
#include "international.hh"
#include "lily-imports.hh"
#include "modified-font-metric.hh"
#include "warn.hh"

#include <cstdio>
#include <memory>
#include <unordered_map>
#include <utility>

std::string
load_font_table (FT_Face face, std::string const &tag_str)
{
  FT_ULong length = 0;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wold-style-cast"
  // The FT_MAKE_TAG macro has C-style casts and GCC is not smart enough to
  // ignore them.
  FT_ULong tag = FT_MAKE_TAG (tag_str[0], tag_str[1], tag_str[2], tag_str[3]);
#pragma GCC diagnostic pop

  FT_Error error_code = FT_Load_Sfnt_Table (face, tag, 0, NULL, &length);
  if (!error_code)
    {
      std::unique_ptr<FT_Byte[]> buffer (new FT_Byte[length]);
      if (!buffer)
        error (_f ("cannot allocate %lu bytes", length));

      error_code = FT_Load_Sfnt_Table (face, tag, 0, buffer.get (), &length);
      if (error_code)
        error (_f ("cannot load font table: %s", tag_str));

      std::string ret;
      ret.assign (reinterpret_cast<const char *> (buffer.get ()), length);
      return ret;
    }
  else
    {
      programming_error (
        _f ("FreeType error: %s", freetype_error_string (error_code).c_str ()));
      return "";
    }
}

SCM
load_scheme_table (const char *tag_str, FT_Face face)
{
  std::string contents = load_font_table (face, tag_str);

  // Try to decompress table.
  z_stream zs;
  memset (&zs, 0, sizeof (zs));

  if (inflateInit (&zs) != Z_OK)
    {
      error (_f ("cannot initialize zlib decompression"));
    }

  zs.next_in = reinterpret_cast<Bytef *> (contents.data ());
  zs.avail_in = static_cast<uInt> (contents.size ());

  int ret;
  char buf[32768];
  std::string inflated;

  // Get decompressed data block by block using a loop.
  do
    {
      zs.next_out = reinterpret_cast<Bytef *> (buf);
      zs.avail_out = sizeof (buf);

      ret = inflate (&zs, Z_NO_FLUSH);

      if (inflated.size () < zs.total_out)
        {
          inflated.append (buf, zs.total_out - inflated.size ());
        }
    }
  while (ret == Z_OK);

  inflateEnd (&zs);

  if (ret == Z_DATA_ERROR || ret == Z_NEED_DICT)
    {
      // Apparently not a compressed table, so load it as-is.
      contents = "(quote (" + contents + "))";
    }
  else
    {
      if (ret != Z_STREAM_END)
        {
          error (_f ("cannot uncompress font table: %s", tag_str));
        }
      contents = "(quote (" + inflated + "))";
    }

  return scm_eval_string (to_scm (contents));
}

Open_type_font::~Open_type_font ()
{
  FT_Done_Face (face_);
}

FT_Face
open_ft_face (const std::string &str, FT_Long idx)
{
  FT_Face face;
  FT_Error error_code
    = FT_New_Face (freetype2_library, str.c_str (), idx, &face);

  if (error_code == FT_Err_Unknown_File_Format)
    error (_f ("unsupported font format: %s", str.c_str ()));
  else if (error_code)
    error (_f ("error reading font file %s: %s", str.c_str (),
               freetype_error_string (error_code).c_str ()));
  return face;
}

std::string
get_font_format (FT_Face face)
{
  auto fmt = static_cast<std::string> (FT_Get_Font_Format (face));
  if (fmt == "CFF")
    {
      // 'CFF2' fonts use the 'CFF' technology, however, they can't be
      // embedded in PS files.  From a practical point of view, they are
      // like TTFs but having a 'CFF2' instead of a 'glyf' table, roughly
      // speaking.
      //
      // FIXME: The font format doesn't change and should be computed and
      //        stored somewhere in a class or structure while opening a
      //        font.
      FT_ULong num_tables;
      FT_Sfnt_Table_Info (face, 0, NULL, &num_tables);

      for (FT_UInt i = 0; i < FT_UInt (num_tables); i++)
        {
          FT_ULong tag, dummy;
          FT_Sfnt_Table_Info (face, i, &tag, &dummy);
          if (tag == TTAG_CFF2)
            return "CFF2";
        }
    }
  return fmt;
}

std::string
get_postscript_name (FT_Face face)
{
  std::string face_ps_name;
  const char *psname = FT_Get_Postscript_Name (face);
  if (psname)
    face_ps_name = psname;
  else
    {
      warning (_ ("cannot get postscript name"));
      return "";
    }

  std::string fmt = get_font_format (face);
  if (!fmt.empty ())
    {
      if (fmt != "CFF")
        return face_ps_name; // For non-CFF font, pass it through.
    }
  else
    {
      warning (_f ("cannot get font %s format", face_ps_name.c_str ()));
      return face_ps_name;
    }

  // For OTF and OTC fonts, we use data from the font's 'CFF' table only
  // because other tables are not embedded in the output PS file.
  // However, parsing CFF takes time, so we use a cache.
  std::string cff_name;
  static std::unordered_map<std::string, std::string> cff_name_cache;
  auto it = cff_name_cache.find (face_ps_name);
  if (it == cff_name_cache.end ())
    {
      cff_name = get_cff_name (face);

      if (cff_name == "")
        {
          warning (
            _f ("cannot get CFF name from font %s", face_ps_name.c_str ()));
          return face_ps_name;
        }
      if (face_ps_name != cff_name)
        {
          debug_output (_f ("Subsitute font name: %s => %s",
                            face_ps_name.c_str (), cff_name.c_str ()));
        }
      else
        {
          debug_output (
            _f ("CFF name for font %s is the same.", cff_name.c_str ()));
        }

      cff_name_cache[face_ps_name] = cff_name;
    }
  else
    {
      cff_name = it->second;
    }

  return cff_name;
}

std::string
get_cff_name (FT_Face face)
{
  std::string cff_table = load_font_table (face, "CFF ");

  FT_Open_Args args;
  args.flags = FT_OPEN_MEMORY;
  args.memory_base = static_cast<const FT_Byte *> (
    static_cast<const void *> (cff_table.data ()));
  args.memory_size = cff_table.size ();

  FT_Face cff_face;
  // According to OpenType Specification ver 1.7,
  // the CFF (derived from OTF and OTC) has only one name.
  // So we use zero as the font index.
  FT_Error error_code
    = FT_Open_Face (freetype2_library, &args, 0 /* font index */, &cff_face);
  if (error_code)
    {
      warning (_f ("cannot read CFF: %s",
                   freetype_error_string (error_code).c_str ()));
      return "";
    }

  std::string ret;
  const char *cffname = FT_Get_Postscript_Name (cff_face);
  if (cffname)
    ret = cffname;
  else
    {
      programming_error (_ ("cannot get CFF name"));
      ret = "";
    }

  FT_Done_Face (cff_face);

  return ret;
}

Preinit_Open_type_font::Preinit_Open_type_font ()
{
  lily_character_table_ = SCM_EOL;
  lily_global_table_ = SCM_EOL;
}

Open_type_font::Open_type_font (const std::string &filename)
  : filename_ (filename)
{
  face_ = open_ft_face (filename, /* index */ 0);

  lily_character_table_
    = Hash_table::alist_to_hashq_table (load_scheme_table ("LILC", face_));
  lily_global_table_
    = Hash_table::alist_to_hashq_table (load_scheme_table ("LILY", face_));
  index_to_charcode_map_ = make_index_to_charcode_map (face_);

  postscript_name_ = get_postscript_name (face_);
}

void
Open_type_font::derived_mark () const
{
  scm_gc_mark (lily_character_table_);
  scm_gc_mark (lily_global_table_);
}

Interval
Open_type_font::ledger_shortening_range (const std::string &glyph_name) const
{
  Interval range;

  SCM sym = ly_symbol2scm (glyph_name);
  SCM entry = scm_hashq_ref (lily_character_table_, sym, SCM_BOOL_F);
  if (scm_is_false (entry))
    return range;

  SCM range_scm = scm_assq_ref (entry,
                                ly_symbol2scm ("ledger-shortening-range"));
  if (!scm_is_pair (range_scm))
    return range;

  return Interval (from_scm<double> (scm_car (range_scm), 0),
                   from_scm<double> (scm_cdr (range_scm), 0)) * point_constant;
}

/*
  Get stem attachment point for a note head glyph.  This reads either
  attachment or attachment-down depending on the direction, for compliance
  with SMuFL.  However, when d is DOWN and attachment-down is not found,
  we fall back to rotating attachment around the note head's center, for
  backwards compatibility with fonts created earlier than the introduction of
  attachment-down.  We need the center of the note head for that, so we
  just delegate the work to Note_head::get_stem_attachment.
*/

std::pair<Offset, bool>
Open_type_font::attachment_point (const std::string &glyph_name,
                                  Direction d) const
{
  SCM sym = ly_symbol2scm (glyph_name);
  SCM entry = scm_hashq_ref (lily_character_table_, sym, SCM_BOOL_F);

  Offset o;
  if (scm_is_false (entry))
    return std::make_pair (o, false); // TODO: error out?

  SCM char_alist = entry;
  SCM att_scm = to_scm (Offset {});
  bool rotate = false;
  if (d == DOWN)
    {
      att_scm = scm_assq_ref (char_alist, ly_symbol2scm ("attachment-down"));
      if (scm_is_false (att_scm))
        {
          rotate = true;
        }
    }

  if (d == UP || rotate)
    {
      att_scm = scm_assq_ref (char_alist, ly_symbol2scm ("attachment"));
      if (scm_is_false (att_scm))
        {
          warning (
            _f ("no stem attachment found in font for glyph %s", glyph_name));
          return std::make_pair (o, false);
        }
    }

  return std::make_pair (point_constant * from_scm<Offset> (att_scm), rotate);
}

Box
Open_type_font::get_indexed_char_dimensions (size_t signed_idx) const
{
  auto const &bbox_it = lily_index_to_bbox_table_.find (signed_idx);
  if (bbox_it != lily_index_to_bbox_table_.end ())
    {
      return bbox_it->second;
    }

  const size_t len = 256;
  char name[len];
  FT_Error code
    = FT_Get_Glyph_Name (face_, FT_UInt (signed_idx), name, FT_UInt (len));
  if (code)
    warning (_f ("FT_Get_Glyph_Name () Freetype error: %s",
                 freetype_error_string (code)));

  SCM sym = ly_symbol2scm (name);
  SCM alist = scm_hashq_ref (lily_character_table_, sym, SCM_BOOL_F);

  if (scm_is_true (alist))
    {
      SCM bbox = scm_cdr (scm_assq (ly_symbol2scm ("bbox"), alist));

      Box b;
      b[X_AXIS][LEFT] = from_scm<double> (scm_car (bbox));
      bbox = scm_cdr (bbox);
      b[Y_AXIS][LEFT] = from_scm<double> (scm_car (bbox));
      bbox = scm_cdr (bbox);
      b[X_AXIS][RIGHT] = from_scm<double> (scm_car (bbox));
      bbox = scm_cdr (bbox);
      b[Y_AXIS][RIGHT] = from_scm<double> (scm_car (bbox));
      bbox = scm_cdr (bbox);

      b.scale (point_constant);

      lily_index_to_bbox_table_[signed_idx] = b;
      return b;
    }

  Box b = get_unscaled_indexed_char_dimensions (signed_idx);

  b.scale (design_size () / static_cast<Real> (face_->units_per_EM));
  return b;
}

Real
Open_type_font::get_units_per_EM () const
{
  return face_->units_per_EM;
}

size_t
Open_type_font::name_to_index (std::string nm) const
{
  FT_UInt idx = FT_Get_Name_Index (face_, const_cast<char *> (nm.c_str ()));
  size_t result = (idx != 0) ? idx : GLYPH_INDEX_INVALID;
  return result;
}

Box
Open_type_font::get_unscaled_indexed_char_dimensions (size_t signed_idx) const
{
  return ly_FT_get_unscaled_indexed_char_dimensions (face_, signed_idx);
}

Box
Open_type_font::get_glyph_outline_bbox (size_t signed_idx) const
{
  return ly_FT_get_glyph_outline_bbox (face_, signed_idx);
}

void
Open_type_font::add_outline_to_skyline (Lazy_skyline_pair *lazy,
                                        Transform const &transform,
                                        size_t signed_idx) const
{
  ly_FT_add_outline_to_skyline (lazy, transform, face_, signed_idx);
}

size_t
Open_type_font::index_to_charcode (size_t i) const
{
  auto iter = index_to_charcode_map_.find (FT_UInt (i));

  if (iter != index_to_charcode_map_.end ())
    return static_cast<size_t> (iter->second);
  else
    {
      programming_error ("Invalid index for character");
      return 0;
    }
}

size_t
Open_type_font::count () const
{
  return index_to_charcode_map_.size ();
}

Real
Open_type_font::design_size () const
{
  SCM entry = scm_hashq_ref (lily_global_table_, ly_symbol2scm ("design_size"),

                             /*
                               Hmm. Design size is arbitrary for
                               non-design-size fonts. I vote for 1 -
                               which will trip errors more
                               quickly. --hwn.
                             */
                             to_scm (1));
  return from_scm<double> (entry) * static_cast<Real> (point_constant);
}

SCM
Open_type_font::get_char_table () const
{
  return lily_character_table_;
}

SCM
Open_type_font::get_global_table () const
{
  return lily_global_table_;
}

std::string
Open_type_font::font_name () const
{
  return postscript_name_;
}

SCM
Open_type_font::glyph_list () const
{
  SCM retval = SCM_EOL;
  SCM *tail = &retval;

  for (int i = 0; i < face_->num_glyphs; i++)
    {
      const size_t len = 256;
      char name[len];
      FT_Error code = FT_Get_Glyph_Name (face_, i, name, len);
      if (code)
        warning (_f ("FT_Get_Glyph_Name () error: %s",
                     freetype_error_string (code).c_str ()));

      *tail = scm_cons (scm_from_latin1_string (name), SCM_EOL);
      tail = SCM_CDRLOC (*tail);
    }

  return retval;
}
