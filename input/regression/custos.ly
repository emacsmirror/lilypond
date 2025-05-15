\version "2.17.6"
\header {
    texidoc = "Custodes may be engraved in various styles."
}

\layout {
  \context {
    \Staff
    \consists "Custos_engraver"
  }
  ragged-right = ##t
}



{
  \override Staff.Custos.neutral-position = #4

  \override Staff.Custos.style = #'hufnagel
  c'1^"hufnagel"
  \break < a d' a' f'' a''>1

  \override Staff.Custos.style = #'medicaea
  c'1^"medicaea"
  \break < a d' a' f'' a''>1

  \override Staff.Custos.style = #'vaticana
  c'1^"vaticana"
  \break < a d' a' f'' a''>1

  \override Staff.Custos.style = #'mensural
  c'1^"mensural"
  \break < a d' a' f'' a''>1
}
