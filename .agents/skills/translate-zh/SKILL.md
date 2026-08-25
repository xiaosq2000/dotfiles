---
name: translate-zh
description: >
  Translate an English document into Simplified Chinese while preserving all formatting, structure, and
  untranslatable elements. Use this skill whenever the user wants to translate a file, document, or text
  to Chinese (Simplified), including requests like "translate this to Chinese", "make a Chinese version",
  "create a zh version", "localize to Chinese", or any mention of translating documentation, README,
  or text files into Chinese/Mandarin/中文. Also triggers when the user says /translate-zh.
---

# Translate to Simplified Chinese

Translate an English document into Simplified Chinese, producing a high-quality, natural-sounding translation
that a native Chinese reader would find clear and idiomatic — not a word-for-word machine translation.

## Input

The user provides a file path as an argument (e.g., `/translate-zh path/to/file.md`).

If no file path is given, ask the user which file to translate.

## Workflow

1. **Read** the source file in full.
2. **Determine the output path**: insert `-zh` before the file extension.
   - `README.md` → `README-zh.md`
   - `docs/guide.rst` → `docs/guide-zh.rst`
   - `notes.txt` → `notes-zh.txt`
   - If the file has no extension: append `-zh` (e.g., `LICENSE` → `LICENSE-zh`)
3. **Translate** the content following the translation rules below.
4. **Write** the translated file to the output path.
5. **Report** the output path to the user.

## Translation Rules

### What to translate
- All prose, headings, list items, table cells, image alt-text, and comments written in English.
- Markdown front matter values that are human-readable (e.g., `title`, `description`). Keep keys in English.

### What to preserve unchanged
These elements must pass through exactly as they appear in the source:

- **Code blocks** (fenced `` ``` `` or indented) — leave all code untouched. Only translate comments inside code blocks if they are full sentences clearly meant for human readers.
- **Inline code** (backtick-wrapped) — keep as-is.
- **URLs and links** — preserve hrefs. Translate link text if it is descriptive English prose.
- **HTML tags and attributes** — preserve structure. Translate visible text content inside tags.
- **File paths, CLI commands, environment variable names.**
- **Brand names, product names, and proper nouns** (e.g., GitHub, Docker, Linux, Claude).
- **Technical terms** that are conventionally kept in English in Chinese technical writing (e.g., API, SDK, JSON, HTTP, webhook, token, DNS). Use your judgment — if a term has a widely-accepted Chinese equivalent that professionals use (e.g., 服务器 for server, 数据库 for database), prefer the Chinese term.

### Formatting preservation
- Maintain the identical markdown/markup structure: heading levels, list nesting, table alignment, blockquotes, horizontal rules, blank lines.
- Keep the same line-break style (if the source uses one sentence per line, do the same).

### Style guidelines
- Use modern, natural Simplified Chinese (简体中文).
- Prefer concise, direct phrasing over overly formal or literary language.
- For technical documentation, match the tone commonly found in official Chinese docs of major open-source projects.
- Keep sentences at a reasonable length — break up overly long sentences if the Chinese reads better that way.
- Use Chinese punctuation (，。、；：""''！？（）) instead of English punctuation in translated text.
