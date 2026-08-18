#!/usr/bin/env bash
# Stage 60 — LaTeX, Pandoc and Quarto for academic writing.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 60 — LATEX / PANDOC / QUARTO"

# The `texlive-most` group no longer exists. Arch reorganised TeX Live to mirror
# upstream collections, so the old `pacman -S texlive-most` fails outright.
#
#   texlive-basic             core
#   texlive-latex             essential LaTeX
#   texlive-latexrecommended  the usual suspects
#   texlive-latexextra        the long tail (large)
#   texlive-bibtexextra       biber / biblatex styles
#   texlive-fontsrecommended  fonts most classes expect
#   texlive-science           amsmath extras, algorithms, siunitx
#   texlive-meta              everything (very large)
#
# Journal and conference classes routinely pull from latexextra and
# bibtexextra, so those are included rather than left to fail at compile time.
pac texlive-basic \
    texlive-latex \
    texlive-latexrecommended \
    texlive-latexextra \
    texlive-bibtexextra \
    texlive-fontsrecommended \
    texlive-science \
    biber

if confirm "also install texlive-meta (everything, several GB)?"; then
    pac texlive-meta
fi

# Pandoc. Arch splits the binary from the Haskell library: pandoc-cli is the
# command-line tool.
pac pandoc-cli

# Cross-referencing. pandoc-crossref alone, deliberately.
#
# The previous script installed pandoc-crossref AND the pandoc-xnos filters
# (pandoc-eqnos / pandoc-fignos / pandoc-tablenos), which are two competing
# cross-reference systems doing the same job with incompatible syntax. Upstream
# xnos development has been dormant for years. Pick one; this picks crossref.
aur pandoc-crossref-bin

# Quarto, for the .qmd side of the writing workflow.
aur quarto-cli-bin

ok "LaTeX stage done"
