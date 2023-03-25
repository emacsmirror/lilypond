\version "2.25.4"

\header {
  texidoc = "
The explicit directional override codes, U+202D and U+202E, are
supported in single-line markup strings.  The overrides must be
terminated with the pop directional formatting character, U+202C.
"
}

%{
You may have to install additional fonts.

Red Hat Fedora

  linux-libertine-fonts (Latin, Hebrew)

Debian GNU/Linux, Ubuntu

  fonts-linuxlibertine (Latin, Hebrew)
%}

% Linux Libertine fonts contain Hebrew glyphs.
\paper {
  fonts.roman = "Linux Libertine O, serif"
}

\markup {
  \column {
    "אבג דהו זחט יךכ"
    "‭אבג דהו זחט יךכ‬"
    \null
    "abc def ghi jkl"
    "‮abc def ghi jkl‬"
  }
}
