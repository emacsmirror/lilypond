% table20.ly
%
% spacing info for LilyPond. Do not edit this.
% It has a lot of hard-wired stringconstants
%

table_twenty = 
\symboltables {

   \texid 	"\input lilyponddefs \musixtwentydefs"

    % index TeXstring, 	xmin xmax ymin ymax

    % not yet updated
    "scripts" = \table {
	"fermata" "\fermata"		0.0\pt 0.0\pt	0.0\pt 6.0\pt
	"-fermata" "\ifermata"		0.0\pt 0.0\pt	-6.0\pt 0.0\pt
	"portato" "\portato"		0.0\pt 4.0\pt	0.0\pt	2.0\pt
	"-portato" "\iportato"		0.0\pt 4.0\pt	-2.0\pt	0.0\pt
	"tenuto" "\tenuto"			0.0\pt 4.0\pt	-1.0\pt	1.0\pt
	"-tenuto" "\itenuto"		0.0\pt 4.0\pt	-1.0\pt	1.0\pt
	"sforzato" "\sforzato"		-0.8\pt 4.0\pt	-1.92\pt 1.92\pt
	"marcato" "\marcato"		0.0\pt 4.0\pt	0.0\pt	4.0\pt
	"-marcato" "\imarcato"		0.0\pt 4.0\pt	-4.0\pt	0.0\pt
	"staccato" "\staccato"		0.0\pt	0.0\pt 	-1.1\pt 1.1\pt
	"staccatissimo" "\staccatissimo"	0.0\pt	0.0\pt	0.0\pt	1.0\pt
	"-staccatissimo" "\istaccatissimo"	0.0\pt	0.0\pt 	0.0\pt	1.0\pt
	"upbow" "\upbow"			-1.0\pt	6.0\pt	0.0\pt	5.0\pt
	"downbow" "\downbow"		0.0\pt	5.0\pt	0.0\pt 7.5\pt
	"back" "\backorfront"		0.0\pt	6.0\pt	0.0\pt	3.0\pt
	"-front" "\backorfront"		0.0\pt	6.0\pt	0.0\pt	3.0\pt
	"heel" "\heel"			0.0\pt	6.0\pt	-1.0\pt	5.0\pt
	"toe" "\toe"			0.0\pt	6.0\pt	-1.0\pt	5.0\pt
	"bheel" "\bheel"			0.0\pt	6.0\pt	-1.0\pt	5.0\pt
	"btoe" "\btoe"			0.0\pt	6.0\pt	-1.0\pt	5.0\pt
	"fheel" "\fheel"			0.0\pt	6.0\pt	-1.0\pt	5.0\pt
	"ftoe" "\ftoe"			0.0\pt	6.0\pt	-1.0\pt	5.0\pt
	"-back" "\backorfront"		0.0\pt	6.0\pt	0.0\pt	3.0\pt
	"front" "\backorfront"		0.0\pt	6.0\pt	0.0\pt	3.0\pt
	"turn"  "\turn"			-2.0\pt	7.0\pt	0.0\pt	4.0\pt
	}

     "style" = \table {
		"roman"	"\settext{%}"	0.0\pt	5.0\pt	0.0\pt	8.0\pt
		"italic"	"\setitalic{%}"	0.0\pt	0.0\pt	0.0\pt	8.0\pt
		"dynamic"	"\setdynamic{%}"	0.0\pt	0.0\pt	0.0\pt	8.0\pt
     }
     "dynamics" = \table {

	"mf" "\dynmf"
	"fff" "\dynfff"
	"ff" "\dynff"
	"f" "\dynf"
	"mp" "\dynmp"
	"p" "\dynp"
	"pp" "\dynpp"
	"ppp" "\dynppp"

	}
     "align" = \table {
		"-1"	"\leftalign{%}"
		"0"	"\centeralign{%}"
		"1"	"\rightalign{%}"
 	}


    "clefs" = \table {
	"violin"	"\violinclef" 	0.0\pt	16.0\pt	-12.5\pt	22.5\pt
	"bass"	"\bassclef" 		0.0\pt	16.0\pt	0.0\pt	20.0\pt
	"alto"	"\altoclef"	 	0.0\pt	16.0\pt	0.0\pt	20.0\pt
	"tenor"	"\altoclef"	 	0.0\pt	16.0\pt	0.0\pt	20.0\pt
	"violin_change"	"\cviolinclef" 	0.0\pt	16.0\pt	-12.5\pt	22.5\pt
	"bass_change"	"\cbassclef"	0.0\pt	16.0\pt	0.0\pt	20.0\pt
	"alto_change"	"\caltoclef" 	0.0\pt	16.0\pt	0.0\pt	20.0\pt
	"tenor_change"	"\caltoclef" 	0.0\pt	16.0\pt	0.0\pt	20.0\pt
    }

    "balls" = \table {
	"1"	"\wholeball"	0.0\pt	7.5\pt	-2.5\pt	2.5\pt
	"2"	"\halfball"	0.0\pt	6.0\pt	-2.5\pt	2.5\pt
	"4"	"\quartball"	0.0\pt	6.0\pt	-2.5\pt	2.5\pt
    }

    "slur" = \table {
	"whole"	"\slurchar%{%}"	0.0\pt	0.0\pt	0.0\pt	0.0\pt
	"half"	"\hslurchar%{%}"	0.0\pt	0.0\pt	0.0\pt	0.0\pt
    }

    "accidentals" = \table {
	"-2"	"\flatflat"	0.0\pt 	10.2\pt	-2.5\pt	7.5\pt
	"-1"	"\flat"		0.0\pt	6.0\pt	-2.5\pt	7.5\pt
	"0"	"\natural"	0.0\pt	6.0\pt	-7.5\pt	7.5\pt
	"1"	"\sharp"	0.0\pt	6.0\pt	-7.5\pt	7.5\pt
	"2"	"\sharpsharp"	0.0\pt	6.0\pt	-2.5\pt	7.5\pt
    }

    "streepjes" = \table {
	"toplines"	"\toplines{%}"	-3.0\pt	9.0\pt	0.0\pt	0.0\pt
	"botlines"	"\botlines{%}"	-3.0\pt	9.0\pt	0.0\pt	0.0\pt
    }

    "bars" = \table {
	"empty"	"\emptybar"
	""	""			0.0\pt	0.0\pt	0.0\pt	16.0\pt
	"|"	"\maatstreep{%}"	0.0\pt	5.0\pt 	0.0\pt	20.0\pt
	"||"	"\doublebar{%}"		0.0\pt	4.0\pt	0.0\pt	20.0\pt
	"|."	"\finishbar{%}"		0.0\pt	2.0\pt	0.0\pt	20.0\pt
	".|"	"\startbar{%}"		0.0\pt	4.0\pt	0.0\pt	20.0\pt
	":|"	"\repeatbar"		-8.0\pt	0.0\pt	0.0\pt	20.0\pt
	"|:"	"\startrepeat"		0.0\pt	8.0\pt	0.0\pt	20.0\pt
	":|:"	"\repeatbarstartrepeat"	0.0\pt	16.0\pt	0.0\pt	20.0\pt
    }

     "rests" = \table {
	"-1o"	"\breverest"		0.0\pt  6.0\pt  0.0\pt  4.0\pt
	"-1"	"\breverest"		0.0\pt	6.0\pt	0.0\pt	4.0\pt
	 "1o"	"\outsidewholerest"	0.0\pt  6.0\pt  0.0\pt  2.0\pt
	 "1"	"\wholerest"		0.0\pt	6.0\pt	0.0\pt	2.0\pt
	 "2"	"\halfrest"		0.0\pt	6.0\pt	-2.0\pt	0.0\pt
	 "2o"	"\outsidehalfrest"		0.0\pt	6.0\pt	-2.0\pt	0.0\pt
	 "4o"	"\quartrest"		-5.0\pt	2.0\pt	-5.0\pt	5.0\pt
	 "8o"	"\eighthrest"		0.0\pt	5.0\pt	0.0\pt	8.0\pt
	 "16o"	"\sixteenthrest"		0.0\pt	6.0\pt	0.0\pt	12.0\pt
	 "4"	"\quartrest"		-5.0\pt	2.0\pt	-5.0\pt	5.0\pt
	 "8"	"\eighthrest"		0.0\pt	5.0\pt	0.0\pt	8.0\pt
	 "16"	"\sixteenthrest"		0.0\pt	6.0\pt	0.0\pt	12.0\pt
	 "32"	"\thirtysecondrest"	0.0\pt	6.0\pt	0.0\pt	16.0\pt
	 "64"	"\sixtyfourthrest"	0.0\pt	6.0\pt	0.0\pt	16.0\pt
	 "128"	"\hundredtwentyeighthrest"	0.0\pt	6.0\pt	0.0\pt	16.0\pt
     }

    "meters" = \table {
	"C"	"\fourfourmeter"		0.0\pt	10.0\pt	-5.0\pt	5.0\pt
	"C2"	"\allabreve"		0.0\pt	10.0\pt	-5.0\pt	5.0\pt
    }

    % dims ignored for this table
    "param" = \table {
	 "brace"    "\pianobrace{%}"	0.0\pt	0.0\pt	0.0\pt	0.0\pt
	 "meter"	"\generalmeter{%}{%}"	0.0\pt	10.0\pt	-5.0\pt	5.0\pt
	 "linestaf"	"\linestafsym{%}{%}"
	 "stem"	"\stem{%}{%}"
	 "fill"	"\hbox{}"
	% ugh. 8\pt
	 "crescendosym" "\crescendosym{%}"	0.0\pt	0.0\pt	-3.0\pt	3.0\pt
	 "decrescendosym" "\decrescendosym{%}"	0.0\pt	0.0\pt	-3.0\pt	3.0\pt
     }

    "dots" = \table {
	"1"	"\lsingledot"		0.0\pt	8.0\pt	-1.0\pt	1.0\pt
	"2"	"\ldoubledot"		0.0\pt	12.0\pt	-1.0\pt	1.0\pt
	"3"	"\ltripledot"		0.0\pt	16.0\pt	-1.0\pt	1.0\pt
    }

    "flags" = \table {
	"8"	"\eighthflag"		0.0\pt	5.0\pt	0.0\pt	0.0\pt	
	"16"	"\sixteenthflag"		0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"32"	"\thirtysecondflag"	0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"64"	"\sixtyfourthflag"	0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"128"	"\hundredtwentyeighthflag"	0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"-8"	"\deighthflag"		0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"-16"	"\dsixteenthflag"		0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"-32"	"\dthirtysecondflag"	0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"-64"	"\dsixtyfourthflag"	0.0\pt	5.0\pt	0.0\pt	0.0\pt
	"-128"	"\dhundredtwentyeighthflag"	0.0\pt	5.0\pt	0.0\pt	0.0\pt
     }

    "beamslopes" = \table {
	"slope"	"\beamslope{%}{%}"
	"horizontal"	"\rulesym{%}{%}"	
    }
}

