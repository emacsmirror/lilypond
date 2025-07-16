\version "2.25.22"

\header {
  texidoc = "If in a subdivided beam one single stem follows a
subdivision the beam count should reflect the beam count of the
subdivision as usual.  That is, the beam count should not be increased
according to the remaining length of the beam.  The appended single
stem has beamlets to the left."
}

\relative c' {
  \time 1/4
  \set subdivideBeams = ##t
  c32 [ c c c c32 ] r16.
  c32 [ c c c c64 ] r32. r16
  c32 [ c c32 ] r32 r8
  c32 [ c c64 ] r32. r8
}
