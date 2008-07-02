%% Do not edit this file; it is auto-generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.11.49"

\header {
  lsrtags = "unfretted-strings, template"

  texidoc = "
This template demonstrates a simple string quartet. It also uses a
@code{\\global} section for time and key signatures

"
  doctitle = "String quartet template (simple)"
} % begin verbatim
global= {
  \time 4/4
  \key c \major
}

violinOne = \new Voice \relative c'' {
  \set Staff.instrumentName = #"Violin 1 "
  
  c2 d
  e1
  
  \bar "|."
}
 
violinTwo = \new Voice \relative c'' {
  \set Staff.instrumentName = #"Violin 2 "
  
  g2 f
  e1
  
  \bar "|."
}

viola = \new Voice \relative c' {
  \set Staff.instrumentName = #"Viola "  
  \clef alto
  
  e2 d
  c1
  
  \bar "|."
}

cello = \new Voice \relative c' {
  \set Staff.instrumentName = #"Cello "
  \clef bass
  
  c2 b
  a1
  
  \bar "|."
}

\score {
  \new StaffGroup <<
    \new Staff << \global \violinOne >>
    \new Staff << \global \violinTwo >>
    \new Staff << \global \viola >>
    \new Staff << \global \cello >>
  >>
  \layout { }
  \midi { }
}
