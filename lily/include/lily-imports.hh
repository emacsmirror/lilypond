/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 2015--2023 by David Kastrup <dak@gnu.org>

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

#ifndef LILY_IMPORTS_HH
#define LILY_IMPORTS_HH

#include "lily-modules.hh"

namespace Guile_user
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable apply;
extern Variable boolean_p;
extern Variable debug_options;
extern Variable equal;
extern Variable f_default_port_encoding;
extern Variable less;
extern Variable plus;
extern Variable make_module;
extern Variable min;
extern Variable module_export_all_x;
extern Variable module_export_x;
extern Variable module_public_interface;
extern Variable module_use_x;
extern Variable symbol_p;
extern Variable the_root_module;
} // namespace Guile_user

namespace Compile
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable compile;
extern Variable default_optimization_level;
} // namespace Compile

namespace Display
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable value_to_lily_string;
} // namespace Display

namespace Goops
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable make;
} // namespace Goops

namespace Hash_table
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable alist_to_hashq_table;
} // namespace Hash_table

namespace Lily
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable all_music_font_encodings;
extern Variable alterations_in_key;
extern Variable backend_testing;
extern Variable bar_glyph_alist;
extern Variable bar_line_calc_glyph_name_for_direction;
extern Variable beam_exceptions;
extern Variable beat_base;
extern Variable beat_structure;
extern Variable calc_measure_length;
extern Variable calc_repeat_slash_count;
extern Variable car_less;
extern Variable clipped_systems_stencils;
extern Variable construct_chord_elements;
extern Variable default_global_scale;
extern Variable default_time_signature_settings;
extern Variable define_markup_command_internal;
extern Variable deprecated_translation_getter_description;
extern Variable deprecated_setter_object_property;
extern Variable feta_design_size_mapping;
extern Variable generate_crop_stencil;
extern Variable generate_preview_stencil;
extern Variable generate_system_stencils;
extern Variable grob_compose_function;
extern Variable grob_offset_function;
extern Variable hash_table_to_alist;
extern Variable headers_property_alist_chain;
extern Variable interpret_markup_list;
extern Variable invalidate_alterations;
extern Variable key_p;
extern Variable key_list_p;
extern Variable key_signature_interface_alteration_positions;
extern Variable layout_extract_page_properties;
extern Variable parse_and_check_version;
extern Variable lilypond_main;
extern Variable line_markup;
extern Variable f_location;
extern Variable lookup_markup_command;
extern Variable lookup_markup_list_command;
extern Variable ly_context_set_property_x;
extern Variable ly_event_p;
extern Variable ly_make_event_class;
extern Variable ly_music_p;
extern Variable make_concat_markup;
extern Variable make_left_brace_markup;
extern Variable make_music;
extern Variable make_span_event;
extern Variable make_tied_lyric_markup;
extern Variable markup_p;
extern Variable markup_command_signature;
extern Variable markup_function_p;
extern Variable markup_list_function_p;
extern Variable markup_list_p;
extern Variable markup_to_string;
extern Variable midi_program;
extern Variable f_parser;
extern Variable output_scopes;
extern Variable percussion_p;
extern Variable pitchnames;
extern Variable pure_chain_offset_callback;
extern Variable regex_match_class;
extern Variable remove_stencil_warnings;
extern Variable scale_p;
extern Variable scale_to_factor;
extern Variable scale_layout;
extern Variable scm_to_string;
extern Variable score_lines_markup_list;
extern Variable score_markup;
extern Variable scorify_music;
extern Variable stencil_whiteout;
extern Variable stencil_whiteout_box;
extern Variable stencil_with_color;
extern Variable symbol_list_p;
extern Variable type_name;
extern Variable unbroken_spanner_p;
extern Variable unbroken_or_first_broken_spanner_p;
extern Variable unbroken_or_last_broken_spanner_p;
extern Variable volta_bracket_calc_hook_visibility;
extern Variable write_performances_midis;
extern Variable write_lilypond_book_aux_files;
} // namespace Lily

namespace Loader
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable load_thunk_from_memory;
} // namespace Loader

namespace Page
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable calc_printable_height;
extern Variable make_page;
extern Variable page_stencil;
} // namespace Page

namespace Srfi_1
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable append_reverse;
extern Variable delete_duplicates;
extern Variable lset_union;
} // namespace Srfi_1

namespace Syntax
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable add_lyrics;
extern Variable alternative;
extern Variable argument_error;
extern Variable composed_markup_list;
extern Variable context_change;
extern Variable context_create;
extern Variable context_find_or_create;
extern Variable create_script;
extern Variable create_script_function;
extern Variable event_chord;
extern Variable lyric_combine;
extern Variable lyric_event;
extern Variable multi_measure_rest;
extern Variable music_function;
extern Variable music_function_call_error;
extern Variable partial_markup;
extern Variable partial_music_function;
extern Variable partial_text_script;
extern Variable property_override;
extern Variable property_revert;
extern Variable property_set;
extern Variable property_unset;
extern Variable repeat;
extern Variable repeat_alt;
extern Variable repetition_chord;
extern Variable sequential_music;
extern Variable simultaneous_music;
extern Variable tempo;
extern Variable unrelativable_music;
extern Variable unspecified_music;
}; // namespace Syntax

namespace Unicode
{
extern Scm_module module;
typedef Module_variable<module> Variable;

extern Variable char_2_formal_name;
}; // namespace Unicode

#endif // LILY_IMPORTS_HH
