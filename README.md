# gcf-mode

`gcf-mode` provides `gcf-ts-mode`, an Emacs major mode for [GCF (Graph
Compact Format)](https://gcformat.com/) files.  It uses the upstream
[Tree-sitter GCF grammar](https://github.com/blackwell-systems/tree-sitter-gcf)
for structural syntax highlighting of the `.gcf` format.

GCF is a line-oriented, token-efficient format for structured data.  It has
generic and graph profiles, including headers, sections, symbols, edges,
tabular rows, comments, and attachments.  This package is an editor mode: it
also provides optional buffer and region conversion through the GCF CLI.

## Requirements

- Emacs 29.1 or newer, built with Tree-sitter support.
- A compiled `gcf` Tree-sitter grammar.  The mode can be installed before the
  grammar; activating it will require the grammar.
- [gcf-python](https://github.com/blackwell-systems/gcf-python) when using
  JSON/GCF conversion commands.

Check Tree-sitter support with `M-: (treesit-available-p) RET`.

## Install

When the package is available from MELPA (or another package archive), install
`gcf-mode` with `M-x package-install RET gcf-mode RET`, or declare it with
`use-package`:

```elisp
(use-package gcf-mode
  :mode "\\.gcf\\'")
```

For a checkout, add its directory to `load-path` and load the library:

```elisp
(add-to-list 'load-path "/path/to/gcf-mode")
(require 'gcf-mode)
```

Emacs 29+ users may also install the checkout through `package-vc`:

```elisp
(package-vc-install "https://github.com/blackwell-systems/gcf-mode")
```

## Install the grammar

The package registers a tested revision of the authoritative upstream grammar.
Run `M-x treesit-install-language-grammar RET gcf RET`.  This compiles native
code, so a C compiler and `make` must be available.

If Emacs cannot compile the grammar, install a trusted prebuilt grammar through
your operating system or another grammar manager, then ensure Emacs can find
it.  `M-: (treesit-ready-p 'gcf) RET` reports whether it is ready.

## Use

Visiting a file ending in `.gcf` selects `gcf-ts-mode`; invoke it manually with
`M-x gcf-ts-mode RET` when needed.  The grammar supports both generic and graph
profiles, including GCF headers, sections, graph symbols and edges, key/value
pairs, tabular rows, nested fields, comments, and summary trailers.

## Convert JSON and GCF with the CLI

The optional conversion commands use the `gcf` executable from
[gcf-python](https://github.com/blackwell-systems/gcf-python).  Install it
with:

```sh
python3 -m pip install gcf-python
gcf version
```

`gcf version` verifies the installation; on macOS and GNU/Linux,
`command -v gcf` also shows the executable that Emacs will normally find on
`PATH`.  The conversion library is separate from the major mode.  When
`gcf-mode` is installed as a package, its autoloads make the commands below
available from `M-x` without first loading `gcf-cli`.  From a source checkout,
add the checkout to `load-path` and load the conversion library explicitly:

```elisp
(add-to-list 'load-path "/path/to/gcf-mode")
(require 'gcf-cli)
```

To convert an entire JSON buffer, ensure that no region is active and run
`M-x gcf-cli-json-to-gcf RET`.  It sends the buffer to `gcf encode-generic`
and replaces it with generic-profile GCF.  To convert that whole GCF buffer
back, run `M-x gcf-cli-gcf-to-json RET`; it uses `gcf decode-generic`.

Conversion changes the selected text only: it does not rename or save the
buffer, or change its major mode.  After converting a JSON buffer, save it with
a `.gcf` extension or run `M-x gcf-ts-mode RET` to enable GCF highlighting.

When the region is active, either command sends and replaces only that region;
text outside it is untouched.  The shorter aliases are also commands:
`M-x gcf-cli-encode RET` is `gcf-cli-json-to-gcf`, and
`M-x gcf-cli-decode RET` is `gcf-cli-gcf-to-json`.  No key bindings are
defined by this package.

These commands deliberately use the generic profile, which handles arbitrary
JSON values (objects, arrays, and primitives).  `gcf encode` and `gcf decode`
are different, graph-profile subcommands: use them only for the GCF graph
payload schema, not as a generic JSON converter.  A graph-profile workflow can
be selected explicitly:

```elisp
(setq gcf-cli-encode-command "encode"
      gcf-cli-decode-command "decode")
```

For a virtual environment or another nonstandard installation, configure the
executable by absolute path.  A `use-package` setup for a source checkout, for
example, can both load it and make that choice:

```elisp
(use-package gcf-cli
  :load-path "/path/to/gcf-mode"
  :custom
  (gcf-cli-executable "/path/to/venv/bin/gcf"))
```

`gcf-cli-arguments` defaults to `nil`; its strings are passed directly, before
the conversion subcommand, with no shell interpretation.  Set it only when a
replacement/wrapper executable documents such options.  Similarly,
`gcf-cli-encode-command` and `gcf-cli-decode-command` should be changed only
to subcommands understood by the executable in use.

A failed CLI process (including a missing executable) signals an Emacs error
and leaves the original buffer or region unchanged; stderr diagnostics are
included when available.  On success, the requested text is replaced normally,
so `C-/` (or `M-x undo`) restores it.

### CLI troubleshooting

- If Emacs says it cannot run `gcf`, compare `M-: (executable-find "gcf") RET`
  with `command -v gcf`; GUI Emacs may have a different `PATH`.  Set
  `gcf-cli-executable` to the full path if needed.
- If `M-x gcf-cli-json-to-gcf` is absent in a source checkout, evaluate
  `(require 'gcf-cli)` after adding the checkout to `load-path`.
- If conversion reports an input error, check that the selected text is a
  complete JSON value for encoding or complete generic GCF for decoding.  The
  source is preserved so it can be corrected and retried.
- Conversion does not install or require the Tree-sitter grammar; grammar
  errors while editing `.gcf` files are addressed by the grammar installation
  instructions above.
