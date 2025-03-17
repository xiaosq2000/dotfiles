-- IndentWise is a Vim plugin that provides for motions based on indent depths or levels in normal, visual, and operator-pending modes.
-- [- : Move to previous line of lesser indent than the current line.
-- [+ : Move to previous line of greater indent than the current line.
-- [= : Move to previous line of same indent as the current line that is separated from the current line by lines of different indents.
-- ]- : Move to next line of lesser indent than the current line.
-- ]+ : Move to next line of greater indent than the current line.
-- ]= : Move to next line of same indent as the current line that is separated from the current line by lines of different indents.
-- [% : Move to beginning of indent-block scope.
-- ]% : Move to end of indent-block scope.
-- The above all take a {count}.
return {
	"jeetsukumaran/vim-indentwise",
}
