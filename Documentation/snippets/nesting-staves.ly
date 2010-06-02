%% Do not edit this file; it is automatically
%% generated from LSR http://lsr.dsi.unimi.it
%% This file is in the public domain.
\version "2.13.16"

\header {
  lsrtags = "staff-notation, contexts-and-engravers, tweaks-and-overrides"

%% Translation of GIT committish: 5a7301fc350ffc3ab5bd3a2084c91666c9e9a549
  texidoces = "
Se puede utilizar la propiedad
@code{systemStartDelimiterHierarchy} para crear grupos de
pentagramas anidados de forma más compleja. La instrucción
@code{\\set StaffGroup.systemStartDelimiterHierarchy} toma una
lista alfabética del número de pentagramas producidos. Se puede
proporcionar antes de cada pentagrama un delimitador de comienzo
de sistema. Se debe encerrar entre corchetes y admite tantos
pentagramas como encierren las llaves. Se pueden omitir los
elementos de la lista, pero el primer corchete siempre abarca
todos los pentagramas. Las posibilidades son
@code{SystemStartBar}, @code{SystemStartBracket},
@code{SystemStartBrace} y @code{SystemStartSquare}.

"
  doctitlees = "Anidado de grupos de pentagramas"


%% Translation of GIT committish: 0a868be38a775ecb1ef935b079000cebbc64de40
  texidocde = "
Die Eigenschaft @code{systemStartDelimiterHierarchy} kann eingesetzt
werden, um komplizierte geschachtelte Systemklammern zu erstellen.  Der
Befehl @code{\\set StaffGroup.systemStartDelimiterHierarchy} nimmt eine
Liste mit der Anzahl der Systeme, die ausgegeben werden, auf.  Vor jedem
System kann eine Systemanfangsklammer angegeben werden.  Sie muss in Klammern eingefügt
werden und umfasst so viele Systeme, wie die Klammer einschließt.  Elemente
in der Liste können ausgelassen werden, aber die erste Klammer umfasst immer
die gesamte Gruppe.  Die Möglichkeiten der Anfangsklammer sind: @code{SystemStartBar},
@code{SystemStartBracket}, @code{SystemStartBrace} und
@code{SystemStartSquare}.

"
  doctitlede = "Systeme schachteln"

%% Translation of GIT committish: 99dc90bbc369722cf4d3bb9f30b7288762f2167f6
  texidocfr = "
La propriété @code{systemStartDelimiterHierarchy} permet de créer des
regroupements imbriqués complexes.  La commande
@code{\\set@tie{}StaffGroup.systemStartDelimiterHierarchy} prend en
argument la liste alphabétique des sous-groupes à hiérarchiser.  Chaque
sous-groupe peut être affublé d'un délimiteur particulier.  Chacun des
regroupements intermédiaires doit être borné par des parenthèses.  Bien
que des éléments de la liste puissent être omis, le premier délimiteur
embrassera toujours l'intégralité des portées.  Vous disposez des quatre
délimiteurs @code{SystemStartBar}, @code{SystemStartBracket},
@code{SystemStartBrace} et @code{SystemStartSquare}.

"
  doctitlefr = "Imbrications de regroupements de portées"


  texidoc = "
The property @code{systemStartDelimiterHierarchy} can be used to make
more complex nested staff groups. The command @code{\\set
StaffGroup.systemStartDelimiterHierarchy} takes an alphabetical list of
the number of staves produced. Before each staff a system start
delimiter can be given. It has to be enclosed in brackets and takes as
much staves as the brackets enclose. Elements in the list can be
omitted, but the first bracket takes always the complete number of
staves. The possibilities are @code{SystemStartBar},
@code{SystemStartBracket}, @code{SystemStartBrace}, and
@code{SystemStartSquare}.

"
  doctitle = "Nesting staves"
} % begin verbatim

\new StaffGroup
\relative c'' <<
  \set StaffGroup.systemStartDelimiterHierarchy
    = #'(SystemStartSquare (SystemStartBrace (SystemStartBracket a
                             (SystemStartSquare b)  ) c ) d)
  \new Staff { c1 }
  \new Staff { c1 }
  \new Staff { c1 }
  \new Staff { c1 }
  \new Staff { c1 }
>>

