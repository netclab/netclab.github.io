# Working on this repository

The netclab organisation site: the landing page at `netclab.dev`, and the slide
decks under `/slides/`.

`README.md` says what the site *is*. This file says what you need to know to
change it, and concentrates on the things that are not obvious — most of them
cost an experiment or a failed deploy to establish.

```
index.html                  the landing page, hand-written
slides/index.html           the index of decks, hand-written
slides/<name>/index.md      one deck, Marp source
scripts/build.sh            the entire build
.github/workflows/pages.yml decides when to run it, and publishes
CNAME  .nojekyll            see "Publishing" -- neither is what it looks like
```

- [Building](#building) · [Adding a deck](#adding-a-deck)
- [Publishing](#publishing) — `CNAME`, `.nojekyll`, branch vs workflow
- [Deploys have a hard ten-minute ceiling](#-deploys-have-a-hard-ten-minute-ceiling) — read this before debugging a failed deploy
- [Checking your work](#checking-your-work) — why green checks are not enough
- [The domain](#the-domain) — DNS, Cloudflare, the three redirect rules
- [Writing a deck](#writing-a-deck)

## Building

```bash
./scripts/build.sh          # -> _site/
```

That script *is* the build. CI runs the same one, so a local run and a published
build cannot disagree about what the site is. `_site/` is gitignored.

You need `node` (for `npx`) and a Chrome or Chromium binary for the PDF export.
Set `CHROME_PATH` if it is not found automatically:

```bash
CHROME_PATH=/usr/bin/chromium-browser ./scripts/build.sh
```

- **marp-cli is pinned** (`MARP_VERSION` in the script). A deck is a document;
  it should not re-render differently because a renderer moved.
- **`--html` is required.** The decks use inline `<br>` and `<span style=…>` for
  layout, and Marp strips raw HTML unless it is allowed. Without the flag the
  layer diagrams silently lose their colours and line breaks.
- Each deck produces **both** `index.html` and `<name>.pdf`. PDF is the form
  anything posted to social media is published in; HTML is the reachable copy.

### Adding a deck

Create `slides/<name>/index.md` and add an entry to `slides/index.html`. Nothing
else — the build loops over `slides/*/index.md`, and so does CI's check, so
there is no list of decks to keep in step.

Decks are **never committed as HTML.** Until 2026-08-06 the one deck here was a
hand export from the VSCode Marp extension, committed beside its source; with a
second deck that is two manual steps per change and no way to tell whether the
committed HTML still matched the Markdown. If you find yourself exporting by
hand, something has gone wrong.

## Publishing

Pages is set to **build from a workflow**, not from a branch:

```bash
gh api repos/netclab/netclab.github.io/pages --jq .build_type   # workflow
```

That single setting has consequences that are easy to get wrong.

### ⚠ `CNAME` must be in the artifact

With a workflow build, the deployed artifact *is* the site. If `CNAME` is not in
it, the custom domain is dropped — which takes `netclab.dev` down. `build.sh`
copies it first and then asserts it, and CI asserts it again, on pull requests
too.

This is the one check in the build that protects something irreversible in
practice, so do not remove it to make the script tidier.

### `.nojekyll` is kept and deliberately not deployed

It is read **only** by the Jekyll build that Pages runs when serving from a
*branch*. A deployed artifact is served exactly as uploaded, so under the
current setup the file does nothing at all.

It stays in the repository anyway, so that reverting Pages to a branch is one
setting rather than a setting plus remembering a file. `build.sh` says so where
it copies the other static files.

(It does **not** cause a Jekyll build, and its absence would not cause one
either. That is worth stating because the opposite is a natural assumption.)

### Switching between branch and workflow: order matters

Flip `build_type` **before** pushing the commit that depends on it. The decks
exist only as `index.md` in the repository, so a branch-served build would
publish `slides/<name>/` with no `index.html` in it.

Measured: after flipping `build_type` and before any deployment has run, Pages
**keeps serving the last deployment**. There is no outage window.

## ⚠ Deploys have a hard ten-minute ceiling

The most expensive thing anyone here has learned. There are **two independent
ten-minute limits**, and the second cannot be raised:

1. The job's `timeout-minutes`. Real, and raising it works.
2. **`actions/deploy-pages`' own `timeout` input — where `600000` ms is the
   MAXIMUM, not merely the default.**

A larger value is accepted, warned about, and silently clamped:

```
##[warning]Warning: timeout value is greater than the allowed maximum
           - timeout set to the maximum of 600000 milliseconds.
```

The action's `action.yml` documents `timeout` only as *"default: 10 minutes"*, so
the ceiling is invisible until a run prints that warning. **An accepted input is
not an applied one.** The proof that setting it changes nothing is a run that
still fails at ten minutes with the larger value in place — which is what
happened, twice, on 2026-08-06.

So the input is not set here, and the comment in `pages.yml` explains why: the
obvious fix looks available and is not.

### ⚠ A timed-out deploy cancels the deployment, and it is keyed by commit SHA

This is what turns a slow afternoon into a stuck repository, and it does not
follow from the timeout message:

```
##[error]Timeout reached, aborting!
Canceling Pages deployment...
Canceled deployment with ID 4551916b7a70daf994c522f1b1adb9f6692fa8e0
```

That ID is the commit SHA — `e881ad7` was cancelled this way at
`2026-08-06T14:07:03Z`. **Re-running that same run cannot recover.** It is handed
the cancelled state and fails in about ten seconds:

```
##[error]Deployment cancelled.
```

**A new run on the same SHA does recover, though.** The cancellation belongs to
that deployment attempt, not to the commit, so a plain
`gh workflow run Pages --ref main` is enough once the queue has cleared — and
being free, it is what to try first. This file claimed until 2026-08-07 that
recovery needed a new commit; it does not, and the wrong version costs an empty
commit every time a queue runs slow.

### What a failed deploy does and does not cost

It costs publication, never availability. The previous deployment keeps serving
throughout — verified during every failure on 2026-08-06, with both
`netclab.dev` and the project docs answering 200 and
`gh api repos/<repo>/pages` reporting `status: built`.

If deploys are failing, the site is not broken. It is stale.

### When it happens, it is usually not this repository

On 2026-08-06 every poll returned `deployment_queued`, `githubstatus.com`
reported Pages and Actions **fully operational** throughout, and the same
workflow had succeeded at **8m04s and 9m12s that same morning** before failing
at 10m06s and 10m07s in the afternoon. The margin is thin by design and nothing
here widens it.

The response is to wait, then start a fresh run — not to change configuration.
On 2026-08-07 the queue had cleared and a deploy took 49s.

## Checking your work

### ⚠ Green checks on a pull request say nothing about publication

`deploy` is gated `if: github.event_name != 'pull_request'`, so it reports
**skipping** on every PR. A change can merge with everything green and never
reach the site. The only honest check is the published page:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://netclab.dev/
```

The build job *does* run on pull requests, which is the point: a deck that
stopped rendering, or a missing `CNAME`, fails in review rather than on `main`.

### ⚠ `gh run watch` is not trustworthy here

Three distinct failures in one session, each giving a wrong impression:

- it **exits before the run finishes**, so a watch reports "completed" while the
  deploy is still queued;
- against a re-run it reports *"Run … has already completed with 'failure'"* and
  exits on the previous attempt's result;
- it has a client-side timeout that aborts with `Timeout reached, aborting!` —
  **wording identical** to what `deploy-pages` prints on its own timeout, so the
  log looks the same whether the watcher or the deploy gave up.

Poll instead:

```bash
until [ "$(gh run view <id> --json status --jq .status)" = completed ]; do
  sleep 30
done
```

## The domain

`netclab.dev` is a Cloudflare zone plus a Pages custom domain set on **this**
repository. Neither half is configured in any repository's files — the `CNAME`
here is written by GitHub when the domain is set in Settings → Pages — so this
section is the only written record of how they fit together.

It lives here because the `CNAME` lives here, because changing DNS and changing
Pages settings is one operation, and because it is this repository's domain that
moves every other repository's pages. `netclab-xp` has `cname: null` and cannot
see or change any of it.

Measured **2026-08-06**. Re-measure before trusting it.

### What serves what

| address | result | from |
|---|---|---|
| `netclab.dev/` | 200, organisation site | this repository |
| `netclab.dev/slides/` | slide decks | this repository |
| `netclab.dev/netclab-xp/` | documentation | `netclab-xp` |
| `netclab.dev/netclab-chart/` | Helm repository | `netclab-chart`, `gh-pages` |
| `xp.netclab.dev/` | 301 → `netclab.dev/netclab-xp/` | rule 2 |
| `chart.netclab.dev/` | 301 → `github.com/netclab/netclab-chart` | rule 1 |
| `www` and any other `*.netclab.dev` | 301 → `netclab.dev` | rule 3 |
| `netclab.dev/xp`, `netclab.dev/chart` | **404, by design** | see below |

```bash
for u in / /slides/ /netclab-xp/ /netclab-chart/index.yaml; do
  curl -sS -o /dev/null -w "$u %{http_code}\n" "https://netclab.dev$u"
done
for h in www xp chart anything; do
  curl -sS -o /dev/null -w "$h %{http_code} %{redirect_url}\n" "https://$h.netclab.dev/"
done
```

**The project rows are GitHub behaviour, not configuration.** When an
organisation site has a custom domain, project pages stop being served at
`netclab.github.io/<repo>/` and 301 to `<domain>/<repo>/`, **path preserved**.
It cannot be turned off, and **no project repository needs a `CNAME` of its
own.** Verified here and on four unrelated organisations before this layout was
adopted; `helm` follows the redirect, so `netclab-chart`'s Helm repository keeps
working through its old URL.

### The one rule everything else follows

Cloudflare records are either **proxied (orange)** or not **(grey)**:

| | |
|---|---|
| 🟠 orange | traffic passes through Cloudflare — **redirect rules apply** |
| ⚪ grey | traffic goes straight to the origin — **Cloudflare does not intervene** |

**The apex must be grey**, because GitHub will not issue a certificate for it
otherwise: its validation does not pass through Cloudflare.

That is the whole complication — **a grey apex has no redirect rules.** It does
not need them, because it serves a real site. The wildcard stays orange, so
rules still apply to every subdomain.

```
netclab.dev.      CNAME  netclab.github.io   grey     (flattened)
*.netclab.dev.    A      192.0.2.1           orange
```

```bash
dig +short netclab.dev       # 185.199.108-111.153 -> GitHub Pages, grey
dig +short www.netclab.dev   # 188.114.x           -> Cloudflare, orange
```

- **`192.0.2.1` is a TEST-NET address with no server behind it.** It exists only
  so Cloudflare has something to proxy while a redirect rule does the work.
  There is no origin under the wildcard.
- A CNAME on the apex is allowed in Cloudflare and flattens itself. Better than
  four hardcoded GitHub addresses, because it keeps up when GitHub changes them.
- **There is no `xp.netclab.dev` record.** The name falls under the wildcard,
  which is what lets rule 2 redirect it without a record of its own.

### The three redirect rules

All three are live. **Rule 2 must stay ahead of rule 3**, or the catch-all
swallows it.

**Rule 3 — "Redirect to Github Organization (all)"**, all requests →
`https://netclab.dev`. ⚠ **This is the rule that serves the entire wildcard.
Never delete it — only retarget it.** It stopped applying to the apex by itself
when the apex went grey, since that traffic no longer reaches Cloudflare. It
still catches every subdomain, so a typo lands on the site rather than on GitHub.

**Rule 2 — "Redirect to Github Pages (xp)"**, hostname equals `xp.netclab.dev` →
`https://netclab.dev/netclab-xp/`. Matches on hostname, not path; it never
preserved the path and does not need to.

**Rule 1 — "Redirect to Github Repo (chart)"**, hostname `chart.netclab.dev`
**or** path `/chart` — combined with OR → `github.com/netclab/netclab-chart`.
⚠ **Half of this rule is dead and fails silently**: the path half cannot fire
against a grey apex, so `netclab.dev/chart` 404s. Worth revisiting whether
`https://netclab.dev/netclab-chart/` — the Helm repository itself — is the
better target than the GitHub source page. That is a change of intent rather
than a repair, so it is left open.

⚠ **Path-based redirects on the apex cannot work at all.** There were two, `/xp`
and `/chart`. This is not a misconfiguration and no rule fixes it. If either
must come back, it becomes **a small HTML file in this repository**, not a rule.

### Before touching DNS or Pages settings

Each of these costs an outage, or worse, if reversed:

- **DNS before the Pages custom domain, never the other way round.** In this
  order GitHub's validation passes immediately and the certificate starts being
  issued. Reversed, the site is unreachable while you wait for propagation.
- **The `CNAME` file comes last.** The moment this repository has it,
  `netclab.github.io` stops serving and 301s to `netclab.dev` — killing the
  preview exactly when it is most needed.
- **Enforce HTTPS on GitHub is mandatory, not optional.** Cloudflare's "Always
  Use HTTPS" does not apply to a grey record, so nothing else upgrades http.
- Issuing the certificate can take **fifteen minutes or more**. That is normal.
- ⚠ **A DNS record pointing at Pages must be deleted together with the `CNAME`
  in the repository that claims it**, not later. The gap is the whole
  vulnerability: on 2026-08-04 `xp.netclab.dev` was left pointing at GitHub with
  no repository claiming the name, and someone else's repository claimed it and
  served a redirect to their own site — over GitHub's certificate.
- **The domain is verified at organisation level** (Settings → Pages → verified
  domains, `TXT _github-pages-challenge-netclab`), so only this organisation can
  claim `netclab.dev` or its subdomains. Keep it that way; it is what makes the
  above unrepeatable.

`gh api … -f https_enforced=true` fails with a type error — a boolean needs `-F`
— and then fails again with *"The certificate has not finished being issued"*
even while HTTPS already answers 200 with a valid certificate. The web UI
accepts it.

### Adding things later

The layout was chosen so the **root belongs to nobody**. If `netclab.dev` were
netclab-xp's site, every new idea unrelated to Crossplane would need a move and
would break published links.

Addresses come from two pools: **`netclab.dev/<repo-name>/` belongs to GitHub**,
allocated automatically to any repository with Pages enabled, with no
configuration and no way to opt out — and **everything else belongs to the file
tree here**.

| what you are adding | how | cost |
|---|---|---|
| a project (tool, lab, chart) | new repository + Pages | **zero** — it appears at `netclab.dev/<repo>/` |
| a page, guide or index | a directory here | **zero** — one commit |
| something that must live apart | a subdomain | real, see below |

⚠ **A subdomain is not an extra address, it is a swap.** It needs its own grey
record — dropping it out of the wildcard and losing rule 3 — and the repository
must claim the name with its own `CNAME`, **which takes it out of the
`netclab.dev/<repo>/` pool**. Worth it only when something genuinely has to be
separate.

**The real constraint is editorial, not technical.** URLs will take anything;
the landing page is what has to. Written as "netclab = Crossplane for networks",
the next subject fits technically and jars editorially — ending in either
rewriting the root or exiling the subject to a subdomain for no better reason
than that it did not fit the copy. So the root is written as **an index of
things**, not a manifesto for one technology.

Two consequences: **repository names are public addresses**, so naming one is a
URL decision; and **a repository name must not collide with a directory here**,
or vice versa — `slides` in both places is a fight over `/slides/`. Which side
wins has not been tested and does not need to be.

### Addresses that still name the old host

The old `netclab.github.io/<repo>/` addresses redirect and things follow the
redirect — measured 2026-08-06: ArtifactHub has ingested all 15 chart versions
through it while still holding the old URL. So these are drift, not breakage:

- `netclab-chart/README.md` — the `helm repo add` line
- `netclab-chart/.github/workflows/release-on-tag.yaml` — the generated `index.html`
- the ArtifactHub repository URL, which answers `helm search hub`

The middle one is the only risky edit: a failure in a release workflow happens
*after* the tag. Let it ride along with the next real change to that file.

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
  npx --yes @marp-team/marp-cli@4.5.0 --html slides/<name>/index.md \
    --images png -o /tmp/check.png
  ```
