%% Do not edit this file; it is automatically
%% generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.13.16"

\header {
  lsrtags = "staff-notation, editorial-annotations"

%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549
  texidoces = "
Se puede engrosar una línea del pentagrama con fines pedagógicos
(p.ej. la tercera línea o la de la clave de Sol).  Esto se puede
conseguir añadiendo más líneas muy cerca de la línea que se quiere
destacar, utilizando la propiedad @code{line-positions} del objeto
@code{StaffSymbol}.

"
  doctitlees = "Hacer unas líneas del pentagrama más gruesas que las otras"


%% Translation of GIT committish: 0a868be38a775ecb1ef935b079000cebbc64de40
  texidocde = "
Für den pädagogischen Einsatz kann eine Linie des Notensystems dicker
gezeichnet werden (z. B. die Mittellinie, oder um den Schlüssel hervorzuheben).
Das ist möglich, indem man zusätzliche Linien sehr nahe an der Linie, die
dicker erscheinen soll, einfügt.  Dazu wird die @code{line-positions}-Eigenschaft
herangezogen.

"
  doctitlede = "Eine Linie des Notensystems dicker als die anderen machen"

%% Translation of GIT committish: 99dc90bbc369722cf4d3bb9f30b7288762f2167f6
  texidocfr = "
Vous pourriez avoir envie, dans un but pédagogique, de rendre certaines
lignes d'une portée plus épaisses que les autres, comme la ligne médiane
ou bien pour mettre en exergue la ligne portant la clé de sol.  Il
suffit pour cela d'ajouter une ligne qui sera accolée à celle qui doît
être mise en évidence, grâce à la propriété @code{line-positions} de
l'objet @code{StaffSymbol}.

"
  doctitlefr = "Empâtement de certaines lignes d'une portée"


  texidoc = "
For pedagogical purposes, a staff line can be thickened (e.g., the
middle line, or to emphasize the line of the G clef).  This can be
achieved by adding extra lines very close to the line that should be
emphasized, using the @code{line-positions} property of the
@code{StaffSymbol} object.

"
  doctitle = "Making some staff lines thicker than the others"
} % begin verbatim

{
  \override Staff.StaffSymbol #'line-positions = #'(-4 -2 -0.2 0 0.2 2 4)
  d'4 e' f' g'
}

