# ====================================================================================
# Custom .latexmkrc configuration file
# This file controls the behavior of latexmk, which is used by many editors and tools
# (including vimtex) to automate the LaTeX compilation process.
# ====================================================================================

# ----- PATH adjustments for the latexminted wrapper -----
BEGIN {
    require Cwd;
    require File::Basename;
    require Config;
    my $rcdir = File::Basename::dirname(Cwd::abs_path(__FILE__));
    my $scripts = $rcdir . '/scripts';
    if (-d $scripts) {
        # Prepend scripts so umwelt can add the pinned Rose Pine Pygments style
        # while still mirroring the TeX Live latexminted dependency versions.
        $ENV{PATH} = $scripts . $Config::Config{path_sep} . $ENV{PATH};
    }
}

$pdf_mode = 4;

# ----- Engine Configuration -----
$lualatex = 'lualatex --shell-escape --file-line-error --synctex=1 %O %S';

# ----- Output Directory -----
$out_dir = 'build';
$aux_dir = 'build';

# ----- Bibliography Settings -----
$bibtex_use = 2;

# ----- Clean-up Configuration -----
$clean_ext = 'aux bbl bcf fdb_latexmk fls log run tdo ' .
             'lof lot lol toc ' .
             'nav snm vrb ' .
             'run.xml %R-blx.bib ' .
             'synctex.gz synctex.gz(busy) ' .
             '*~ *.bak *.backup';
$clean_ext .= ' luatex.*';
# Keep the minted cache on routine `latexmk -c` cleans: dropping it forces
# every snippet through latexminted again on the next build. `latexmk -C`
# still removes it.
$clean_full_ext = $clean_ext . ' _minted-%R/* _minted-%R _minted_cache/* _minted_cache';

# ----- Preview and Continuous Mode Settings -----
$sleep_time = 1;
$force_mode = 1;

# ----- Notification Settings -----
$show_time = 1;
$max_repeat = 5;
