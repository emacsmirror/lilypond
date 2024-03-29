\version "2.23.3"

\header {
  texidoc = "@code{ly:grob-object} supports a third optional parameter, the
fallback value to use when the property is undefined in the grob.  This
test should print 'Test OK' twice."
}

{
  \override Score.SpacingSpanner.spacing-increment = 5
  \override NoteColumn.after-line-breaking =
  #(lambda (grob)
     (let ((rest (ly:grob-object grob 'rest #f)))
       (if rest
           (ly:grob-set-property!
            rest
            'stencil
            (lambda (grob)
              (grob-interpret-markup grob "Test OK"))))))
  c' d' e' f'
  r4 c' r g
  c1
}
