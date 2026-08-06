# netclab.github.io

The netclab organisation site, served at **https://netclab.dev**.

- `/` — the landing page, linking the projects
- `/slides/` — slide decks about them

Built by GitHub Actions and published to Pages. The landing pages are
hand-written HTML; the decks are Marp Markdown, rendered to HTML and PDF by the
build. Nothing generated is committed.

See [DEVELOPMENT.md](DEVELOPMENT.md) to change any of it.

## Links are root-relative

Project documentation lives in its own repository and is served by GitHub under
`/<repo>/`. Links here use root-relative paths (`/netclab-xp/`) so they resolve
both at `netclab.dev` and at `netclab.github.io`.

## Custom domain

`netclab.dev` is set on this repository, and verified at organisation level.

Every project page moves with it: a project site with no domain of its own stops
being served at `netclab.github.io/<repo>/` and redirects to
`netclab.dev/<repo>/`, path preserved. That is GitHub behaviour, not
configuration — it cannot be turned off, and **no project repository needs a
`CNAME` of its own.**
