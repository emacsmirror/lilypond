
\header {

  texidoc = "With balloon texts, objects in the output can be marked,
with lines and explanatory text added."

}
\version "2.21.0"

\layout{ ragged-right = ##t }

\score{
  \new Voice \with {\consists "Balloon_engraver" }
  {
    \relative c'  {
      \balloonGrobText #'Stem #'(3 . 4) "I'm a Stem"
      <c-\balloonText #'(-2 . -2) "hoi"  >8
      \balloonLengthOn
      \balloonGrobText #'Rest #'(-1 . -2) "Rest"
      r
      \balloonLengthOff
      \balloonGrobText #'Script #'(-1 . -1) "Accent"
      c4->
    }
  }

  \layout {
    \context {
      \Score
      \override PaperColumn.keep-inside-line = ##f
    }
  }
}
