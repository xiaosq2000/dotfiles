# Custom .latexmkrc file.

# Always create PDFs and set default engine to LuaLaTeX.
$pdf_mode = 1;
# Set the lualatex variable.
$lualatex = 'lualatex --file-line-error %O %S';

$bibtex_use = 2;
$clean_ext = 'synctex.gz synctex(busy) synctex.gz(busy) aux toc nav snm fls log run.xml bbl bcf fdb_latexmk run tdo %R-blx.bib xelatex*.fls lualatex*.fls';
