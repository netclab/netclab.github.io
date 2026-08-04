# netclab.github.io

The netclab organisation site. Served by GitHub Pages from `main` at the
repository root.

`.nojekyll` is present on purpose: files are served exactly as committed, so a
hand-written `index.html` cannot collide with a Jekyll-rendered `index.md`, and
exported HTML (the slide deck) needs no front matter.

## Links are root-relative

Project documentation lives in its own repository and is served by GitHub under
`/<repo>/`. Links here use root-relative paths (`/netclab-xp/`) so they resolve
both at `netclab.github.io` and, once the custom domain lands, at `netclab.dev`.

## Custom domain

Not set yet. When `netclab.dev` is pointed here, set it under
Settings → Pages — that writes the `CNAME` file — and enable *Enforce HTTPS*.
Setting it before DNS points at GitHub makes this site redirect to a domain that
does not serve it yet.

Every project page then moves from `netclab.github.io/<repo>/` to
`netclab.dev/<repo>/` automatically, with the path preserved. That is GitHub
behaviour, not configuration: it cannot be turned off, and no project repository
needs a `CNAME` of its own.
