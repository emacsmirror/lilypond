%% DO NOT EDIT this file manually; it is automatically
%% generated from LSR http://lsr.di.unimi.it
%% Make any changes in LSR itself, or in Documentation/snippets/new/ ,
%% and then run scripts/auxiliar/makelsr.py
%%
%% This file is in the public domain.
\version "2.23.9"

\header {
  lsrtags = "repeats"

  texidoc = "
The @code{Volta_engraver} by default resides in the @code{Score}
context, and brackets for the repeat are thus normally only printed
over the topmost staff. This can be adjusted by adding the
@code{Volta_engraver} to the @code{Staff} context where the brackets
should appear; see also the @qq{Volta multi staff} snippet.

"
  doctitle = "Adding volta brackets to additional staves"
} % begin verbatim

<<
  \new Staff { \repeat volta 2 { c'1 } \alternative { c' } }
  \new Staff { \repeat volta 2 { c'1 } \alternative { c' } }
  \new Staff \with { \consists "Volta_engraver" } { c'2 g' e' a' }
  \new Staff { \repeat volta 2 { c'1 } \alternative { c' } }
>>
