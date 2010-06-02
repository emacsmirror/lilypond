% Do not edit this file; it is automatically
% generated from Documentation/snippets/new
% This file is in the public domain.
%% Note: this file works from version 2.13.4
\version "2.13.16"

\header {
%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549


  texidoces = "
A diferencia de los glissandos, los @q{slides} o ligaduras pueden
partir de un punto impreciso del mástil hasta un traste específico.
Una buena forma de hacerlo es añadir una nota de mordente antes de la
nota real, como se muestra en el ejemplo siguiente.

"

  doctitlees = "Ligaduras de guitarra"

  lsrtags = "fretted-strings"

  texidoc = "
Unlike glissandos, slides may go from an imprecise point of the
fretboard to a specific fret. A good way to do that is to add a grace
hidden note before the note which is actually played, as demonstrated
in the following example.
"
  doctitle = "Guitar slides"
} % begin verbatim


%% Hide fret number: useful to draw slide into/from a casual point of
%% the fretboard.
hideFretNumber = {
  \once \override TabNoteHead #'transparent = ##t
  \once \override NoteHead #'transparent = ##t
  \once \override Stem #'transparent = ##t
  \once \override NoteHead #'no-ledgers = ##t
  \once \override Glissando #'(bound-details left padding) = #0.3
}

music= \relative c' {
  \grace { \hideFretNumber d8\2 \glissando s2 } g2\2
  \grace { \hideFretNumber g8\2 \glissando s2 } d2 |

  \grace { \hideFretNumber c,8 \glissando s } f4\5^\markup \tiny { Slide into }
  \grace { \hideFretNumber f8 \glissando s } a4\4
  \grace { \hideFretNumber e'8\3 \glissando s } b4\3^\markup \tiny { Slide from }
  \grace { \hideFretNumber b'8 \glissando s2 } g4 |
}

\score {
  <<
    \new Staff {
      \clef "G_8"
      \music
    }
    \new TabStaff {
      \music
    }
  >>
}
