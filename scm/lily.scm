;;;; This file is part of LilyPond, the GNU music typesetter.
;;;;
;;;; Copyright (C) 1998--2021 Jan Nieuwenhuizen <janneke@gnu.org>
;;;; Han-Wen Nienhuys <hanwen@xs4all.nl>
;;;;
;;;; LilyPond is free software: you can redistribute it and/or modify
;;;; it under the terms of the GNU General Public License as published by
;;;; the Free Software Foundation, either version 3 of the License, or
;;;; (at your option) any later version.
;;;;
;;;; LilyPond is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;; GNU General Public License for more details.
;;;;
;;;; You should have received a copy of the GNU General Public License
;;;; along with LilyPond.  If not, see <http://www.gnu.org/licenses/>.

;; Internationalisation: (_i "to be translated") gets an entry in the
;; POT file; (gettext ...) must be invoked explicitly to do the actual
;; "translation".
;;
;; (define-macro (_i x) x)
;; (define-macro-public _i (x) x)
;; (define-public-macro _i (x) x)
;; Abbrv-PWR!

(define-module (lily))

(defmacro-public _i (x) x)

;; GUILE defaults to fixed seed.
(define-public (randomize-rand-seed)
  (ly:randomize-rand-seed)
  (let*
      ((t (gettimeofday))
       ;; GUILE's random initialization is clumsy (it converts the
       ;; integer to decimal string, and then sums groups of 8 bytes
       ;; as 64 bit integers.  Here we multiply to spread the entropy
       ;; around a bit better.
       (seed (*
              (cdr t)
              (car t)
              (getpid))))
    (set! *random-state* (seed->random-state seed))))

(randomize-rand-seed)

(read-enable 'positions)
(cond-expand
 (guile-2
  (begin
    (debug-enable 'backtrace)
    (debug-set! show-file-name #t)))
 (else (debug-enable 'debug)))

(define-public PLATFORM
  (string->symbol
   (string-downcase
    (car (string-tokenize (utsname:sysname (uname)) char-set:letter)))))

;; We don't use (srfi srfi-39) (parameter objects) here because that
;; does not give us a name/handle to the underlying fluids themselves.

(define %parser (make-fluid))
(define %location (make-fluid))
;; No public setters: should not get overwritten in action
(define-public (*parser*) (fluid-ref %parser))
(define-public (*location*) (fluid-ref %location))

(define-public _ gettext)

;; Guile 1.8 doesn't have (and doesn't need) eval-when.
(defmacro-public eval-early (expr)
  `(cond-expand
    (guile-2 (eval-when (expand load eval) ,expr))
    (else ,expr)))

;; It would be nice to convert occurences of parser/location to
;; (*parser*)/(*location*) using the syncase module but it is utterly
;; broken in GUILE 1 and would require changing a lot of unrelated
;; innocuous constructs which just happen to fall apart with
;; inscrutable error messages.

;;
;; Session-handling variables and procedures.
;;
;;  A "session" corresponds to one .ly file processed on a LilyPond
;;  command line.  Every session gets to see a reasonably fresh state
;;  of LilyPond and should work independently from previous files.
;;
;;  Session management relies on cooperation, namely the user not
;;  trying to change variables and data structures internal to
;;  LilyPond.  It is not proof against in-place modification of data
;;  structures (as they are just reinitialized with the original
;;  identities), and it is not proof against tampering with internals.
;;
;;  As a consequence, session management is not sufficient for
;;  separating multiple independent .ly files in "-dsafe" mode: you
;;  should give each its own LilyPond process when reliable separation
;;  is mandatory.
;;
;;  For standard tasks and programming practices, multiple sessions in
;;  the same LilyPond job should work reasonably independently and
;;  without "bleed-over" while still loading and compiling the
;;  relevant .scm and .ly files only once.
;;

(define lilypond-declarations
  ;; a (cons* SYMBOL IS-PARSER? VAR VALUE) tuple.  On reinitializing a session,
  ;; we assign VALUE to VAR, and use the VAR to define SYMBOL in the
  ;; parser module if IS-PARSER? is true
  '())

(define lilypond-exports '())
(define after-session-hook (make-hook))

(define-public (call-after-session thunk)
  (if first-session-done?
      (ly:error (_ "call-after-session used after session start")))
  (add-hook! after-session-hook thunk #t))

(define (make-session-variable name value)
  (if first-session-done?
      (ly:error (_ "define-session used after session start")))
  (let ((var (module-make-local-var! (current-module) name)))
    (if (variable-bound? var)
        (ly:error (_ "symbol ~S redefined") name))
    (variable-set! var value)
    var))

(define (define-session-internal name value)
  ;; work function for define-session
  (set! lilypond-declarations
        (cons (cons* name #f (make-session-variable name value) value)
              lilypond-declarations)))


(defmacro define-session (name value)
  "This defines a variable @var{name} with the starting value
@var{value} that is reinitialized at the start of each session.
A@tie{}session basically corresponds to one LilyPond file on the
command line.  The value is recorded at the start of the first session
after loading all initialization files and before loading the user
file and is reinstated for all of the following sessions.  This
happens just by replacing the value, not by copying structures, so you
should not destructively modify them.  For example, lists defined in
this manner should be changed within a session only be adding material
to their front or replacing them altogether, not by modifying parts of
them.  It is an error to call @code{define-session} after the first
session has started."
  `(define-session-internal ',name ,value))

(define (define-session-public-internal name value)
  ;; work function for define-session-public
  (set! lilypond-exports
        (acons name (make-session-variable name value) lilypond-exports)))

(defmacro define-session-public (name value)
  "Like @code{define-session}, but also exports @var{name} into parser modules."
  `(begin
     ;; this is a bit icky: we place the variable right into every
     ;; parser module so that both set! and define will affect the
     ;; original variable in the (lily) module.  However, we _also_
     ;; export it normally from (lily) for the sake of other modules
     ;; not sharing the name space of the parser.
     (define-session-public-internal ',name ,value)
     (export ,name)))

(define (session-terminate)
  ;; For GUILE 2.x, restore the modules recorded during (session-init)
  ;; and remove any additional modules so that they can be collected.
  (cond-expand
   (guile-2
    (set-module-submodules! root-module
                            (alist->hash-table session-modules)))
   (else))
  (for-each
   (lambda (p) (variable-set! (caddr p) (cdddr p)))
   lilypond-declarations)
  (run-hook after-session-hook))

(define lilypond-interfaces #f)
(cond-expand
 (guile-2
  (define root-module (resolve-module '() #f))
  (define global-modules (module-submodules root-module))
  (define session-modules #f))
 (else))
(define first-session-done? #f)

(define-public (session-replay)
  (module-use-interfaces! (current-module) (reverse lilypond-interfaces))
  (for-each
   (lambda (p)
     (let ((sym (car p))
           (is-parser? (cadr p))
           (var (caddr p))
           (val (cdddr p)))
       
       (variable-set! var val)
       (if is-parser?
           (module-add! (current-module) sym var)
           )))
   lilypond-declarations))

(define-public (session-save)
  "Save identifiers for use with session-replay."
  
  ;; lilypond-exports is no longer needed since we will grab its
  ;; values from (current-module).
  (set! lilypond-exports #f)
  (set! lilypond-interfaces
        (filter (lambda (m) (eq? 'interface (module-kind m)))
                (module-uses (current-module))))
  ;; Create a copy of the hash-table as an alist. We construct a new
  ;; hash-table after processing each file.
  (cond-expand
   (guile-2
    (set! session-modules (hash-map->list cons global-modules)))
   (else))

  ;; Extract changes made to variables after defining them
  (set! lilypond-declarations
        (map (lambda (v)
               (cons* (car v) #f (caddr v) (variable-ref (caddr v))))
             lilypond-declarations))
  (module-for-each
   (lambda (sym var)
     (let ((val (variable-ref var)))
       (if (and (not (eq? sym '%module-public-interface)) (not (ly:lily-parser? val)))
           (set! lilypond-declarations
                 (cons
                  (cons* sym #t var val)
                  lilypond-declarations)))))
   (current-module))

  (dump-zombies 0)
  (set! first-session-done? #t))

(define scheme-options-definitions
  `(
    ;; NAMING: either

    ;; - [subject-]object-object-verb +"ing"
    ;; - [subject-]-verb-object-object

    ;; Avoid overlong lines in `lilypond -dhelp'!  Strings should not
    ;; be longer than 48 characters per line.

    (anti-alias-factor 1
                       "Render at higher resolution (using given
positive integer factor <=8) and scale down
result to prevent jaggies in PNG images.")
    (aux-files #t
               "Create .tex, .texi, .count files in the
EPS backend.")
    (backend ps
             "Select backend.  Possible values: 'eps, 'null,
'ps, 'scm, 'svg.")
    (check-internal-types #f
                          "Check every property assignment for types.")
    (clip-systems #f
                  "Generate cut-out snippets of a score.")
    (crop #f
          "Generate additional, possibly tall
single-page output file(s) with cropped margins.")
    (datadir #f
             "LilyPond prefix for data files (read-only).")
    (debug-eval ,(ly:verbose-output?)
                "Use the debugging Scheme evaluator.")
    (debug-gc-object-lifetimes 5 "Sanity check object lifetimes") 
    (debug-gc-assert-parsed-dead #f
                                 "For internal use.")
    (debug-lexer #f
                 "Debug the flex lexer.")
    (debug-page-breaking-scoring #f
                                 "Dump scores for many different page breaking
configurations.")
    (debug-parser #f
                  "Debug the bison parser.")
    (debug-property-callbacks #f
                              "Debug cyclic callback chains.")
    (debug-skylines #f
                    "Debug skylines.")
    (delete-intermediate-files #t
                               "Delete unusable, intermediate PostScript files.")
    (dump-signatures #f
                     "Dump output signatures of each system.")
    (embed-source-code #f
                       "Embed the source files inside the generated PDF
document.")
    (eps-box-padding #f
                     "Pad left edge of the output EPS bounding box by
given amount (in mm).")
    (font-export-dir #f
                     "Directory for exporting fonts as PostScript
files.")
    (font-ps-resdir #f
                    "Build a subset of PostScript resource directory
for embedding fonts.")
    (gs-api #t
            "Whether to use the Ghostscript API (read-only
if not available).")
    (gs-load-fonts #f
                   "Load fonts via Ghostscript.")
    (gs-load-lily-fonts #f
                        "Load only LilyPond fonts via Ghostscript.")
    (gs-never-embed-fonts #f
                          "Make Ghostscript embed only TrueType fonts and
no other font format.")
    (gui #f
         "Run LilyPond from a GUI and redirect stderr to
a log file.")
    (help #f
          "Show this help.")
    (include-book-title-preview #t
                                "Include book titles in preview images.")
    (include-eps-fonts #t
                       "Include fonts in separate-system EPS files.")
    (include-settings #f
                      "If string FOO is given as an argument, include
file `FOO' (using LilyPond syntax) for global
settings, included before the score is
processed.")
    (job-count #f
               "Process in parallel, using the given number of
jobs.")
    (log-file #f
              "If string FOO is given as an argument, redirect
output to log file `FOO.log'.")
    (max-markup-depth 1024
                      "Maximum depth for the markup tree.  If a markup
has more levels, assume it will not terminate
on its own, print a warning and return a null
markup instead.")
    (midi-extension ,(if (eq? PLATFORM 'windows)
                         "mid"
                         "midi")
                    "Set the default file extension for MIDI output
file to given string.")
    (music-font-encodings #f
                          "Use font encodings and the PostScript `show'
operator with music fonts.")
    (music-strings-to-paths #f
                            "Convert text strings to paths when glyphs
belong to a music font.")
    (outline-bookmarks #t
                       "Use bookmarks in table of contents metadata
(e.g., for PDF viewers).")
    (paper-size "a4"
                "Set default paper size.")
    (pixmap-format "png16m"
                   "Set GhostScript's output format for pixel
images.")
    (png-width 0
               "Image width for PNG output (in pixels).")
    (png-height 0
                "Image height for PNG output (in pixels).")
    (point-and-click #t
                     "Add point & click links to PDF and SVG output.")
    (preview #f
             "Create preview images also.")
    (print-pages #t
                 "Print pages in the normal way.")
    (profile-property-accesses #f
                               "Keep statistics of get_property() calls.")
    (protected-scheme-parsing #t
                              "Continue when errors in inline Scheme are
caught in the parser.  If #f, halt on errors
and print a stack trace.")
    (read-file-list #f
                    "Specify name of a file which contains a list of
input files to be processed.")
    (relative-includes #t
                       "When processing an \\include command, look for
the included file relative to the current file\
\n(instead of the root file).")
    (resolution 101
                "Set resolution for generating PNG pixmaps to
given value (in dpi).")
    (safe #f
          "Run in safer mode.")
    (separate-log-files #f
                        "For input files `FILE1.ly', `FILE2.ly', ...
output log data to files `FILE1.log',
`FILE2.log', ...")
    (show-available-fonts #f
                          "List available font names.")
    (strict-infinity-checking #f
                              "Force a crash on encountering Inf and NaN
floating point exceptions.")
    (strip-output-dir #t
                      "Don't use directories from input files while
constructing output file names.")
    (strokeadjust #f
                  "Set the PostScript `strokeadjust' operator
explicitly.  This employs different drawing
primitives, resulting in large PDF file size
increases but often markedly better PDF
previews.")
    (svg-woff #f
              "Use woff font files in SVG backend.")
    (verbose ,(ly:verbose-output?)
             "Verbose output, i.e., loglevel at least DEBUG
(read-only).")
    (warning-as-error #f
                      "Change all warning and programming_error
messages into errors.")
    ))

;; Need to do this in the beginning.  Other parts of the Scheme
;; initialization depend on these options.

(for-each (lambda (x)
            (ly:add-option (car x) (cadr x) (caddr x)))
          scheme-options-definitions)

;; 'debug-gc-object-lifetimes not supported on GUILE 2
(cond-expand
 (guile-2
  (ly:set-option 'debug-gc-object-lifetimes #f))
 (else))

(for-each (lambda (x)
            (ly:set-option (car x) (cdr x)))
          (with-input-from-string (ly:command-line-options) read))

(debug-set! stack 0)

(if (defined? 'set-debug-cell-accesses!)
    (set-debug-cell-accesses! #f))

;;(set-debug-cell-accesses! 1000)

(use-modules (ice-9 regex)
             (ice-9 safe)
             (ice-9 format)
             (ice-9 rdelim)
             (ice-9 optargs)
             (oop goops)
             (srfi srfi-1)
             (srfi srfi-13)
             (srfi srfi-14)
             (lily clip-region)
             (lily safe-utility-defs))

;;; There are new modules defined in Guile V2.0 which we need to use.
;;
;;  Modules and scheme files loaded by lily.scm use currying
;;  in Guile V2 this needs a module which is not present in Guile V1.8
;;

(cond-expand
 (guile-2
  (ly:debug (_ "Using (ice-9 curried-definitions) module\n"))
  (use-modules (ice-9 curried-definitions)))
 (else
  (ly:debug (_ "Guile 1.8\n"))))

;; TODO add in modules for V1.8.7 deprecated in V2.0 and integrated
;; into Guile base code, like (ice-9 syncase).
;;

(define ice9-format format)
(define format simple-format)


;;; General settings.
;;;
;;; Debugging evaluator is slower.  This should have a more sensible
;;; default.


(if (or (ly:get-option 'verbose) (ly:get-option 'debug-eval))
    (begin
      (ly:set-option 'protected-scheme-parsing #f)
      (debug-enable 'backtrace)
      (read-enable 'positions)))

(define music-string-to-path-backends
  '(svg))

(if (memq (ly:get-option 'backend) music-string-to-path-backends)
    (ly:set-option 'music-strings-to-paths #t))

(define-public (ly:load x)
  (let* ((full-path (string-append "lily/" x))
         (file-name (%search-load-path full-path)))
    (ly:debug "[~A" file-name)
    (if (not file-name)
        (ly:error (_ "cannot find: ~A") x))
    ;; FIXME: primitive-load-path may load a compiled version of the code;
    ;;        can this be detected and printed? If not, ly:load can be replaced
    ;;        by primitive-load-path right away.
    (primitive-load-path full-path)  ;; to support Guile V2 autocompile
    ;; TODO: Any chance to use ly:debug here? Need to extend it to prevent
    ;;       a newline in this case
    (if (ly:get-option 'verbose)
        (ly:progress "]\n"))))

(define (slashify x)
  (if (string-index x #\\)
      x
      (string-regexp-substitute
       "//*" "/"
       (string-regexp-substitute "\\\\" "/" x))))

(define-public (ly-getcwd)
  (if (eq? PLATFORM 'windows)
      (slashify (getcwd))
      (getcwd)))

(define-public (is-absolute? file-name)
  (let ((file-name-length (string-length file-name)))
    (if (= file-name-length 0)
        #f
        (or (eq? (string-ref file-name 0) #\/)
            (and (eq? PLATFORM 'windows)
                 (> file-name-length 2)
                 (eq? (string-ref file-name 1) #\:)
                 (or (eq? (string-ref file-name 2) #\\)
                     (eq? (string-ref file-name 2) #\/)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; If necessary, emulate Guile V2 module_export_all! for Guile V1.8.n
(cond-expand
 (guile-2 #f)
 (else
  (define (module-export-all! mod)
    (define (fresh-interface!)
      (let ((iface (make-module)))
        (set-module-name! iface (module-name mod))
        ;; for guile 2: (set-module-version! iface (module-version mod))
        (set-module-kind! iface 'interface)
        (set-module-public-interface! mod iface)
        iface))
    (let ((iface (or (module-public-interface mod)
                     (fresh-interface!))))
      (set-module-obarray! iface (module-obarray mod))))))


(define-safe-public (lilypond-version)
  (string-join
   (map (lambda (x) (if (symbol? x)
                        (symbol->string x)
                        (number->string x)))
        (ly:version))
   "."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; init pitch system

(ly:set-default-scale (ly:make-scale #(0 1 2 5/2 7/2 9/2 11/2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; other files.

;;
;;  List of Scheme files to be loaded into the (lily) module.
;;
;;  - Library definitions, need to be at the head of the list
(define init-scheme-files-lib
  '("lily-library"
    "output-lib"))
;;  - Files containing definitions used later by other files later in load
(define init-scheme-files-used
  '("markup-macros"
    "parser-ly-from-scheme"))
;;  - Main body of files to be loaded
(define init-scheme-files-body
  '("file-cache"
    "define-event-classes"
    "define-music-callbacks"
    "define-music-types"
    "define-note-names"
    "c++"
    "chord-entry"
    "skyline"
    "markup"
    "define-markup-commands"
    "stencil"
    "modal-transforms"
    "chord-ignatzek-names"
    "music-functions"
    "part-combiner"
    "autochange"
    "define-music-properties"
    "time-signature"
    "time-signature-settings"
    "auto-beam"
    "chord-name"
    "bezier-tools"

    "define-context-properties"
    "translation-functions"
    "script"
    "midi"
    "layout-beam"
    "parser-clef"
    "layout-slur"
    "font"

    "bar-line"
    "flag-styles"
    "fret-diagrams"
    "tablature"
    "harp-pedals"
    "define-woodwind-diagrams"
    "display-woodwind-diagrams"
    "predefined-fretboards"
    "define-grob-properties"
    "define-grobs"
    "define-grob-interfaces"
    "define-stencil-commands"
    "scheme-engravers"
    "titling"

    "paper"
    "backend-library"
    "color"))
;;  - Files to be loaded last
(define init-scheme-files-tail
  ;;  - must be after everything has been defined
  '("safe-lily"))
;;
;; Now construct the load list
;;
(define init-scheme-files
  (append init-scheme-files-lib
          init-scheme-files-used
          init-scheme-files-body
          init-scheme-files-tail))

(for-each ly:load init-scheme-files)

(define-public r5rs-primary-predicates
  `((,boolean? . "boolean")
    (,char? . "character")

    (,list? . "list")
    (,null? . "null")

    (,number? . "number")
    (,complex? . "complex number")
    (,integer? . "integer")
    (,rational? . "rational number")
    (,real? . "real number")

    (,pair? . "pair")

    (,port? . "port")
    (,input-port? . "input port")
    (,output-port? . "output port")
    (,eof-object? . "end-of-file object")

    (,procedure? . "procedure")
    (,string? . "string")
    (,symbol? . "symbol")
    (,vector? . "vector")))

(define-public r5rs-secondary-predicates
  `((,char-alphabetic? . "alphabetic character")
    (,char-lower-case? . "lower-case character")
    (,char-numeric? . "numeric character")
    (,char-upper-case? . "upper-case character")
    (,char-whitespace? . "whitespace character")

    (,even? . "even number")
    (,exact? . "exact number")
    (,inexact? . "inexact number")
    (,negative? . "negative number")
    (,odd? . "odd number")
    (,positive? . "positive number")
    (,zero? . "zero")
    ))

(define-public guile-predicates
  `((,hash-table? . "hash table")
    ))

(define-public lilypond-scheme-predicates
  `((,boolean-or-symbol? . "boolean or symbol")
    (,color? . "color")
    (,cheap-list? . "list")
    (,fraction? . "fraction, as pair")
    (,grob-list? . "list of grobs")
    (,index? . "non-negative integer")
    (,integer-or-markup? . "integer or markup")
    (,key? . "index or symbol")
    (,key-list? . "list of indexes or symbols")
    (,key-list-or-music? . "key list or music")
    (,key-list-or-symbol? . "key list or symbol")
    (,markup? . "markup")
    (,markup-command-list? . "markup command list")
    (,markup-list? . "markup list")
    (,moment-pair? . "pair of moment objects")
    (,number-list? . "number list")
    (,number-or-grob? . "number or grob")
    (,number-or-pair? . "number or pair")
    (,number-or-string? . "number or string")
    (,number-pair? . "pair of numbers")
    (,number-pair-list? . "list of number pairs")
    (,exact-rational? . "an exact rational number")
    (,rational-or-procedure? . "an exact rational or procedure")
    (,rhythmic-location? . "rhythmic location")
    (,scale? . "non-negative rational, fraction, or moment")
    (,scheme? . "any type")
    (,string-or-pair? . "string or pair")
    (,string-or-music? . "string or music")
    (,string-or-symbol? . "string or symbol")
    (,symbol-list? . "symbol list")
    (,symbol-list-or-music? . "symbol list or music")
    (,symbol-list-or-symbol? . "symbol list or symbol")
    (,void? . "void")
    ))

(define-public lilypond-exported-predicates
  `((,ly:book? . "book")
    (,ly:context? . "context")
    (,ly:context-def? . "context definition")
    (,ly:context-mod? . "context modification")
    (,ly:dimension? . "dimension, in staff space")
    (,ly:dir? . "direction")
    (,ly:dispatcher? . "dispatcher")
    (,ly:duration? . "duration")
    (,ly:event? . "post event")
    (,ly:font-metric? . "font metric")
    (,ly:grob? . "graphical (layout) object")
    (,ly:grob-array? . "array of grobs")
    (,ly:grob-properties? . "grob properties")
    (,ly:input-location? . "input location")
    (,ly:item? . "item")
    (,ly:iterator? . "iterator")
    (,ly:lily-lexer? . "lily-lexer")
    (,ly:lily-parser? . "lily-parser")
    (,ly:listener? . "listener")
    (,ly:moment? . "moment")
    (,ly:music? . "music")
    (,ly:music-function? . "music function")
    (,ly:music-list? . "list of music objects")
    (,ly:music-output? . "music output")
    (,ly:otf-font? . "OpenType font")
    (,ly:output-def? . "output definition")
    (,ly:page-marker? . "page marker")
    (,ly:pango-font? . "pango font")
    (,ly:paper-book? . "paper book")
    (,ly:paper-system? . "paper-system Prob")
    (,ly:pitch? . "pitch")
    (,ly:prob? . "property object")
    (,ly:score? . "score")
    (,ly:skyline? . "skyline")
    (,ly:skyline-pair? . "pair of skylines")
    (,ly:source-file? . "source file")
    (,ly:spanner? . "spanner")
    (,ly:spring? . "spring")
    (,ly:stencil? . "stencil")
    (,ly:stream-event? . "stream event")
    (,ly:transform? . "coordinate transform")
    (,ly:translator? . "translator")
    (,ly:translator-group? . "translator group")
    (,ly:unpure-pure-container? . "unpure/pure container")
    ))


(set! type-p-name-alist
      (append r5rs-primary-predicates
              r5rs-secondary-predicates
              guile-predicates
              lilypond-scheme-predicates
              lilypond-exported-predicates))

;; Undead objects that should be ignored after the first time round
(define gc-zombies
  (make-weak-key-hash-table))

;; For testing the debug-gc-object-lifetimes feature.
(define-public debug-gc-object-lifetimes-test-object #f)

(define (dump-zombies limit)
  "Check for new objects that should have been dead. Print `limit`
instances of them (#t for no limit). Doesn't work on GUILE 2"
  (ly:set-option 'debug-gc-assert-parsed-dead #t)
  (gc)
  (ly:set-option 'debug-gc-assert-parsed-dead #f)
  ;; We must read out ly:parsed-undead-list! in this function: if we
  ;; waited, another (gc) might come along, freeing the zombies, and
  ;; we'd read freed cells later on.
  (for-each
   (lambda (x)
     (if (not (hashq-ref gc-zombies x))
         (begin
           (if (or (eq? limit #t) (< 0 limit))
               (begin
                 (ly:programming-error "Parsed object should be dead ~a" x)
                 (if (number? limit) (set! limit (1- limit)))))
           (hashq-set! gc-zombies x #t))))
   (ly:parsed-undead-list!))
  (set! debug-gc-object-lifetimes-test-object #f))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (multi-fork count)
  "Split this process into COUNT helpers.  Returns either a list of
PIDs or the number of the process."
  (define (helper count acc)
    (if (> count 0)
        (let* ((pid (primitive-fork)))
          (if (= pid 0)
              (begin
                (randomize-rand-seed)
                (1- count))
              (helper (1- count) (cons pid acc))))
        acc))

  (helper count '()))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define* (ly:exit status #:optional (silently #f))
  "Exit function for lilypond"
  (if (ly:get-option 'gs-api)
      (ly:shutdown-gs))
  (if (not silently)
      (case status
        ((0) (ly:basic-progress (_ "Success: compilation successfully completed")))
        ((1) (ly:warning (_ "Compilation completed with warnings or errors")))
        (else (ly:message ""))))
  (exit status))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (lilypond-main files)
  "Entry point for LilyPond."
  (eval-string (ly:command-line-code))
  (if (ly:get-option 'help)
      (begin (ly:option-usage)
             (ly:exit 0 #t)))
  (if (ly:get-option 'show-available-fonts)
      (begin (ly:font-config-display-fonts)
             (ly:exit 0 #t)))
  (if (ly:get-option 'gui)
      (gui-main files))
  (if (null? files)
      (begin (ly:usage)
             (ly:exit 2 #t)))
  (if (ly:get-option 'read-file-list)
      (set! files
            (remove string-null?
                    (append-map
                     (lambda (f)
                       (string-split
                        (cond-expand
                         (guile-2 (string-delete #\cr (ly:gulp-file f)))
                         (else (string-delete (ly:gulp-file f) #\cr)))
                        #\nl))
                     files))))
  (if (and (number? (ly:get-option 'job-count))
           (>= (length files) (ly:get-option 'job-count)))
      (let* ((count (ly:get-option 'job-count))
             (split-todo (split-list files count))
             (joblist (multi-fork count))
             (errors '()))
        (if (not (string-or-symbol? (ly:get-option 'log-file)))
            (ly:set-option 'log-file "lilypond-multi-run"))
        (if (number? joblist)
            (begin (ly:set-option
                    'log-file (format #f "~a-~a"
                                      (ly:get-option 'log-file) joblist))
                   (set! files (vector-ref split-todo joblist)))
            (begin (ly:progress "\nForking into jobs:  ~a\n" joblist)
                   (for-each
                    (lambda (pid)
                      (let* ((stat (cdr (waitpid pid))))
                        (if (not (= stat 0))
                            (set! errors
                                  (acons (list-element-index joblist pid)
                                         stat errors)))))
                    joblist)
                   (for-each
                    (lambda (x)
                      (let* ((job (car x))
                             (state (cdr x))
                             (logfile (format #f "~a-~a.log"
                                              (ly:get-option 'log-file) job))
                             (log (ly:gulp-file logfile))
                             (len (string-length log))
                             (tail (substring  log (max 0 (- len 1024)))))
                        (if (status:term-sig state)
                            (ly:message
                             "\n\n~a\n"
                             (format #f (_ "job ~a terminated with signal: ~a")
                                     job (status:term-sig state)))
                            (ly:message
                             (_ "logfile ~a (exit ~a):\n~a")
                             logfile (status:exit-val state) tail))))
                    errors)
                   (if (pair? errors)
                       (ly:error (_ "Children ~a exited with errors.")
                                 (map car errors)))
                   ;; must overwrite individual entries
                   (if (null? errors)
                       (ly:exit 0 #f)
                       (ly:exit 1 #f))))))

  (if (string-or-symbol? (ly:get-option 'log-file))
      (ly:stderr-redirect (format #f "~a.log" (ly:get-option 'log-file)) "w"))
  (let ((log-file (and (ly:get-option 'separate-log-files) (dup 2)))
        (failed (lilypond-all files)))
    (if log-file (ly:stderr-redirect log-file))
    (if (pair? failed)
        (begin (ly:error (_ "failed files: ~S") (string-join failed))
               (ly:exit 1 #f))
        (begin
          (ly:exit 0 #f)))))

(define-public (session-start-record)
  (for-each (lambda (v)
	    ;; import all public session variables natively into parser
	    ;; module.  That makes them behave identically under define/set!
	    (module-add! (current-module) (car v) (cdr v)))
  lilypond-exports))

(define-public (lilypond-all files)
  (cond-expand
   (guile-2
    (if (ly:get-option 'debug-gc-object-lifetimes)
        (begin (ly:set-option 'debug-gc-object-lifetimes #f)
               (ly:warning (_ "option 'debug-gc-object-lifetimes not supported on GUILE 2")))))
   (else #t))

  ;; Do this relatively late (after forking for multiple jobs), so Pango
  ;; can spawn threads (since version 1.48.3) without leading to hangs.
  (ly:reset-all-fonts)
  (ly:parse-init "declarations-init.ly")

  (let* ((failed '())
         (debug-lifetimes-limit (ly:get-option 'debug-gc-object-lifetimes))
         (separate-logs (ly:get-option 'separate-log-files))
         (ping-log (and separate-logs (dup 2)))
         (handler (lambda (key failed-file)
                    (set! failed (append (list failed-file) failed)))))
    (if debug-lifetimes-limit
        (gc))
    (for-each
     (lambda (x)
       (let* ((base (dir-basename x ".ly"))
              (all-settings (ly:all-options)))
         (if ping-log
             (begin
               (ly:stderr-redirect ping-log)
               (ly:message (_ "Processing `~a'\n") x)))
         (if separate-logs
             (ly:stderr-redirect (format #f "~a.log" base) "w"))
         (lilypond-file handler x)
         (ly:check-expected-warnings)
         (session-terminate)
         (for-each (lambda (s)
                     (ly:set-option (car s) (cdr s)))
                   all-settings)
         (ly:reset-all-fonts)

         (if debug-lifetimes-limit
             (dump-zombies debug-lifetimes-limit))
         (flush-all-ports)))
     files)
    failed))

(define (lilypond-file handler file-name)
  (catch 'ly-file-failed
         (lambda () (ly:parse-file file-name))
         (lambda (x . args) (handler x file-name))))

(use-modules (lily editor))

(define-public (gui-main files)
  (if (null? files)
      (gui-no-files-handler))
  (if (not (string? (ly:get-option 'log-file)))
      (let* ((base (dir-basename (car files) ".ly"))
             (log-name (string-append base ".log")))
        (if (not (ly:get-option 'gui))
            (ly:message (_ "Redirecting output to ~a...") log-name))
        (ly:stderr-redirect log-name "w")
        (ly:message "# -*-compilation-*-"))
      (let ((failed (lilypond-all files)))
        (if (pair? failed)
            (begin
              (system (get-editor-command log-name 0 0 0))
              (ly:error (_ "failed files: ~S") (string-join failed))
              ;; not reached?
              (exit 1))
            (ly:exit 0 #f)))))

(define (gui-no-files-handler)
  (let* ((ly (string-append (ly:effective-prefix) "/ly/"))
         ;; FIXME: soft-code, localize
         (welcome-ly (string-append ly "Welcome_to_LilyPond.ly"))
         (cmd (get-editor-command welcome-ly 0 0 0)))
    (ly:message (_ "Invoking `~a'...\n") cmd)
    (system cmd)
    (ly:exit 1 #f)))
