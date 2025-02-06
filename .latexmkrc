# ====================================================================================
# Custom .latexmkrc configuration file
# This file controls the behavior of latexmk, which is used by many editors and tools
# (including vimtex) to automate the LaTeX compilation process.
# ====================================================================================

# ----- Basic PDF Generation Settings -----
# 0: No PDF output
# 1: Use pdfLaTeX
# 2: Use ps2pdf to convert PostScript to PDF
# 3: Use dvipdf to convert DVI to PDF
# 4: Use lualatex
# 5: Use xelatex
$pdf_mode = 4;

# ----- Engine Configuration -----
$lualatex = 'lualatex --shell-escape --file-line-error --synctex=1 %O %S';

# ----- Bibliography Settings -----
$bibtex_use = 2;

# ----- Clean-up Configuration -----
$clean_ext = '
    # Standard LaTeX auxiliary files
    aux bbl bcf fdb_latexmk fls log run tdo
    
    # Table of contents, list of figures, etc.
    lof lot lol toc
    
    # Beamer presentation files
    nav snm vrb
    
    # Bibliography auxiliary files
    run.xml %R-blx.bib
    
    # SyncTeX files
    synctex.gz synctex.gz(busy)
    
    # Engine-specific auxiliary files
    xelatex*.fls lualatex*.fls
    
    # Temporary and backup files
    *~ *.bak *.backup

    # Minted files
    $clean_ext .= " _minted-%R/* _minted-%R";
';

$clean_full_ext = $clean_ext;

# ----- Preview and Continuous Mode Settings -----
$sleep_time = 1; # seconds

# If nonzero, continue processing past minor latex errors including unrecognized cross references. Equivalent to specifying the -f option.
$force_mode = 1;

# ----- Notification Settings -----
$show_time = 1;

# ----- Advanced Settings -----
$max_repeat = 5;
