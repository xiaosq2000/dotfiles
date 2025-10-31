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

# ----- PATH adjustments for latexminted wrapper -----
BEGIN {
    require Cwd;
    require File::Basename;
    require Config;
    my $rcdir = File::Basename::dirname(Cwd::abs_path(__FILE__));
    my $scripts = $rcdir . '/scripts';
    if (-d $scripts) {
        # Prepend the scripts dir so our latexminted wrapper takes precedence on PATH
        $ENV{PATH} = $scripts . $Config::Config{path_sep} . $ENV{PATH};
    }
}

$pdf_mode = 4;

# ----- Engine Configuration -----
$lualatex = 'lualatex --shell-escape --file-line-error --synctex=1 %O %S';

# ----- Output Directory -----
# Place auxiliary and output files in the 'build' subdirectory
$out_dir = 'build';
$aux_dir = 'build';

# ----- Bibliography Settings -----
$bibtex_use = 2;

# ----- Clean-up Configuration -----
# Standard LaTeX auxiliary files
$clean_ext = 'aux bbl bcf fdb_latexmk fls log run tdo ' .
             'lof lot lol toc ' .
             'nav snm vrb ' .
             'run.xml %R-blx.bib ' .
             'synctex.gz synctex.gz(busy) ' .
             '*~ *.bak *.backup';

# Minted files (directory and its contents)
$clean_ext .= ' _minted-%R/* _minted-%R';

# LuaLaTeX scratch directories like "luatex.tQ5OTp"
$clean_ext .= ' luatex.*';

$clean_full_ext = $clean_ext;

# ----- Preview and Continuous Mode Settings -----
$sleep_time = 1; # seconds

# If nonzero, continue processing past minor latex errors including unrecognized cross references. Equivalent to specifying the -f option.
$force_mode = 1;

# ----- Notification Settings -----
$show_time = 1;

# ----- Advanced Settings -----
$max_repeat = 5;
