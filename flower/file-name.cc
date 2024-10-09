/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1997--2023 Han-Wen Nienhuys <hanwen@xs4all.nl>
  Jan Nieuwenhuizen <janneke@gnu.org>

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

// TODO: Replace the whole file with the `<filesystem>` functionality
//       provided by C++17.  This will eventually avoid platform-dependent
//       code and tests.

#include "config.hh"

#include "file-name.hh"

#include "flower-proto.hh"
#include "std-vector.hh"

#include <cerrno>
#include <cstdio>
#include <limits.h>

#if HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#define ROOTSEP ':'
#define DIRSEP '/'

/** Use slash as directory separator.  On Windows, they can pretty
    much be exchanged.  */
#if 0
static /* avoid warning */
#endif
std::string
slashify (std::string file_name)
{
  replace_all (&file_name, '\\', '/');
  replace_all (&file_name, std::string ("//"), "/");
  return file_name;
}

std::string
dir_name (const std::string &file_name)
{
  std::string s = file_name;
  s = slashify (s);
  ssize n = s.length ();
  if (n && s[n - 1] == '/')
    s[n - 1] = 0;
  if (s.rfind ('/') != NPOS)
    s = s.substr (0, s.rfind ('/'));
  else
    s = "";

  return s;
}

std::string
get_working_directory ()
{
#ifdef PATH_MAX
  std::vector<char> cwd (PATH_MAX);
#else
  std::vector<char> cwd (1024);
#endif
  while (getcwd (cwd.data (), cwd.size ()) == NULL)
    {
      if (errno != ERANGE)
        {
          // getcwd () fails.
          return "";
        }
      cwd.resize (cwd.size () * 2);
    }
  return std::string (cwd.data ());
}

/* Join components to full file_name. */
std::string
File_name::dir_part () const
{
  std::string s;

  if (!root_.empty ())
    s = root_ + ROOTSEP;

  // handle special case of `/'
  if (dir_.empty () && is_absolute_)
    s += DIRSEP;

  if (!dir_.empty ())
    s += dir_;

  return s;
}

std::string
File_name::file_part () const
{
  std::string s = base_;

  if (!ext_.empty ())
    s += '.' + ext_;

  return s;
}

std::string
File_name::to_string () const
{
  std::string d = dir_part ();
  std::string f = file_part ();

  if (!f.empty () && !dir_.empty ())
    d += DIRSEP;

  return d + f;
}

File_name::File_name (std::string file_name)
{
  ssize i;

#ifdef __MINGW32__
  file_name = slashify (file_name);

  i = file_name.find (ROOTSEP);
  if (i != NPOS)
    {
      root_ = file_name.substr (0, i);
      file_name = file_name.substr (i + 1);
    }
#endif

  // note: `c:foo' is not absolute
  i = file_name.find (DIRSEP);
  is_absolute_ = (i == 0 ? true : false);

  i = file_name.rfind (DIRSEP);
  if (i != NPOS)
    {
      dir_ = file_name.substr (0, i);
      file_name = file_name.substr (i + 1);
    }

  // handle `.' and `..' specially
  if (file_name == std::string (".") || file_name == std::string (".."))
    {
      if (!dir_.empty ())
        dir_ += DIRSEP;
      dir_ += file_name;
      return;
    }

  i = file_name.rfind ('.');
  if (i != NPOS)
    {
      base_ = file_name.substr (0, i);
      ext_ = file_name.substr (i + 1);
    }
  else
    base_ = file_name;
}

bool
File_name::is_absolute () const
{
  return is_absolute_;
}

File_name
File_name::absolute (std::string const &cwd) const
{
  if (is_absolute_)
    return *this;

  File_name abs;
  File_name cwd_name (cwd + "/file.ext");

  abs.is_absolute_ = true;
  /*
    See
    https://devblogs.microsoft.com/oldnewthing/20101011-00/?p=12563
    for more background on cwd per drive.
   */
  abs.root_ = cwd_name.root_;
  abs.dir_ = cwd_name.dir_;
  if (!dir_.empty ())
    abs.dir_ += "/" + dir_;
  abs.base_ = base_;
  abs.ext_ = ext_;
  return abs;
}

File_name
File_name::canonicalized () const
{
  File_name c = *this;

  replace_all (&c.dir_, std::string ("//"), std::string ("/"));

  std::vector<std::string> components = string_split (c.dir_, '/');
  std::vector<std::string> new_components;

  for (vsize i = 0; i < components.size (); i++)
    {
      if (i && components[i] == std::string ("."))
        continue;
      else if (new_components.size () && components[i] == std::string (".."))
        {
          std::string s = new_components.back ();
          new_components.pop_back ();
          if (!new_components.size ())
            {
              if (s == std::string ("."))
                new_components.push_back ("..");
              else
                new_components.push_back (".");
            }
        }
      else
        new_components.push_back (components[i]);
    }

  c.dir_ = string_join (new_components, "/");
  return c;
}
