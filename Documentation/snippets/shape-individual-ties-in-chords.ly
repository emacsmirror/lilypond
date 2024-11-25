%% DO NOT EDIT this file manually; it was automatically
%% generated from the LilyPond Snippet Repository
%% (http://lsr.di.unimi.it).
%%
%% Make any changes in the LSR itself, or in
%% `Documentation/snippets/new/`, then run
%% `scripts/auxiliar/makelsr.pl`.
%%
%% This file is in the public domain.

\version "2.24.0"

\header {
  lsrtags = "staff-notation, tweaks-and-overrides"

  texidoc = "
To shape individual ties in chords use the method demonstrated below.
"

  doctitle = "Shape individual ties in chords"
} % begin verbatim


\paper { tagline = ##f }

\markup "Chords can be tied note by note"

{ <c'~ e'~ g'~ c''~>2 q }

\markup \wordwrap {
Affecting those ties with "\\shape" will not succeed, because TieColumn positions
them on its own behalf and more or less ignores the "\\shape-input".
You may surpress this by setting 'positioning-done true. Alas, 'positioning-done
is an internal property, setting it true means: all positioning is done, don't
do anything further. So you better take care you really did. See the example
below where this is missed: All directions are down and the thickness is not
accurate:
}

{
  <c'~ e'~ g'~ c''~>2
  \once \override TieColumn.positioning-done = ##t
  q
}

\markup "To cure that, enter ties with explicit direction-modifiers"

{
  <c'_~ e'_~ g'_~ c''^~>2
  \once \override TieColumn.positioning-done = ##t
  q
}

\markup "Now you can use \\shape for each tie as usual"

{
  <c'-\shape #'((0 . 0) (0 . -10) (0 . -10) (0 . 0)) _~
   e'-\shape #'((0 . 0) (0 . -5) (0 . -5) (0 . 0)) _~
   g'-\shape #'((0 . 0) (0 . -2) (0 . -2) (0 . 0)) _~
   c''-\shape #'((0 . 0) (0 . 5) (0 . 5) (0 . 0)) ^~
  >2
  \once \override TieColumn.positioning-done = ##t
  q
}

\markup "This works at line break as well."

{
  <c'-\shape #'(((0 . 0) (0 . -10) (0 . -10) (0 . 0))
                ((0 . 0) (0 . -10) (0 . -10) (0 . 0)))
     _~
   e'-\shape #'(((0 . 0) (0 . -5) (0 . -5) (0 . 0))
                ((0 . 0) (0 . -5) (0 . -5) (0 . 0)))
     _~
   g'-\shape #'(((0 . 0) (0 . -2) (0 . -2) (0 . 0))
                ((0 . 0) (0 . -2) (0 . -2) (0 . 0)))
     _~
   c''-\shape #'(((0 . 0) (0 . 5) (0 . 5) (0 . 0))
                 ((0 . 0) (0 . 5) (0 . 5) (0 . 0)))
     ^~
  >2
  \break
  \once \override TieColumn.positioning-done = ##t
  q
}

\markup "Same with tieWaitForNote"

{
  \set tieWaitForNote = ##t
  c'4-\shape #'((0 . 0) (0 . -10) (0 . -10) (0 . 0)) _~
  e'-\shape #'((0 . 0) (0 . -5) (0 . -5) (0 . 0)) _~
  g'-\shape #'((0 . 0) (0 . -2) (0 . -2) (0 . 0)) _~
  c''-\shape #'((0 . 0) (0 . 5) (0 . 5) (0 . 0)) ^~
  \once \override TieColumn.positioning-done = ##t
  <c' e' g' c''>1
}
