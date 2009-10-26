;;;; editor.scm --
;;;;
;;;;  source file of the GNU LilyPond music typesetter
;;;; 
;;;; (c) 2005--2009 Jan Nieuwenhuizen <janneke@gnu.org>

(define-module (scm editor))

;; Also for standalone use, so cannot include any lily modules.
(use-modules
 (ice-9 regex)
 (srfi srfi-13)
 (srfi srfi-14))

(define PLATFORM
  (string->symbol
   (string-downcase
    (car (string-tokenize (vector-ref (uname) 0) char-set:letter)))))

(define (get-editor)
  (or (getenv "LYEDITOR")
      (getenv "XEDITOR")
      (getenv "EDITOR")

      ;; FIXME: how are default/preferred editors specified on
      ;; different platforms?
      (case PLATFORM
	((windows) "lilypad")
	(else
	 "emacs"))))

(define editor-command-template-alist
  '(("emacs" .  "emacsclient --no-wait +%(line)s:%(column)s %(file)s || (emacs +%(line)s:%(column)s %(file)s&)")
    ("gvim" . "gvim --remote +:%(line)s:norm%(column)s %(file)s")
    ("uedit32" . "uedit32 %(file)s -l%(line)s -c%(char)s")
    ("nedit" . "nc -noask +%(line)s %(file)s")
    ("gedit" . "gedit +%(line)s %(file)s")
    ("jedit" . "jedit -reuseview %(file)s +line:%(line)s")
    ("syn" . "syn -line %(line)s -col %(char)s %(file)s")
    ("lilypad" . "lilypad +%(line)s:%(char)s %(file)s")))

(define (get-command-template alist editor)
  (define (get-command-template-helper)
    (if (null? alist)
	(if (string-match "%\\(file\\)s" editor)
	    editor
	    (string-append editor " %(file)s"))
	(if (string-match (caar alist) editor)
	    (cdar alist)
	    (get-command-template (cdr alist) editor))))
  (if (string-match "%\\(file\\)s" editor)
      editor
      (get-command-template-helper)))

(define (re-sub re sub string)
  (regexp-substitute/global #f re string 'pre sub 'post))

(define (slashify x)
 (if (string-index x #\/)
     x
     (re-sub "\\\\" "/" x)))

(define-public (get-editor-command file-name line char column)
  (let* ((editor (get-editor))
	 (template (get-command-template editor-command-template-alist editor))
	 (command
	  (re-sub "%\\(file\\)s" (format #f "~S" file-name)
		  (re-sub "%\\(line\\)s" (format #f "~a" line)
			  (re-sub "%\\(char\\)s" (format #f "~a" char)
				  (re-sub
				   "%\\(column\\)s" (format #f "~a" column)
				   (slashify template)))))))
    command))
