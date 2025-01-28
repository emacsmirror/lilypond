;;;; This file is part of LilyPond, the GNU music typesetter.
;;;;
;;;; Copyright (C) 2012--2023 David Nalesnik <david.nalesnik@gmail.com>
;;;;                          Thomas Morley <thomasmorley65@gmail.com>
;;;;                          Dan Eble <nine.fierce.ballads@gmail.com>
;;;;                          Jonas Hahnfeld <hahnjo@hahnjo.de>
;;;;                          Jean Abou Samra <jean@abou-samra.fr>
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

(use-modules (ice-9 match))

(define-public (ly:make-listener callback)
  "This is a compatibility wrapper for creating a @q{listener} for use
with @code{ly:add-listener} from a @var{callback} taking a single
argument.  Since listeners are equivalent to callbacks, this is no
longer needed."
  callback)

(define-public (Breathing_sign_engraver context)
  (let ((breathing-event #f))
    (make-engraver
     (listeners
      ((breathing-event engraver event)
       (set! breathing-event event)))

     ((process-music engraver)
      (if (ly:stream-event? breathing-event)
          (let ((b-type (ly:context-property context 'breathMarkType)))
            (if (symbol? b-type)
                (let ((grob (ly:engraver-make-grob
                             engraver 'BreathingSign breathing-event)))
                  (ly:breathing-sign::set-breath-properties
                   grob context b-type))))))

     ((stop-translation-timestep engraver)
      (set! breathing-event #f)))))

(ly:register-translator
 Breathing_sign_engraver 'Breathing_sign_engraver
 '((grobs-created . (BreathingSign))
   (events-accepted . (breathing-event))
   (properties-read . (breathMarkType))
   (properties-written . ())
   (description . "Notate breath marks.")))

(define-public (Divisio_engraver context)
  ;; "div info" is (priority breath-type event)
  (define (div-info-max old new)
    (if (> (car new) (car old))
        new
        old))

  (let ((div-info (list 0 #f #f))
        (grob #f))

    (make-engraver
     (listeners
      ((volta-repeat-start-event engraver event #:once)
       (set! div-info (div-info-max div-info
                                    (list 5 'chantdoublebar event))))
      ((volta-repeat-end-event engraver event #:once)
       (set! div-info (div-info-max div-info
                                    (list 4 'chantdoublebar event))))
      ((fine-event engraver event #:once)
       (set! div-info (div-info-max div-info
                                    (list 3 'chantdoublebar event))))
      ((section-event engraver event #:once)
       (set! div-info (div-info-max div-info
                                    (list 2 'chantdoublebar event))))
      ((caesura-event engraver event #:once)
       (set! div-info (div-info-max div-info
                                    (list 1 'fromcontext event)))))

     ((process-music engraver)
      (let* ((b-type (cadr div-info))
             (event (caddr div-info))
             (props (if (eq? b-type 'fromcontext)
                        (ly:context-property context 'caesuraType)
                        `((breath . ,b-type)))))
        ;; Add the user's articulations to the caesuraType.
        (let ((art-types
               (if (ly:stream-event? event)
                   (map (lambda (art-event)
                          (ly:event-property art-event 'articulation-type))
                        (ly:event-property event 'articulations))
                   '())))
          (set! props (acons 'articulations art-types props)))
        ;; Pass the caesuraType through the transform function, if it is set.
        (let ((transform (ly:context-property context 'caesuraTypeTransform)))
          (when (procedure? transform)
            (set! props (transform context props '()))))
        (set! b-type (assq-ref props 'breath))
        (when (symbol? b-type)
          (set! grob (ly:engraver-make-grob engraver 'Divisio event))
          (ly:breathing-sign::set-breath-properties grob context b-type))))

     ((stop-translation-timestep engraver)
      (set! div-info (list 0 #f #f))
      (set! grob #f)))))

(ly:register-translator
 Divisio_engraver 'Divisio_engraver
 '((grobs-created . (Divisio))
   (events-accepted . (caesura-event
                       fine-event
                       section-event
                       volta-repeat-end-event
                       volta-repeat-start-event))
   (properties-read . (caesuraType
                       caesuraTypeTransform))
   (properties-written . ())
   (description . "Create divisiones: chant notation for points of
breathing or caesura.")))

(define (set-counter-text! grob
                           property
                           number
                           alternative-number
                           measure-pos
                           context)
  ;; FIXME: slight code duplication with Bar_number_engraver
  (let* ((style (ly:context-property context 'alternativeNumberingStyle))
         (number-alternatives (eq? style 'numbers-with-letters))
         (final-alt-number (if number-alternatives alternative-number 0))
         (formatter (ly:context-property context 'barNumberFormatter #f)))
    (if formatter
        (ly:grob-set-property! grob
                               property
                               (formatter number
                                          measure-pos
                                          (1- final-alt-number)
                                          context)))))

(define-public (Measure_counter_engraver context)
  (let ((count-spanner '()) ; a single element of the count
        (start-event #f)
        (go? #f) ; is the count in progress?
        (stop-event #f)
        (last-measure-seen 0)
        (last-alternative-number #f)
        ;; Acknowledge bar lines and start a new count when there
        ;; is one.  This is similar to the Bar_number_engraver.
        (first-time-step #t)
        (now-is-bar-line #t)
        (done-in-time-step #f)
        (first-measure-in-count 0))

    (make-engraver
     (listeners
      ((measure-counter-event engraver event)
       (cond
        ((= START (ly:event-property event 'span-direction))
         (let ((current-bar-number (ly:context-property context 'currentBarNumber)))
           (set! start-event event)
           (set! first-measure-in-count current-bar-number)
           ;; initialize one less so first measure receives a count spanner
           (set! last-measure-seen (1- current-bar-number))))
        ((= STOP (ly:event-property event 'span-direction))
         (set! stop-event event)))))

     (acknowledgers
      ((bar-line-interface engraver grob source-engraver)
       (set! now-is-bar-line #t)))

     ((process-acknowledged trans)
      (when (and now-is-bar-line
                 (not done-in-time-step))
        (let ((col (ly:context-property context 'currentCommandColumn))
              (measure-pos (ly:context-property context 'measurePosition))
              (current-bar (ly:context-property context 'currentBarNumber)))
          (set! done-in-time-step #t)
          ;; Each measure of a count receives a new spanner, which is bounded
          ;; by the first "command column" of that measure and the following one.
          (if (or (eq? #t (ly:context-property context 'measureStartNow))
                  ;; This first-time-step criterion also applies for a Staff
                  ;; created mid-piece; starting a measure counter mid-measure
                  ;; is not meaningful anyway.
                  first-time-step)
              (begin
                ;; Finish the previous count-spanner if there is one.
                (if (ly:grob? count-spanner)
                    (begin
                      (ly:spanner-set-bound! count-spanner RIGHT col)
                      (ly:pointer-group-interface::add-grob count-spanner 'columns col)
                      (ly:engraver-announce-end-grob trans count-spanner col)
                      (if (> current-bar (1+ last-measure-seen))
                          ;; Measure counter spanning over a compressed MM rest.
                          (let* ((counter (ly:grob-property count-spanner 'count-from))
                                 (right-number
                                  (1- (+ counter
                                         (- current-bar first-measure-in-count)))))
                            (set-counter-text!
                             count-spanner
                             'right-number-text
                             right-number
                             ;; Edge case of compressed MM rests in alternatives.
                             ;; It would be wrong to take the context's
                             ;; alternativeNumber here, because we are
                             ;; looking behind at the last measure before
                             ;; this one.  Actually, a compressed MM rest
                             ;; is one single time step, so there is no
                             ;; right time where we could look up the property.
                             ;; Fortunately, MM rests from different alternatives
                             ;; cannot be compressed together, so we can just take
                             ;; the alternative number that was current at the
                             ;; time of the start of this measure counter.
                             last-alternative-number
                             measure-pos
                             context)))
                      (set! count-spanner '())))
                (if stop-event
                    (set! go? #f))
                (if start-event
                    (if go?
                        (ly:event-warning start-event
                                          (G_ "count not ended before another begun"))
                        (set! go? #t)))
                ;; If count is in progress, begin a count-spanner.
                (if go?
                    (let* ((c (ly:engraver-make-grob trans 'MeasureCounter col))
                           (counter (ly:grob-property c 'count-from))
                           (left-number
                            (+ counter (- current-bar first-measure-in-count)))
                           (alternative-number
                            (ly:context-property context 'alternativeNumber 0)))
                      (ly:spanner-set-bound! c LEFT col)
                      (ly:pointer-group-interface::add-grob c 'columns col)
                      (set-counter-text! c
                                         'left-number-text
                                         left-number
                                         alternative-number
                                         measure-pos
                                         context)
                      (set! count-spanner c)
                      (set! last-alternative-number alternative-number)))))
          (set! last-measure-seen current-bar))))

     ((stop-translation-timestep trans)
      (set! start-event #f)
      (set! stop-event #f)
      (set! now-is-bar-line #f)
      (set! done-in-time-step #f)
      (set! first-time-step #f))

     ((finalize trans)
      (if go?
          (begin
            (set! go? #f)
            (ly:grob-suicide! count-spanner)
            (set! count-spanner '())
            (ly:warning (G_ "measure count left unfinished"))))))))

(define-public (Measure_spanner_engraver context)
  (let ((span '())
        (finished '())
        (event-start '())
        (event-stop '()))
    (make-engraver
     (listeners ((measure-spanner-event engraver event)
                 (if (= START (ly:event-property event 'span-direction))
                     (set! event-start event)
                     (set! event-stop event))))
     ((process-music trans)
      (if (ly:stream-event? event-stop)
          (if (null? span)
              (ly:warning (G_ "cannot find start of measure spanner"))
              (begin
                (set! finished span)
                (ly:engraver-announce-end-grob trans finished event-start)
                (set! span '())
                (set! event-stop '()))))
      (if (ly:stream-event? event-start)
          (begin
            (set! span (ly:engraver-make-grob trans 'MeasureSpanner event-start))
            (set! event-start '()))))
     ((stop-translation-timestep trans)
      (if (and (ly:spanner? span)
               (not (ly:spanner-bound span LEFT #f))
               (moment<=? (ly:context-property context 'measurePosition) ZERO-MOMENT))
          (ly:spanner-set-bound! span LEFT
                                 (ly:context-property context 'currentCommandColumn)))
      (if (and (ly:spanner? finished)
               (moment<=? (ly:context-property context 'measurePosition) ZERO-MOMENT))
          (begin
            (if (not (ly:spanner-bound finished RIGHT #f))
                (ly:spanner-set-bound! finished RIGHT
                                       (ly:context-property context 'currentCommandColumn)))
            (set! finished '())
            (set! event-start '())
            (set! event-stop '()))))
     ((finalize trans)
      (if (and (ly:spanner? finished)
               (not (ly:spanner-bound finished RIGHT #f)))
          (set! (ly:spanner-bound finished RIGHT)
                (ly:context-property context 'currentCommandColumn)))
      (if (ly:spanner? span)
          (begin
            (ly:warning (G_ "unterminated measure spanner"))
            (ly:grob-suicide! span)))))))

(ly:register-translator
 Measure_counter_engraver 'Measure_counter_engraver
 '((grobs-created . (MeasureCounter))
   (events-accepted . (measure-counter-event))
   (properties-read . (currentCommandColumn
                       measurePosition
                       currentBarNumber))
   (properties-written . ())
   (description . "\
This engraver numbers ranges of measures, which is useful in parts as an
aid for counting repeated measures.  There is no requirement that the
affected measures be repeated, however.  The user delimits the area to
receive a count with @code{\\startMeasureCount} and
@code{\\stopMeasureCount}.")))

(ly:register-translator
 Measure_spanner_engraver 'Measure_spanner_engraver
 '((grobs-created . (MeasureSpanner))
   (events-accepted . (measure-spanner-event))
   (properties-read . (measurePosition
                       currentCommandColumn))
   (properties-written . ())
   (description . "\
This engraver creates spanners bounded by the columns that start and
end measures in response to @code{\\startMeasureSpanner} and
@code{\\stopMeasureSpanner}.")))

(ly:register-translator
 Span_stem_engraver 'Span_stem_engraver
 '((grobs-created . (Stem))
   (events-accepted . ())
   (properties-read . ())
   (properties-written . ())
   (description . "Connect cross-staff stems to the stems above in the system")))

(define (has-one-or-less? lst) (or (null? lst) (null? (cdr lst))))
(define (has-at-least-two? lst) (not (has-one-or-less? lst)))
(define (all-equal? lst pred)
  (or (has-one-or-less? lst)
      (and (pred (car lst) (cadr lst)) (all-equal? (cdr lst) pred))))

(define-public (Merge_mmrest_numbers_engraver context)
  (define (text-equal? a b)
    (equal?
     (ly:grob-property a 'text)
     (ly:grob-property b 'text)))

  (let ((mmrest-numbers '()))
    (make-engraver
     ((start-translation-timestep translator)
      (set! mmrest-numbers '()))
     (acknowledgers
      ((multi-measure-rest-number-interface engraver grob source-engraver)
       (set! mmrest-numbers (cons grob mmrest-numbers))))
     ((stop-translation-timestep translator)
      (if (and (has-at-least-two? mmrest-numbers)
               (all-equal? mmrest-numbers text-equal?))
          (for-each ly:grob-suicide! (cdr (reverse mmrest-numbers))))))))

(ly:register-translator
 Merge_mmrest_numbers_engraver 'Merge_mmrest_numbers_engraver
 '((grobs-created . ())
   (events-accepted . ())
   (properties-read . ())
   (properties-written . ())
   (description . "\
Engraver to merge multi-measure rest numbers in multiple voices.

This works by gathering all multi-measure rest numbers at a time step. If they
all have the same text and there are at least two only the first one is retained
and the others are hidden.")))

(define-public (Merge_rests_engraver context)
  (define (measure-count-eqv? a b)
    (eqv?
     (ly:grob-property a 'measure-count)
     (ly:grob-property b 'measure-count)))

  (define (rests-all-unpitched? rests)
    "Returns true when all rests do not override the staff-position grob
    property. When a rest has a position set we do not want to merge rests at
    that position."
    (every (lambda (rest) (null? (ly:grob-property rest 'staff-position))) rests))

  (define (merge-mmrests mmrests)
    "Move all multimeasure rests to the single voice location."
    (if (all-equal? mmrests measure-count-eqv?)
        (begin
          (for-each
           (lambda (rest) (ly:grob-set-property! rest 'direction CENTER))
           mmrests)
          (for-each
           (lambda (rest) (ly:grob-set-property! rest 'transparent #t))
           (cdr mmrests)))))

  (define (merge-rests rests)
    (for-each
     (lambda (rest) (ly:grob-set-property! rest 'staff-position 0))
     rests)
    (for-each
     (lambda (rest) (ly:grob-set-property! rest 'transparent #t))
     (cdr rests)))

  (let ((mmrests '())
        (rests '())
        (dots '()))
    (make-engraver
     ((start-translation-timestep translator)
      (set! rests '())
      (set! mmrests '())
      (set! dots '()))
     (acknowledgers
      ((dot-column-interface engraver grob source-engraver)
       (if (not (ly:context-property context 'suspendRestMerging #f))
           (set!
            dots
            (append (ly:grob-array->list (ly:grob-object grob 'dots))
                    dots))))
      ((rest-interface engraver grob source-engraver)
       (cond
        ((ly:context-property context 'suspendRestMerging #f)
         #f)
        ((grob::has-interface grob 'multi-measure-rest-interface)
         (set! mmrests (cons grob mmrests)))
        (else
         (set! rests (cons grob rests))))))
     ((stop-translation-timestep translator)
      (let (;; get a list of the rests 'duration-lengths, 'duration-log does
            ;; not take dots into account
            (durs
             (map
              (lambda (g)
                (ly:duration->moment
                 (ly:prob-property
                  (ly:grob-property g 'cause)
                  'duration)))
              rests)))
        (if (and
             (has-at-least-two? rests)
             (all-equal? durs equal?)
             (rests-all-unpitched? rests))
            (begin
              (merge-rests rests)
              ;; ly:grob-suicide! works nicely for dots, as opposed to rests.
              (if (pair? dots) (for-each ly:grob-suicide! (cdr dots)))))
        (if (has-at-least-two? mmrests)
            (merge-mmrests mmrests)))))))

(ly:register-translator
 Merge_rests_engraver 'Merge_rests_engraver
 '((grobs-created . ())
   (events-accepted . ())
   (properties-read . (suspendRestMerging))
   (properties-written . ())
   (description . "\
Engraver to merge rests in multiple voices on the same staff.  This works by
gathering all rests at a time step.  If they are all of the same length and
there are at least two they are moved to the correct location as if there were
one voice.")))

(define-public (event-has-articulation? event-type stream-event)
  "Is @var{event-type} in the @code{articulations} list of the music causing
@var{stream-event}?"
  (if (ly:stream-event? stream-event)
      (any
       (lambda (art)
         (memq event-type (ly:music-property art 'types)))
       (ly:music-property (ly:event-property stream-event 'music-cause)
                          'articulations))
      #f))

(define-public (duration-line::calc-thickness grob)
  ;; The visible thickness of DurationLine follows staff space.
  ;; Though, if ly:line-interface::line is used in the stencil, it looks at
  ;; grob.thickness not staff space. Thus we recalculate grob.thickness here.
  (let ((style (ly:grob-property grob 'style))
        (grob-thickness (ly:grob-property grob 'thickness))
        (layout-line-thick (layout-line-thickness grob))
        (staff-space (ly:staff-symbol-staff-space grob))
        (staff-line-thickness
         (ly:staff-symbol-line-thickness grob)))

    (* staff-space
       (if (eq? style 'beam)
           (* grob-thickness layout-line-thick)
           (* grob-thickness
              (/  layout-line-thick staff-line-thickness))))))

(define-public (Duration_line_engraver context)
  (let ((dur-event #f)
        (start-duration-line #f)
        (stop-duration-line #f)
        (current-dur-grobs #f)
        (created '())
        (rhyth-event #f)
        (mmr-event #f)
        (skip #f)
        (tie #f))
    (make-engraver
     (listeners
      ((duration-line-event this-engraver event)
       (set! dur-event event)
       (set! start-duration-line #t))
      ((multi-measure-rest-event this-engraver event)
       (set! mmr-event event))
      ((rhythmic-event this-engraver event)
       (set! rhyth-event (cons (ly:context-current-moment context) event)))
      ((skip-event this-engraver event)
       (set! skip event))
      ((tie-event this-engraver event)
       (set! tie event)))

     (acknowledgers
      ((multi-measure-rest-interface this-engraver grob source-engraver)
       (if stop-duration-line
           (begin
             (for-each
              (lambda (dur-line)
                ;; TODO rethink:
                ;; For MultiMeasureRest always use to-barline #t
                (ly:grob-set-property! dur-line 'to-barline #t)
                (ly:spanner-set-bound! dur-line RIGHT
                                       (ly:context-property context 'currentMusicalColumn))
                (ly:engraver-announce-end-grob this-engraver dur-line grob))
              current-dur-grobs)
             (set! stop-duration-line #f)
             (set! current-dur-grobs #f)))


       (if (and start-duration-line
                (event-has-articulation? 'duration-line-event mmr-event))
           (begin
             (set! start-duration-line #f)
             (set! stop-duration-line #t)
             (set! current-dur-grobs
                   (let ((dur-line
                          (ly:engraver-make-grob
                           this-engraver
                           'DurationLine
                           dur-event)))
                     (ly:spanner-set-bound! dur-line LEFT
                                            (ly:context-property context 'currentMusicalColumn))
                     (set! created (cons dur-line created))
                     (list dur-line)))
             (set! mmr-event #f)
             (set! dur-event #f))))
      ((note-column-interface this-engraver grob source-engraver)
       (let* ((note-heads-array (ly:grob-object grob 'note-heads))
              (nc-rest (ly:grob-object grob 'rest))
              (note-heads
               (if (ly:grob-array? note-heads-array)
                   (ly:grob-array->list note-heads-array)
                   '())))
         (cond  ;; Don't stop at tied NoteHeads
          ;; TODO make this a context-property?
          ((and (ly:stream-event? tie) stop-duration-line)
           (set! tie #f))
          (stop-duration-line
           (begin
             (for-each
              (lambda (dur-line)
                (ly:spanner-set-bound! dur-line RIGHT grob)
                (ly:engraver-announce-end-grob
                 this-engraver dur-line grob))
              current-dur-grobs)
             (set! stop-duration-line #f)
             (set! current-dur-grobs #f))))

         (if start-duration-line
             (begin
               (set! start-duration-line #f)
               (set! stop-duration-line #t)
               (set! current-dur-grobs
                     (cond
                      ;; get one DurationLine for entire NoteColumn
                      ((ly:context-property context 'startAtNoteColumn #f)
                       (let ((dur-line
                              (ly:engraver-make-grob
                               this-engraver
                               'DurationLine
                               dur-event)))
                         (ly:spanner-set-bound! dur-line LEFT grob)
                         (set! created (cons dur-line created))
                         (list dur-line)))
                      ;; get DurationLines for every NoteHead
                      ((pair? note-heads)
                       (map
                        (lambda (nhd)
                          (let ((dur-line
                                 (ly:engraver-make-grob
                                  this-engraver
                                  'DurationLine
                                  dur-event)))
                            (ly:spanner-set-bound! dur-line LEFT nhd)
                            (set! created (cons dur-line created))
                            dur-line))
                        note-heads))
                      ;; get DurationLine for Rest
                      (else
                       (let ((dur-line
                              (ly:engraver-make-grob
                               this-engraver
                               'DurationLine
                               dur-event)))
                         (ly:spanner-set-bound! dur-line LEFT nc-rest)
                         (set! created (cons dur-line created))
                         (list dur-line)))))
               (set! dur-event #f))))))

     ((process-music this-engraver)
      ;; If 'endAtSkip is set #t, DurationLine may end at skips.
      ;; In this case set right bound to PaperColumn
      (if (and (pair? current-dur-grobs)
               (ly:stream-event? skip)
               (ly:context-property context 'endAtSkip #f)
               stop-duration-line)
          (begin
            (for-each
             (lambda (dur-line)
               (if (not (ly:spanner-bound dur-line RIGHT #f))
                   (let ((cmc (ly:context-property
                               context
                               'currentMusicalColumn)))
                     (ly:spanner-set-bound! dur-line RIGHT cmc)
                     (ly:engraver-announce-end-grob
                      this-engraver dur-line cmc))))
             current-dur-grobs)
            (set! stop-duration-line #f)
            (set! skip #f)
            (set! current-dur-grobs #f)))
      ;; If 'startAtSkip is set #t, DurationLine may start at skips.
      ;; In this case set left bound to PaperColumn .
      ;; We need to care about 'duration-line-event, otherwise we loose the
      ;; ability to ignore skips.
      ;; Thus, only do so if skip has a 'duration-line-event.
      (if (and start-duration-line
               (event-has-articulation? 'duration-line-event skip)
               (ly:context-property context 'startAtSkip #t))
          (begin
            (set! start-duration-line #f)
            (set! stop-duration-line #t)
            (set! current-dur-grobs
                  (let ((dur-line
                         (ly:engraver-make-grob
                          this-engraver
                          'DurationLine
                          dur-event)))
                    (ly:grob-set-property! dur-line 'to-barline #f)
                    (ly:spanner-set-bound! dur-line LEFT
                                           (ly:context-property context 'currentMusicalColumn))
                    (set! created (cons dur-line created))
                    (list dur-line)))
            (set! skip #f)
            (set! dur-event #f))))
     ((stop-translation-timestep this-engraver)
      ;; If no duration-line is active clear local `tie`.
      (when (and (not start-duration-line) (not stop-duration-line))
        (set! tie #f))
      ;; If a context dies or "pauses" (i.e. no rhythmic-event for some time,
      ;; because other contexts are active), set right bound to
      ;; NonMusicalPaperColumn.
      ;; We calculate the end-moment of the rhythmic-event and compare with
      ;; current-moment to get the condition for ending the DurationLine.
      ;; We can't go for (ly:context-property context 'busyGrobs), because
      ;; we then wouldn't know if a skip-event needs to be respected.

      (if rhyth-event
          (let* ((rhyhtmic-evt-start (car rhyth-event))
                 (rhyhtmic-evt-length
                  (ly:prob-property (cdr rhyth-event) 'length ZERO-MOMENT))
                 (rhyhtmic-evt-end
                  (ly:moment-add rhyhtmic-evt-start rhyhtmic-evt-length))
                 (current-moment (ly:context-current-moment context)))
            (if (and (equal? current-moment rhyhtmic-evt-end)
                     (pair? current-dur-grobs)
                     stop-duration-line)
                (begin
                  (for-each
                   (lambda (dur-line)
                     (if (not (ly:spanner-bound dur-line RIGHT #f))
                         (let ((cmc (ly:context-property
                                     context
                                     'currentCommandColumn)))
                           (ly:spanner-set-bound! dur-line RIGHT cmc)
                           (ly:engraver-announce-end-grob
                            this-engraver dur-line cmc))))
                   current-dur-grobs)
                  (set! stop-duration-line #f)
                  (set! current-dur-grobs #f)
                  (set! rhyth-event #f))))))
     ((finalize this-engraver)
      ;; All created DurationLines were cumulated in `created'.
      ;; Their 'thickness needs to be adjusted to follow staff space, not staff
      ;; symbol thickness, which ly:line-interface::line does.
      ;; We do it here to avoid multiple resetting DurationLine.thickness for
      ;; broken ones. Furthermore 'staff-symbol is not always available at
      ;; earlier steps.
      (for-each
       (lambda (dur-line)
         (ly:grob-set-property! dur-line 'thickness
                                (duration-line::calc-thickness dur-line)))
       created)
      ;; likely unneeded, better be paranoid
      (if (pair? current-dur-grobs)
          (begin
            (for-each
             (lambda (dur-line)
               (ly:warning (G_ "unterminated DurationLine"))
               (ly:grob-suicide! dur-line))
             current-dur-grobs)
            (set! current-dur-grobs #f)
            (set! stop-duration-line #f)))))))

(ly:register-translator
 Duration_line_engraver 'Duration_line_engraver
 '((grobs-created . (DurationLine))
   (events-accepted . (duration-line-event))
   (properties-read . (currentCommandColumn
                       currentMusicalColumn
                       startAtSkip
                       endAtSkip
                       startAtNoteColumn
                       ))
   (properties-written . ())
   (description . "\
Engraver to print a line representing the duration of a rhythmic event like
@code{NoteHead}, @code{NoteColumn} or @code{Rest}.")))


(define-public Bend_spanner_engraver
  ;; Creates a BendSpanner, sets its bounds, keeps track and sets
  ;; details.successive-level in order to nest consecutive bends accordingly.
  ;;
  ;; Sets the property 'bend-me to decide which strings should be bent.
  ;; Per default open strings should not be bent unless the user forces it.
  ;; To know which note will be done on open strings we need to know the result
  ;; of the 'noteToFretFunction'.
  ;; User-specified StringNumbers are respected.
  ;; Fingerings are not needed for setting 'bend-me, thus we disregard them.
  (lambda (context)
    (let ((bend-spanner #f)
          (bend-start #f)
          (bend-stop #f)
          (previous-bend-dir #f)
          (nc-start #f)
          (successive-lvl #f)
          (tab-note-heads '()))
      (make-engraver
       ((initialize this-engraver)
        ;; Set 'supportNonIntegerFret #t, if unspecified
        (ly:context-set-property! context 'supportNonIntegerFret
                                  (ly:context-property context 'supportNonIntegerFret #t)))
       ((start-translation-timestep trans)
        ;; Clear 'tab-note-heads' in order not to confuse 'excluding notes
        ;; further below
        (set! tab-note-heads '())
        ;; Set 'bend-spanner' left-bound
        ;; We do it in start-translation-timestep, because here we have access
        ;; to the 'style-property
        (if (and bend-spanner nc-start)
            (begin
              (ly:spanner-set-bound! bend-spanner LEFT nc-start)
              ;; For consecutive BendSpanners, i.e. 'previous-bend-dir' is
              ;; not #f, in/decrease details.successive-level with
              ;;'previous-bend-dir' unless 'bend-style' is 'hold
              (if (and previous-bend-dir successive-lvl)
                  (let* ((hold-style?
                          (eq? (ly:grob-property bend-spanner 'style) 'hold))
                         (increase-lvl
                          (if hold-style? 0 previous-bend-dir)))
                    (ly:grob-set-nested-property!
                     bend-spanner
                     '(details successive-level)
                     (+ successive-lvl increase-lvl))
                    (set! nc-start #f))))))
       (listeners
        ((bend-span-event this-engraver event)
         (set! bend-start event)))
       (acknowledgers
        ((note-column-interface this-engraver grob source-engraver)
         ;; Set the 'bend-me property for notes to be played on open strings
         ;; Per default it will be set #f
         ;; Relies on context-property stringFretFingerList.
         ;;
         ;; Needs to be done here in acknowledgers for note-column-interface,
         ;; otherwise the calculation of bend-dir (relying only on notes
         ;; actually prepares for bending, i.e. 'bend-me should not be #f)
         ;; may cause wrong results.
         (for-each
          (lambda (tnh strg-frt-fngr)
            (if (eq? 0 (cadr strg-frt-fngr))
                (ly:grob-set-property! tnh 'bend-me
                                       (ly:grob-property tnh 'bend-me #f))))
          (reverse tab-note-heads)
          (ly:context-property context 'stringFretFingerList))

            ;;;;
         ;; End the bend-spanner, if found NoteColumn is suitable
            ;;;;
         (if (and bend-stop
                  (ly:spanner? bend-spanner)
                  (ly:grob-property grob 'bend-me #t)
                  (not (ly:spanner-bound bend-spanner RIGHT #f)))
             (let* ((nhds-array (ly:grob-object grob 'note-heads))
                    (nhds
                     (if (ly:grob-array? nhds-array)
                         (ly:grob-array->list nhds-array)
                         #f))
                    (style (ly:grob-property bend-spanner 'style 'default))
                    (boundable?
                     (and nhds
                          (or
                           (eq? style 'pre-bend)
                           (ly:grob-property grob 'bend-me #t)))))
               (if boundable?
                   (begin
                     (ly:spanner-set-bound! bend-spanner RIGHT grob)
                     (set! bend-stop #f)
                     ;; Keep track of 'successive-level, to place
                     ;; consecutive BendSpanners nicely and
                     ;; in/decrease with 'previous-bend-dir'
                     (let* ((details
                             (ly:grob-property bend-spanner 'details))
                            (successive-level
                             (assoc-get 'successive-level details))
                            (span-bound-pitches
                             (bounding-note-heads-pitches bend-spanner)))
                       (if (and (pair? (car span-bound-pitches))
                                (pair? (cdr span-bound-pitches)))
                           (let* ((quarter-diffs
                                   (get-quarter-diffs span-bound-pitches))
                                  (current-bend-dir
                                   (if (negative? quarter-diffs) DOWN UP))
                                  (consecutive-bend?
                                   (and previous-bend-dir
                                        (not (eqv? previous-bend-dir
                                                   current-bend-dir)))))
                             (set! successive-lvl successive-level)
                             (if consecutive-bend?
                                 (begin
                                   (ly:grob-set-nested-property!
                                    bend-spanner
                                    '(details successive-level)
                                    (+ successive-lvl current-bend-dir))
                                   (set! successive-lvl
                                         (+ successive-lvl
                                            current-bend-dir))))
                             (set! previous-bend-dir current-bend-dir)
                             (set! bend-spanner #f))
                           (begin
                             (ly:warning (G_ "No notes found to start from,
ignoring. If you want to bend an open string, consider to override/tweak the
'bend-me property."))
                             (ly:grob-suicide! bend-spanner)))))

                   (begin
                     (set! successive-lvl #f)
                     (set! previous-bend-dir #f)))))

            ;;;;
         ;; Create the bend-spanner grob, if found NoteColumn is suitable
            ;;;;
         (if (and (ly:stream-event? bend-start)
                  (ly:grob-array? (ly:grob-object grob 'note-heads)))
             (let* ((bend-grob
                     (ly:engraver-make-grob
                      this-engraver 'BendSpanner bend-start)))
               (set! bend-spanner bend-grob)
               (set! nc-start grob)
               (set! bend-start #f)
               (set! bend-stop #t))))
        ((tab-note-head-interface this-engraver grob source-engraver)
         (set! tab-note-heads (cons grob tab-note-heads))))
       ((stop-translation-timestep this-engraver)
        (ly:context-set-property! context 'stringFretFingerList '())
        ;; Clear some local variables if no bend-spanner is in work
        (if (and (not bend-start) (not bend-stop))
            (begin
              (set! previous-bend-dir #f)
              (set! successive-lvl #f))))
       ((finalize this-engraver)
        ;; final house-keeping
        (if bend-spanner
            (begin
              (ly:warning (G_ "Unbound BendSpanner, ignoring"))
              (ly:grob-suicide! bend-spanner))))))))

(ly:register-translator
 Bend_spanner_engraver 'Bend_spanner_engraver
 '((grobs-created . (BendSpanner))
   (events-accepted . (bend-span-event
                       note-event
                       string-number-event))
   (properties-read . (stringFretFingerList
                       supportNonIntegerFret))
   (properties-written . (stringFretFingerList
                          supportNonIntegerFret))
   (description . "\
Engraver to print a BendSpanner.")))


(define (finger-key-glide mus-arts il rl glides)
  "Return a list of sublists, where each sublist's first entry is the name of
the grob where the @code{FingerGlideSpanner} starts: @code{Fingering},
@code{StringNumber} or @code{StrokeFinger}.  The second entry is @code{id},
@code{text}, @code{digit}, etc., which serves as a key later on.
The third entry is the corrsponding @code{finger-glide-event}.

We first work on simple events here in order to ensure the correct order,
Thus we finally need to exchange the simple event with the correct
stream-event.

@var{mus-arts} is supposed to be a list of articulations derived from
@code{music-cause} of a @code{note-event}.
@var{il} is an intermediate list.  It is started with a
@code{finger-glide-event} filled with the relevant finger-grob and its name.
Then it is moved to @var{rl} as a sublist. @var{rl} is the final result and
return value."

  (let* ((finger-glide?
           (lambda (ev)
             (eq? (ly:prob-property ev 'name) 'FingerGlideEvent)))
         (fingering?
           (lambda (ev)
             (eq? (ly:prob-property ev 'name) 'FingeringEvent)))
         (string-number?
           (lambda (ev)
             (eq? (ly:prob-property ev 'name) 'StringNumberEvent)))
         (stroke-finger?
           (lambda (ev)
             (eq? (ly:prob-property ev 'name) 'StrokeFingerEvent))))
    (if (null? mus-arts)
        rl
        (cond
          ((finger-glide? (car mus-arts))
             (let ((glide-others
                     ;; We need to get finger-glide-stream-events, which
                     ;; (car mus-arts) is not.
                     ;; Replace (car mus-arts) with the relevant stream-event,
                     ;; looking at the 'origin of (car mus-arts) and 'origin
                     ;; of the 'music-cause of stream-events in `glide`.
                     ;;
                     ;; Thus we split `glide` into two list, the first only
                     ;; takes the current finger-glide-stream-event, the
                     ;; second the others.
                     ;;
                     ;; TODO The direct call of equal? is always #t, why do
                     ;;      we have to compare 'origin?
                     (call-with-values
                       (lambda ()
                         (partition
                           (lambda (gl)
                             (equal?
                               (ly:prob-property (car mus-arts) 'origin)
                               (ly:prob-property
                                 (ly:event-property gl 'music-cause)
                                 'origin)))
                           glides))
                       (lambda (a b) (list (car a) b)))))
               (finger-key-glide
                 (cdr mus-arts)
                 (cons (car glide-others) il)
                 rl
                 (cadr glide-others))))
          ((fingering? (car mus-arts))
             (if (null? il)
                 (finger-key-glide (cdr mus-arts) il rl glides)
                 (let ((digit (ly:prob-property (car mus-arts) 'digit #f))
                       (text (ly:prob-property (car mus-arts) 'text #f))
                       (id (ly:prob-property (car mus-arts) 'id #f)))
                   (finger-key-glide (cdr mus-arts)
                      '()
                      (cons (cons* 'Fingering (or id digit text) il) rl)
                      glides))))
          ((string-number? (car mus-arts))
             (if (null? il)
                  (finger-key-glide (cdr mus-arts) il rl glides)
                  (let ((string-number
                          (ly:prob-property (car mus-arts) 'string-number #f))
                        (id (ly:prob-property (car mus-arts) 'id #f)))
                    (finger-key-glide (cdr mus-arts)
                      '()
                      (cons (cons* 'StringNumber (or id string-number) il) rl)
                      glides))))
          ((stroke-finger? (car mus-arts))
             (if (null? il)
                 (finger-key-glide (cdr mus-arts) il rl glides)
                  (let ((stroke-finger-digit
                         (ly:prob-property
                           (car mus-arts)
                           'stroke-finger-digit
                           #f))
                        (stroke-finger-text
                          (ly:prob-property
                            (car mus-arts)
                            'stroke-finger-text
                            #f))
                        (id (ly:prob-property (car mus-arts) 'id #f)))
                   (finger-key-glide
                     (cdr mus-arts)
                     '()
                     (cons
                       (cons*
                         'StrokeFinger
                         (or id stroke-finger-digit stroke-finger-text)
                         il)
                       rl)
                     glides))))
          (else (finger-key-glide (cdr mus-arts) il rl glides))))))

(define-public Finger_glide_engraver
  (lambda (context)
    (let (;; Maps fingering numbers to fingering glide events
          ;;      string numbers to string-number glide events
          ;;      stroke fingers to stroke-finger glide events
          (finger-glide-event '())
          (string-number-glide-event '())
          (stroke-finger-glide-event '())
          ;; Maps fingering numbers to fingering glide grobs
          ;;      string numbers to string-number glide grobs
          ;;      stroke fingers to stroke-finger glide grobs
          (finger-glide-grobs '())
          (string-number-glide-grobs '())
          (stroke-finger-glide-grobs '()))
      (make-engraver
       (listeners
        ((note-event this-engraver event)
         (let* ((event-arts (ly:event-property event 'articulations))
                (music-cause (ly:event-property event 'music-cause))
                (music-arts (ly:prob-property music-cause 'articulations))
                (glide-events '()))

           ;; Find FingerGlideEvents and accumulate them in glide-events here.
           ;; NB These are stream-events.
           (for-each
            (lambda (art-ev)
             (when (memq 'finger-glide-event (ly:event-property art-ev 'class))
               (set! glide-events (cons art-ev glide-events))))
            event-arts)

           ;; Fill the lists finger-glide-event, string-number-glide-event, and
           ;; stroke-finger-glide-event with the id, digit, text etc and the
           ;; starting finger-glide-event.
           (for-each
            (lambda (ls)
             (when (eq? (car ls) 'Fingering)
               (set! finger-glide-event
                     (acons (cadr ls) (last ls) finger-glide-event)))
             (when (eq? (car ls) 'StringNumber)
               (set! string-number-glide-event
                     (acons (cadr ls) (last ls) string-number-glide-event)))
             (when (eq? (car ls) 'StrokeFinger)
               (set! stroke-finger-glide-event
                     (acons (cadr ls) (last ls) stroke-finger-glide-event))))
            (finger-key-glide music-arts '() '() glide-events)))))
       (acknowledgers
        ((stroke-finger-interface this-engraver grob source-engraver)
         (let* ((cause (ly:grob-property grob 'cause))
                (stroke-finger-digit
                  (ly:prob-property cause 'stroke-finger-digit #f))
                (stroke-finger-text
                  (ly:prob-property cause 'stroke-finger-text #f))
                (id (ly:prob-property cause 'id #f))
                (stroke-finger-glide-evt
                  (assoc-get (or id stroke-finger-digit stroke-finger-text)
                             stroke-finger-glide-event))
                (new-glide-grob
                 (if stroke-finger-glide-evt
                     (ly:engraver-make-grob
                      this-engraver
                      'FingerGlideSpanner
                      stroke-finger-glide-evt)
                     #f)))
           ;; Set right bound, select the grob via its 'id or
           ;; stroke-finger-digit/text from `stroke-finger-glide-grobs`,
           ;; 'id is preferred.
           (let* ((relevant-grob
                    (assoc-get (or id stroke-finger-digit stroke-finger-text)
                               stroke-finger-glide-grobs)))
             (when relevant-grob
               (ly:spanner-set-bound! relevant-grob RIGHT grob)
               (ly:engraver-announce-end-grob this-engraver relevant-grob grob)
               (set! stroke-finger-glide-grobs
                     (assoc-remove!
                       stroke-finger-glide-grobs
                       (or id stroke-finger-digit stroke-finger-text)))))
           ;; Set left bound and store the 'id or stroke-finger-digit/text with
           ;; the created grob as a pair in local `stroke-finger-glide-grobs`,
           ;; 'id is preferred.
           (when new-glide-grob
             (set! stroke-finger-glide-grobs
                   (acons (or id stroke-finger-digit stroke-finger-text)
                          new-glide-grob
                          stroke-finger-glide-grobs))
             (ly:spanner-set-bound! new-glide-grob LEFT grob)
             (set! stroke-finger-glide-event
                   (assoc-remove!
                     stroke-finger-glide-event
                     (or id stroke-finger-digit stroke-finger-text))))))
        ((string-number-interface this-engraver grob source-engraver)
         (let* ((cause (ly:grob-property grob 'cause))
                (string-number (ly:prob-property cause 'string-number #f))
                (id (ly:prob-property cause 'id #f))
                (string-number-glide-evt
                    (assoc-get (or id string-number) string-number-glide-event))
                (new-glide-grob
                 (if string-number-glide-evt
                     (ly:engraver-make-grob
                      this-engraver
                      'FingerGlideSpanner
                      string-number-glide-evt)
                     #f)))
           ;; Set right bound, select the grob via its 'id or string-number from
           ;; `string-number-glide-grobs`, 'id is preferred.
           (let* ((relevant-grob
                    (assoc-get (or id string-number)
                               string-number-glide-grobs)))
             (when relevant-grob
               (ly:spanner-set-bound! relevant-grob RIGHT grob)
               (ly:engraver-announce-end-grob this-engraver relevant-grob grob)
               (set! string-number-glide-grobs
                     (assv-remove! string-number-glide-grobs
                                   (or id string-number)))))
           ;; Set left bound and store the 'id or string-number with the created
           ;; grob as a pair in local `string-number-glide-grobs`, 'id is
           ;; preferred.
           (when new-glide-grob
             (set! string-number-glide-grobs
                   (acons (or id string-number) new-glide-grob
                          string-number-glide-grobs))
             (ly:spanner-set-bound! new-glide-grob LEFT grob)
             (set! string-number-glide-event
                   (assv-remove! string-number-glide-event
                                 (or id string-number))))))
        ((finger-interface this-engraver grob source-engraver)
         (let* ((cause (ly:grob-property grob 'cause))
                (digit (ly:prob-property cause 'digit #f))
                (text (ly:prob-property cause 'text #f))
                (id (ly:prob-property cause 'id #f))
                (digit-glide-evt
                  (assoc-get (or id digit text) finger-glide-event))
                (new-glide-grob
                 (if digit-glide-evt
                     (ly:engraver-make-grob
                      this-engraver
                      'FingerGlideSpanner
                      digit-glide-evt)
                     #f)))
           ;; Set right bound, select the grob via its 'id, digit or text from
           ;; `finger-glide-grobs`, 'id is preferred.
           (let* ((relevant-grob
                   (assoc-get (or id digit text) finger-glide-grobs)))
             (when relevant-grob
               (ly:spanner-set-bound! relevant-grob RIGHT grob)
               (ly:engraver-announce-end-grob this-engraver relevant-grob grob)
               (set! finger-glide-grobs
                     (assoc-remove! finger-glide-grobs (or id digit text)))))
           ;; Set left bound and store the 'id. digit or text with the created
           ;; grob as a pair in local `finger-glide-grobs`, 'id is preferred.
           (when new-glide-grob
             (set! finger-glide-grobs
                   (acons (or id digit text) new-glide-grob finger-glide-grobs))
             (ly:spanner-set-bound! new-glide-grob LEFT grob)
             (set! finger-glide-event
                   (assoc-remove! finger-glide-event (or id digit text)))))))
       ((finalize this-engraver)
        ;; Warn for a created grob without right bound, suicide the grob.
        (for-each
         (lambda (grob-entry)
           (ly:event-warning
            (event-cause (cdr grob-entry))
            (G_ "unterminated finger glide spanner"))
           (ly:grob-suicide! (cdr grob-entry)))
         (append
           finger-glide-grobs
           string-number-glide-grobs
           stroke-finger-glide-grobs)))))))

(ly:register-translator
 Finger_glide_engraver 'Finger_glide_engraver
 '((grobs-created . (FingerGlideSpanner))
   (events-accepted . (note-event))
   (properties-read . ())
   (properties-written . ())
   (description . "\
Engraver to print a line between two @code{Fingering}, @code{StringNumber} or
@code{StrokeFinger} grobs.")))


(define (Lyric_repeat_count_engraver context)
  (let ((end-event '()))
    (make-engraver
     (listeners
      ((volta-repeat-end-event engraver event #:once)
       (let ((count (ly:event-property event 'repeat-count 0)))
         (if (positive? count)
             (set! end-event event)))))

     ((process-music engraver)
      (if (ly:stream-event? end-event)
          (let* ((count (ly:event-property end-event 'repeat-count))
                 (formatter (ly:context-property
                             context 'lyricRepeatCountFormatter))
                 (text (and (procedure? formatter) (formatter context count))))
            (if (markup? text)
                (let ((grob (ly:engraver-make-grob
                             engraver 'LyricRepeatCount end-event)))
                  (ly:grob-set-property! grob 'text text))))))

     ((stop-translation-timestep engraver)
      (set! end-event '())))))

(ly:register-translator
 Lyric_repeat_count_engraver 'Lyric_repeat_count_engraver
 '((grobs-created . (LyricRepeatCount))
   (events-accepted . (volta-repeat-end-event))
   (properties-read . (lyricRepeatCountFormatter))
   (properties-written . ())
   (description . "Create repeat counts within lyrics for modern
transcriptions of Gregorian chant.")))

;; TODO: yet another engraver for alignment... Ultimately, it would be nice to
;; merge Dynamic_align_engraver, Piano_pedal_align_engraver and
;; Centered_bar_number_align_engraver.
(define-public (Centered_bar_number_align_engraver context)
  (let ((support-line #f))
    (make-engraver
     (acknowledgers
      ((centered-bar-number-interface engraver grob source-engraver)
       ;; Create the support spanner on the fly when we meet a first
       ;; centered bar number, to avoid an extra grob in the most
       ;; common case.
       (if (not support-line)
           (begin
             (set! support-line
                   (ly:engraver-make-grob engraver
                                          'CenteredBarNumberLineSpanner
                                          '()))
             (ly:spanner-set-bound!
              support-line
              LEFT
              (ly:context-property context 'currentCommandColumn))))
       (ly:axis-group-interface::add-element support-line grob)))
     ((finalize engraver)
      (if support-line
          (ly:spanner-set-bound!
           support-line
           RIGHT
           (ly:context-property context 'currentCommandColumn)))))))

(ly:register-translator
 Centered_bar_number_align_engraver 'Centered_bar_number_align_engraver
 '((grobs-created . (CenteredBarNumberLineSpanner))
   (events-accepted . ())
   (properties-read . (currentCommandColumn))
   (properties-written . ())
   (description . "Group measure-centered bar numbers in a
@code{CenteredBarNumberLineSpanner} so they end up on the same
vertical position.")))

(define (Alteration_glyph_engraver context)
  (make-engraver
   (acknowledgers
    ((accidental-switch-interface engraver grob source-engraver)
     (let ((alteration-glyphs
            (ly:context-property context 'alterationGlyphs)))
       (if alteration-glyphs
           (ly:grob-set-property! grob
                                  'alteration-glyph-name-alist
                                  alteration-glyphs)))))))

(ly:register-translator
 Alteration_glyph_engraver 'Alteration_glyph_engraver
 '((grobs-created . ())
   (events-accepted . ())
   (properties-read . (alterationGlyphs))
   (properties-written . ())
   (description . "Set the @code{glyph-name-alist} of all grobs having the
@code{accidental-switch-interface} to the value of the context's
@code{alterationGlyphs} property, when defined.")))

(define (Signum_repetitionis_engraver context)
  (let ((end-event '()))
    (make-engraver
     (listeners
      ((volta-repeat-end-event engraver event #:once)
       (set! end-event event)))

     ((process-music engraver)
      (if (ly:stream-event? end-event)
          (if (= 0 (ly:event-property end-event 'alternative-number 0))
              ;; Simple repeat: Indicate the repeat count with 1 to 4
              ;; strokes.  (Thanks to Dr. Ross W. Duffin for
              ;; explaining this in his Notation Manual at
              ;; https://casfaculty.case.edu/ross-duffin/.)
              (let ((n (ly:event-property end-event 'repeat-count 0)))
                (if (positive? n)
                    (let ((grob (ly:engraver-make-grob
                                 engraver 'SignumRepetitionis end-event))
                          (glyph (case n
                                   ((1) ":,:")
                                   ((2) ":,,:")
                                   ((3) ":,,,:")
                                   ((4) ":,,,,:")
                                   (else #f))))
                      (if (string? glyph)
                          (ly:grob-set-property! grob 'glyph glyph)))))
              ;; Alternative ending: This is not a use case for this
              ;; ancient notation.  Just create a grob with the
              ;; default glyph if there is a return.
              (let ((n (ly:event-property end-event 'return-count 0)))
                (if (positive? n)
                    (ly:engraver-make-grob
                     engraver 'SignumRepetitionis end-event))))))

     ((stop-translation-timestep engraver)
      (set! end-event '())))))

(ly:register-translator
 Signum_repetitionis_engraver 'Signum_repetitionis_engraver
 '((grobs-created . (SignumRepetitionis))
   (events-accepted . (volta-repeat-end-event))
   (properties-read . ())
   (properties-written . ())
   (description . "Create a @code{SignumRepetitionis} at the end of
a @code{\\repeat volta} section.")))

(define (Spanner_tracking_engraver context)
  ;; Naming note: "spanner" is the grob we take care of
  ;; (e.g., a footnote) and "host" is the grob that
  ;; "spanner" is attached to (e.g., the annotated grob).
  (let (
        ;; Map host spanners to lists of (spanner . source-engraver)
        ;; pairs.  We keep the source-engraver so we can announce the end
        ;; from it rather than from this engraver.
        (table (make-hash-table)))
    (make-engraver
     (acknowledgers
      ((sticky-grob-interface engraver grob source-engraver)
       (if (ly:spanner? grob)
           (let ((host (ly:grob-object grob 'sticky-host)))
             (hashq-set! table
                         host
                         (cons (cons grob source-engraver)
                               (hashq-ref table host '())))))))
     (end-acknowledgers
      ((spanner-interface engraver host source-engraver)
       (let ((spanners (hashq-ref table host)))
         (if spanners
             (begin
               (for-each
                (lambda (spanner-engraver-pair)
                  (let ((spanner (car spanner-engraver-pair))
                        (source-engraver (cdr spanner-engraver-pair)))
                    (ly:engraver-announce-end-grob source-engraver spanner host)))
                spanners)
               (hashq-remove! table host)))))))))

(ly:register-translator
 Spanner_tracking_engraver 'Spanner_tracking_engraver
 '((grobs-created . ())
   (events-accepted . ())
   (properties-read . ())
   (properties-written . ())
   (description . "Helper for creating spanners attached to other spanners.
If a spanner has the @code{sticky-grob-interface}, the engraver tracks the
spanner contained in its @code{sticky-host} object.  When the host ends,
the sticky spanner attached to it has its end announced too.")))

(define (Skip_typesetting_engraver context)
  (let ((ellipsis #f)
        (first-time? #t)
        (was-skipping? #f))
    (make-engraver

     ((process-music engraver)
      ;; If we created an ellipsis in a prior timestep, we know now that it
      ;; doesn't qualify as a STOP ellipsis since we're typesetting again.
      (set! ellipsis #f)
      (when was-skipping?
        (set! ellipsis (ly:engraver-make-grob engraver 'StaffEllipsis '()))
        ;; If we haven't done any typesetting yet, this ellipsis qualifies as a
        ;; START ellipsis.
        (when first-time?
          (ly:grob-set-property! ellipsis 'ellipsis-direction START)))
      (set! first-time? #f))

     ((stop-translation-timestep engraver)
      (set! was-skipping? (ly:context-property context 'skipTypesetting #f)))

     ((finalize engraver)
      (when ellipsis
        (ly:grob-set-property! ellipsis 'ellipsis-direction STOP))))))

(ly:register-translator
 Skip_typesetting_engraver 'Skip_typesetting_engraver
 '((grobs-created . (StaffEllipsis))
   (events-accepted . ())
   (properties-read . (skipTypesetting))
   (properties-written . ())
   (description . "Create a @code{StaffEllipsis} when
@code{skipTypesetting} is used.")))

(define (Show_control_points_engraver context)
  ;; The usual ties and slurs are spanners, but semi-ties
  ;; (laissez vibrer and repeat ties) are items.  We create
  ;; grobs of either class accordingly, with ly:engraver-make-sticky.
  (let ((beziers-found '()))
    (make-engraver
     (acknowledgers
      ;; Keep the origin engraver of each Bézier so as to
      ;; create the control points from it.  Rationale:
      ;; the engraver is in Score because otherwise its
      ;; process-acknowledged slot could be called before
      ;; the Tweak_engraver has had a chance to set
      ;; the show-control-points property.  Having it
      ;; in Score also makes \vshape work everywhere including
      ;; in custom context types where (for instance) the
      ;; Slur_engraver is consisted.  Creating the control
      ;; points from the origin engraver allows overrides
      ;; to be directed to the same context as slurs, and
      ;; could be useful for a custom engraver acknowledging
      ;; the control points.
      ((bezier-curve-interface engraver bezier source-engraver)
       (set! beziers-found
             (cons (cons bezier source-engraver)
                   beziers-found))))
     ((process-acknowledged engraver)
      (for-each
       (lambda (bezier-engraver-pair)
         (let ((bezier (car bezier-engraver-pair))
               (source-engraver (cdr bezier-engraver-pair)))
           (if (ly:grob-property bezier 'show-control-points #f)
               (begin
                                        ; Create control polygon.
                 (let ((polygon
                        (ly:engraver-make-sticky source-engraver
                                                 'ControlPolygon
                                                 bezier
                                                 bezier)))
                   (ly:grob-set-object! polygon 'bezier bezier))
                                        ; Create four control points.
                 (for-each
                  (lambda (i)
                    (let ((point
                           (ly:engraver-make-sticky source-engraver
                                                    'ControlPoint
                                                    bezier
                                                    bezier)))
                      (ly:grob-set-property! point 'index i)
                      (ly:grob-set-object! point 'bezier bezier)))
                  (iota 4))))))
       beziers-found)
      (set! beziers-found '())))))

(ly:register-translator
 Show_control_points_engraver 'Show_control_points_engraver
 '((grobs-created . (ControlPoint ControlPolygon))
   (events-accepted . ())
   (properties-read . ())
   (properties-written . ())
   (description . "Create grobs to visualize control points of Bézier
curves (ties and slurs) for ease of tweaking.")))


(define (Current_chord_text_engraver context)
  (let ((note-events '())
        (rest-event #f))
    (make-engraver
     (listeners
      ((note-event engraver event)
       (set! note-events (cons event note-events)))
      ((general-rest-event engraver event #:once)
       (set! rest-event event)))
     ((pre-process-music engraver)
      (cond
       (rest-event
        (ly:context-set-property! context 'currentChordCause rest-event)
        (let ((symbol (ly:context-property context 'noChordSymbol)))
          (ly:context-set-property! context 'currentChordText symbol)))
       ((pair? note-events)
        (ly:context-set-property! context 'currentChordCause (car note-events))
        (let ((pitches '())
              (bass '())
              (inversion '()))
          (for-each
           (lambda (note-ev)
             (let ((pitch (ly:event-property note-ev 'pitch)))
               (when (ly:pitch? pitch)
                 (let ((is-bass (ly:event-property note-ev 'bass #f))
                       (is-inversion (ly:event-property note-ev 'inversion #f)))
                   (if is-bass
                       (set! bass pitch)
                       (let* ((oct (ly:event-property note-ev 'octavation))
                              (orig
                               (if (integer? oct)
                                   (let ((transp (ly:make-pitch (- oct)
                                                                0)))
                                     (ly:pitch-transpose pitch transp))
                                   pitch)))
                         (set! pitches (cons orig pitches))
                         (when is-inversion
                           (set! inversion pitch)
                           (when (not (integer? oct))
                             (ly:programming-error
                              "inversion does not have original pitch")))))))))
           note-events)
          (let* ((sorted-pitches (sort pitches ly:pitch<?))
                 (formatter (ly:context-property context 'chordNameFunction))
                 (markup (formatter sorted-pitches bass inversion context)))
            (ly:context-set-property! context 'currentChordText markup))))
       (else
        (ly:context-set-property! context 'currentChordCause #f)
        (ly:context-set-property! context 'currentChordText #f))))
     ((stop-translation-timestep engraver)
      (set! note-events '())
      (set! rest-event #f)))))

(ly:register-translator
 Current_chord_text_engraver 'Current_chord_text_engraver
 '((events-accepted . (note-event general-rest-event))
   (properties-read . (chordNameExceptions
                       chordNameFunction
                       chordRootNamer
                       chordNoteNamer
                       majorSevenSymbol
                       noChordSymbol))
   (properties-written . (currentChordCause currentChordText))
   (description . "Catch note and rest events and generate the
appropriate chord text using @code{chordNameFunction}.  Actually
creating a chord name grob is left to other engravers.")))


(define (Chord_name_engraver context)
  (make-engraver
   ((process-music engraver)
    (let ((text (ly:context-property context 'currentChordText #f)))
      ;; Note that user tweaks to ChordName.text are respected.
      ;; However, this is only possible if the default logic would
      ;; have given some text.  Indeed, we cannot create a ChordName
      ;; and look at its text property to decide that we shouldn't
      ;; have created the grob because the property is '().  Practically,
      ;; this means you can't \override ChordName.text to get a ChordName
      ;; if noChordSymbol is '().
      (when (markup? text)
        (let* ((cause (ly:context-property context 'currentChordCause))
               (grob (ly:engraver-make-grob engraver 'ChordName cause))
               ;; Fetching ChordName.text in case it's a callback can't
               ;; be delayed anyway: it needs to be compared for the sake
               ;; of chordChanges.
               (grob-text (ly:grob-property grob 'text #f))
               (final-text (or grob-text text))
               (chord-changes (ly:context-property context 'chordChanges #f)))
          (ly:grob-set-property! grob 'text final-text)
          (when (and chord-changes
                     (equal? final-text (ly:context-property context 'lastChord)))
            ;; FIXME: begin-of-line-visible is misnamed.  Setting it to #t
            ;; doesn't make the grob more visible, but less: it means to
            ;; suppress the chord name unless it's at the beginning of a line.
            (ly:grob-set-property! grob 'begin-of-line-visible #t))
          (ly:context-set-property! context 'lastChord final-text)))))))

(ly:register-translator
 Chord_name_engraver 'Chord_name_engraver
 '((events-accepted . ())
   (grobs-created . (ChordName))
   (properties-read . (currentChordCause currentChordText chordChanges lastChord))
   (properties-written . (lastChord))
   (description . "Read @code{currentChordText} to create chord names.")))


(define (Grid_chord_name_engraver context)
  (let (;; Maintained as the left bound for newly created GridChordName grobs.
        ;; This is the currentCommandColumn at the start of the piece, and the
        ;; latest BarLine afterwards.
        (left-bound #f)
        ;; Was a bar line found in this time step?  Reset after each
        ;; timestep, unlike left-bound.
        (bar-found #f)
        ;; GridChordName being created.
        (chord-name #f)
        ;; All grid chord names from the current measure, to be ended at the
        ;; next bar line.
        (accumulated-chord-names '()))
    (make-engraver
     ((process-music engraver)
      (when (not left-bound) ; first timestep
        (set! left-bound (ly:context-property context 'currentCommandColumn)))
      (let ((text (ly:context-property context 'currentChordText #f)))
        (when text
          (let ((cause (ly:context-property context 'currentChordCause)))
            (set! chord-name (ly:engraver-make-grob engraver 'GridChordName cause))
            ;; This logic is similar to Chord_name_engraver.
            (let* ((grob-text (ly:grob-property chord-name 'text #f))
                   (final-text (or grob-text text)))
              (ly:grob-set-property! chord-name 'text final-text))))))
     (acknowledgers
      ((bar-line-interface engraver grob source-engraver)
       (set! left-bound grob)
       (set! bar-found grob)))
     ((stop-translation-timestep engraver)
      (when bar-found
        (for-each
         (lambda (c)
           (ly:spanner-set-bound! c RIGHT bar-found))
         accumulated-chord-names)
        (set! accumulated-chord-names '())
        (set! bar-found #f))
      (when chord-name
        (ly:spanner-set-bound! chord-name LEFT left-bound)
        (set! accumulated-chord-names (cons chord-name accumulated-chord-names))
        (set! chord-name #f)))
     ((finalize engraver)
      ;; Maybe the piece ended without a bar line.
      (let ((column (ly:context-property context 'currentCommandColumn)))
        (for-each
         (lambda (c)
           (ly:spanner-set-bound! c RIGHT column))
         accumulated-chord-names))))))

(ly:register-translator
 Grid_chord_name_engraver 'Grid_chord_name_engraver
 '((grobs-created . (GridChordName))
   (events-accepted . ())
   (properties-read . (currentChordText currentChordCause currentCommandColumn))
   (properties-written . ())
   (description . "Read @code{currentChordText} to create chord names
adapted for typesetting within a chord grid.")))


(define (Chord_square_engraver context)
  (let (;; Current ChordSquare grob.
        (square #f)
        ;; List of moments at which the measure is split (triggered by chords or
        ;; rests or skips).  Used to determine measure-division property.
        (moms '())
        ;; Whether this is the first timestep.
        (first-timestep #t)
        ;; Chord name found.  Expect only one chord name per time step.
        (chord-name #f)
        ;; Whether we are in a skip.
        (in-skip #f)
        ;; Moment at which the latest chord stops playing.
        (chord-end-mom (ly:make-moment -inf.0))
        ;; Whether the ChordSquare was created at this timestep.
        (new-square-created #f)
        ;; Index for the next chord name we will find.  Reset after terminating
        ;; a ChordSquare.
        (index 0))
    (define (set-square-measure-division!)
      (let* ((now-mom (ly:context-current-moment context))
             (extended-moms (cons now-mom moms))
             (mom-deltas (let loop ((remaining extended-moms)
                                    (acc '()))
                           (match remaining
                             ((_)
                              acc)
                             ((m1 m2 . rest)
                              (loop (cons m2 rest)
                                    (cons (ly:moment-sub m1 m2)
                                          acc))))))
             (total-span (ly:moment-sub now-mom (last extended-moms)))
             (fracs (map (lambda (delta)
                           ;; Don't care about grace chord names.
                           (ly:moment-main (ly:moment-div delta total-span)))
                         mom-deltas)))
        (ly:grob-set-property! square 'measure-division fracs)))
    (make-engraver
     ((start-translation-timestep engraver)
      ;; Can't be done in stop-translation-timestep since the value
      ;; needs to be known in finalize.
      (set! new-square-created #f))
     ((process-music engraver)
      (when first-timestep
        (let ((column (ly:context-property context 'currentCommandColumn)))
          (set! square (ly:engraver-make-grob engraver 'ChordSquare '()))
          (ly:spanner-set-bound! square LEFT column))
        (set! new-square-created #t)))
     (acknowledgers
      ((bar-line-interface engraver grob source-engraver)
       (when (not first-timestep) ; don't duplicate if there's a bar line at the beginning
         (let ((column (ly:context-property context 'currentCommandColumn)))
           (ly:spanner-set-bound! square RIGHT grob)
           (set-square-measure-division!)
           (set! moms '())
           ;; Reset so skips in the next measure count as a new part of a square.
           (set! in-skip #f)
           (ly:engraver-announce-end-grob engraver square grob)
           (set! square (ly:engraver-make-grob engraver 'ChordSquare '()))
           (ly:spanner-set-bound! square LEFT grob)
           (set! new-square-created #t)
           (set! index 0)))
       (when first-timestep
         ;; If we do have a bar line at the beginning, make it the bound of the
         ;; already created chord square.
         (ly:spanner-set-bound! square LEFT grob)))
      ((grid-chord-name-interface engraver grob source-engraver)
       (set! chord-name grob)))
     ((stop-translation-timestep engraver)
      (let ((mom (ly:context-current-moment context)))
        (cond
         ;; Chord name found: register it.
         (chord-name
          (set! moms (cons mom moms))
          (ly:pointer-group-interface::add-grob square 'chord-names chord-name)
          (ly:grob-set-property! chord-name 'index index)
          (ly:grob-set-parent! chord-name X square)
          (ly:grob-set-parent! chord-name Y square)
          (set! index (1+ index))
          (let* ((ev (event-cause chord-name))
                 (length (ly:event-property ev 'length))
                 (now (ly:context-current-moment context)))
            (set! chord-end-mom (ly:moment-add now length)))
          (set! chord-name #f)
          (set! in-skip #f))
         ;; No chord name found and previous chord name no longer active.  This
         ;; is a skip or something similar.  Record the moment where the skip
         ;; started -- unless it already started earlier, in which case it is
         ;; merged with the previous one (also happens if another voice has
         ;; material that causes timesteps in the middle of the skip in the
         ;; chord grid).
         ((and (or (not chord-end-mom)
                   (let ((now (ly:context-current-moment context)))
                     (moment<=? chord-end-mom now)))
               (not in-skip))
          (set! moms (cons mom moms))
          (set! in-skip #t)
          (set! index (1+ index)))))
      (set! first-timestep #f))
     ((finalize engraver)
      ;; Avoid a dangling ChordSquare at the end.  If it was created in this
      ;; timestep, the music ends on a bar line, as most music does, or perhaps
      ;; the music has zero length.  In that case, kill it silently.  Else, we
      ;; have an unterminated measure, so warn about it.
      (when (not new-square-created)
        (ly:warning (G_ "unterminated measure for chord square")))
      (let ((chord-names (ly:grob-object square 'chord-names #f)))
        (when chord-names
          (for-each ly:grob-suicide! (ly:grob-array->list chord-names))))
      (ly:grob-suicide! square)))))

(ly:register-translator
 Chord_square_engraver 'Chord_square_engraver
 '((events-accepted . ())
   (grobs-created . (ChordSquare))
   (properties-read . (currentCommandColumn))
   (properties-written . ())
   (description . "Engrave chord squares in chord grids.")))


(define (Trill_spanner_engraver context)
  (let ((start-event #f)
        (stop-event #f)
        (trill #f)
        (ended-trill #f))
    (make-engraver
     (listeners
      ((trill-span-event engraver event)
       (if (eqv? START (ly:event-property event 'span-direction))
           (set! start-event event)
           (set! stop-event event))))
     ((process-music engraver)
      (let ((ender (or stop-event start-event)))
        (when (and ender trill)
          (set! ended-trill trill)
          (ly:engraver-announce-end-grob engraver ended-trill ender)
          (set! trill #f)))
      (when start-event
        (set! trill (ly:engraver-make-grob engraver 'TrillSpanner start-event))
        (ly:side-position-interface::set-axis! trill Y)
        (let ((direction (ly:event-property start-event 'direction)))
          (when (ly:dir? direction)
            (ly:grob-set-property! trill 'direction direction)))
        (when ended-trill
          (ly:grob-set-object! ended-trill 'right-neighbor trill))))
     (acknowledgers
      ((note-column-interface engraver grob source-engraver)
       ;; If we find a note column, use it for the left bound of the
       ;; newly created trill and the right bound of the trill that
       ;; ended here.
       (when trill
         (ly:pointer-group-interface::add-grob trill 'note-columns grob)
         (ly:pointer-group-interface::add-grob trill 'side-support-elements grob)
         (when start-event
           (ly:spanner-set-bound! trill LEFT grob)))
       (when ended-trill
         (ly:pointer-group-interface::add-grob ended-trill 'note-columns grob)
         (ly:pointer-group-interface::add-grob ended-trill 'side-support-elements grob)
         (when (not (ly:spanner-bound ended-trill RIGHT #f)) ; respect to-barline
           (ly:spanner-set-bound! ended-trill RIGHT grob)))))
     ((stop-translation-timestep engraver)
      ;; Absent any note column, fall back on the musical paper column.
      (when (and trill
                 ;; A bound already set is a note column, added above.
                 (not (ly:spanner-bound trill LEFT #f)))
        (let ((col (ly:context-property context 'currentMusicalColumn)))
          (ly:spanner-set-bound! trill LEFT col)))
      (when (and ended-trill
                 ;; A bound already set is either a note column, added
                 ;; above, or a BarLine due to to-barline.
                 (not (ly:spanner-bound ended-trill RIGHT #f)))
        (let ((col (ly:context-property context 'currentMusicalColumn)))
          (ly:spanner-set-bound! ended-trill RIGHT col))
        (set! ended-trill #f))
      (set! start-event #f)
      (set! stop-event #f))
     ((finalize engraver)
      (when trill
        ;; Fix the bound of a trill extending to the end of the piece:
        ;; the musical column is past the end of the score.  Use the
        ;; non-musical column instead.
        (let ((col (ly:context-property context 'currentCommandColumn)))
          (ly:spanner-set-bound! trill RIGHT col)))))))

(ly:register-translator
 Trill_spanner_engraver 'Trill_spanner_engraver
 '((events-accepted . (trill-span-event))
   (grobs-created . (TrillSpanner))
   (properties-read . (currentCommandColumn currentMusicalColumn))
   (properties-written . ())
   (description . "Create trill spanners.")))


(define (Staff_highlight_engraver context)
  (let ((start-event #f)
        (stop-event #f)
        (highlight #f)
        (ended-highlight #f)
        ;; List of staff symbols "active" in this time step.  A staff symbol is
        ;; active from the time step of \startStaff (probably implicitly the
        ;; first time step) to the time step of \stopStaff (probably implicitly
        ;; the last time step).  Both ends are included.
        (active-staff-symbols '())
        ;; List of staff symbols considered for the whole highlight.
        ;; #f when there is no highlight in progress.
        (highlight-staff-symbols #f))
    ;; Properly handling ossia staves is a little tricky.
    ;; highlight-staff-symbols contains all staff symbols spanned.  Yet, if an
    ;; ossia staff ended where the highlight started, we actually don't want it.
    ;; It would be complicated to handle this by excluding it in
    ;; highlight-staff-symbols because the end of a staff symbol is actually
    ;; announced one time step later (because Staff_symbol_engraver terminates a
    ;; staff symbol implicitly in finalize).  So we filter those unwanted staff
    ;; symbols here.  Namely, if a staff symbol ended just where the highlight
    ;; started, remove it.  Also, if a staff symbol started just where the
    ;; highlight ended, it is implicitly excluded because
    ;; highlight-staff-symbols doesn't contain it yet.
    (define (set-ended-highlight-staff-symbols! grob)
      (ly:grob-set-object!
       grob
       'elements
       (ly:grob-list->grob-array
        (remove
         (lambda (staff-sym)
           (let ((right-bound (ly:spanner-bound staff-sym RIGHT #f)))
             (and right-bound
                  (equal? (grob::when right-bound)
                          (grob::when grob)))))
         highlight-staff-symbols))))
    (make-engraver
     (listeners
      ((staff-highlight-event engraver event)
       (if (eqv? START (ly:event-property event 'span-direction))
           (set! start-event event)
           (set! stop-event event))))
     ((process-music engraver)
      ;; ignore spurious event
      (when (and stop-event (not highlight))
        (ly:event-warning stop-event (G_ "no highlight to end")))
      ;; \staffHighlight implicitly ends the current highlight, if any,
      ;; acting like a \stopStaffHighlight.  This is handy when you want to
      ;; highlight every single measure.
      (let ((ender (or stop-event start-event)))
        (when (and highlight ender)
          (set! ended-highlight highlight)
          (set! highlight #f)
          (let ((non-musical-col
                 (ly:context-property context 'currentCommandColumn)))
            (ly:spanner-set-bound! ended-highlight RIGHT non-musical-col))
          (ly:engraver-announce-end-grob engraver ended-highlight ender)))
      (when start-event
        (set! highlight
              (ly:engraver-make-grob engraver 'StaffHighlight start-event))
        (let ((non-musical-col
               (ly:context-property context 'currentCommandColumn)))
          (ly:spanner-set-bound! highlight LEFT non-musical-col)))
      (when highlight
        (let ((musical-col
               (ly:context-property context 'currentMusicalColumn)))
          (ly:pointer-group-interface::add-grob highlight 'columns musical-col))))
     (acknowledgers
      ((staff-symbol-interface engraver grob source-engraver)
       (set! active-staff-symbols (cons grob active-staff-symbols))))
     (end-acknowledgers
      ((staff-symbol-interface engraver grob source-engraver)
       (set! active-staff-symbols (delq grob active-staff-symbols))))
     ((stop-translation-timestep engraver)
      (when ended-highlight
        (set-ended-highlight-staff-symbols! ended-highlight)
        (set! highlight-staff-symbols #f)
        (set! ended-highlight #f))
      (when start-event
        ;; Initialize highlight-staff-symbols for the new highlight.
        (set! highlight-staff-symbols '()))
      (when highlight-staff-symbols
        ;; Add new staff symbols found in this time step.  If a highlight was
        ;; just started, this also adds all staff symbols started earlier and
        ;; still current.  This way, when we want to end the highlight,
        ;; highlight-staff-symbols will be the list of all staff symbols that
        ;; were active at one or several of the time steps the highlight spans.
        (set! highlight-staff-symbols
              (lset-union eq? highlight-staff-symbols active-staff-symbols)))
      (set! start-event #f)
      (set! stop-event #f))
     ((finalize engraver)
      (when highlight
        ;; Implicitly terminate the current highlight.
        (let ((col (ly:context-property context 'currentCommandColumn)))
          (ly:spanner-set-bound! highlight RIGHT col))
        (set-ended-highlight-staff-symbols! highlight))))))

(ly:register-translator
 Staff_highlight_engraver 'Staff_highlight_engraver
 '((events-accepted . (staff-highlight-event))
   (grobs-created . (StaffHighlight))
   (properties-read . (currentCommandColumn))
   (properties-written . ())
   (description . "Highlights music passages.")))


(define (Text_mark_engraver context)
  (let ((evs '())
        (grobs '()))
    (make-engraver
     (listeners
      ((text-mark-event engraver event)
       (set! evs (cons event evs))))
     ((process-music engraver)
      (let ((i 0))
        (for-each
         (lambda (ev)
           (let* ((grob (ly:engraver-make-grob engraver 'TextMark ev))
                  ;; FIXME: this is not the only place where we sneakily modify
                  ;; values of outside-staff-priority to enforce a deterministic
                  ;; order.  Improve.
                  (osp (ly:grob-property grob 'outside-staff-priority #f)))
             (when osp ; if unset, leave it unset
               (ly:grob-set-property! grob 'outside-staff-priority (+ osp i))
               (set! i (1+ i)))
             (set! grobs (cons grob grobs))))
         ;; The default order has the first mark heard closest to the staff.
         (reverse evs))))
     ((stop-translation-timestep engraver)
      (let ((staves (ly:context-property context 'stavesFound)))
        (for-each
         (lambda (grob)
           (ly:grob-set-object!
            grob
            'side-support-elements
            (ly:grob-list->grob-array staves)))
         grobs))
      (set! evs '())
      (set! grobs '())))))

(ly:register-translator
 Text_mark_engraver 'Text_mark_engraver
 '((events-accepted . (text-mark-event))
   (grobs-created . (TextMark))
   (properties-read . (stavesFound))
   (properties-written . ())
   (description . "Engraves arbitrary textual marks.")))


(define-public Measure_grouping_engraver
  (lambda (ctx)
    (let ((grouping-spanner #f)
          (stop-grouping-moment #f))
      (make-engraver
       ((process-music engraver)
        (let ((now (ly:context-current-moment ctx)))
          (when (zero? (ly:moment-grace now))
            (when (and grouping-spanner
                       (not (ly:moment<? now stop-grouping-moment)))
              (ly:spanner-set-bound!
               grouping-spanner
               RIGHT
               (ly:context-property ctx 'currentMusicalColumn))
              (set! grouping-spanner #f))

            (let*
                ((beat-base (ly:context-property ctx 'beatBase))
                 (measure-position (ly:context-property ctx 'measurePosition)))
              (let loop ((where ZERO-MOMENT)
                         (grouping (ly:context-property ctx 'beatStructure)))
                (when (and (equal? where measure-position)
                           (pair? grouping))
                  (ly:context-schedule-moment
                   ;; make sure the next grouping step will be encountered
                   ;; by engravers (i.e. by this one)
                   ctx
                   (+ now (ly:make-moment (* beat-base (car grouping)))))
                  (if grouping-spanner
                      (ly:programming-error
                       "last grouping-spanner not finished yet")
                      (when (> (car grouping) 1)
                        (set! grouping-spanner (ly:engraver-make-grob
                                                engraver 'MeasureGrouping '()))
                        (ly:spanner-set-bound!
                         grouping-spanner LEFT
                         (ly:context-property ctx 'currentMusicalColumn))
                        (set! stop-grouping-moment
                              (+ now (ly:make-moment
                                      (* beat-base (1- (car grouping))))))
                        (ly:context-schedule-moment ctx stop-grouping-moment)
                        (ly:grob-set-property!
                         grouping-spanner 'style
                         (if (= (car grouping) 3) 'triangle 'bracket))
                        (set! grouping '()))))
                (when (pair? grouping)
                  (loop
                   (+ where (ly:make-moment (* beat-base (car grouping))))
                   (cdr grouping))))))))
       (acknowledgers
        ((note-column-interface engraver grob source-engraver)
         (when grouping-spanner
           (ly:pointer-group-interface::add-grob grouping-spanner
                                                 'side-support-elements
                                                 grob))))
       ((finalize engraver)
        (when grouping-spanner
          (ly:spanner-set-bound!
           grouping-spanner
           RIGHT
           (ly:context-property ctx 'currentMusicalColumn))
          (ly:grob-suicide! grouping-spanner)))))))

(ly:register-translator
 Measure_grouping_engraver 'Measure_grouping_engraver
 '((events-accepted . ())
   (grobs-created . (MeasureGrouping))
   (properties-read . (beatBase
                       beatStructure
                       currentMusicalColumn
                       measurePosition))
   (properties-written . ())
   (description . "Create @code{MeasureGrouping} to indicate beat subdivision.")))


(define (Bend_engraver context)
  (let
      ((stop-moment #f)
       (fall-event #f)
       (fall #f)
       (start-in-grace #f)
       (last-fall #f)
       (note-head #f))
    (define (stop-fall)
      (set! last-fall fall)
      (set! fall #f)
      (set! start-in-grace #f)
      (set! note-head #f)
      (set! fall-event #f))
    (make-engraver
     ((start-translation-timestep engraver)
      (set! last-fall #f)
      (when (and fall
                 (if start-in-grace
                     ;; For falls starting in grace time, compare actual
                     ;; moments to make sure the band spans the full (grace)
                     ;; length of the main note.
                     ;; For falls starting in non-grace time, compare only
                     ;; moment-main's to make sure the fall gets terminated
                     ;; before any grace notes coming before the next note.
                     (not (ly:moment<? (ly:context-current-moment context)
                                       stop-moment))
                     (>= (ly:moment-main (ly:context-current-moment context))
                         (ly:moment-main stop-moment))))
        (stop-fall)))
     (listeners
      ((bend-after-event engraver event #:once)
       (set! fall-event event)))
     ((process-music engraver)
      (when (and fall-event (not fall))
        (set! fall (ly:engraver-make-grob engraver 'BendAfter fall-event))
        (ly:grob-set-property! fall 'delta-position
                               (ly:event-property fall-event 'delta-step))))
     (acknowledgers
      ((note-head-interface engraver grob source-engraver)
       (when fall-event
         (when (and note-head fall)
           (stop-fall))
         (set! note-head grob)
         (let
             ((now (ly:context-current-moment context)))
           (set! start-in-grace (negative? (ly:moment-grace now)))
           (set! stop-moment
                 (ly:moment-add
                  now
                  (ly:event-length (event-cause grob) now)))))))
     ((stop-translation-timestep engraver)
      (when last-fall
        (ly:spanner-set-bound!
         last-fall
         RIGHT
         (if (ly:grob? (ly:context-property context 'currentBarLine))
             ;; don't cross a barline!
             (ly:context-property context 'currentCommandColumn)
             (ly:context-property context 'currentMusicalColumn))))
      (when (and fall
                 (not (ly:grob? (ly:spanner-bound fall LEFT))))
        (ly:spanner-set-bound! fall LEFT note-head)
        (ly:grob-set-parent! fall Y note-head)))
     ((finalize engraver)
      (when last-fall
        (ly:spanner-set-bound!
         last-fall
         RIGHT
         (ly:context-property context 'currentCommandColumn)))))))

(ly:register-translator
 Bend_engraver 'Bend_engraver
 '((events-accepted . (bend-after-event))
   (grobs-created . (BendAfter))
   (properties-read . (currentBarLine currentCommandColumn currentMusicalColumn))
   (properties-written . ())
   (description . "Create fall spanners.")))


(define Tab_tie_follow_engraver
  (lambda (context)
    (let ((ties '())
          (repeat-ties '())
          (tab-note-heads '())
          (left-bound-tab-nhds '())
          (spanners '()))

      (make-engraver
       (acknowledgers
        ((semi-tie-interface this-engraver grob source-engraver)
         (when (positive? (ly:grob-property grob 'head-direction))
           (set! repeat-ties (cons grob repeat-ties))))
        ((spanner-interface this-engraver grob source-engraver)
         (when (grob::has-interface grob 'tie-interface)
           (set! ties (cons grob ties)))
         (when (or (grob::has-interface grob 'slur-interface)
                   (grob::has-interface grob 'glissando-interface))
           (set! spanners (cons grob spanners))))
        ((tab-note-head-interface this-engraver grob source-engraver)
         ;; Only sort TabNoteHead grobs if `tabFullNotation` is not used.
         ;; If `tabFullNotation` is used unset 'after-line-breaking, in order
         ;; to avoid printing transparent and parenthesized.
         (if (ly:context-property context 'tabFullNotation #f)
             (ly:grob-set-property! grob 'after-line-breaking '())
             (begin
               ;; In-chord repeat ties and those at stand-alone note heads are
               ;; in tab-note-head's 'articulations, thus affect tab-note-head
               ;; here, setting the `repeat-tied` sub-property.
               ;; Otherwise tab-note-head may be part of an event-chord with
               ;; \repeatTie in 'elements, thus store and accumulate them and
               ;; check for RepeaTie later
               (let* ((cause (ly:grob-property grob 'cause))
                      (repeat-tie?
                       (event-has-articulation? 'repeat-tie-event cause)))
                 (when repeat-tie?
                   (ly:grob-set-nested-property!
                    grob '(details tied-properties repeat-tied) #t)))
               (set! tab-note-heads (cons grob tab-note-heads))
               ;; accumulate tab-note-heads where a Tie ends
               ;; in `left-bound-tab-nhds`
               (when (pair? ties)
                 (for-each
                  (lambda (tie)
                    (when (equal? grob (ly:spanner-bound tie RIGHT))
                      (set! left-bound-tab-nhds
                            (cons grob left-bound-tab-nhds))))
                  ties))))))

       ((stop-translation-timestep this-engraver)
       ;;;; RepeatTies, attached to an event-chord or stand-alone TabNoteHead.
        ;;
        ;; TODO Stand-alone TabNoteHead are already done in `acknowledgers`,
        ;; should we filter for them?
        ;;
        ;; Equal lengths means, \repeatTie was applied to an
        ;; event-chord or a stand-alone note-head. Set the `repeat-tied`
        ;; sub-property.
        (when (and (pair? repeat-ties) (pair? tab-note-heads)
                   (= (length repeat-ties) (length tab-note-heads)))
          (for-each
           (lambda (tnhd)
             (ly:grob-set-nested-property!
              tnhd '(details tied-properties repeat-tied) #t))
           tab-note-heads))

       ;;;; Ties
        ;;
        ;; Set the `tied` subproperty for TabNoteHeads ending a Tie.
        (when (pair? left-bound-tab-nhds)
          (for-each
           (lambda (grob)
             (ly:grob-set-nested-property! grob
                                           '(details tied-properties tied) #t))
           left-bound-tab-nhds))
        ;; `ties` can not be cleared at this stage, because a Tie may be broken,
        ;; and we are interested in the *final* right bound TabNoteHead.

       ;;;; Slur and Glissando
        ;;
        ;; Set the `span-start` property for TabNoteHeads starting a Slur or
        ;; Glissando
        ;; NB Slur is bound by note-column, Glissando by note-head
        (when (pair? spanners)
          (for-each
           (lambda (sp)
             (let* ((left-bound (ly:spanner-bound sp LEFT))
                    (left-bounds-array
                     (ly:grob-object left-bound 'note-heads #f)))
               (for-each
                (lambda (g)
                  (when (memv g left-bound-tab-nhds)
                    (ly:grob-set-property! g 'span-start #t)))
                (if left-bounds-array
                    (ly:grob-array->list left-bounds-array)
                    (list left-bound)))))
           spanners))

        (set! left-bound-tab-nhds '())
        (set! spanners '())
        (set! tab-note-heads '())
        (set! repeat-ties '()))

       ((finalize trans)
        (set! ties '()))))))

(ly:register-translator
 Tab_tie_follow_engraver 'Tab_tie_follow_engraver
 '((grobs-created . ())
   (events-accepted . ())
   (properties-read . (tabFullNotation))
   (properties-written . ())
   (description . "Adjust @code{TabNoteHead} properties when the
@code{TabNoteHead} holds a @code{RepeatTie}, when a @code{Tie} ends and when a
@code{Slur} or @code{Glissando} starts at a tied @code{TabNoteHead}.")))


(define Horizontal_script_engraver
  (lambda (ctx)
    (let ((raw-scripts '())
          (nhds '())
          (nc #f)
          (stem #f)
          (acc-placement #f)
          (dot-col #f)
          (script-row #f)
          (script-defs (ly:context-property ctx 'scriptDefinitions)))
      (make-engraver
        (acknowledgers
          ((script-interface this-engraver grob source-engraver)
            ;; NB script-interface is currently used in
            ;; AccidentalSuggestion, CaesuraScript, DynamicText,
            ;; MultiMeasureRestScript and Script.
            ;; For setting 'grob-defaults take only Script-grobs
            (when (eq? (grob::name grob) 'Script)
              (let* ((cause (ly:grob-property grob 'cause))
                     (art-type
                       (ly:prob-property cause 'articulation-type)))
                ;; Fill grob-object 'grob-defaults with the relevant entry
                ;; of `script-defs`. Do this for all Script grobs, this also
                ;; makes it easier to restrict other overrides to targeted
                ;; types.
                (ly:grob-set-object!
                  grob 'grob-defaults (assv art-type script-defs))))
            (set! raw-scripts (cons grob raw-scripts)))
          ((script-column-interface this-engraver grob source-engraver)
            (when (eq? (grob::name grob) 'ScriptRow)
              (set! script-row grob)))
          ((note-column-interface this-engraver grob source-engraver)
            (set! nc grob))
          ((note-head-interface this-engraver grob source-engraver)
            (set! nhds (cons grob nhds)))
          ((stem-interface this-engraver grob source-engraver)
            (set! stem grob))
          ((accidental-placement-interface this-engraver grob source-engraver)
            (set! acc-placement grob))
          ((dot-column-interface this-engraver grob source-engraver)
            (set! dot-col grob)))
        ((process-music this-engraver)
          (let ((scripts
                 ;; late filtration supports \tweak
                 (filter
                   (lambda (sc) (eqv? (ly:grob-property sc 'side-axis) X))
                   raw-scripts)))

            ;; Proceed only if script-grobs with side-axis X are found
            (when (pair? scripts)
              (let* ((dots-array (if dot-col (ly:grob-object dot-col 'dots) #f))
                     (dots
                       (if dots-array
                           (ly:grob-array->list dots-array)
                           '())))
                (if script-row
                    ;; If ScriptRow is present, its 'side-support-elements
                    ;; already contains probable Arpeggio, Accidental and
                    ;; AccidentalPlacement grobs. We add dots in order to avoid
                    ;; collisions for Script added at right side of a dotted
                    ;; note.
                    (for-each
                      (lambda (sc)
                        (let* ((side-support-elements
                                (ly:grob-object sc 'side-support-elements '())))
                          (ly:grob-set-object! sc 'side-support-elements
                            (ly:grob-list->grob-array
                              (append
                                dots
                                (ly:grob-array->list side-support-elements))))))
                      scripts)
                    ;; If ScriptRow does not exist yet, we manually add
                    ;; Accidentals, 'conditional-elements (i.e. Arpeggio),
                    ;; Stem, NoteHeads and Dots to 'side-support-elements of
                    ;; the Script.
                    ;; Script_row_engraver may then create a ScriptRow-grob.
                    (let* ((acc-alist
                            (if (ly:grob? acc-placement)
                                (ly:grob-object acc-placement 'accidental-grobs)
                                #f))
                           (accs
                            (if acc-alist
                                (map cadr acc-alist)
                                '()))
                           (conditional-elts-array
                            (if nc
                                (ly:grob-object nc 'conditional-elements #f)
                                #f))
                           (conditional-elts
                            (if conditional-elts-array
                                (ly:grob-array->list conditional-elts-array)
                                '())))
                      (for-each
                        (lambda (sc)
                          (ly:grob-set-object! sc 'side-support-elements
                            (ly:grob-list->grob-array
                              (append
                                (list stem)
                                conditional-elts
                                accs
                                nhds
                                dots))))
                        scripts)))
                ;; Set Script's Y-parent to NoteHead
                ;;
                ;; Script applied to a stand-alone note-head or inside of an
                ;; event-chord has already note-head as X- or Y-parent.
                ;; Catch it.
                ;; Script applied to an event-chord has note-column as
                ;; X-parent. Best we can do is to catch the first note-head.
                ;; This may not fullfill what a user has in mind, better to
                ;; use in-chord script then.
                (for-each
                  (lambda (sc)
                    (let* ((par-X (ly:grob-parent sc X))
                           (par-Y (ly:grob-parent sc Y))
                           (new-par-Y
                             (cond
                               ((and (ly:grob? par-X)
                                     (grob::has-interface
                                       par-X 'note-column-interface))
                                 (car
                                   (ly:grob-array->list
                                     (ly:grob-object par-X 'note-heads))))
                               ((and (ly:grob? par-X)
                                     (grob::has-interface
                                       par-X 'note-head-interface))
                                 par-X)
                               ((and (ly:grob? par-Y)
                                     (grob::has-interface
                                       par-Y 'note-head-interface))
                                     par-Y)
                               (else
                                 (ly:warning
                                   "Need NoteHead as parent for Script.")))))
                      (ly:grob-set-parent! sc Y new-par-Y)))
                  scripts)))

            (set! raw-scripts '())
            (set! nhds '())
            (set! nc #f)
            (set! stem #f)
            (set! acc-placement #f)
            (set! dot-col #f)
            (set! script-row #f)))))))

(ly:register-translator
 Horizontal_script_engraver 'Horizontal_script_engraver
 '((events-accepted . ())
   (grobs-created . ())
   (properties-read . (scriptDefinitions))
   (properties-written . ())
   (description . "Aligns @code{Script} horizontally")))
