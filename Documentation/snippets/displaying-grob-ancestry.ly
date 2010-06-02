% Do not edit this file; it is automatically
% generated from Documentation/snippets/new
% This file is in the public domain.
%% Note: this file works from version 2.13.10
\version "2.13.16"

\header {
%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549

  texidoces = "
Al trabajar con los callbacks de un grob, puede ser de mucha ayuda
entender el @qq{árbol genealógico} de un grob.  La mayor parte de los
grobs tienen @qq{padres} que influyen en el posicionamiento del grob.
los padres X e Y influyen en las posiciones horizontal y vertical del
grob, respectivamente.  Además, cada pade puede tener padres a su vez.


Por desgracia, existen varios aspectos de la genealogía de un grob que
pueden llevar a confusión:


@itemize

@item Los tipos de padre que tiene un grob pueden depender del
contexto.

@item Para ciertos grobs, los padres X e Y son el mismo.

@item Un @qq{ancestro} concreto puede estar relacionado con un grob de
mas de una manera.

@item El concepto de @qq{generaciones} es engañoso.

@end itemize


Por ejemplo, el grob @code{System} puede ser tanto un padre (sobre el
lado Y) como un abuelo (dos veces en el lado X) de un grob
@code{VerticalAlignment}.


Este macro imprime, en la consola, una representación textual de la
genealogía de un grob.


Cuando se llama de esta forma

@example
@{
   \\once \\override NoteHead #'before-line-breaking = #display-ancestry
   c4
@}
@end example


Se genera la siguiente salida:


@example
------------------------------------

NoteHead X,Y: NoteColumn
    X: PaperColumn
       X,Y: System
    Y: VerticalAxisGroup
       X: NonMusicalPaperColumn
          X,Y: System
       Y: VerticalAlignment
          X: NonMusicalPaperColumn
             X,Y: System
          Y: System
@end example

"

  doctitlees = "Imprimir el árbol genealógico de un grob"

  lsrtags = "tweaks-and-overrides"

  texidoc = "
When working with grob callbacks, it can be helpful to understand a
grob's @qq{ancestry}.  Most grobs have @qq{parents} which influence the
positioning of the grob.  X- and Y-parents influence the horizontal and
vertical positions for the grob, respectively.  Additionally, each
parent may have parents of its own.


Unfortunately, there are several aspects of a grob's ancestry that can
lead to confusion:


@itemize

@item
The types of parents a grob has may depend on context.

@item
For some grobs, the X- and Y-parents are the same.

@item
A particular @qq{ancestor} may be related to a grob in multiple ways.

@item
The concept of @qq{generations} is misleading.

@end itemize


For example, the @code{System} grob can be both parent (on the Y-side)
and grandparent (twice on the X-side) to a @code{VerticalAlignment}
grob.


This macro prints (to the console) a textual representation of a grob's
ancestry.


When called this way

@example
@{
   \\once \\override NoteHead #'before-line-breaking = #display-ancestry
   c4
@}
@end example


The following output is generated:


@example
------------------------------------

NoteHead X,Y: NoteColumn
    X: PaperColumn
       X,Y: System
    Y: VerticalAxisGroup
       X: NonMusicalPaperColumn
          X,Y: System
       Y: VerticalAlignment
          X: NonMusicalPaperColumn
             X,Y: System
          Y: System
@end example


"
  doctitle = "Displaying grob ancestry"
} % begin verbatim


#(define (grob-name grob)
   (if (ly:grob? grob)
       (assoc-ref (ly:grob-property grob 'meta) 'name)
       #f))

#(define (get-ancestry grob)
   (if (not (null? (ly:grob-parent grob X)))
       (list (grob-name grob)
             (get-ancestry (ly:grob-parent grob X))
             (get-ancestry (ly:grob-parent grob Y)))
       (grob-name grob)))

#(define (format-ancestry lst padding)
   (string-append
    (symbol->string (car lst))
    "\n"
    (let ((X-ancestry
           (if (list? (cadr lst))
               (format-ancestry (cadr lst) (+ padding 3))
               (symbol->string (cadr lst))))
          (Y-ancestry
           (if (list? (caddr lst))
               (format-ancestry (caddr lst) (+ padding 3))
               (symbol->string (caddr lst)))))
      (if (equal? X-ancestry Y-ancestry)
          (string-append
           (format #f "~&")
           (make-string padding #\space)
           "X,Y: "
           (if (list? (cadr lst))
               (format-ancestry (cadr lst) (+ padding 5))
               (symbol->string (cadr lst))))
          (string-append
           (format #f "~&")
           (make-string padding #\space)
           "X: " X-ancestry
           "\n"
           (make-string padding #\space)
           "Y: " Y-ancestry
           (format #f "~&"))))
    (format #f "~&")))

#(define (display-ancestry grob)
   (display
    (string-append
     (format #f "~3&~a~2%" (make-string 36 #\-))
     (format-ancestry (get-ancestry grob) 0)
     (format #f "~2&"))))

\relative c' {
  \once \override NoteHead #'before-line-breaking = #display-ancestry
  f4
  \once \override Accidental #'before-line-breaking = #display-ancestry
  \once \override Arpeggio #'before-line-breaking = #display-ancestry
  <f as c>4\arpeggio
}
