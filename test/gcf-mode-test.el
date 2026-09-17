;;; gcf-mode-test.el --- Tests for gcf-mode -*- lexical-binding: t; -*-

;; This file is intentionally not a provided feature.  MELPA excludes test
;; libraries from package archives by convention.

;;; Commentary:

;; Public-behavior checks for `gcf-ts-mode'.  The grammar is optional in this
;; test environment: loading the package must work without it, and the
;; activation test is skipped until a `gcf' grammar is installed.

;;; Code:

(require 'ert)
(require 'cl-lib)

(let ((root (file-name-directory
             (directory-file-name
              (file-name-directory (or load-file-name buffer-file-name))))))
  (add-to-list 'load-path root))

(require 'gcf-mode)

(defconst gcf-mode-test--cli-lazy-loading-state
  (list (not (featurep 'gcf-cli))
        (autoloadp (symbol-function 'gcf-cli-json-to-gcf))
        (autoloadp (symbol-function 'gcf-cli-gcf-to-json)))
  "CLI loading state immediately after requiring the main package library.")

(defun gcf-mode-test--grammar-ready-p ()
  "Return non-nil when this Emacs can activate the GCF Tree-sitter mode."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (fboundp 'treesit-ready-p)
       ;; `treesit-ready-p' may emit a loader warning while looking for an
       ;; absent optional grammar.  That is an expected test condition, so
       ;; suppress it only around this capability probe.
       (cl-letf (((symbol-function 'display-warning)
                  (lambda (&rest _arguments) nil)))
         (treesit-ready-p 'gcf))))

(ert-deftest gcf-ts-mode-is-a-public-command ()
  "The package exposes its documented major mode command."
  (should (commandp 'gcf-ts-mode)))

(ert-deftest gcf-mode-exposes-cli-commands-lazily ()
  "Loading gcf-mode exposes CLI commands without loading their implementation."
  (should (equal gcf-mode-test--cli-lazy-loading-state '(t t t)))
  (should (commandp 'gcf-cli-json-to-gcf))
  (should (commandp 'gcf-cli-gcf-to-json))
  (should (commandp 'gcf-cli-encode))
  (should (commandp 'gcf-cli-decode)))

(ert-deftest gcf-ts-mode-registers-file-extension-and-grammar-source ()
  "The package registers its mode and reproducible grammar source."
  (should (eq (cdr (assoc "\\.gcf\\'" auto-mode-alist))
              'gcf-ts-mode))
  (let ((source (assq 'gcf treesit-language-source-alist)))
    (should source)
    (should (equal (cadr source)
                   "https://github.com/blackwell-systems/tree-sitter-gcf"))
    (should (equal (caddr source) "v1.4.1"))))

(ert-deftest gcf-ts-mode-activates-when-grammar-is-installed ()
  "The public mode activates when the optional grammar is ready."
  (skip-unless (gcf-mode-test--grammar-ready-p))
  (with-temp-buffer
    (gcf-ts-mode)
    (should (eq major-mode 'gcf-ts-mode))
    (should (derived-mode-p 'prog-mode))))

;;; gcf-mode-test.el ends here
