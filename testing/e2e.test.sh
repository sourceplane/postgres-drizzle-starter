#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, migrates, deploys (dry),
# serves, and reads and writes its database through the page's own query path.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree,
# and that its own plan converges in the right order. This proves it WORKS,
# by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its PR merges), run what
#      `checks.yml` runs on that PR — install with the lockfile the phase
#      placed, render the wrangler fixture (which must change nothing: the
#      render is committed), typecheck, lint, test, build. That landing WAITS
#      on its checks;
#   2. a Postgres of its own on a random port, with Supabase's roles — the
#      database a Supabase project would be: `postgres` a login role WITHOUT
#      superuser or BYPASSRLS, `anon` and `authenticated` with the Data API's
#      default grants (testing/lib/local-postgres.sh) — and a stand-in for the
#      ONE Supabase Management API endpoint the migration runner calls
#      (testing/lib/fake-supabase-api.py), connected as `postgres`;
#   3. the db-migrate lane's own steps, rendered by `orun plan` for a push to
#      main and run IN THE TREE THE RUNNER STAGES for the job: install, build
#      @saas/db, apply — the `profiles` table and row-level security on every
#      table in `public` — then apply again, which must apply nothing, and the
#      pull-request profile's offline plan. The table exists, EMPTY, before
#      the app serves a single request;
#   4. the web lane's own steps for stage, rendered for a pull request (the
#      verify profile carries deploy-dry-run; the deploy profile does not) and
#      run in its staged job tree: install, `verify-app-structure` (the
#      committed wrangler.jsonc must exist BEFORE the build, in a tree with no
#      build output), `build-app` — which re-renders the config from the
#      stage wiring document it is handed, as the deploy does — then
#      `verify-build-output` and `deploy-dry-run`;
#   5. the built Worker under `wrangler dev`, its HYPERDRIVE binding pointed at
#      that Postgres (the binding stubbed to the local database, as Hyperdrive
#      would hand the Worker the Supabase one). Eight concurrent FIRST
#      requests to the page over the empty table: every one renders the table,
#      and the database ends with exactly the three seed rows the page wrote —
#      the write path, raced. Then the component's OWN `smokeCommand`,
#      verbatim; every route the product promises (the page under the
#      product's name, its Open Graph link on the stage origin, the static
#      assets, a 404, and `/api/health`, which only the Worker answers); a row
#      written behind the app's back that the next render reads; and a
#      table emptied behind its back that the next render re-seeds. (wrangler
#      dev's local binding has no query cache; a real Hyperdrive serves a
#      plain read from its cache for up to a minute, which is why the page's
#      read-back after a seed calls NOW() — tests/web holds that query);
#   6. the Data API's view of the same database: every table in `public` has
#      row-level security, and `anon` and `authenticated` — granted everything
#      Supabase grants them — read none of the rows the page wrote and can
#      write none, while the app, as the table's owner and nothing more, just
#      did both.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered tokens, create a real Supabase project and Hyperdrive config
# (Terraform is validated, not applied, in this repository), deploy for real
# and probe workers.dev. That is a bootstrap against a workspace
# (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, psql and a
# PostgreSQL server install (initdb, pg_ctl), and the network for
# `pnpm install` (or a warm store). A few minutes: three installs, two builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"
# shellcheck source=lib/local-postgres.sh
source "$here/lib/local-postgres.sh"

for bin in orun node pnpm python3 git curl psql; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done
pg_bin >/dev/null || { echo "e2e.test.sh needs a PostgreSQL server install (initdb, pg_ctl)" >&2; exit 1; }

scratch="$(mktemp -d)"
pgdir="$(mktemp -d)"
dev_pid=""
api_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So each
# server is started as its own process group (setsid) and the group stopped.
stop_group() {
  local pid="$1"
  [ -n "$pid" ] || return 0
  kill -TERM -- "-$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$pid" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$pid" 2>/dev/null || true
}
cleanup() {
  stop_group "$dev_pid"
  stop_group "$api_pid"
  pg_down "$pgdir"
  [ -n "$pgdir" ] && [ -d "$pgdir" ] && rm -rf "$pgdir"
  [ -n "$scratch" ] && [ -d "$scratch" ] && rm -rf "$scratch"
}
trap cleanup EXIT
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# What checks.yml runs, step for step, read out of the workflow the product
# carries so the two cannot drift: every `run:` of its one job, in order.
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  while IFS= read -r cmd; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done < <(python3 - "$dir/.github/workflows/checks.yml" <<'PY'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
for job in wf["jobs"].values():
    for step in job["steps"]:
        if "run" in step:
            print(step["run"].strip())
PY
)
}

# One job of a plan, written out as the runner would run it: each `run:` step
# (the `use:` actions are setup-node and setup-pnpm, which this machine has)
# as a numbered script, the job's env, and the component path the steps run
# in. Steps are picked BY ID when given, else every `run:` step in order.
extract_job() { # PLAN JOB-ID OUT-DIR [STEP-ID…]
  python3 - "$@" <<'PY'
import json, pathlib, sys
plan, jid, out, *want = sys.argv[1:]
job = next((j for j in json.load(open(plan))["jobs"] if j["id"] == jid), None)
if job is None:
    sys.exit(f"the plan has no job {jid}")
out = pathlib.Path(out); out.mkdir(parents=True)
steps = [s for s in job["steps"] if s.get("run")]
if want:
    by = {s["id"]: s for s in steps}
    missing = [w for w in want if w not in by]
    if missing:
        sys.exit(f"{jid} has no step(s) {missing}")
    steps = [by[w] for w in want]
for i, s in enumerate(steps):
    (out / f"{i:02d}.sh").write_text(s["run"])
    (out / f"{i:02d}.id").write_text(s["id"])
(out / "path").write_text(job.get("path") or ".")
with (out / "env").open("w") as f:
    for k, v in (job.get("env") or {}).items():
        f.write(f"export {k}={json.dumps(v)}\n")
PY
}
run_job() { # STEPS-DIR WORK-TREE ENV LOG-PREFIX
  local steps="$1" work="$2" envname="$3" logp="$4" s id
  for s in "$steps"/[0-9][0-9].sh; do
    id="$(cat "${s%.sh}.id")"
    echo "   ▸ $id"
    if ! (cd "$work/$(cat "$steps/path")" && source "$steps/env" && export ORUN_ENVIRONMENT="$envname" \
          && bash -e "$s") > "$logp-$id.log" 2>&1; then
      echo "FAIL: the lane's $id step" >&2; tail -40 "$logp-$id.log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"

# ── 1. the product's own pull request ──────────────────────────────────────
echo "── 01-product's landing, under the checks its PR waits on"
s01="$(git -C "$tree" rev-parse HEAD~1)"
at01="$scratch/at-01/$repo"
git -C "$tree" worktree add -q "$at01" "$s01"
checks "$at01" "$scratch/checks.log"
dirty="$(git -C "$at01" status --porcelain)"
[ -z "$dirty" ] || { echo "FAIL: the checks changed tracked files — the committed wrangler.jsonc is not the fixture render:" >&2; echo "$dirty" >&2; exit 1; }
echo "   the checks left the tree as committed (wire:fixture rendered the committed wrangler.jsonc)"

# ── 2. a database, and the one API the migration runner calls ──────────────
echo "── a local Postgres and the Supabase Management API stand-in"
pgurl="$(pg_up "$pgdir" "$(free_port)")" || { echo "FAIL: Postgres did not start" >&2; exit 1; }
api_port="$(free_port)"
ref="localproject"
setsid python3 "$here/lib/fake-supabase-api.py" "$api_port" "$pgurl" --ref "$ref" > "$scratch/api.log" 2>&1 < /dev/null &
api_pid=$!
for _ in $(seq 1 30); do curl -s -o /dev/null "http://127.0.0.1:$api_port/" && break; sleep 0.3; done
# Said out loud rather than found later as the runner's bare "fetch failed":
# the stand-in must be up, and stay up, before a lane is pointed at it.
api_up() { kill -0 "$api_pid" 2>/dev/null && curl -s -o /dev/null "http://127.0.0.1:$api_port/"; }
api_up || { echo "FAIL: the Management API stand-in is not answering on :$api_port" >&2; cat "$scratch/api.log" >&2; exit 1; }
echo "   $pgurl; the API on :$api_port"

# The two plans the lanes below run from, each in the product's own tree: a
# push to main at the 01-product commit (the db-migrate lane's APPLY profile),
# and a pull request over the finished product against an empty base (the web
# lane's VERIFY profile, which carries deploy-dry-run, and db-migrate's PLAN).
(cd "$at01" && orun plan --intent intent.yaml --trigger github-push-main --env stage --output "$scratch/plan-main.json") > "$scratch/plan-main.log" 2>&1 \
  || { echo "FAIL: orun plan (push to main)" >&2; tail -15 "$scratch/plan-main.log" >&2; exit 1; }
git -C "$tree" worktree remove --force "$at01"
mkdir -p "$scratch/pr"
git clone -q "$tree" "$scratch/pr/$repo"
prtree="$scratch/pr/$repo"
git -C "$prtree" checkout -q --orphan empty
git -C "$prtree" rm -rqf .
git -C "$prtree" -c user.email=t@example.invalid -c user.name=t commit -qm empty --allow-empty
git -C "$prtree" checkout -q main
(cd "$prtree" && orun plan --intent intent.yaml --trigger github-pull-request --base empty --head HEAD --env stage \
   --output "$scratch/plan-pr.json") > "$scratch/plan-pr.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan-pr.log" >&2; exit 1; }
# This tier runs the orun the product's CI pins, which reads the per-edge
# `modeRules`: on a pull request — which applies and deploys nothing — the
# infrastructure edges that order a push to main are advisory, so no lane
# waits on another. (placement.test.sh checks the push to main's order.)
python3 - "$scratch/plan-pr.json" <<'PY'
import json, sys
jobs = {j["component"]: j for j in json.load(open(sys.argv[1]))["jobs"] if j["environment"] == "stage"}
chain = ["supabase", "cloudflare-hyperdrive", "db-migrate", "web"]
for a, b in zip(chain, chain[1:]):
    ja, jb = jobs[a], jobs[b]
    if ja["id"] in (jb.get("dependsOn") or []) or ja["id"] not in (jb.get("advisoryDependsOn") or []):
        sys.exit(f"FAIL: on a pull request {b}@stage must name {a}@stage as advisory, not wait on it")
print("   pull request: " + " → ".join(chain) + ", every edge advisory")
PY

# ── 3. the db-migrate lane, in its staged job tree ─────────────────────────
echo "── the stage db-migrate lane: install, build @saas/db, apply — then apply again, and the PR's plan"
extract_job "$scratch/plan-main.json" db-migrate.stage.migrate "$scratch/steps-migrate" \
  install-dependencies build-db-package "Migration Apply"
extract_job "$scratch/plan-main.json" db-migrate.stage.migrate "$scratch/steps-migrate-again" "Migration Apply"
extract_job "$scratch/plan-pr.json" db-migrate.stage.migrate "$scratch/steps-migrate-plan" "Migration Plan"
# Staged from the fresh clone (a CI checkout: no build output, no
# node_modules); its migrations are the 01-product commit's, byte for byte.
mwork="$prtree/.orun/runs/e2e/db-migrate.stage.migrate/work"
python3 "$here/lib/stage-job.py" "$prtree" "$mwork"
# The component's secretEnv, as the lane resolves it: the supabase apply's
# published credentials and the brokered access token. SUPABASE_API_URL is
# the one value no lane has — it points the runner at the stand-in.
export SUPABASE_ACCESS_TOKEN=e2e-token SUPABASE_PROJECT_REF="$ref" SUPABASE_DB_PASSWORD=postgres \
       SUPABASE_DB_URL="$pgurl" SUPABASE_API_URL="http://127.0.0.1:$api_port"
api_up || { echo "FAIL: the Management API stand-in stopped before the lane ran" >&2; cat "$scratch/api.log" >&2; exit 1; }
run_job "$scratch/steps-migrate" "$mwork" stage "$scratch/migrate" \
  || { echo "   the stand-in's log:" >&2; tail -20 "$scratch/api.log" >&2; exit 1; }
applied() { python3 -c "import json,sys;t=open(sys.argv[1]).read();print(' '.join(json.loads(t[t.index('{'):t.rindex('}')+1])['applied']))" "$1"; }
want="000_control_baseline 010_profiles 020_row_level_security"
[ "$(applied "$scratch/migrate-Migration Apply.log")" = "$want" ] \
  || { echo "FAIL: the first apply applied '$(applied "$scratch/migrate-Migration Apply.log")', not '$want'" >&2; exit 1; }
echo "   applied $want"
run_job "$scratch/steps-migrate-again" "$mwork" stage "$scratch/migrate-again"
[ -z "$(applied "$scratch/migrate-again-Migration Apply.log")" ] \
  || { echo "FAIL: a second apply applied '$(applied "$scratch/migrate-again-Migration Apply.log")'" >&2; exit 1; }
echo "   a second apply applied nothing (the ledger holds $(psql "$pgurl" -XAtc 'select count(*) from _migrations.applied') migrations)"
table="$(psql "$pgurl" -XAtc "select to_regclass('public.profiles') is not null, (select relrowsecurity from pg_class where oid = to_regclass('public.profiles')), pg_get_userbyid((select relowner from pg_class where oid = to_regclass('public.profiles'))), (select count(*) from profiles)")"
[ "$table" = "t|t|postgres|0" ] \
  || { echo "FAIL: after the migrations profiles should exist, with RLS, owned by postgres, empty — got '$table'" >&2; exit 1; }
echo "   profiles exists before the app serves: row-level security on, owned by postgres, no rows"
run_job "$scratch/steps-migrate-plan" "$mwork" stage "$scratch/migrate-plan"
[ "$(applied "$scratch/migrate-plan-Migration Plan.log")" = "$want" ] \
  || { echo "FAIL: the pull request's offline plan did not verify every migration" >&2; exit 1; }
echo "   the pull request's plan step verifies every migration's checksum offline"
unset SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF SUPABASE_DB_PASSWORD SUPABASE_DB_URL SUPABASE_API_URL
rm -rf "$mwork"

# ── 4. the web lane's steps, for stage ─────────────────────────────────────
echo "── the stage web lane: install, verify-app-structure, build-app, verify-build-output, deploy-dry-run"
extract_job "$scratch/plan-pr.json" web.stage.verify-deploy "$scratch/steps-web" \
  install-workspace-dependencies verify-app-structure build-app verify-build-output deploy-dry-run
work="$prtree/.orun/runs/e2e/web.stage.verify-deploy/work"
# The job's private tree, staged as orun stages it — no build output, no
# node_modules: under stack-tectonic 0.19.0 the job installs inside it.
python3 "$here/lib/stage-job.py" "$prtree" "$work"
[ ! -e "$work/apps/web/.open-next" ] && [ -f "$work/apps/web/wrangler.jsonc" ] \
  || { echo "FAIL: the staged tree is not a fresh checkout with the committed wrangler.jsonc" >&2; exit 1; }
echo "   staged: $(realpath --relative-to="$prtree" "$work") — no build output, the committed wrangler.jsonc"
# The stage wiring document, as the cloudflare-hyperdrive apply publishes it
# and the lane resolves it (secretEnv WIRING_CLOUDFLARE_HYPERDRIVE_STAGE).
hd_id="e2e0000000000000000000000000c0de"
export WIRING_CLOUDFLARE_HYPERDRIVE_STAGE="{\"hyperdrive_id\":\"$hd_id\",\"hyperdrive_name\":\"stg-$repo-stage\"}"
run_job "$scratch/steps-web" "$work" stage "$scratch/web"
unset WIRING_CLOUDFLARE_HYPERDRIVE_STAGE
build_log="$(ls "$scratch"/web-build-app.log)"
grep -q '(Turbopack)' "$build_log" \
  || { echo "FAIL: the staged build did not run on Turbopack" >&2; grep -m3 'Next.js' "$build_log" >&2; exit 1; }
grep -q "\"id\": \"$hd_id\"" "$work/apps/web/wrangler.jsonc" \
  || { echo "FAIL: build-app did not re-render wrangler.jsonc from the stage wiring document" >&2; exit 1; }
[ "$(node -e 'const fs=require("fs");process.stdout.write(String(fs.readdirSync(process.argv[1]).length))' "$work/node_modules")" -gt 0 ] && [ ! -L "$work/node_modules" ] \
  || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
echo "   the staged build ran on Turbopack, inside its own tree, bound to the stage Hyperdrive id it was handed"

# ── 5. serve it over the migrated, empty database ──────────────────────────
echo "── wrangler dev over the built Worker, its HYPERDRIVE binding on the local Postgres"
[ ! -e "$work/apps/web/.dev.vars" ] || { echo "FAIL: the staged tree carries a .dev.vars" >&2; exit 1; }
port="$(free_port)"
(cd "$work/apps/web" && CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE="$pgurl" \
   exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
   --name "$repo-web-stage" --show-interactive-dev-session=false) > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
# Ready when the Worker answers its database check — which reads, and never
# writes, so the page's first request is still to come.
for _ in $(seq 1 90); do
  curl -s -o /dev/null "$url/api/health" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/api/health" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
[ "$(psql "$pgurl" -XAtc 'select count(*) from profiles')" = 0 ] \
  || { echo "FAIL: something wrote to profiles before the page's first request" >&2; exit 1; }

echo "   ▸ eight concurrent first requests to the page, over the empty table"
python3 - "$url" <<'PY' || { echo "FAIL: the concurrent first requests; wrangler dev said:" >&2; tail -40 "$scratch/dev.log" >&2; exit 1; }
import concurrent.futures, re, sys, urllib.request
base = sys.argv[1]
def get(_):
    # React's streamed render separates adjacent text nodes with `<!-- -->`
    # ("Fetched <!-- -->3<!-- --> users"); the text a reader sees has none.
    with urllib.request.urlopen(base + "/", timeout=120) as r:
        return r.status, r.read().decode().replace("<!-- -->", "")
with concurrent.futures.ThreadPoolExecutor(8) as pool:
    results = list(pool.map(get, range(8)))
bad = [(s, re.findall(r"Fetched \d+ users", b)) for s, b in results
       if s != 200 or "Recent Users" not in b or "Fetched 3 users in" not in b]
if bad:
    sys.exit(f"  ✕ {len(bad)} of 8 first requests did not render the three seeded profiles: {bad[:3]}")
print("   all 8 rendered the table with the 3 profiles the page seeded")
PY
rows="$(psql "$pgurl" -XAtc "select count(*) || ' ' || count(distinct email) from profiles")"
[ "$rows" = "3 3" ] || { echo "FAIL: eight racing first requests left '$rows' (rows, distinct emails), not exactly the three seed rows" >&2; exit 1; }
echo "   the database holds exactly the 3 seed rows, written by the page through the binding"

echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the product" >&2; tail -20 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ every route the product promises, and the page reading and writing the database"
python3 - "$url" "$values" "$pgurl" <<'PY' || { echo "FAIL: the routes; wrangler dev said:" >&2; tail -40 "$scratch/dev.log" >&2; exit 1; }
import html, http.client, json, re, subprocess, sys, time, urllib.error, urllib.request
base, values, pgurl = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
name, repo, sub = values["productname"], values["reponame"], values["subdomain"]
problems = []
def bad(m): problems.append(m)

def req(path):
    # A GET whose CONNECTION drops (not one that answers an error) is asked
    # again, twice at most, and says so: `wrangler dev` on a loaded machine
    # has dropped one.
    for attempt in range(3):
        try:
            with urllib.request.urlopen(base + path, timeout=60) as resp:
                return resp.status, {k.lower(): v for k, v in resp.headers.items()}, resp.read()
        except urllib.error.HTTPError as e:
            return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read()
        except (http.client.RemoteDisconnected, ConnectionResetError) as e:
            if attempt == 2:
                raise
            print(f"   (GET {path}: the connection dropped ({e.__class__.__name__}) — asking again)")
            time.sleep(1)
def psql(sql):
    return subprocess.run(["psql", pgurl, "-XAtc", sql], capture_output=True, text=True, check=True).stdout.strip()
def text(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()

# ── the page, under the product's own name ────────────────────────────────
s, _, body = req("/"); page = body.decode().replace("<!-- -->", "")
if s != 200:
    bad(f"/ answered {s}")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or html.unescape(title.group(1)) != name:
    bad(f"the page's <title> is {title and title.group(1)!r}, not {name!r}")
h1 = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
if not h1 or text(h1.group(1)) != name:
    bad(f"the page's heading is {h1 and text(h1.group(1))!r}, not {name!r}")
if "Postgres on Cloudflare" in page:
    bad("the page still carries the baseline's name")
for email in ("rauchg@vercel.com", "lee@vercel.com", "stey@vercel.com"):
    if email not in page:
        bad(f"the page does not list the seeded {email}")
if 'href="https://github.com/vercel/examples/tree/main/storage/postgres-drizzle"' not in page:
    bad("the page's link to the upstream template was renamed")
if f'href="https://github.com/{values["githuborg"]}/{repo}"' not in page:
    bad("the page's source link does not name the product's repository")
og = re.search(r'<meta property="og:image" content="([^"]+)"', page)
want_origin = f"https://{repo}-web-stage.{sub}.workers.dev/"
if not og or not og.group(1).startswith(want_origin + "opengraph-image.png"):
    bad(f"the Open Graph image is {og and og.group(1)!r}, not on the stage origin {want_origin} the build was given")

# ── what only the Worker answers ──────────────────────────────────────────
s, h, body = req("/api/health")
if s != 200 or json.loads(body) != {"ok": True, "database": "reachable", "schema": "migrated"} \
        or h.get("cache-control") != "no-store":
    bad(f"/api/health answered {s} {body[:120]!r} ({h.get('cache-control')})")

# ── the static assets and the not-found page ─────────────────────────────
for path, kind in (("/vercel.svg", "image/svg+xml"), ("/github.svg", "image/svg+xml"),
                   ("/favicon.ico", "image/"), ("/opengraph-image.png", "image/png")):
    s, h, body = req(path)
    if s != 200 or not h.get("content-type", "").startswith(kind) or not body:
        bad(f"{path} answered {s} {h.get('content-type')}")
s, _, _ = req("/no-such-page")
if s != 404:
    bad(f"/no-such-page answered {s}, not 404")

# ── the page reads the database (locally on every request: no Hyperdrive cache)
psql("insert into profiles (name, email, image) values ('Ada Lovelace', 'ada@example.invalid', "
     "'https://images.ctfassets.net/e5382hct74si/x/y/ada.jpg')")
s, _, body = req("/"); page = body.decode().replace("<!-- -->", "")
if s != 200 or "ada@example.invalid" not in page or "Fetched 4 users in" not in page:
    bad(f"a row written behind the app's back is not on the next render ({s})")

# ── …and writes it again when it finds the table empty ───────────────────
psql("delete from profiles")
s, _, body = req("/"); page = body.decode().replace("<!-- -->", "")
if s != 200 or "Fetched 3 users in" not in page:
    bad(f"an emptied table was not re-seeded on the next render ({s})")
if psql("select count(*) from profiles") != "3":
    bad(f"after the re-seed the table holds {psql('select count(*) from profiles')} rows, not 3")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   / as {name!r} (title, heading, Open Graph on {want_origin}), the upstream link kept; "
      f"/api/health; four static assets; a 404; a row added behind its back read on the next "
      f"render, an emptied table re-seeded")
PY

# ── 6. what Supabase's Data API would see ──────────────────────────────────
echo "── the Data API's roles (anon, authenticated) against the same database"
psql "$pgurl" -X -q -v ON_ERROR_STOP=1 -At > "$scratch/rls.out" 2> "$scratch/rls.err" <<'SQL' \
  || { echo "FAIL: the row-level security checks" >&2; cat "$scratch/rls.err" >&2; exit 1; }
SELECT 'app role: superuser=' || rolsuper || ' bypassrls=' || rolbypassrls FROM pg_roles WHERE rolname = current_user;
SELECT 'public tables without RLS: ' || count(*) FILTER (WHERE NOT c.relrowsecurity) || ' of ' || count(*)
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p');
SELECT 'not owned by the app: ' || count(*) FILTER (WHERE pg_get_userbyid(c.relowner) <> current_user)
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p');
SELECT 'app sees profiles: ' || count(*) FROM profiles;
SET ROLE anon;
SELECT 'anon sees profiles: ' || count(*) FROM profiles;
RESET ROLE;
SET ROLE authenticated;
SELECT 'authenticated sees profiles: ' || count(*) FROM profiles;
RESET ROLE;
SQL
sed 's/^/   /' "$scratch/rls.out"
grep -qx "app role: superuser=false bypassrls=false" "$scratch/rls.out" \
  && grep -qE "^public tables without RLS: 0 of [1-9][0-9]*$" "$scratch/rls.out" \
  && grep -qx "not owned by the app: 0" "$scratch/rls.out" \
  || { echo "FAIL: the app's role, the tables' owner or their row-level security is not what Supabase's would be" >&2; exit 1; }
app_rows="$(sed -n 's/^app sees profiles: //p' "$scratch/rls.out")"
[ "${app_rows:-0}" -ge 1 ] || { echo "FAIL: the page wrote no profile the app can see" >&2; exit 1; }
for line in "anon sees profiles: 0" "authenticated sees profiles: 0"; do
  grep -qx "$line" "$scratch/rls.out" || { echo "FAIL: expected '$line'" >&2; exit 1; }
done
# A write through the Data API's roles is refused by row-level security.
for role in anon authenticated; do
  if psql "$pgurl" -X -q -At -c "SET ROLE $role; INSERT INTO profiles (name, email, image) VALUES ('$role', '$role@example.invalid', 'x')" > "$scratch/rls-write.log" 2>&1; then
    echo "FAIL: $role wrote a profile through row-level security" >&2; exit 1
  fi
  grep -q "row-level security" "$scratch/rls-write.log" \
    || { echo "FAIL: $role's write was refused for another reason:" >&2; cat "$scratch/rls-write.log" >&2; exit 1; }
done
echo "   anon and authenticated, granted what Supabase grants them, read $app_rows profile(s) as 0 and write none"

echo "e2e.test.sh: ok"
