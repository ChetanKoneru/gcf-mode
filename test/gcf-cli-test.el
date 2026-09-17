;;; gcf-cli-test.el --- Tests for gcf-cli -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is not part of GNU Emacs.

;;; Commentary:

;; These tests use a tiny executable stub, so they do not require gcf-python.

;;; Code:

(require 'ert)
(require 'gcf-cli)

(defvar gcf-cli-test--stub-script nil)

(defun gcf-cli-test--make-stub (body)
  "Create an executable gcf CLI stub containing BODY.
Return its file name."
  (let ((file (make-temp-file "gcf-cli-stub-")))
    (with-temp-file file
      (insert "#!/bin/sh\nset -eu\n" body "\n"))
    (set-file-modes file #o700)
    (push file gcf-cli-test--stub-script)
    file))

(defmacro gcf-cli-test-with-stub (body &rest forms)
  "Evaluate FORMS with the gcf executable replaced by a shell stub BODY."
  (declare (indent 1) (debug (sexp body)))
  `(let ((gcf-cli-test--stub-script
          (cons (gcf-cli-test--make-stub ,body)
                gcf-cli-test--stub-script)))
     (unwind-protect
         (let ((gcf-cli-executable (car gcf-cli-test--stub-script)))
           ,@forms)
       (dolist (file gcf-cli-test--stub-script)
         (ignore-errors (delete-file file))))))

(ert-deftest gcf-cli-encode-replaces-whole-buffer ()
  "JSON-to-GCF converts the whole buffer with the generic subcommand."
  (gcf-cli-test-with-stub
      "case \"$1\" in\n  encode-generic) printf 'ENCODED:'; cat ;;\n  *) exit 99 ;;\nesac"
    (with-temp-buffer
      (insert "{\"answer\":42}")
      (gcf-cli-json-to-gcf)
      (should (equal (buffer-string) "ENCODED:{\"answer\":42}")))))

(ert-deftest gcf-cli-decode-replaces-active-region-and-preserves-point ()
  "GCF-to-JSON changes only the active region and keeps point in it."
  (gcf-cli-test-with-stub
      "case \"$1\" in\n  decode-generic) printf 'JSON:'; cat ;;\n  *) exit 99 ;;\nesac"
    (with-temp-buffer
      (insert "before\nGCF DATA\nafter")
      (goto-char (+ (point-min) 7))
      (set-mark (+ (point) 8))
      (activate-mark)
      (let ((original-point (point))
            (beg (region-beginning)))
        (gcf-cli-gcf-to-json)
        (should (equal (buffer-string) "before\nJSON:GCF DATA\nafter"))
        (should (= (point) (+ beg (min (- original-point beg)
                                      (- (point-max) beg)))))
        (should (equal (buffer-substring (- (point-max) 5) (point-max))
                       "after"))))))

(ert-deftest gcf-cli-failure-preserves-buffer-and-reports-stderr ()
  "A failed conversion leaves the source text unchanged and reports stderr."
  (gcf-cli-test-with-stub
      "echo 'invalid payload' >&2\nprintf 'partial output'\nexit 7"
    (with-temp-buffer
      (insert "source remains untouched")
      (let ((error-data (should-error (gcf-cli-json-to-gcf)
                                      :type 'user-error)))
        (should (string-match-p "invalid payload"
                                (error-message-string error-data))))
      (should (equal (buffer-string) "source remains untouched")))))

(ert-deftest gcf-cli-missing-executable-preserves-buffer ()
  "A missing executable reports an error without changing source text."
  (let ((gcf-cli-executable "gcf-cli-test-command-does-not-exist"))
    (with-temp-buffer
      (insert "unchanged")
      (should-error (gcf-cli-json-to-gcf) :type 'user-error)
      (should (equal (buffer-string) "unchanged")))))

;;; gcf-cli-test.el ends here
