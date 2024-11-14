/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1997--2023 Jan Nieuwenhuizen <janneke@gnu.org>

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

#ifndef SOURCES_HH
#define SOURCES_HH

#include "file-path.hh"
#include "lily-guile.hh"
#include "lily-proto.hh"

#include <string>
#include <vector>

/** holds a list of Source_files, which are assumed to be protected
    objects. On destruction, unprotect the objects.
 */
class Sources
{
  Sources (Sources const &) = delete;
  Sources &operator= (Sources const &) = delete;

  std::vector<Source_file *> sourcefiles_;
  File_path path_;
  std::string find_full_path (std::string file_string,
                              const std::string &dir) const;

public:
  explicit Sources (File_path const &path)
    : path_ (path)
  {
  }
  ~Sources ();

  Source_file *get_file (std::string file_name, std::string const &currentpath);
  void add (Source_file *sourcefile);
  std::string search_path () const;
};

SCM ly_source_files (SCM parser_smob);

#endif /* SOURCES_HH */
