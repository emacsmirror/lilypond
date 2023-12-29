\version "2.25.1"

\header {
  lsrtags = "expressive-marks, tweaks-and-overrides"

  texidoc = "
The vertical ordering of scripts is controlled with the
@code{script-priority} property.  The lower this number, the closer it will
be put to the note.  In this example, the @code{TextScript} (the
@emph{sharp} symbol) first has the lowest priority, so it is put lowest in
the first example.  In the second, the @emph{prall trill} (the
@code{Script}) has the lowest, so it is on the inside.  When two objects
have the same priority, the order in which they are entered determines which
one comes first.

Note that for @code{Fingering}, @code{StringNumber}, and @code{StrokeFinger}
grobs, if used within a chord, the vertical order is also determined by the
vertical position of the associated note head, which is added to (or,
depending on the direction, subtracted from) the grob's
@code{script-priority} value.  This ensures that for fingerings above a
chord the lower note is associated with the lower fingering (and vice versa
for the other direction); it doesn't matter whether you input the notes in
the chord from top to bottom or from bottom to top.

By default, the least technical scripts are positioned closest to the note
head; the rough order is articulation, flageolet, fingering, right-hand
fingering, string number, fermata, bowing, and text script."

  doctitle = "Controlling the vertical ordering of scripts"
}


\relative c''' {
  \once \override TextScript.script-priority = -100
  a2^\prall^\markup { \sharp }

  \once \override Script.script-priority = -100
  a2^\prall^\markup { \sharp }

  \set fingeringOrientations = #'(up)
  <c-2 a-1>2
  <a-1 c\tweak script-priority -100 -2>2
}
