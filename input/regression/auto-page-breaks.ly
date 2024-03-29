\version "2.25.0"

\header {
  texidoc = "@code{\\autoPageBreaksOff} turns off automatic
page breaking; @code{\\autoPageBreaksOn} reenables it."
}

\paper {
  #(set-paper-size "b8")
  short-indent = 2
}

{
  \repeat unfold 15 { c'1 }
  \autoPageBreaksOff
  \repeat unfold 15 { d'1 }
  \pageBreak
  \repeat unfold 15 { e'1 }
  \autoPageBreaksOn
  \repeat unfold 15 { f'1 }
}
