\version "2.25.22"

\header {
  texidoc = "Regression test for Issue #6205.  Expected output is a
single staff with notes C and E."
}

{
  c'1
  \tuplet 1/1 \set Timing.beatBase = #1/4
  e'1
}
