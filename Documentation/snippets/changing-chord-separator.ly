%% Do not edit this file; it is automatically
%% generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.13.31"

\header {
  lsrtags = "chords"

%% Translation of GIT committish: 0b55335aeca1de539bf1125b717e0c21bb6fa31b
  texidoces = "
Se puede establecer el separador entre las distintas partes del
nombre de un acorde para que sea cualquier elemento de marcado.

"
  doctitlees = "Modificación del separador de acordes"


%% Translation of GIT committish: 0a868be38a775ecb1ef935b079000cebbc64de40
  texidocde = "
Der Trenner zwischen unterschiedlichen Teilen eines Akkordsymbols kann
beliebiger Text sein.

"
  doctitlede = "Akkordsymboltrenner verändern"

  texidoc = "
The separator between different parts of a chord name can be set to any
markup.

"
  doctitle = "Changing chord separator"
} % begin verbatim

\chords {
  c:7sus4
  \set chordNameSeparator
    = \markup { \typewriter | }
  c:7sus4
}

