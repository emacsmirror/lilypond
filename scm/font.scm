;;;; font.scm -- construct font trees
;;;;
;;;;  source file of the GNU LilyPond music typesetter
;;;; 
;;;; (c) 2004 Han-Wen Nienhuys <hanwen@xs4all.nl>

;; As an excercise, do it with records.
;; Should use GOOPS, really.

;; TODO:
;;
;; lookup-font should be written in  C.
;;
;; should dump tree to .texi as internal documentation
;; 
;; * should extract design sizes from fonts: fonts should 
;; be read off the disk, on demand, something like:
;;  
;; cmr -> ((font-load "cmr6") (font-load "cmr8")  .. )
;;

(define-class <Font-tree-element>
  ())


(define-class <Font-tree-leaf> (<Font-tree-element>)
  (default-size #:init-keyword #:default-size)
  (size-vector  #:init-keyword #:size-vector))

(define-class <Font-tree-node> (<Font-tree-element>)
  (qualifier #:init-keyword #:qualifier  #:accessor font-qualifier)
  (default #:init-keyword #:default #:accessor font-default)
  (children #:init-keyword #:children #:accessor font-children))

(define (make-font-tree-leaf size size-font-vector)
  (make <Font-tree-leaf> #:default-size size #:size-vector size-font-vector))

(define (make-font-tree-node
	 qualifier default)
  (make <Font-tree-node>
    #:qualifier qualifier
    #:default default 
    #:children (make-hash-table 11)))

(define-method (display (leaf <Font-tree-leaf>) port)
  (map (lambda (x) (display x port))
       (list
	"Font-size-family: \n"
	(slot-ref leaf 'default-size) 
	(slot-ref leaf 'size-vector) )))

(define-method (display (node <Font-tree-node>) port)

  (map
   (lambda (x)
     (display x port))

   (list
    "Font_node { \nqual: "
    (font-qualifier node)
    "(def: "
    (font-default node)
    ") {\n"))
  (for-each 
   (lambda (x)
     (display "\n")
     (display (car x) port)
     (display "=" port)
     (display (cdr x) port))
   (hash-table->alist (font-children node)))
  (display "} } \n"))


(define default-qualifier-order
  '(font-encoding font-family font-shape font-series))

(define-method (add-font (node <Font-tree-node>) fprops size-family)
  (define (assoc-delete key alist)
    (assoc-remove! (list-copy alist) key))
  (define (make-node fprops size-family)
    (if (null? fprops)
	(make-font-tree-leaf (car size-family) (cdr size-family))
	(let*
	    ((qual (next-qualifier default-qualifier-order fprops)))
	  (make-font-tree-node qual
			       (assoc-get qual fprops)))))

  (define (next-qualifier order props)
    (cond
     ((and (null? props) (null? order))
      #f)
     ((null? props) (car order))
     ((null? order) (caar props))
     (else
      (if (assoc-get (car order) props)
	  (car order)
	  (next-qualifier (cdr order) props)))))


  (let*
      ((q (font-qualifier node))
       (d (font-default node))
       (v (assoc-get q fprops d))
       (new-fprops (assoc-delete q fprops))
       (child (hashq-ref (slot-ref node 'children)
			 v #f)))


    (if (not child)
	(begin
	  (set! child (make-node new-fprops size-family))
	  (hashq-set! (slot-ref node 'children) v child)))
    (if (pair? new-fprops)
	(add-font child new-fprops size-family))))


(define-method (add-font (node <Font-tree-leaf>) fprops size-family)
  (throw "must add to node, not leaf"))


(define-method (g-lookup-font (node <Font-tree-node>) alist-chain)
  (let*
      ((qual (font-qualifier node))
       (def (font-default node))
       (val (chain-assoc-get qual alist-chain def))
       (desired-child (hashq-ref (font-children node) val)))

    (if desired-child
	(g-lookup-font desired-child alist-chain)
	(g-lookup-font (hashq-ref (font-children node) def) alist-chain))))


(define-method (g-lookup-font (node <Font-tree-leaf>) alist-chain)
  node)

;; two step call  is handy for debugging.
(define (lookup-font node alist-chain)
  (g-lookup-font node alist-chain))

					;
					; Each size family is a vector of fonts, loaded with a delay.
					; The vector should be sorted according to ascending design size.
					;

(define-public (add-music-fonts node factor)
  (for-each
   (lambda (x)
     (add-font node
	       (list (cons 'font-encoding (car x)))
	       (cons (* factor (cadr x))
		     (caddr x))))
   `(
     (fetaNumber 14
		 #(
		  ,(delay  (ly:font-load "bigcheese11"))
		  ,(delay  (ly:font-load "bigcheese13"))
		  ,(delay  (ly:font-load "bigcheese14"))
		  ,(delay  (ly:font-load "bigcheese16"))		  
		  ,(delay  (ly:font-load "bigcheese18"))
		  ,(delay  (ly:font-load "bigcheese20"))		  
		  ,(delay  (ly:font-load "bigcheese23"))		  
		  ,(delay  (ly:font-load "bigcheese26"))))
     
     (fetaDynamic 20.0  #(
		  ,(delay  (ly:font-load "bigcheese11"))
		  ,(delay  (ly:font-load "bigcheese13"))		  
		  ,(delay  (ly:font-load "bigcheese14"))
		  ,(delay  (ly:font-load "bigcheese16"))		  
		  ,(delay  (ly:font-load "bigcheese18"))
		  ,(delay  (ly:font-load "bigcheese20"))		  
		  ,(delay  (ly:font-load "bigcheese23"))		  
		  ,(delay  (ly:font-load "bigcheese26"))))
			  
     (fetaMusic 20.0
		#(
		  ,(delay  (ly:font-load "bigcheese11"))
		  ,(delay  (ly:font-load "bigcheese13"))		  
		  ,(delay  (ly:font-load "bigcheese14"))
		  ,(delay  (ly:font-load "bigcheese16"))		  
		  ,(delay  (ly:font-load "bigcheese18"))
		  ,(delay  (ly:font-load "bigcheese20"))		  
		  ,(delay  (ly:font-load "bigcheese23"))		  
		  ,(delay  (ly:font-load "bigcheese26"))))

     (fetaBraces 15 #(,(delay
			  (ly:font-load "aybabtu")))))))

(define-public (add-cmr-fonts node factor)
  (add-font node '((font-encoding . TeX-math))
	    `(,(* factor 10) . #(,(delay (ly:font-load "msam10")))))
  (for-each
   (lambda (x)
     (add-font node `((font-encoding . TeX-text)
		      (font-series . ,(vector-ref (car x) 2))
		      (font-shape . ,(vector-ref (car x) 1))
		      (font-family . ,(vector-ref (car x) 0)))
	       (cons (* factor (cadr x))
		     (cddr x))))
   `((#(roman upright medium) 
      . (10.0 . #(,(delay (ly:font-load "cmr6"))
		  ,(delay (ly:font-load "cmr8")) 
		  ,(delay (ly:font-load "cmr10"))
		  ,(delay (ly:font-load "cmr17")))))
     (#(roman upright bold) 
      . (10.0 . #(,(delay (ly:font-load "cmbx6"))
		  ,(delay (ly:font-load "cmbx8"))
		  ,(delay (ly:font-load "cmbx10"))
		  ,(delay (ly:font-load "cmbx12")))))
     (#(roman italic medium) 
      . (10.0 . #(,(delay (ly:font-load "cmti7"))
		  ,(delay (ly:font-load "cmti10"))
		  ,(delay (ly:font-load "cmti12")))))
     (#(roman italic bold) 
      . (10.0 . #(,(delay (ly:font-load "cmbxti8"))
		  ,(delay (ly:font-load "cmbxti10"))
		  ,(delay (ly:font-load "cmbxti14")))))
     (#(roman caps medium) 
      . (10.0 . #(,(delay (ly:font-load "cmcsc10")))))
     (#(roman upright bold-narrow ) 
      . (10.0 . #(,(delay (ly:font-load "cmb10")))))
     (#(sans upright medium) 
      . (10.0  . #(,(delay (ly:font-load "cmss8"))
		   ,(delay (ly:font-load "cmss10"))
		   ,(delay (ly:font-load "cmss12"))
		   ,(delay (ly:font-load "cmss17")))))
     (#(typewriter upright medium) 
      . (10.0 . #(,(delay (ly:font-load "cmtt8"))
		  ,(delay (ly:font-load "cmtt10"))
		  ,(delay (ly:font-load "cmtt12"))))))))

;; Debian lmodern font support.
(define-public (add-cork-lm-fonts node factor)
  (for-each
   (lambda (x)
     (add-font node `((font-encoding . cork-lm)
		      (font-series . ,(vector-ref (car x) 2))
		      (font-shape . ,(vector-ref (car x) 1))
		      (font-family . ,(vector-ref (car x) 0)))
	       (cons (* factor (cadr x)) (cddr x))))
   `((#(roman upright medium) 
      . (10.0 . #(,(delay (ly:font-load "lmr6"))
		  ,(delay (ly:font-load "lmr8"))
		  ,(delay (ly:font-load "lmr10"))
		  ,(delay (ly:font-load "lmr17")))))
     (#(roman upright bold) 
      . (10.0 . #(,(delay (ly:font-load "lmbx6"))
		  ,(delay (ly:font-load "lmbx8"))
		  ,(delay (ly:font-load "lmbx10"))
		  ,(delay (ly:font-load "lmbx12")))))
     (#(roman italic medium) 
      . (10.0 . #(,(delay (ly:font-load "lmri7"))
		  ,(delay (ly:font-load "lmri10"))
		  ,(delay (ly:font-load "lmri12")))))
     (#(roman italic bold)
      . (10.0 . #(,(delay (ly:font-load "lmbxi10")))))
     (#(roman caps medium)
      . (10.0 . #(,(delay (ly:font-load "lmcsc10")))))
     (#(roman upright bold-narrow ) 
      . (10.0 . #(,(delay (ly:font-load "lmb10")))))
     (#(sans upright medium) 
      . (10.0  . #(,(delay (ly:font-load "lmss8"))
		   ,(delay (ly:font-load "lmss10"))
		   ,(delay (ly:font-load "lmss12"))
		   ,(delay (ly:font-load "lmss17")))))
     (#(sans upright bold) 
      . (10.0  . #(,(delay (ly:font-load "lmssbx10")))))

     (#(typewriter upright medium) 
      . (10.0 . #(,(delay (ly:font-load "lmtt8"))
		  ,(delay (ly:font-load "lmtt10"))
		  ,(delay (ly:font-load "lmtt12"))))))))

;; ec-fonts-mftraced font support.
(define-public (add-ec-fonts node factor)
  (for-each
   (lambda (x) (add-font node
			 `((font-encoding . Extended-TeX-Font-Encoding---Latin)
			   (font-series . ,(vector-ref (car x) 2))
			   (font-shape . ,(vector-ref (car x) 1))
			   (font-family . ,(vector-ref (car x) 0)))
			 (cons (* factor (cadr x)) (cddr x))))

   `((#(roman upright medium) 
      . (10.0 . #(,(delay (ly:font-load "ecrm6"))
		  ,(delay (ly:font-load "ecrm8"))
		  ,(delay (ly:font-load "ecrm10"))
		  ,(delay (ly:font-load "ecrm17")))))
     (#(roman upright bold) 
      . (10.0 . #(,(delay (ly:font-load "ecbx6"))
		  ,(delay (ly:font-load "ecbx8"))
		  ,(delay (ly:font-load "ecbx10"))
		  ,(delay (ly:font-load "ecbx12")))))
     (#(roman italic medium) 
      . (10.0 . #(,(delay (ly:font-load "ecti7"))
		  ,(delay (ly:font-load "ecti10"))
		  ,(delay (ly:font-load "ecti12")))))
     (#(roman italic bold) 
      . (10.0 . #(,(delay (ly:font-load "ecbi8"))
		  ,(delay (ly:font-load "ecbi10"))
		  ,(delay (ly:font-load "ecbi14")))))
     (#(roman caps medium) 
      . (10.0 . #(,(delay (ly:font-load "eccc10")))))
     (#(roman slanted-caps medium) 
      . (10.0 . #(,(delay (ly:font-load "ecsc10")))))
     (#(roman upright bold-narrow ) 
      . (10.0 . #(,(delay (ly:font-load "ecrb10")))))
     (#(sans upright medium) 
      . (10.0  . #(,(delay (ly:font-load "ecss8"))
		   ,(delay (ly:font-load "ecss10"))
		   ,(delay (ly:font-load "ecss12"))
		   ,(delay (ly:font-load "ecss17")))))
     (#(typewriter upright medium) 
      . (10.0 . #(,(delay (ly:font-load "ectt8"))
		  ,(delay (ly:font-load "ectt10"))
		  ,(delay (ly:font-load "ectt12"))))))))

;; (display (make-font-tree 1.0))

;; Century Schoolbook fonts file names on Debian/Sid
(define-public (add-century-schoolbook-fonts node factor)
  (add-font node
	    '((font-family . roman)
	      (font-shape . upright)
	      (font-series . medium)
	      (font-encoding . latin1))
	    `(10.0 . #(,(delay (ly:font-load "uncr8a")))))
  (add-font node
	    '((font-family . roman)
	      (font-shape . italic)
	      (font-series . medium)
	      (font-encoding . latin1))
	    `(10.0 . #(,(delay (ly:font-load "uncri8a")))))
  (add-font node
	    '((font-family . roman)
	      (font-shape . upright)
	      (font-series . bold)
	      (font-encoding . latin1))
	    `(10.0 . #(,(delay (ly:font-load "uncb8a")))))
  (add-font node
	    '((font-family . roman)
	      (font-shape . italic)
	      (font-series . bold)
	      (font-encoding . latin1))
	    `(10.0 . #(,(delay (ly:font-load "uncbi8a"))))))

(define-public (make-cmr-tree factor)
  (let ((n (make-font-tree-node 'font-encoding 'fetaMusic)))
    (add-music-fonts n factor)
    (add-cmr-fonts n factor)
    (if (ly:kpathsea-find-file "lmr10.pfb")
	(add-cork-lm-fonts n factor))
    (if (ly:kpathsea-find-file "ecrm10.pfa")
	(add-ec-fonts n factor))
    n))

(define-public (make-century-schoolbook-tree factor)
  (let ((n (make-font-tree-node 'font-encoding 'fetaMusic)))
    (add-music-fonts n factor)
    (add-century-schoolbook-fonts n factor)
    n))

(define-public (magstep x)
  (exp (* (/ x 6) (log 2))))
