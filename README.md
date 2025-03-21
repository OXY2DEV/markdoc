![Demo 1](https://github.com/OXY2DEV/markdoc/blob/main/assets/markdoc-1-min.png)

![Demo 2](https://github.com/OXY2DEV/markdoc/blob/main/assets/markdoc-2-min.png)

<p align="center">✨ markdoc</p>
<p align="center">A feature rich markdown to vimdoc converter for pandoc.</p>

<MKDocTOC/>

## 🥅 Goals

| Goal                                     | Progress |
|------------------------------------------|----------|
| Basic markdown syntax support            | Complete |
| Basic HTML support                       | Complete |
| Handling of `\n` in HTML                 | Complete |
| Allowing text alignment                  | Complete |
| Callout support                          | Complete |
| Wrap for nested elements                 | Complete |
| Ability to change configuration per file | Complete |
| Ability to place TOC anywhere            | Complete |
| Handling LaTeX                           | None     |
| Handling characters with varying widths  | None     |
| More syntax support(HTML, Markdown)      | None     |

## 💥 Features

- Config per file, allows configuring `markdoc` using YAML metadata.
- Tag(s) per heading, allows using Lua patterns to add one or more tags to matching headings. 
- Creating TOCs, allows creating Table of contents via YAML.
- Callout & title support, supports callouts(even custom ones) and titles for block quotes.
- Prettier table rendering, tables can be created with custom borders with text wrapping support.
- Nesting support, supports nesting of block elements.
- Base HTML support, supports basic HTML tags.
- `align=""` support, allows aligning text via HTML.

## 📚 Usage

You only need the `markdoc.lua` file. So, just copy it to your desired location.

You can then run it like so,

```shell
pandoc -t path/to/markdoc.lua README.md -o help.txt
```

>[!TIP]
> You can store metadata in a separate file too if you like. Then you will do something like this,
> 
> ```sh
> # Load the metadata file first
> pandoc metadata.md README.md -t path/to/markdoc.lua -o help.txt
> ```

## 💨 Github actions

>[!WARNING]
> I am not very knowledgable when it comes to GitHub actions, so feel free to do PR(s) to fix issues I missed.

```yml
name: markdoc
on:
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  doc:
    runs-on: ubuntu-latest
    name: "To vimdoc"
    steps:
      - uses: actions/checkout@v2
        with:
          ref: ${{ github.heade_ref }}
      - uses: OXY2DEV/markdoc@main
        with:
          config: '{ "doc/markdoc.txt": [ "mREADME.md", "README.md" ] }'
          help_dirs: '[ "doc" ]'
      - uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: "doc: Generated help files"
          branch: ${{ github.head_ref }}
```

This basically runs `git checkout`, `pandoc mREADME.md README.md -t markdoc.lua -o doc/markdoc.txt`, `git add .` and `git commit -m "doc: Generated help files"`.

### 📌 Configuring workflow

The workflow comes with a single option, `config`. It's a JSON string that actually looks like this,

```json
{
  "doc/markdoc.txt": [ "mREADME.md", "README.md" ]
}
```

This generates `markdoc.txt` from `mREADME.md`(this file is used for metadata) and `README.md`.

You can add more keys to create more files. For example,

```json
{
  "doc/markdoc.txt": [ "mREADME.md", "README.md" ],
  "doc/markdoc-arch.txt": [ "ARCHITECTURE.md" ]
}
```

This will generate another help file named `markdoc-arch` from the `ARCHITECTURE.md` file.

---

As of `v3` there is also a `help_dirs` option. This is a JSON list of directories where `helptags` will be run.

```json
[ "doc" ]
```

By default it only runs on the `doc/` directory.

## 🪨 Limitations

>[!IMPORTANT]
> `markdoc` is best-effort only. It's not perfect but for most use cases it should be good enough.

- Whitespace loss, due to the nature of syntax trees the whitespace in the document may not be preserved.
- Issues with complex characters, some UTF-8 characters don't get properly wrapped(either due to multi-byte width or limitation of Lua).
- Issues with complex document structures, though `markdoc` should support complex documents it is still preferable to keep them simple.

  You may encounter text wrapping issues if the document gets too deeply nested(due to lack of space).

## 🔩 Configuration

<p align="center">"One function to rule them all,</p>
<p align="center">One function to find them,</p>
<p align="center">One function to bring them all,</p>
<p align="center">And in the darkness bind them."</p>

You can configure `markdoc` for a file by adding a YAML metadata section to the start of the file.

It should look something like this,

```text
---
markdoc:
  textwidth: 78
  title: "Markdown 🤝 Vimdoc"
  title_tag: "markdoc"

  tags:
    Features$: [ "markdoc-features", "markdoc-feat" ]
  Usage$: [ "markdoc-usage" ]
---
Some text.
```

>[!NOTE]
> All configuration options should be inside `markdoc`.

The configuration options are given below,

### block_quotes

Changes block quote configuration.

#### Example

```yaml
  block_quotes:
    default:
      border: "║"

    # Name SHOULD be in lowercase.
    # This will match any variation of,
    # [!CUSTOM]
    custom:
      border: "┊" # Block quote border
      callout: "🎵 Custom" # Text to show at the top
      icon: "🎵" # Icon before title(if there is any).
```

### fold_refs

When `true`, link & image references are folded.

#### Example

```yaml
  fold_refs: true
```

### foldmarkers

Markers used for folding.

#### Example

```yaml
  # This is the same as `:set foldmarker`
  foldmarkers: "{{{,}}}"
```

### tags

Tag configuration for different headings.

#### Example

```yaml
    tags:
      # The key is a Lua patter.
      Features$: [ "markdoc-features", "markdoc-feat" ] # Adds 2 tags to headings ending with Feature.
      Usage$: [ "markdoc-usage" ]
```

### table

Table configuration.

#### Example

```yaml
    table:
      col_minwidth: 10 # Minimum width for columns.

      top: [ "╭", "─", "╮", "┬" ]
      header: [ "│", "│", "│" ]

      separator: [ "├", "─", "┤", "┼" ]
      header_separator: [ "├", "─", "┤", "┼" ]
      row_separator: [ "├", "─", "┤", "┼" ]

      row: [ "│", "│", "│" ]
      bottom: [ "╰", "─", "╯", "┴" ]
```

### textwidth

Width of the document.

#### Example

```yaml
  # Same as `:set textwidth`
  textwidth: 78
```

### title

Title of the document.

#### Example

```yaml
  title: "Markdown 🤝 Vimdoc"
```

### title_tag

Tag for the document title.

#### Example

```yaml
  title_tag: "markdoc"
```

### toc_title

Title for the generated table of contents section.
Defaults to `Table of contents:` when unset.

#### Example

```yaml
  toc_title: "Markdoc: TOC"
```

### toc

Entries for the table of contents.

>[!TIP]
> You can add `<MKDocTOC/>` to anywhere in your document and the table of contents will be placed there!
> However, It will also only replace the 1st one.

#### Example

```yaml
  toc:
    "Features": "markdoc-features"
```

------

Vimdoc version, see `doc/markdoc.txt`.
Markdown version, see `README.md`(metadata is at `mREADME.md`).
