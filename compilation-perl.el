;;; compilation-perl.el --- extra error regexps for Perl

;; Copyright 2007, 2008 Kevin Ryde

;; Author: Kevin Ryde <user42@zip.com.au>
;; Version: 5
;; Keywords: processes
;; URL: http://www.geocities.com/user42_kevin/compilation/index.html
;; EmacsWiki: PerlLanguage

;; compilation-perl.el is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as published
;; by the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; compilation-perl.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
;; Public License for more details.
;;
;; You can get a copy of the GNU General Public License online at
;; <http://www.gnu.org/licenses>.


;;; Commentary:

;; This is a spot of code adding `compilation-error-regexp-alist' patterns
;; for Perl
;;
;;     * die messages with "during global destruction" suffix
;;     * Pod::Checker module, including its podchecker program
;;     * Pod::Simple module
;;     * Test module
;;     * Test::Harness module
;;     * Test::Builder module and its users like Test::More
;;     * xsubpp program
;;
;; And toning down Emacs 22 "gnu" pattern for the benefit of
;;
;;     * Glib::Log module, shared by all of Gtk2-Perl
;;
;; Emacs already has patterns for perl's normal compile and run errors, but
;; the above are all a bit different.

;;; Install:

;; Put compilation-perl.el somewhere in your `load-path', and in .emacs put
;;
;;     (eval-after-load "compile" '(require 'compilation-perl))
;;
;; There's an autoload cookie below for this, if you're brave enough to use
;; `update-file-autoloads' and friends.

;;; Emacsen:

;; Works in Emacs 22, Emacs 21, and XEmacs 21.

;;; History:

;; Version 1 - the first version
;; Version 2 - fixes for Test and Test::Harness
;; Version 3 - add xsubpp
;; Version 4 - add "during global destruction"
;; Version 5 - add Test::Builder and a hack for Glib::Log
;; Version 6 - add Pod::Simple "complain_stderr"


;;; Code:

;;;###autoload (eval-after-load "compile" '(require 'compilation-perl))

(require 'compile)

(dolist
    (elem
     '(;; global destruction messages, eg.
       ;;
       ;;    (in cleanup) something bad at foo.pl line 3 during global destruction.
       ;;
       ;; This is the pattern already in Emacs, but adding "during
       ;; global destruction" allowed at the end.  Emacs 23 (or
       ;; whatever it's going to be) is going to have this itself.
       ;;
       (compilation-perl--global-destruction
        " at \\([^ \n]+\\) line \\([0-9]+\\) during global destruction\\.$"
        1 2)

       ;; Pod::Checker module messages, as from the podchecker program.
       ;; The style is per the Pod::Checker::poderror() function, eg.
       ;;
       ;; *** ERROR: Spurious text after =cut at line 193 in file foo.pm
       ;;
       ;; Plus end_pod() can give "at line EOF" instead of a number, so
       ;; for that match "on line N" which is the originating spot, eg.
       ;;
       ;; *** ERROR: =over on line 37 without closing =back at line EOF in file bar.pm
       ;;
       ;; Plus command() can give both "on line N" and "at line N".  The
       ;; latter is desired and is matched because the .* is greedy.
       ;;
       ;; *** ERROR: =over on line 1 without closing =back (at head1) at line 3 in file x.pod
       ;;
       (compilation-perl--Pod::Checker
        ;;            1          2                  3                  4            5                 6
        "^\\*\\*\\* \\(ERROR\\|\\(WARNING\\)\\).* \\(at\\|on\\) line \\([0-9]+\\) \\(.* \\)?in file \\([^ \t\n]+\\)"
        6 4 nil (2))

       ;; Pod::Simple module messages, if you enable its "complain_stderr"
       ;; setting.  Style per its _complain_warn() function, eg.
       ;;
       ;; foo.pod around line 9: Unknown directive: =fsdkfsd
       ;;
       ;; The pattern "around line N:" is probably close enough to
       ;; unambiguous.  Not fantastic, but hopefully ok in practice.
       ;;
       (compilation-perl--Pod::Simple
        "^\\([^ \t\r\n]+\\) around line \\([0-9]+\\): " 1 2 nil)

       ;; Test module error messages.
       ;; Style per the Test::ok() function "$context", eg. plain boolean,
       ;;
       ;; # Failed test 1 in foo.t at line 6
       ;;
       ;; Or when comparing got/want values,
       ;; # Test 2 got: "xx" (t-compilation-perl-2.t at line 10)
       ;;
       ;; And under Test::Harness they're preceded by progress stuff with
       ;; \r and "NOK",
       ;; ... NOK 1# Test 1 got: "1234" (t/foo.t at line 46)
       ;; ... NOK 1# Failed test 1 in foo.t at line 8
       ;;
       (compilation-perl--Test
        "^\\(.*NOK.*\\)?# Failed test [0-9]+ in \\([^ \t\r\n]+\\) at line \\([0-9]+\\)"
        2 3)
       (compilation-perl--Test2
        "^\\(.*NOK.*\\)?# Test [0-9]+ got:.* (\\([^ \t\r\n]+\\) at line \\([0-9]+\\))"
        2 3)

       ;; Test::Builder fail messages, as used for instance by Test::More.
       ;; Style per the ok() function in Builder.pm, and the # as added
       ;; by diag() in that file.
       ;;
       ;; A message "Failed (TODO) test" is deliberately not matched,
       ;; since a test flagged as todo isn't an error.  If you want to
       ;; match that you can slip a "\\( (TODO)\\)?" into the pattern
       ;; (perhaps classing it as a warning).
       ;;
       ;; with no test name,
       ;; #   Failed test in foo.t at line 5.
       ;;
       ;; with a test name,
       ;; #   Failed test 'my name'
       ;; #   in foo.t at line 5.
       ;;
       ;; or a multi-line name,
       ;; #   Failed test 'my name
       ;; #   blah
       ;; #   '
       ;; #   in foo.t at line 5.
       ;;
       (compilation-perl--Test::Builder
        "^# +Failed test.*?\\(\n#.*?\\)*? +in \\([^ \t\r\n]+\\) at line \\([0-9]+\\)"
        2 3)

       ;; xsubpp program messages
       ;; Style per the Warn() function in the xsubpp script, eg.
       ;;
       ;;  Warning: #if without #endif in this function in Foo.xs, line 12
       ;;
       ;;  Error: `endif' with no matching `if' in Foo.xs, line 25
       ;;
       ;;  Code is not inside a function (maybe last function was ended by a blank line  followed by a statement on column one?) in Foo.xs, line 19
       ;;
       ;; The same style "in FILENAME, line NNN" is used in a couple of
       ;; other places too.  The "Warning:" or "Error:" bit is not
       ;; always present, treat messages with neither as errors.
       ;;
       (compilation-perl--xsubpp
        "^\\(Warning:\\)?.* in \\([^ \t\n]+\\), line \\([0-9]+\\)"
        2 3 nil (1))))

  (cond ((boundp 'compilation-error-regexp-systems-list)
         ;; xemacs21
         (add-to-list 'compilation-error-regexp-alist-alist
                      (list (car elem) ;; key
                            (list (nth 1 elem)    ;; regexp
                                  (nth 2 elem)    ;; file subexp
                                  (nth 3 elem)    ;; line subexp
                                  (nth 4 elem)))) ;; column subexp
         (compilation-build-compilation-error-regexp-alist))

        ((boundp 'compilation-error-regexp-alist-alist)
         ;; emacs22
         (add-to-list 'compilation-error-regexp-alist-alist elem)
         (add-to-list 'compilation-error-regexp-alist (car elem)))

        (t
         ;; emacs21
         (add-to-list 'compilation-error-regexp-alist
                      (list (nth 1 elem) ;; regexp
                            (nth 2 elem) ;; file subexp
                            (nth 3 elem) ;; line subexp
                            (nth 4 elem) ;; column subexp
                            )))))

;; The following is a nasty hack to the "gnu" pattern in Emacs 22.
;; On a perl Glib::Log message like the following, per GLog.xs
;; gperl_log_handler(),
;;
;;     GLib-GObject-WARNING **: /build/buildd/glib2.0-2.14.5/gobject/gsignal.c:1741: instance `0x8206790' has no handler with id `1234' at t-compilation-perl-gtk.pl line 3.
;;
;; the "gnu" pattern of Emacs 22 takes the whole of
;;
;;     GLib-GObject-WARNING **: /build/buildd/glib2.0-2.14.5/gobject/gsignal.c
;;
;; as the filename.  Firstly of course the "...-WARNING" bit is not
;; right and secondly it's unhelpful here to match gsignal.c when the
;; perl filename at the end is the interesting bit.  That latter is
;; matched by the ordinary perl patterns, but `next-error' goes to the
;; first on the line, and so asks where the supposed leading filename
;; is.
;;
;; A new "compilation-perl--munged-gnu" pattern is added to
;; compilation-error-regexp-alist-alist, disallowing "*" in the
;; filename part.  It should be very rare to have "*" in a filename so
;; this won't hurt the things the gnu pattern should normally match.
;;
;; This new pattern is enabled by removing the "gnu" symbol from
;; compilation-error-regexp-alist, replacing it with the new
;; "compilation-perl--munged-gnu".  The actual "gnu" regexp in
;; compilation-error-regexp-alist-alist is unchanged, so if you need
;; the original in some particular mode it's just a matter of the
;; symbols selected in compilation-error-regexp-alist.
;;
;; In Emacs 21 and XEmacs 21 the gnu entry has a tighter filename
;; pattern and already doesn't match "GLib-GObject-WARNING **:...", so
;; nothing needs to be done there.
;;
(when (member 'gnu compilation-error-regexp-alist) ;; only Emacs 22
  (let* ((gnu-elem (assoc 'gnu compilation-error-regexp-alist-alist))
         (regexp   (cadr gnu-elem)))
    (when ;; only for the form present in Emacs 22.1
        (string-match
         (regexp-quote "\\([0-9]*[^0-9\n]\\(?:[^\n ]\\| [^-\n]\\)*?\\):")
         regexp)
      (setq regexp (replace-match
                    "\\([0-9]*[^0-9\n]\\(?:[^*\n ]\\| [^-*\n]\\)*?\\):"
                    t t ;; fixedcase and literal
                    regexp))
      (let ((new-elem (copy-tree gnu-elem)))
        (setcar new-elem 'compilation-perl--munged-gnu)
        (setcar (cdr new-elem) regexp)
        (add-to-list 'compilation-error-regexp-alist-alist new-elem)

        (setq compilation-error-regexp-alist
              (remove 'gnu compilation-error-regexp-alist))
        (add-to-list 'compilation-error-regexp-alist
                     'compilation-perl--munged-gnu)))))

(provide 'compilation-perl)

;;; compilation-perl.el ends here
