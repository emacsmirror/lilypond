%% Do not edit this file; it is automatically
%% generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.13.16"

\header {
  lsrtags = "rhythms, vocal-music, ancient-notation, contexts-and-engravers"

%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549
  texidoces = "
Este tipo de notación se utiliza para el canto de los Salmos, en
que las estrofas no siempre tienen la misma longitud.

"
  doctitlees = "Notación de responsos o salmos"

  texidoc = "
This form of notation is used for the chant of the Psalms, where verses
aren't always the same length.

"
  doctitle = "Chant or psalms notation"
} % begin verbatim

stemOn = { \revert Staff.Stem #'transparent }
stemOff = { \override Staff.Stem #'transparent = ##t }

\score {
  \new Staff \with { \remove "Time_signature_engraver" }
  {
    \key g \minor
    \cadenzaOn
    \stemOff a'\breve bes'4 g'4
    \stemOn a'2 \bar "||"
    \stemOff a'\breve g'4 a'4
    \stemOn f'2 \bar "||"
    \stemOff a'\breve^\markup { \italic flexe }
    \stemOn g'2 \bar "||"
  }
}

