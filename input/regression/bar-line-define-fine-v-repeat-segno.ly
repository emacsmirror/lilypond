\version "2.23.1"

#(ly:set-option 'warning-as-error #t)

\header {
  texidoc="The @code{\\fine} command gives @code{fineBarType}
precedence in the selection of repeat bar types where
@code{underlyingRepeatType} or @code{sectionBarType} would normally be
used.  Customizing @code{fineBarType} is effective when appropriate
bar lines are defined.  The output should show two adjacent repeated
sections with doubled dots and thick bar lines, followed by a double
thick bar line without dots."
}

\layout {
  ragged-right = ##t

  \context {
    \Score
    fineBarType = "..-test"
    %% N.B. We don't want the "-..-test" annotation on these.
    %% LilyPond should append it at \fine based on fineBarType.
    doubleRepeatSegnoType = "::..S..::"
    endRepeatSegnoType = "::..S"
    fineSegnoType = "..S"
    fineStartRepeatSegnoType = "..S..::"
  }
}

%% Notice that we define *only* annotated versions of these.
%%
%% For a score with span-bars, "..S..::" would need to be defined as
%% well, but we don't need to complicate this test with that.
\defineBarLine "..S..::-..-test" #'("..S..::" "..S..::" "") % start repeat
\defineBarLine "::..S-..-test" #'("::..S" "::..S" "") % end repeat
\defineBarLine "::..S..::-..-test" #'("::..S..::" "::..S..::" "") % double rep.
\defineBarLine "..S-..-test" #'("..S" "..S" "") % fine

%% It is important that these bars are not aligned to measure
%% boundaries.  It shows that LilyPond chooses fineBarType over
%% underlyingRepeatType as well as over sectionBarType.
\new Score \fixed c' {
  r2.
  \repeat volta 2 {
    \fine \section \inStaffSegno r4 | r2.
  }
  \repeat volta 2 {
    \fine \section \inStaffSegno
    r4 | r2.
    \fine \section \inStaffSegno
  }
  r4 | r2.
  \fine \section \inStaffSegno
}
