;;; gcf-cli.el --- CLI conversion support for gcf-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Chetan Koneru <kchetan.hadoop@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, tree-sitter
;; URL: https://github.com/ChetanKoneru/gcf-mode

;; This file is not part of GNU Emacs.
;;
;;; License:
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This library is a lazily loaded part of the gcf-mode package.  It provides
;; safe, synchronous buffer and region commands backed by the `gcf' executable
;; installed by the gcf-python package.  The generic profile is used because
;; it accepts arbitrary JSON values:
;; `gcf encode-generic' and `gcf decode-generic' both read stdin and write
;; stdout.

;;; Code:

(require 'subr-x)

(defgroup gcf-cli nil
  "Convert JSON and GCF using the gcf-python command-line interface."
  :group 'gcf
  :prefix "gcf-cli-")

(defcustom gcf-cli-executable "gcf"
  "Name or absolute file name of the gcf-python executable."
  :type 'string
  :group 'gcf-cli)

(defcustom gcf-cli-arguments nil
  "Additional arguments passed to gcf before its conversion command.

Arguments are passed directly to the process and are never interpreted by a
shell.  This can be useful for a wrapper executable or global CLI options."
  :type '(repeat string)
  :group 'gcf-cli)

(defcustom gcf-cli-encode-command "encode-generic"
  "Subcommand used to convert JSON input to generic-profile GCF."
  :type 'string
  :group 'gcf-cli)

(defcustom gcf-cli-decode-command "decode-generic"
  "Subcommand used to convert generic-profile GCF input to JSON."
  :type 'string
  :group 'gcf-cli)

(defun gcf-cli--error-text (file)
  "Return trimmed text from stderr FILE, or nil when it is empty."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents-literally file)
      (let ((text (string-trim (buffer-string))))
        (unless (string-empty-p text)
          text)))))

(defun gcf-cli--run (command input)
  "Run gcf COMMAND on INPUT and return its stdout as a string.

COMMAND is passed as one argument after `gcf-cli-arguments'.  INPUT is sent
on standard input.  A non-zero exit status, a signal, or an inability to
start the executable signals a `user-error'."
  (let ((input-file (make-temp-file "gcf-cli-input-"))
        (error-file (make-temp-file "gcf-cli-error-"))
        (output-buffer (generate-new-buffer " *gcf-cli-output*"))
        status launch-error)
    (unwind-protect
        (progn
          (with-temp-file input-file
            (insert input))
          (condition-case err
              (let ((coding-system-for-read 'utf-8-unix)
                    (coding-system-for-write 'utf-8-unix))
                (setq status
                      (apply #'process-file
                             gcf-cli-executable
                             input-file
                             (list output-buffer error-file)
                             nil
                             (append gcf-cli-arguments (list command)))))
            (file-missing (setq launch-error err))
            (file-error (setq launch-error err)))
          (if launch-error
              (user-error "Unable to run %s: %s"
                          gcf-cli-executable
                          (error-message-string launch-error))
            (if (and (integerp status) (zerop status))
                (with-current-buffer output-buffer
                  (buffer-string))
              (let ((diagnostic (gcf-cli--error-text error-file)))
                (user-error "GCF %s failed%s"
                            command
                            (if diagnostic
                                (format ": %s" diagnostic)
                              (if (integerp status)
                                  (format " (exit status %d)" status)
                                (format " (%s)" status))))))))
      (when (buffer-live-p output-buffer)
        (kill-buffer output-buffer))
      (ignore-errors (delete-file input-file))
      (ignore-errors (delete-file error-file)))))

(defun gcf-cli--bounds ()
  "Return the active region bounds, or the entire buffer bounds."
  (if (use-region-p)
      (cons (region-beginning) (region-end))
    (cons (point-min) (point-max))))

(defun gcf-cli--replace-bounds (bounds text)
  "Replace BOUNDS with TEXT and preserve point as reasonably as possible."
  (let* ((beg (car bounds))
         (end (cdr bounds))
         (old-point (point))
         (point-at-end (= old-point end))
         (point-offset (max 0 (min (- old-point beg) (- end beg)))))
    (delete-region beg end)
    (goto-char beg)
    (insert text)
    (goto-char (if point-at-end
                   (+ beg (length text))
                 (+ beg (min point-offset (length text)))))
    (setq deactivate-mark t)))

(defun gcf-cli--convert (command)
  "Convert the active region or entire buffer with gcf COMMAND."
  (let* ((region-p (use-region-p))
         (bounds (gcf-cli--bounds))
         (input (buffer-substring-no-properties (car bounds) (cdr bounds)))
         (output (gcf-cli--run command input)))
    ;; Do not touch the source until the process has succeeded and all output
    ;; has been collected.  This makes failures non-destructive.
    (gcf-cli--replace-bounds bounds output)
    (message "GCF %s converted %s"
             command
             (if region-p "region" "buffer"))))

;;;###autoload
(defun gcf-cli-json-to-gcf ()
  "Convert JSON in the active region or current buffer to generic GCF."
  (interactive)
  (gcf-cli--convert gcf-cli-encode-command))

;;;###autoload
(defun gcf-cli-gcf-to-json ()
  "Convert generic GCF in the active region or current buffer to JSON."
  (interactive)
  (gcf-cli--convert gcf-cli-decode-command))

;;;###autoload
(defalias 'gcf-cli-encode #'gcf-cli-json-to-gcf)

;;;###autoload
(defalias 'gcf-cli-decode #'gcf-cli-gcf-to-json)

(provide 'gcf-cli)

;;; gcf-cli.el ends here
