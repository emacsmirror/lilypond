%% Do not edit this file; it is auto-generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.11.49"

\header {
  lsrtags = "vocal-music, chords, template"

  texidoc = "
Here is a simple lead sheet template with melody, lyrics, chords and
fret diagrams.

"
  doctitle = "Single staff template with notes, lyrics, chords and frets"
} % begin verbatim
% Define the fret diagrams to be used
cFretDiagram = \markup {
  \fret-diagram #"5-3-3;4-2-2;3-o;2-1-1;1-o"
}

gFretDiagram = \markup {
  \fret-diagram #"6-3-2;5-2-1;4-o;3-o;2-o;1-3-3"
}

verseI = \lyricmode {
  \set stanza = #"1."
  This is the first verse
}

verseII = \lyricmode {
  \set stanza = #"2."
  This is the second verse.
}

theChords = \new ChordNames {
  \chordmode {
    % insert the chords for chordnames here
    c2 g4 c
  }
}

staffMelody = \new Staff  {
 \context Voice = "voiceMelody" {
   \key c \major
   \clef treble
   \relative c' {
     % Type notes and fret diagram markups here
     c4^\cFretDiagram d8 e f4^\gFretDiagram g^\cFretDiagram
     \bar "|."
   }
 }
}

\score {
  <<
    \theChords
    \staffMelody
    \new Lyrics = "lyricsI" \lyricmode {
      \lyricsto "voiceMelody" \verseI
    }
    \new Lyrics = "lyricsII" \lyricmode {
      \lyricsto "voiceMelody" \verseII
    }
  >>
  \layout { }
  \midi { }
}
