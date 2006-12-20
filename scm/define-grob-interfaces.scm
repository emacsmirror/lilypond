;;;; interface-description.scm -- part of generated backend documentation
;;;;
;;;;  source file of the GNU LilyPond music typesetter
;;;;
;;;; (c) 1998--2006  Han-Wen Nienhuys <hanwen@xs4all.nl>
;;;;                 Jan Nieuwenhuizen <janneke@gnu.org>


;; should include default value?


(ly:add-interface
 'accidental-suggestion-interface
   "An accidental, printed as a suggestion (typically: vertically over a note)"
   '())

(ly:add-interface
 'bass-figure-interface
 "A bass figure text"
 '(implicit))

(ly:add-interface
 'bend-after-interface
 "A doit or drop."
 '(thickness delta-position))

(ly:add-interface
 'bass-figure-alignment-interface
 ""
 '())

(ly:add-interface
 'dynamic-interface
   "Any kind of loudness sign"
   '())

(ly:add-interface
 'dynamic-line-spanner-interface
   "Dynamic line spanner"
   '(avoid-slur))

(ly:add-interface
 'finger-interface
 "A fingering instruction"
 '())

(ly:add-interface
 'fret-diagram-interface
 "A fret diagram"
 '(align-dir barre-type dot-color dot-radius finger-code fret-count
  label-dir number-type size string-count
  string-fret-finger-combinations thickness))

(ly:add-interface
 'grace-spacing-interface
 "Keep track of durations in a run of grace notes."
 '(columns common-shortest-duration))

(ly:add-interface
 'ligature-interface
 "A ligature"
 '())

(ly:add-interface
 'ligature-bracket-interface
 "A bracket indicating a ligature in the original edition"
 '(width thickness height))


(ly:add-interface
 'lyric-syllable-interface
 "A single piece of lyrics"
 '())

(ly:add-interface
 'lyric-interface
 "Any object that is related to lyrics."
 '())

(ly:add-interface
 'mark-interface
 "A rehearsal mark"
 '())

(ly:add-interface
 'metronome-mark-interface
 "A metronome mark"
 '())

(ly:add-interface
 'multi-measure-interface
 "Multi measure rest, and the text or number that is printed over it."
 '(bound-padding))

(ly:add-interface
'note-name-interface
 "Note name"
 '(style))

(ly:add-interface
 'only-prebreak-interface
 "Kill this grob after the line breaking process."
 '())

(ly:add-interface
 'parentheses-interface
 "Parentheses for other objects"
 '(padding stencils))

(ly:add-interface
 'piano-pedal-interface
 "A piano pedal sign"
 '())

(ly:add-interface
 'piano-pedal-script-interface
 "A piano pedal sign, fixed size"
 '())

(ly:add-interface
 'pitched-trill-interface
   "A note head to indicate trill pitches"
   '(accidental-grob))

(ly:add-interface
 'trill-pitch-accidental-interface
 "An accidental for trill pitch"
 '(accidentals))

(ly:add-interface
 'rhythmic-grob-interface
 "Any object with a duration. Used to determine which grobs are
interesting enough to maintain a hara-kiri staff."
 '())


(ly:add-interface
 'spacing-options-interface
 "Supports setting of spacing variables"
 '(spacing-increment shortest-duration-space))

(ly:add-interface
 'stanza-number-interface
 "A stanza number, to be put in from of a lyrics line"
 '())

(ly:add-interface
 'string-number-interface
 "A string number instruction"
 '())

(ly:add-interface
 'stroke-finger-interface
 "A right hand finger instruction"
 '(digit-names))

(ly:add-interface
 'system-start-text-interface
 "A text at the beginning of a system."
 '(text long-text collapse-height style))

;;; todo: this is not typesetting info. Move to interpretation.
(ly:add-interface
 'tablature-interface
 "An interface for any notes set in a tablature staff"
 '())

(ly:add-interface
 'vertically-spaceable-interface
 "Objects that should be kept at constant vertical distances. Typically:
@internalsref{VerticalAxisGroup} objects of @internalsref{Staff} contexts."
 '())
