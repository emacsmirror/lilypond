%% DO NOT EDIT this file manually; it is automatically
%% generated from LSR http://lsr.di.unimi.it
%% Make any changes in LSR itself, or in Documentation/snippets/new/ ,
%% and then run scripts/auxiliar/makelsr.py
%%
%% This file is in the public domain.
\version "2.23.9"

\header {
  lsrtags = "contexts-and-engravers, rhythms"

  texidoc = "
Bar numbers can be removed entirely by removing the
@code{Bar_number_engraver} from the @code{Score} context.

"
  doctitle = "Removing bar numbers from a score"
} % begin verbatim


\layout {
  \context {
    \Score
    \omit BarNumber
    % or:
    %\remove "Bar_number_engraver"
  }
}

\relative c'' {
  c4 c c c \break
  c4 c c c
}
