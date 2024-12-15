# lys-to-tely.py
#
# This file is part of LilyPond, the GNU music typesetter.
#
# Copyright (C) 2002--2023 Han-Wen Nienhuys <hanwen@xs4all.nl>,
# Copyright (C) 2001--2023 Jan Nieuwenhuizen <janneke@gnu.org>
#
# LilyPond is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# LilyPond is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LilyPond.  If not, see <http://www.gnu.org/licenses/>.

'''
TODO:

 * Add @nodes, split at sections?

 * -o --output   listed in help is not implemented?!
'''


import sys
import os
import getopt
import re
import glob

from pathlib import Path


program_name = 'lys-to-tely'

include_snippets = '@lysnippets'
fragment_options = 'printfilename,texidoc'
help_text = r"""Usage: %(program_name)s [OPTIONS]... LY-FILE...
Construct tely doc from LY-FILEs.

Options:
 -h, --help                  print this help
 -f, --fragment-options=OPTIONS
                             use OPTIONS as lilypond-book fragment options
 -o, --output=OUTPUT         write tely doc to OUTPUT
 -n, --name=NAME             use NAME for info file name
     --prefix=PREFIX         prefix filenames with PREFIX
 -i, --input-filenames=NAME  read list of files from a file instead of stdin
 -g, --glob-input=GLOB       a string which will be passed to glob.glob(GLOB)
 -t, --title=TITLE           set tely doc title to TITLE
 -a, --author=AUTHOR         set tely author to AUTHOR
     --template=TEMPLATE     use TEMPLATE as texinfo template file instead of
                               standard template; TEMPLATE should contain a
                               marker '%(include_snippets)s' to indicate
                               where to insert LY-FILEs.  When this option is
                               used, NAME and TITLE are ignored

If a lilypond-book options file exists for an input file (stripping off the
file name's suffix and appending `.lybook`) that gets eventually included
with `@musicxmlfile` or `@lilypondfile`, use its contents as additional
fragment options (separated by whitespace) for this input file.
"""


def help(text):
    sys.stdout.write(text)
    sys.exit(0)


(options, files) = getopt.getopt(sys.argv[1:], 'f:hn:t:',
                                 ['fragment-options=', 'help', 'name=',
                                  'title=', 'author=', 'template=',
                                  'input-filenames=', 'glob-input=',
                                  'prefix=', 'output='])

name = "ly-doc.info"
output = "ly-doc.tely"
title = "Ly Doc"
author = "The LilyPond development team"
input_filename = ""
glob_input = ""
template = r'''\input texinfo

@c This file was autogenerated
@c     from: %s
@c     by:   %s

@settitle %%(title)s

@documentencoding UTF-8
@afourpaper

@finalout @c we do not want black boxes.

@titlepage
@title LilyPond
@subtitle The music typesetter
@titlefont{%%(title)s}
@author %%(author)s
@end titlepage

@ifnottex
@node Top
@top %%(title)s
@end ifnottex

%s

@bye
''' % (", ".join(files), sys.argv[0], include_snippets)

prefix = ''

for opt in options:
    o = opt[0]
    a = opt[1]
    if o == '-h' or o == '--help':
        # We can't use vars () inside a function, as that only contains all
        # local variables and none of the global variables! Thus we have to
        # generate the help text here and pass it to the function...
        help(help_text % vars())
    elif o == '-n' or o == '--name':
        name = a
    elif o == '-o' or o == '--output':
        output = a
    elif o == '-t' or o == '--title':
        title = a
    elif o == '-a' or o == '--author':
        author = a
    elif o == '-i' or o == '--input-filenames':
        input_filename = a
    elif o == '-p' or o == '--glob-input':
        glob_input = a
    elif o == '-f' or o == '--fragment-options':
        fragment_options = a
    elif o == '--prefix':
        prefix = a
    elif o == '--template':
        template = open(a, 'r', encoding='utf-8').read()
    else:
        raise Exception('unknown option: ' + o)

html_file_re = re.compile(r'.*\.i?html?$')
info_file_re = re.compile(r'.*\.info$')
pdf_file_re = re.compile(r'.*\.i?pdf$')
tex_file_re = re.compile(r'.*\.i?(la)?tex$')
texi_file_re = re.compile(r'.*\.i?te(ly|xi|xinfo)$')
xml_file_re = re.compile(r'.*\.i?(xm|mx)l$')


def name2line(n):
    file_name = Path(n)
    options_file = file_name.with_suffix('.lybook')

    options_string = ''
    if os.path.isfile(options_file):
        options = open(options_file, encoding='utf-8').read().split()
        if options:
            options_string = ',' + ','.join(options)

    if texi_file_re.match(n):
        # We have a texi include file, simply include it:
        s = r"@include %s" % os.path.basename(n)
    elif (html_file_re.match(n) or info_file_re.match(n)
          or pdf_file_re.match(n) or tex_file_re.match(n)):
        s = r"""
@ifhtml
@html
<a href="%s">%s</a>
<br/>
@end html
@end ifhtml
""" % (os.path.basename(n), os.path.basename(n))

    elif xml_file_re.match(n):
        # Assume it's a MusicXML file -> convert, create image etc.
        s = r"""
@ifhtml
@html
<a name="%s"></a>
@end html
@end ifhtml

@musicxmlfile[%s]{%s}
""" % (os.path.basename(n), fragment_options + options_string, prefix + n)

    else:
        # Assume it's a lilypond file -> create image etc.
        s = r"""
@ifhtml
@html
<a name="%s"></a>
@end html
@end ifhtml

@lilypondfile[%s]{%s}
""" % (os.path.basename(n), fragment_options + options_string, prefix + n)
    return s


if glob_input:
    files = glob.glob(glob_input)
elif input_filename:
    files = open(input_filename, encoding='utf-8').read().split()

if files:
    template = template % vars()
    s = "\n".join(map(name2line, files))
    s = template.replace(include_snippets, s, 1)
    h = open(output, "w", encoding="utf8")
    h.write(s)
    h.close()
else:
    # not Unix philosophy, but hey, at least we notice when
    # we don't distribute any .ly files.
    sys.stderr.write(
        "No files specified. Doing nothing. Use -h to display usage.")
