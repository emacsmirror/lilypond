/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 2005--2023 Han-Wen Nienhuys <hanwen@xs4all.nl>

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

#include "config.hh"

#include "file-path.hh"
#include "international.hh"
#include "main.hh"
#include "warn.hh"

#include <cstdio>
#include <fontconfig/fontconfig.h>
#include <sys/stat.h>

FcConfig *font_config_global = 0;

void
init_fontconfig ()
{
  debug_output (_ ("Initializing FontConfig..."));

  /* Create an empty configuration */
  font_config_global = FcConfigCreate ();

  /* fontconfig conf files */
  std::vector<std::string> confs;

  /* LilyPond local fontconfig conf file 00
     This file is loaded *before* fontconfig's default conf. */
  confs.push_back (lilypond_datadir + "/fonts/00-lilypond-fonts.conf");

  /* fontconfig's default conf file */
  {
    FcChar8 *default_conf = FcConfigFilename (nullptr);
    /* emplace_back only if default conf exists */
    if (default_conf)
      confs.emplace_back (reinterpret_cast<char *> (default_conf));
    else
      warning (_ ("cannot find fontconfig default config, skipping."));
    FcStrFree (default_conf);
  }

  /* LilyPond local fontconfig conf file 99
     This file is loaded *after* fontconfig's default conf. */
  confs.push_back (lilypond_datadir + "/fonts/99-lilypond-fonts.conf");

  /* Load fontconfig conf files */
  for (const auto &conf : confs)
    {
      auto *const fcstr = reinterpret_cast<const FcChar8 *> (conf.c_str ());
      if (!FcConfigParseAndLoad (font_config_global, fcstr, FcTrue))
        error (_f ("failed to add fontconfig configuration file `%s'",
                   conf.c_str ()));
      else
        debug_output (
          _f ("Adding fontconfig configuration file: %s", conf.c_str ()));
    }

  std::string dir (lilypond_datadir + "/fonts/otf");

  if (!FcConfigAppFontAddDir (font_config_global,
                              reinterpret_cast<const FcChar8 *> (dir.c_str ())))
    error (_f ("failed adding font directory: %s", dir.c_str ()));
  else
    debug_output (_f ("Adding font directory: %s", dir.c_str ()));

  debug_output (_ ("Building font database..."));

  // FcConfigParseAndLoad calls should be followed by FcConfigBuildFonts, which
  // does the actual work of building the font database using all the
  // configuration files loaded.  Note that adding extra configuration after
  // this function is called has indeterminate effect according to its
  // documentation, but adding application fonts is fine, and this is what
  // ly:font-config-add-{font,directory} do.
  FcConfigBuildFonts (font_config_global);

  FcConfigSetCurrent (font_config_global);

  debug_output ("\n");
}
