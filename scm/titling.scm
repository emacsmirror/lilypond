;;;; This file is part of LilyPond, the GNU music typesetter.
;;;;
;;;; Copyright (C) 2004--2023 Jan Nieuwenhuizen <janneke@gnu.org>
;;;;          Han-Wen Nienhuys <hanwen@xs4all.nl>
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

(use-modules (lily page))

(define-public (layout-extract-page-properties layout)
  (list (append `((line-width . ,(ly:paper-get-number
                                  layout 'line-width)))
                (ly:output-def-lookup layout 'property-defaults)
                '((font-encoding . latin1)))))

(define-public (headers-property-alist-chain headers)
  "Take a list of @code{\\header} blocks (Guile modules).  Return an
alist chain containing all of their bindings where the names have been
prefixed with @code{header:}.  This alist chain is suitable for
interpreting a markup in the context of these headers."
  (map
   (lambda (module)
     (map
      (lambda (entry)
        (cons
         (string->symbol
          (string-append "header:"
                         (symbol->string (car entry))))
         (cdr entry)))
      (ly:module->alist module)))
   headers))

;;;;;;;;;;;;;;;;;;

(define-public ((marked-up-headfoot what-odd what-even) page)
  "Read variables @var{what-odd} and @var{what-even} from the page's
layout.  Interpret either of them as header or footer markup, with
properties reflecting the variables in the page's layout and header
modules."
  (let* ((paper-book (page-property page 'paper-book))
         (layout (ly:paper-book-paper paper-book))
         (page-number (page-property page 'page-number))
         (even-mkup (ly:output-def-lookup layout what-even))
         (odd-mkup (ly:output-def-lookup layout what-odd))
         ;; what-even defaults to what-odd if not defined.
         (header-mkup (cond
                       ((and (even? page-number)
                             (markup? even-mkup))
                        even-mkup)
                       ((markup? odd-mkup)
                        odd-mkup)
                       (else #f))))
    (if header-mkup
        (let* ((scopes (ly:paper-book-scopes paper-book))
               (is-last-bookpart (page-property page 'is-last-bookpart))
               (is-bookpart-last-page (page-property page 'is-bookpart-last-page))
               (number-type (ly:output-def-lookup layout 'page-number-type))
               ;; Support tagline in \paper
               (tagline (ly:modules-lookup scopes
                                           'tagline
                                           (ly:output-def-lookup layout 'tagline)))
               (basic-props (layout-extract-page-properties layout))
               (header-props (headers-property-alist-chain scopes))
               (extra-properties
                `((page:is-last-bookpart . ,is-last-bookpart)
                  (page:is-bookpart-last-page . ,is-bookpart-last-page)
                  (page:page-number . ,page-number)
                  (page:page-number-string . ,(number-format number-type page-number))
                  (header:tagline . ,tagline)))
               (props (cons extra-properties (append header-props basic-props)))
               (stil (interpret-markup layout props header-mkup)))
          ;; A stencil that is merely Y-empty counts as horizontal spacing.
          ;; Since we want those to register as lines of their own (is this a
          ;; good idea?), we make them a separately visible line.
          ;; See also comment in `stack-lines` from stencil.scm
          (if (and (ly:stencil-empty? stil Y)
                   (not (ly:stencil-empty? stil X)))
              (ly:make-stencil
               (ly:stencil-expr stil) (ly:stencil-extent stil X) '(0 . 0))
              stil))
        empty-stencil)))

(define-public ((marked-up-title what) layout scopes)
  "Read variable @var{what} from the page's layout.  Interpret it as
title markup, with properties reflecting the variable in the page's
layout and header modules."
  (let* ((prefixed-alists (headers-property-alist-chain scopes))
         (props (append prefixed-alists
                        (layout-extract-page-properties layout)))
         (title-markup (ly:output-def-lookup layout what)))
    (if (markup? title-markup)
        (interpret-markup layout props title-markup)
        empty-stencil)))
