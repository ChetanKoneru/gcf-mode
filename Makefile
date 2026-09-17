EMACS ?= emacs
ELISP_FILES := gcf-mode.el gcf-cli.el
TEST_FILES := test/gcf-mode-test.el test/gcf-cli-test.el

.PHONY: test compile checkdoc package-lint lint check

test:
	$(EMACS) -Q --batch -L . -L test $(foreach test,$(TEST_FILES),-l $(test)) \
		-f ert-run-tests-batch-and-exit

# Write the temporary byte-compiled file outside the checkout and remove it.
compile:
	$(EMACS) -Q --batch -L . --eval "(progn (require 'bytecomp) (let* ((destination (make-temp-file \"gcf-mode-\" nil \".elc\")) (byte-compile-dest-file-function (lambda (_) destination))) (unwind-protect (dolist (source '(\"gcf-mode.el\" \"gcf-cli.el\")) (byte-compile-file source)) (when (file-exists-p destination) (delete-file destination)))))"

checkdoc:
	$(EMACS) -Q --batch -l checkdoc --eval "(dolist (source '(\"gcf-mode.el\" \"gcf-cli.el\")) (checkdoc-file source))"

# Set PACKAGE_LINT_PATH to a package-lint checkout or installation directory.
package-lint:
	test -n "$(PACKAGE_LINT_PATH)"
	$(EMACS) -Q --batch -L "$(PACKAGE_LINT_PATH)" -l package-lint \
		-f package-lint-batch-and-exit $(ELISP_FILES)

# package-lint is deliberately separate because it is not a runtime dependency.
lint: checkdoc

check: compile lint test
