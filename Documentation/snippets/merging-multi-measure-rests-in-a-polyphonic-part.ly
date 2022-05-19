%% DO NOT EDIT this file manually; it is automatically
%% generated from LSR http://lsr.di.unimi.it
%% Make any changes in LSR itself, or in Documentation/snippets/new/ ,
%% and then run scripts/auxiliar/makelsr.py
%%
%% This file is in the public domain.
\version "2.23.9"

\header {
  lsrtags = "really-simple, rhythms, version-specific"

  texidoc = "
When using multi-measure rests in a polyphonic staff, the rests will be
placed differently depending on the voice they belong to. However they
can be printed on the same staff line, using the following setting.

"
  doctitle = "Merging multi-measure rests in a polyphonic part"
} % begin verbatim

normalPos = \revert MultiMeasureRest.direction

{
  <<
    {
      c''1
      R1
      c''1
      \normalPos
      R1
    }
    \\
    {
      c'1
      R1
      c'1
      \normalPos
      R1
    }
  >>
}
