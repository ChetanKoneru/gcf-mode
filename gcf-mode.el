;;; gcf-mode.el --- Tree-sitter major mode for GCF  -*- lexical-binding: t; -*-

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

;; `gcf-ts-mode' is a major mode for Graph Compact Format (GCF) files.  It
;; uses the tree-sitter grammar from `gcf-ts-mode--grammar-source'.  To install
;; the grammar, run `treesit-install-language-grammar' and choose `gcf'.
;;
;; This package also includes lazily loaded commands for converting JSON to
;; GCF and back with the gcf-python executable.  See
;; `gcf-cli-json-to-gcf' and `gcf-cli-gcf-to-json'.

;;; Code:

(require 'treesit)

;; Keep optional process integration out of the major mode's load path while
;; still exposing it when this repository is used without generated package
;; autoloads.
(autoload 'gcf-cli-json-to-gcf "gcf-cli"
  "Convert JSON in the active region or current buffer to generic GCF." t)
(autoload 'gcf-cli-gcf-to-json "gcf-cli"
  "Convert generic GCF in the active region or current buffer to JSON." t)
(autoload 'gcf-cli-encode "gcf-cli"
  "Convert JSON in the active region or current buffer to generic GCF." t)
(autoload 'gcf-cli-decode "gcf-cli"
  "Convert generic GCF in the active region or current buffer to JSON." t)

(defgroup gcf nil
  "Major mode for editing Graph Compact Format files."
  :group 'languages
  :prefix "gcf-ts-mode-")

(defcustom gcf-ts-mode-indent-offset 2
  "Number of spaces used to indent GCF attachment data."
  :type 'natnum
  :safe #'natnump
  :group 'gcf)

(defconst gcf-ts-mode--grammar-source
  '(gcf "https://github.com/blackwell-systems/tree-sitter-gcf"
        "v1.4.1")
  "Tree-sitter source recipe tested by `gcf-ts-mode'.")

;; Do not replace a grammar recipe selected by the user or another package.
(unless (assq 'gcf treesit-language-source-alist)
  (add-to-list 'treesit-language-source-alist gcf-ts-mode--grammar-source t))

(defvar gcf-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    ;; A comment starts with "# ", while "##" introduces a section.  A
    ;; syntax-table comment entry cannot distinguish them, so comment commands
    ;; use `comment-start-skip' instead.
    (modify-syntax-entry ?# "." table)
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?- "w" table)
    table)
  "Syntax table for `gcf-ts-mode'.")

(defvar gcf-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'gcf
   :feature 'comment
   '((comment) @font-lock-comment-face
     (ref_line) @font-lock-comment-face)

   :language 'gcf
   :feature 'keyword
   '((gcf_keyword) @font-lock-keyword-face
     (["##" "##!" "summary"] @font-lock-keyword-face)
     (edge_status) @font-lock-keyword-face)

   :language 'gcf
   :feature 'number
   '((count_number) @font-lock-number-face
     (id_number) @font-lock-number-face
     (score) @font-lock-number-face)
   ;; A string query prevents package-lint from mistaking the grammar node
   ;; `distance' for the obsolete Emacs Lisp function of the same name.
   :language 'gcf
   :feature 'number
   "(distance) @font-lock-number-face"

   :language 'gcf
   :feature 'string
   '((header_value) @font-lock-string-face
     (kv_value) @font-lock-string-face
     (scalar_value) @font-lock-string-face
     (inline_values) @font-lock-string-face
     (tabular_row_inline) @font-lock-string-face
     (quoted_string) @font-lock-string-face
     (quoted_data_row) @font-lock-string-face
     (tabular_row) @font-lock-string-face
     (indented_data) @font-lock-string-face
     (text_content) @font-lock-string-face)

   :language 'gcf
   :feature 'type
   '((section_name) @font-lock-type-face
     (kind) @font-lock-type-face
     (edge_type) @font-lock-type-face)

   :language 'gcf
   :feature 'function
   '((qualified_name) @font-lock-function-name-face
     (removed_line) @font-lock-function-name-face
     (delta_edge_line) @font-lock-function-name-face)

   :language 'gcf
   :feature 'property
   :override t
   '((header_key) @font-lock-property-use-face
     (kv_key) @font-lock-property-use-face
     (field_name) @font-lock-property-use-face
     (attachment_name) @font-lock-property-use-face
     (inline_array_name) @font-lock-property-use-face)

   :language 'gcf
   :feature 'constant
   '((local_id) @font-lock-constant-face
     (provenance) @font-lock-variable-name-face
     (expanded_value) @font-lock-variable-name-face)

   :language 'gcf
   :feature 'operator
   '((deferred_marker) @font-lock-operator-face
     (keyed_marker) @font-lock-operator-face
     (attachment_cell) @font-lock-operator-face
     (["=" "<" "@" "^" "."] @font-lock-operator-face))

   :language 'gcf
   :feature 'bracket
   '((count_bracket
      ["[" "]"] @font-lock-bracket-face)
     (field_decl
      ["{" "}"] @font-lock-bracket-face)
     (attachment_object) @font-lock-bracket-face)

   :language 'gcf
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `gcf-ts-mode'.")

(defvar gcf-ts-mode--font-lock-feature-list
  '((comment)
    (keyword number string type)
    (function property constant operator bracket)
    (error))
  "Tree-sitter font-lock feature list for `gcf-ts-mode'.")

(defun gcf-ts-mode--previous-nonblank-indentation ()
  "Return indentation appropriate after the preceding nonblank line."
  (save-excursion
    (beginning-of-line)
    (let ((continue t))
      (while (and continue (not (bobp)))
        (forward-line -1)
        (unless (looking-at-p "^[[:space:]]*$")
          (setq continue nil)))
      (if (or continue (looking-at-p "^[[:space:]]*$"))
          0
        (let ((indentation (current-indentation)))
          (if (looking-at "[[:space:]]*\\.")
              (+ indentation gcf-ts-mode-indent-offset)
            (if (looking-at "[[:space:]]+")
                indentation
              0)))))))

(defun gcf-ts-mode-indent-line ()
  "Indent the current GCF line.

Top-level GCF records start in column zero.  Data following an attachment
declaration is indented by `gcf-ts-mode-indent-offset'."
  (interactive)
  (let ((indentation (gcf-ts-mode--previous-nonblank-indentation))
        (column (current-column)))
    (indent-line-to indentation)
    (when (< column indentation)
      (back-to-indentation))))

(defun gcf-ts-mode--section-name (node)
  "Return the section name represented by section header NODE, or nil."
  (when (equal (treesit-node-type node) "section_header")
    (let ((index 0)
          (child-count (treesit-node-child-count node t))
          name)
      (while (and (< index child-count) (not name))
        (let ((child (treesit-node-child node index t)))
          (when (equal (treesit-node-type child) "section_name")
            (setq name (treesit-node-text child t))))
        (setq index (1+ index)))
      name)))

(defun gcf-ts-mode--ensure-ready ()
  "Signal an actionable error unless the GCF grammar is ready to use."
  (cond
   ((not (and (fboundp 'treesit-available-p)
              (treesit-available-p)))
    (user-error "GCF tree-sitter mode needs Emacs built with tree-sitter support"))
   ((not (treesit-language-available-p 'gcf))
    (user-error (concat "GCF grammar is not installed; run "
                        "M-x treesit-install-language-grammar RET gcf RET")))
   ((not (treesit-ready-p 'gcf t))
    (user-error (concat "GCF tree-sitter grammar is not ready for this buffer; "
                        "check `treesit-max-buffer-size'")))))

;;;###autoload
(define-derived-mode gcf-ts-mode prog-mode "GCF"
  "Major mode for editing Graph Compact Format files with tree-sitter."
  :group 'gcf
  :syntax-table gcf-ts-mode--syntax-table

  (gcf-ts-mode--ensure-ready)
  (setq-local treesit-primary-parser (treesit-parser-create 'gcf))

  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "#[ \t]+")
  (setq-local comment-use-syntax nil)
  (setq-local indent-tabs-mode nil)
  (setq-local indent-line-function #'gcf-ts-mode-indent-line)

  (setq-local treesit-defun-type-regexp "\\`section_header\\'")
  (setq-local treesit-defun-name-function #'gcf-ts-mode--section-name)
  (setq-local treesit-simple-imenu-settings
              '(("Sections" "\\`section_header\\'" nil
                 gcf-ts-mode--section-name)))

  (setq-local treesit-font-lock-settings gcf-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              gcf-ts-mode--font-lock-feature-list)
  (treesit-major-mode-setup)
  ;; `treesit-major-mode-setup' preserves custom indentation, but setting this
  ;; explicitly makes the mode's line-oriented attachment indentation clear.
  (setq-local indent-line-function #'gcf-ts-mode-indent-line))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gcf\\'" . gcf-ts-mode))

(provide 'gcf-mode)

;;; gcf-mode.el ends here
