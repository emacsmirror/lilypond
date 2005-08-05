\header
{
  title  = "Proportional notation"
}


%% RhythmicStaff broken with 32nd rests ? 

\layout
{
  indent = #0.0 
  \context {
    \Voice
    \remove "Forbid_line_break_engraver"
    tupletNumberFormatFunction = #fraction-tuplet-formatter
    tupletFullLength = ##t
    allowBeamBreak = ##t
  }
  \context {
    \Score
    \override SpacingSpanner #'uniform-stretching = ##t
    \override SpacingSpanner #'strict-note-spacing = ##t
    proportionalNotationDuration = #(ly:make-moment 1 64)
    \override TimeSignature #'break-visibility = #begin-of-line-visible
    \override Beam #'break-overshoot = #'(-0.5 . 1.0)
    
  }
}

staffKind = "RhythmicStaff"

%staffKind = "Staff"

\relative c''
\new StaffGroup <<
  \new \staffKind <<
    {
      \skip 2
      \skip 2
      \break \time 4/8
      
      \skip 1 \break \time 4/8
    }
    
    {
    \time 4/8 

    \times 7/9 {
      \times 4/6 {
	r8 r32[ c c c c c c c] r4
	r32[ c32 c16 }
	\times 5/4 {
	  c16 c c] r32[ c32 c16 c] r8 }
      }
    \times 10/12 {
      \times 7/6 {
	r32[ c32. c16 c16.] r4
	r16[ c16 c16. c32
	   }	   
	\times 5/8 {
	  c16 c c16. c32] r8 c8[ c] r4
      }
    }

    \times 4/7 {
      r8
      r16[ c16
	\times 5/4 {
	  c16 r16 c8 c c
	}
    }
      
    \times 3/4 {
      c8]
      r16[ c
	   \times  2/3 {
	     c16 r16]
	   r4 }
    }
  }  
    >>
  \new \staffKind {
    \times 9/5 {
      r8. c16[ c c  c c c
      c 
    }
    \times 4/7 {
      c16 c c c ]
      \times 5/4 {
	c16[ c32 c32]
	r4
	c32[ c c16
      }
    }
    c16 c16 c8] r8 r4
    \times 10/12 {
      \times 7/9 {
        r8.[ c32 c16 c r8 c16 c16 
      }
      c16 c32 c32]
      r4 r16
    }
  }  
>>

		 
    
  
