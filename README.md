# netclab.github.io

The netclab organisation site, served at **https://netclab.dev**.

- `/`: the landing page, linking the projects
- `/avd/`: an AVD fabric live in Kubernetes, screenshots and a quick start
- `/slides/`: slide decks about them

Built by GitHub Actions and published to Pages. The landing pages are
hand-written HTML; the decks are Marp Markdown, rendered to HTML and PDF by the
build. Nothing generated is committed.

```
index.html                  the landing page, hand-written
avd/                        the AVD page, hand-written, and its screenshots
slides/index.html           the index of decks, hand-written
slides/<name>/index.md      one deck, Marp source
scripts/build.sh            the entire build
.github/workflows/pages.yml decides when to run it, and publishes
CNAME                       the custom domain; must reach the artifact
```

## Building

```bash
./scripts/build.sh          # -> _site/
```

That script *is* the build. CI runs the same one, so a local run and a published
build cannot disagree about what the site is. `_site/` is gitignored.

It needs `node` (for `npx`) and a Chrome or Chromium binary for the PDF export.
Set `CHROME_PATH` if it is not found automatically:

```bash
CHROME_PATH=/usr/bin/chromium-browser ./scripts/build.sh
```

- **marp-cli is pinned** (`MARP_VERSION` in the script). A deck is a document;
  it should not re-render differently because a renderer moved.
- **`--html` is required.** The decks use inline `<br>` and `<span style=...>` for
  layout, and Marp strips raw HTML unless it is allowed. Without the flag the
  layer diagrams silently lose their colours and line breaks.
- Each deck produces **both** `index.html` and `<name>.pdf`. PDF is the form
  anything posted to social media is published in; HTML is the reachable copy.

## Adding a deck

Create `slides/<name>/index.md` and add an entry to `slides/index.html`. Nothing
else: the build loops over `slides/*/index.md`, and so does CI's check, so there
is no list of decks to keep in step.

Decks are **never committed as HTML.** Exporting one by hand means something has
gone wrong.

## Links are root-relative

Project documentation lives in its own repository and is served by GitHub under
`/<repo>/`. Links here use root-relative paths (`/netclab-xp/`) so they resolve
both at `netclab.dev` and at `netclab.github.io`.

## Publishing

`netclab.dev` is set on this repository, and verified at organisation level.
Every project page moves with it: a project site with no domain of its own stops
being served at `netclab.github.io/<repo>/` and redirects to
`netclab.dev/<repo>/`, path preserved. That is GitHub behaviour, not
configuration: it cannot be turned off, and **no project repository needs a
`CNAME` of its own.**

Pages builds from the workflow, not from a branch, so the deployed artifact *is*
the site. **`CNAME` must be in it**: without it the custom domain is dropped,
which takes `netclab.dev` down. `build.sh` copies it first and then asserts it,
and CI asserts it again, on pull requests too. Do not remove that check to make
the script tidier.

## Checking

**Green checks on a pull request say nothing about publication.** `deploy` is
gated `if: github.event_name != 'pull_request'`, so it reports skipping on every
PR, and a change can merge with everything green and never reach the site. The
build job does run on pull requests: a deck that stopped rendering, or a missing
`CNAME`, fails in review rather than on `main`. The only honest check is the
published page:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://netclab.dev/
```

## Writing a deck

Content rules, all of which were applied to text that read fine before someone
pushed back:

- **Quote things, do not invent them.** A line formatted as a quotation must be
  one. The fabric deck's title slide originally carried a sentence written
  in-house and styled as a quote, next to a deck quoting crossplane.io verbatim.
- **No claim that was not measured.** Device output on a slide is output from a
  run. Three claims were cut from the netclab-xp deck for being false rather
  than merely vague, including two API kinds that do not exist.
- **Development detail is not marketing.** A kustomize workaround, a lab's RAM
  budget, or a limitation of the package are not selling points. Three slides
  were cut or rewritten on this basis.
- **A slide must show what its text promises.** One said "netclab-xp names it in
  `dependsOn`" above a manifest that has no such field.
- **Check that slides fit.** Marp does not warn on overflow; it silently cuts the
  bottom line. Render to images and look:

  ```bash
  MARP_VERSION=$(sed -n 's/^MARP_VERSION=//p' scripts/build.sh)
  timeout 180 npx --yes @marp-team/marp-cli@$MARP_VERSION --html slides/<name>/index.md \
    --images png -o /tmp/check.png
  ```

  The timeout is there because a render can hang without a word, and a second
  run of the same deck finishes in seconds.
