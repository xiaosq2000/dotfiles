---
name: plain-writing
description: Draft or revise prose in the user's plain style. Use for writing tasks, clarity edits, and /plain-writing deslopify; not code changes.
license: MIT
---

# Plain writing

Write plain, descriptive prose that the reader can understand in one pass.
Apply the user's style to the words around code while preserving code, quoted
text, identifiers, and required document syntax. An explicit audience, format,
or language request takes precedence over these defaults.

## Language and explanation

Use familiar words and consistent names. Use established technical terms when
they are precise, and explain them if the audience may not know them. Avoid
invented jargon, compressed compound labels, slogans, puffery, and empty
emphasis. Contractions are welcome.

State the point directly and describe the actual mechanism or consequence.
Use literal explanations without analogies or imagery. Avoid rhetorical
questions and contrasts such as "not just X, but Y". Use ordinary factual verbs
for systems, such as "the API returns JSON", without attributing intentions.

Start with the main conclusion and enough context to understand it. Develop
each paragraph around one idea with the evidence or explanation it needs.
For technical updates, connect the original problem, changed behavior, and
verification result. Include uncertainty when it affects the conclusion.

## Sentences and formatting

Write complete, connected sentences in ordinary prose. Keep a thought together
when it reads naturally, and split sentences that make the reader track too
many ideas. Avoid stacks of punchy fragments. Make pronoun references clear.

Use sentence case headings and straight quotes in English prose. Avoid em
dashes, en dashes, and middle-dot separators; write ranges with "to". Do not
join prose clauses with colons. Colons are fine for lists and short labels.

Use lists, tables, and headings when they make the information easier to follow.
Avoid decorative bold, unnecessary nesting, and openings that merely announce
how many points are coming. Adapt structure to the content without fixed
sentence, clause, or list counts.

## Deslopify

For `/plain-writing deslopify`, rewrite the supplied text or the previous agent
response for a capable reader with no project context. Lead with the conclusion,
then explain the background and details in a logical order. Preserve meaning,
evidence, and uncertainty. Return only the rewrite.
