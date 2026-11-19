---
name: translate-zh
description: Translate English files or supplied text into Simplified Chinese while preserving document structure and technical literals.
---

# Translate to Simplified Chinese

Produce natural, concise Simplified Chinese using the source's technical meaning
and tone. Translate the supplied text directly. For a file, use the requested
destination or insert `-zh` before its extension (`README.md` becomes
`README-zh.md`); append `-zh` if it has no extension. Preserve the source unless
the user requests an in-place translation. Ask for the source only when it is
missing from the request and conversation.

## Content and structure

Translate prose, headings, list items, table cells, descriptive link text,
image alt text, and visible HTML text. Translate human-readable frontmatter
values such as `title` and `description`; preserve keys and machine-readable
values such as status enums and identifiers.

Preserve heading levels, list nesting, table structure, blockquotes, blank
lines, and the source's line-break convention. Keep URLs and link destinations,
HTML tags and attributes, paths, commands, environment variable names, inline
code, and proper names unchanged. If translated headings break generated anchor
links, retain the original anchors using the document format's supported
mechanism. Report any unresolved anchor limitation.

Keep executable code and code-block formatting unchanged. Translate comments
inside code only when they are full sentences for readers; preserve directives,
doctests, expected output, and machine-readable annotations.

## Chinese style and completion

Use common Chinese technical terms where established, and keep customary
English terms such as API, SDK, and JSON. Use Chinese punctuation in translated
prose and choose sentence lengths that read naturally. These language choices
take precedence over English-specific writing defaults.

Review the result for missing content, altered literals, and broken structure.
For a file translation, write the output and report its path. For supplied text,
return the translation directly.
