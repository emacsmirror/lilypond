%% Do not edit this file; it is automatically
%% generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.13.16"

\header {
  lsrtags = "rhythms, tweaks-and-overrides"

%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549
 doctitlees = "Cambiar la forma de los silencios multicompás"
 texidoces = "
Si hay diez compases de silencio o menos, se imprime en el pentagrama
una serie de silencios de breve y longa (conocidos en alemán como
@qq{Kirchenpausen}, «silencios eclesiásticos»); en caso contrario se
muestra una barra normal.  Este número predeterminado de diez se
puede cambiar sobreescribiendo la propiedad @code{expand-limit}:

"


%% Translation of GIT committish: 0a868be38a775ecb1ef935b079000cebbc64de40
  texidocde = "
Wenn zehn oder weniger Pausentakte vorkommen, wird eine Reihe von Longa-
und Brevispausen (auch Kirchenpausen genannt) gesetzt, bei mehr Takten
wird eine Line mit der Taktanzahl ausgegeben.  Der vorgegebene Wert von
zehn kann geändert werden, indem man die @code{expand-limit}-Eigenschaft
setzt:
"
  doctitlede = "Die Erscheinung von Pausentakten ändern"



%% Translation of GIT committish: 4da4307e396243a5a3bc33a0c2753acac92cb685
texidocfr = "
Dans le cas où ce silence dure moins de dix mesures, LilyPond imprime sur
la portée des @qq{ silences d'église } -- @emph{Kirchenpause} en
allemand -- et qui sont une simple suite de rectangles.  La propriété
@code{expand-limit} permet d'obtenir un silence unique :

"
  doctitlefr = "Modifier l'apparence d'un silence multi-mesures"

  texidoc = "
If there are ten or fewer measures of rests, a series of longa and
breve rests (called in German @qq{Kirchenpausen} - church rests) is
printed within the staff; otherwise a simple line is shown. This
default number of ten may be changed by overriding the
@code{expand-limit} property.

"
  doctitle = "Changing form of multi-measure rests"
} % begin verbatim

\relative c'' {
  \compressFullBarRests
  R1*2 | R1*5 | R1*9
  \override MultiMeasureRest #'expand-limit = #3
  R1*2 | R1*5 | R1*9
}
