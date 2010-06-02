%% Do not edit this file; it is automatically
%% generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.13.16"

\header {
  lsrtags = "expressive-marks"

%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549
  texidoces = "
Para hacer invisibles partes de un regulador de crescendo, se usa
el método de dibujar un rectángulo blanco encima de la parte
respectiva del regulador, tapándola.  El rectángulo se define como
código PostScript dentro de un elemento de marcado de texto.

Para realizar un ajuste fino de la posición y el tamaño del
elemento de marcado, se puede establecer el número que precede a
@code{setgray} en la definición de PostScript a un valor menor que
la unidad, haciendo que sea de color gris.  Los dos números que
están antes de @code{scale} en el código PostScript son los
responsables del ancho y la altura del rectángulo, y los dos
números que están antes de @code{translate} cambian las
coordenadas X e Y de origen del rectángulo.

Asegúrse de poner el regulador en una capa más baja que el
elemento de marcado de texto para trazar el rectángulo encima del
regulador.

"
  doctitlees = "Regulador interrumpido"

  texidoc = "
In order to make parts of a crescendo hairpin invisible, the following
method is used: A white rectangle is drawn on top of the respective
part of the crescendo hairpin, making it invisible.  The rectangle is
defined as postscript code within a text markup.

To fine-tune the position and size of the markup, the number preceding
@code{setgray} in the postscript definition can be set to a value less
than one, making it grey.  The two numbers before @code{scale} in the
postscript code are responsible for the width and height of the
rectangle, the two numbers before @code{translate} change the x- and
y-origin of the rectangle.


Make sure to put the hairpin in a lower layer than the text markup to
draw the rectangle over the hairpin.

"
  doctitle = "Broken Crescendo Hairpin"
} % begin verbatim

\relative c' {
  <<
    {
      \dynamicUp
      \override DynamicLineSpanner #'staff-padding = #4
      r2 r16 c'8.\pp r4
    }
    \\
    {
      \override DynamicLineSpanner #'layer = #0
      des,2\mf\< ~
      \override TextScript #'layer = #2
      des16_\markup {
        \postscript #"
          1.9 -8 translate
          5 4 scale
          1 setgray
          0 0 moveto
          0 1 lineto
          1 1 lineto
          1 0 lineto
          0 0 lineto
          fill"
      }
      r8. des4 ~ des16->\sff
    }
  >>
}

