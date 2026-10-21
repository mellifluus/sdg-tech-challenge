# AI Prompts Log

Every prompt given to the AI assistant (Claude Code, model Claude Opus 5.5) during this
challenge, in chronological order. Expand each entry to see the prompt and the answer.

| # | Topic |
|---|-------|
| 1 | Repo bootstrap & AI-usage rules |
| 2 | Common Docker labels |
| 3 | README architecture graph |
| 4 | Terraform heredoc syntax |
| 5 | Creating the bucket in one command |
| 6 | MinIO bootstrap review |
| 7 | MinIO bootstrap follow-up |
| 8 | PostgreSQL bootstrap & REVOKE/GRANT |
| 9 | Root Makefile |
| 10 | Integration test script |
| 11 | Test follow-up |
| 12 | Storage persistence options |
| 13 | Layered state review |
| 14 | Prometheus tests & suggestions |
| 15 | Monitoring network isolation plan |
| 16 | Isolation review & graph update |
| 17 | PROMPTS.md readability |
| 18 | Grafana dashboard & alerts |
| 19 | Grafana in `make credentials` |
| 20 | Missing Grafana home dashboard |
| 21 | Grafana tests & graph |
| 22 | Persistence test & CI pipeline |
| 23 | Airflow requirements & graph rule |
| 24 | Airflow volumes |
| 25 | cryptography "Illegal instruction" |
| 26 | Passwords file permission denied |
| 27 | Airflow tests & graph |
| 28 | Connectivity check DAG |
| 29 | Airflow DAG tests |
| 30 | StatsD mapping for Airflow |
| 31 | Airflow Grafana dashboard & alerts |

---

<details>
<summary><strong>#1 · Repo bootstrap & AI-usage rules</strong></summary>

> **Prompt**
>
> Bootstrap a git repo called sdg-tech-challenge for this tech challenge: "/Users/massi/Downloads/_SDG Data Infrastructure - Prova Tecnica Engineer - Semplificata.pdf". Point remote to the same repo name, by "mellifluus". Pin the latest stable Terraform version in a .terraform-version file for tfenv users. Create a CLAUDE.md file concisely explaining the challenge and acceptance criterias. AI use is allowed, but needs to be documented. Create a PROMPTS.md file which shows all prompts made in this project ( including this one ) as expandable dropdowns that show your answers. Also set this rule in CLAUDE.md.

**Answer**

Read the challenge PDF (Italian), then:

- Initialised a git repo on `main` with remote `origin` →
  `https://github.com/mellifluus/sdg-tech-challenge.git` (HTTPS, matching the user's other repos).
- Pinned Terraform **1.16.6** (latest stable per HashiCorp's checkpoint API and `tfenv list-remote`)
  in `.terraform-version`.
- Created `CLAUDE.md` summarising the challenge (Terraform + Docker orchestrating MinIO and
  PostgreSQL), the acceptance criteria as a checklist (MinIO on ports 9000/9001, persistent
  storage, `data-bucket` bucket, PostgreSQL for orchestrator metadata + destination data,
  single-command deploy), the nice-to-haves (CI/CD, monitoring, volume persistence), and the
  rule to log every prompt in `PROMPTS.md`.
- Created this `PROMPTS.md`.
- Added a Terraform `.gitignore` (state files, `.terraform/`, `*.tfvars`) so state and secrets
  are never committed.

Nothing was committed or pushed; the GitHub repo `mellifluus/sdg-tech-challenge` still needs to
be created on GitHub (the `gh` CLI isn't installed) before the first push.

</details>

---

<details>
<summary><strong>#2 · Common Docker labels</strong></summary>

> **Prompt**
>
> Does it make sense to set up common labels on each thing this repo spawns in Docker as a fallback for corrupted state or for maybe automate testing later? Answer concisely, no hard examples.

**Answer**

Yes, it's worth doing. It costs little and pays off in a few ways:

- **Recovering from a lost or corrupted state.** Filtering on one project label shows every
  container, network and volume this repo created. You can then either bring each one back under
  Terraform with `terraform import` or delete the leftovers cleanly. The labels don't replace
  state; they make it easy to find what has fallen out of it.
- **Testing and CI.** Smoke tests and pipeline checks can find components by role (for example
  "the object store") instead of relying on hard-coded container names.
- **Monitoring.** Prometheus Docker service discovery and cAdvisor can pick targets up from
  labels, which ties in with the monitoring nice-to-have.
- **Keeping it separate from other Docker work.** It's clear which containers belong to this
  project and which are unrelated local experiments.

Things to watch out for:

- **Keep label values fixed.** The Docker provider can't update labels on volumes and networks
  in place. Changing a label means Terraform destroys and recreates the resource, and for a
  volume that loses its data, which breaks the persistence goal. Don't put changing values like
  timestamps or git SHAs in labels.
- **Labels must be added to each resource.** The Docker provider has no equivalent of AWS
  `default_tags`. Define the label set once in `locals.tf` and add it to every resource with a
  `dynamic "labels"` block.
- **Use only a few labels.** Project, component and managed-by cover all the uses above.

</details>

---

<details>
<summary><strong>#3 · README architecture graph</strong></summary>

> **Prompt**
>
> can you please, on a new README.md file, mantain a mermaid graph of the stack while I work? for now you can just draw a big bounding box representing Docker, and two other bounding boxes inside, representing the sdg-data and sdg-monitoring "networks". add a rule to CLAUDE.md to also check if the graph needs updating on each prompt.

**Answer**

- Created `README.md` with a Mermaid `flowchart`: an outer `Docker` subgraph containing two
  (still empty) subgraphs, `sdg-data network` and `sdg-monitoring network`.
- Added an "Architecture graph rule" to `CLAUDE.md`: on every prompt, check whether the changes
  (containers, networks, volumes, ports, connections) require updating the graph, and update it
  if so.

</details>

---

<details>
<summary><strong>#4 · Terraform heredoc syntax</strong></summary>

> **Prompt**
>
> please remind me of the multiline string syntax in terraform. like the classic UNIX one

**Answer**

Terraform uses heredoc syntax:

```hcl
value = <<EOT
line one
line two
EOT
```

Use `<<-EOT` to strip the common leading indentation, so the body and closing marker can be
indented with the surrounding code. `${...}` interpolation works inside both forms.

</details>

---

<details>
<summary><strong>#5 · Creating the bucket in one command</strong></summary>

> **Prompt**
>
> so the challenge states everything needs to be provisioned in one command. that basically means that using the minio provider to create the required data bucket is out of the question. is there any way to run a startup job or similar that fails the terraform apply if it doesn't succeed? if so, what should i search for? if not, any advice?

**Answer**

The minio provider is not ruled out. Terraform can configure a provider from resources in the
same config. The problem here is `random_password`: the minio provider's password is unknown at
first plan, which providers handle badly. A static endpoint plus `depends_on` would otherwise
work in one apply.

Yes, a startup job that fails the apply is possible. Two options:

1. **One-shot `minio/mc` container (recommended).** Run a `docker_container` with
   `command = ["sh", "-c", "mc alias set local http://minio:9000 $USER $PASS && mc mb --ignore-existing local/data-bucket"]`,
   `attach = true`, `must_run = false` and `logs = true`. The provider does not fail on a
   non-zero exit by itself. Add `lifecycle { postcondition { condition = self.exit_code == 0 } }`
   so it does. MinIO must be ready first: give it a `healthcheck`, and use `wait = true` on the
   MinIO container (or a retry loop in the script).
   Search for: *kreuzwerker docker_container attach exit_code*, *terraform lifecycle
   postcondition*, *docker_container wait healthcheck*.
2. **`terraform_data` + `local-exec` provisioner** that runs `docker exec <minio> mc mb ...`.
   A non-zero exit fails the apply. It needs the docker CLI on the host and is less declarative.
   Search for: *terraform_data local-exec provisioner*.

To re-run the job on rebuilds, add `replace_triggered_by` pointing at the MinIO container.

</details>

---

<details>
<summary><strong>#6 · MinIO bootstrap review</strong></summary>

> **Prompt**
>
> finally managed to make the bootstrap job for minio work. is there anything worth adding there?

**Answer**

Reviewed `modules/minio/bootstrap.tf` and `bootstrap.sh.tftpl`. The design is solid. Suggestions,
most important first:

1. **Re-runs probably break on `policy attach`.** `mc admin policy attach` fails with "policy
   change is already in effect" when the policy is already attached. That happens whenever the
   job runs again against a persisted volume (MinIO container replaced, bucket list changed).
   With `set -e` the apply then fails. Tolerate that case only:
   `mc admin policy attach ... || mc admin user info local "${app_user}" | grep -qw ${policy_name}`.
   Test with `terraform apply -replace=module.minio.docker_container.minio`.
2. **Bound the wait.** `mc ready local` can block forever and hang the apply. Use
   `timeout 120 mc ready local`.
3. **A failed job may stay failed.** The exited container is saved in state, so the next plan
   likely fails the postcondition again without re-running it. Add the fix to the error message:
   `terraform apply -replace=module.minio.docker_container.bootstrap`.
4. **Self-validate the requirement.** End with `mc stat local/data-bucket` (or loop `mc stat`
   over the buckets) so the job also proves the acceptance criterion.
5. **Credentials in env.** The exited container keeps the root credentials in its env
   (`docker inspect`). For a local setup this is acceptable. You could upload an
   `mc` config file instead.
6. Minor: typo `creatig`. `MINIO_ENDPOINT` is only echoed; use the module's internal endpoint
   in one place. Run `terraform fmt` (alignment in `main.tf`). shellcheck does not see
   `.tftpl` files.

Optional: enable versioning on `data-bucket` (`mc version enable`), and add a MinIO
`healthcheck` for the monitoring nice-to-have.

Also updated the README Mermaid graph: MinIO container, data volume, bootstrap job, host ports.

</details>

---

<details>
<summary><strong>#7 · MinIO bootstrap follow-up</strong></summary>

> **Prompt**
>
> addressing feedback. 1. tried running terraform apply -replace=module.minio.docker_container.minio after a full apply but everything succeded. are you saying it will break when i add storage persistence? 2. the image doesn't ship with timeout. added a timeout to the bootstrap resource in terraform. should work the same, right? 3. i don't understand your feedback. 4. i plan to add smoke tests later, no need 5. that's alright for this challenge. also added versioning with a variable, looks good?

**Answer**

1. **The earlier claim was wrong.** Persistence already works: `sdg-minio-data` is a named
   volume and survives the replace. Re-ran the existing job with `docker start -a
   sdg-minio-bootstrap` against the existing data. `policy attach` succeeds when the policy is
   already attached, and the job exits 0. Nothing to change.
2. **Mostly the same.** The `timeouts.create` deadline covers the provider waiting on the
   attached container. Differences: the error is a deadline error, not your postcondition
   message, and the timed-out container keeps running. Terraform should mark it tainted, so the
   next apply replaces it. To test, point `MC_HOST_local` at a wrong host for one apply. Also
   remove the trailing whitespace on the blank line before `timeouts` (pre-commit will flag it).
3. **Clarified.** A job that exits non-zero is still created and saved in state. The open
   question is what the next `terraform apply` does when nothing in the config changed:
   - The container is tainted: it gets replaced and the job re-runs. Fine.
   - It is not tainted: the postcondition fails again at plan time from the saved
     `exit_code`, and the job never re-runs. Then you need `-replace`.

   Not sure which one Terraform 1.16 does. Test: add `exit 1` to the script, apply (fails),
   then run `terraform plan`. If the plan says "tainted, must be replaced", drop this point.
4. / 5. Noted.

**Versioning:**
- **Bug:** `main.tf` does not pass `bucket_versioning = var.minio_bucket_versioning`, so the
  root variable is ignored and the module default (`true`) always applies. Pass it, and remove
  the module default so it matches the other module inputs.
- Setting it to `false` later does not turn versioning off, because the script only enables it.
  Add `%{ else ~}` + `mc version suspend "local/$${bucket}"` so the flag is applied both ways.
  (A MinIO bucket can only be suspended, never set back to unversioned.)
- Optional: with versioning on, every overwrite and delete keeps the old version. A lifecycle
  rule (`mc ilm rule add --noncurrent-expire-days N`) stops the storage from growing without
  limit.

No graph change needed.

</details>

---

<details>
<summary><strong>#8 · PostgreSQL bootstrap & REVOKE/GRANT</strong></summary>

> **Prompt**
>
> i went for a bootstrap job for postgresql too. it had the same issue as minio - first plan would fail. i added two lines at the end of the for database loop, that I found in an old project where I was studying database hardening. I'm not sure what they do, would be great if you explained and told me if they make sense here

**Answer**

**`REVOKE ALL ON DATABASE "x" FROM PUBLIC;`**
`PUBLIC` means every role, including roles created later. When Postgres creates a database, it
gives `PUBLIC` the `CONNECT` and `TEMPORARY` privileges on it by default. So without this line,
the `orchestrator` user can log in to `warehouse` and the other way round. This line removes
that default. After it, only the owner and superusers can connect.

**`GRANT CONNECT, TEMPORARY ON DATABASE "x" TO "x";`**
This gives those two privileges back to the database's own role. It changes nothing in
practice: the role owns the database (`CREATE DATABASE ... OWNER`), and an owner already has
every privilege on its database. It is harmless and documents intent. Keep it if you like
being explicit, or drop it.

**Do they make sense here?** Yes. They give least privilege between the two tenants: the
orchestrator's metadata and the warehouse data share one instance, but each user can only
reach its own database. Both statements are idempotent, so re-running the job is safe. One
thing to remember: when the orchestrator runs pipelines that write to the warehouse, it must
use the **warehouse** credentials, not its own role.

Graph updated: added the `postgres` and `postgres-bootstrap` containers, the `sdg-postgres-data`
volume and host port 5432.

</details>

---

<details>
<summary><strong>#9 · Root Makefile</strong></summary>

> **Prompt**
>
> can you create a makefile at the root of the project? it should have all the classics like .PHONY, help etc and make it easier for me to just run terraform commands from the root of the project. also lint, fmt, and possibly a make credentials command that prints out all the credentials that i need to test this

**Answer**

Added a root `Makefile` that runs Terraform with `terraform -chdir=terraform`, so you can run every
command from the repository root. Running `make` with no target prints the help.

| Target | What it does |
|---|---|
| `init` / `validate` / `plan` / `apply` / `destroy` / `output` | Runs the Terraform command of the same name. Extra flags go in `ARGS="..."` |
| `up` / `down` | Runs `apply` or `destroy` with `-auto-approve` (the single-command deploy) |
| `credentials` | Prints the MinIO URLs, users and passwords, and the password of each Postgres role, read from `terraform output -json` with `jq`. If nothing is deployed yet, it tells you to run `make up` first |
| `fmt` / `fmt-check` | Runs `terraform fmt -recursive`. `fmt-check` only reports and suits CI |
| `lint` | Runs `fmt-check`, then `validate`, then `tflint --recursive` with the repository's `.tflint.hcl` |
| `pre-commit` | Runs all pre-commit hooks on every file |
| `clean` | Deletes the `.terraform/` directories but keeps the state |

The `credentials` target needs `jq`. `shellcheck` is not installed locally, so the pre-commit
shellcheck hook relies on the pip-installed copy.

No graph change needed.

</details>

---

<details>
<summary><strong>#10 · Integration test script</strong></summary>

> **Prompt**
>
> i wanna add some sort of automated testing that could also run on a ci/cd environment. i was thinking of a shell script, that uses the mc client image and the postgres image to test everything works. i added them to the tf outputs. we should test the following:<br>
> MinIO: api and web console healthcheck, check data-bucket exists and versioning is on, make app user upload some fixture to the data-bucket ( you just add some sample data to the repo ) and check the data is in the bucket afterwards. finally, check app user privileges like creating other buckets.<br>
> PostgreSQL: healthcheck, check connection with each user of each database and check connections of each user to the other database.<br>
> e2e: create a new table in the warehouse database, if it doesn't exist. stream the fixture out of the bucket, put the data in the table, finally check it exists.<br>
>
> i think im covering everything. everything is up currently, so you can probably test while you go. if im missing something, ask before adding and let's discuss about it

**Answer**

Added `tests/run.sh`, `tests/fixtures/orders.csv` (10 orders) and a `make test` target. Ran it against the live stack: **16 passed, 0 failed**. A second run also passed, so the script is idempotent.

The script reads all its config from `terraform output -json`. It runs `mc` / `psql` in throwaway
containers on `sdg-data` and passes secrets by env var name only. The exit code is the number of failed checks.

- **MinIO**: `curl` against the published ports (`/minio/health/ready` on 9000, `/` on 9001),
  bucket exists, `versioning.status == Enabled`, app user `mc pipe`s the fixture, then root
  `mc cat`s it back and the sha256 is compared on the host. Checks that the app user is denied `mc mb` and `mc admin`.
- **PostgreSQL**: `pg_isready`, plus a 2×2 matrix: each role can connect to its own DB and is denied the other. I confirmed the denials fail with "permission denied for database" and "Access Denied", not with some unrelated error.
- **E2E**: `CREATE TABLE IF NOT EXISTS e2e_orders`, then `mc cat | psql -1 -c TRUNCATE -c "\copy … FROM pstdin"`. That is one
  transaction, so re-runs don't duplicate rows. Then it compares `count|sum(qty*price)` with values computed from the CSV using awk.

Notes:
- Only `mc_image` was in the outputs, so I added a `postgres_image` output.
- Coreutils inside the Chainguard mc image (`ls`, `cat`, `wc`, `head`) crash with *Illegal instruction* on
  this machine (arm64). `mc` works, so the script only runs `mc` in that container and computes checksums on the host.

Open points to discuss (not added):
1. **Cleanup**: the fixture stays in the bucket, and with versioning on, each run adds a version. The app user can't delete versions, because the policy has no `s3:DeleteObjectVersion`.
2. **Persistence test**: destroy/recreate containers and check the data survives (nice-to-have).
3. **CI workflow**: the script is CI-ready, but no GitHub Actions file was written.

Graph updated: added an ephemeral `tests/run.sh` node with dashed edges to MinIO and PostgreSQL, plus a Testing section in the README.

</details>

---

<details>
<summary><strong>#11 · Test follow-up</strong></summary>

> **Prompt**
>
> thanks. about cleanup, it is fine. the tests are just for demo purposes and this is definitely not production stuff. about 2 and 3, i'll do everything later.

**Answer**

No changes. The fixture and its old versions stay in `data-bucket`. The persistence test and CI workflow are left for later.

No graph change needed.

</details>

---

<details>
<summary><strong>#12 · Storage persistence options</strong></summary>

> **Prompt**
>
> i'm now at the point where i want to implement some sort of mechanism to persist the storage layer ( probably also networks and credentials ). currently you either apply everything or destroy everything. i was thinking of putting the volumes on a separate state; but the challenge says everything should be up with one command and i'm interpreting it as a single terraform apply. my second option is a variable, passed on apply. something like services_enabled, that when false basically tears everything down except for volumes networks and credentials. wdyt? is there any other option/advice you can give me?

**Answer**

Advice only, no code changes.

**First, check what the requirement actually asks.** The nice-to-have says data survives *container* destroy/recreate. Named volumes already do that: `terraform apply -replace=module.postgres.docker_container.postgres` or an image bump keeps the data. You may only need a test for it. Surviving a full `terraform destroy` goes beyond the requirement.

**If you want more than that, here are the options:**

1. **Separate state (recommended).** Split into two roots: `foundation/` holds the networks, volumes and `random_password`s; `platform/` holds the images, containers and bootstrap jobs. `platform/` reads `foundation/` through `terraform_remote_state` (local backend) or `docker_*` data sources by name. "Single command" means `make up` (apply foundation, then platform), not a single `terraform apply`. Reviewers will accept a Makefile/CI entrypoint. Then `make down` destroys only `platform/`, and `make nuke` destroys both in reverse order. This is the standard layered-state pattern (stateful and stateless resources have different lifecycles). It also makes a good point to write up in the README.
2. **`services_enabled` variable with `count` on the modules.** It works, but there are problems. A plain `terraform destroy` still deletes everything, so the protection only holds if people remember the flag. "Destroy by apply" is unusual. And `count` changes every resource address (`module.x[0]`), which needs `moved` blocks.
3. **`lifecycle { prevent_destroy = true }` on volumes.** It doesn't keep the data in place. It makes `terraform destroy` fail with an error, so it's a safety net, not a mechanism.
4. **Host bind mounts** (`docker_volume` with `driver_opts = { type = "none", o = "bind", device = abspath(...) }`). This keeps a single state, and the files outlive the volume object. But Terraform no longer fully owns the data, and you need `.gitignore` entries and host-path permissions.

**Gotcha whatever you choose: credentials must persist together with the data.** If `random_password` is regenerated while the PG volume survives, `POSTGRES_PASSWORD` is ignored, because the data dir is already initialized. The new superuser password won't work, and the bootstrap job breaks. MinIO is similar: changing root creds over existing IAM data can cause trouble. Options 1 and 2 handle this if the passwords stay in the persistent layer. Option 4 doesn't.

No graph change needed.

</details>

---

<details>
<summary><strong>#13 · Layered state review</strong></summary>

> **Prompt**
>
> decided to go with option 1. it worked pretty well i think. please update my Makefile and then review my work, first time using terraform_remote_state

**Answer**

**Makefile**: added `LAYERS := foundation platform` and the variables `TF_FOUNDATION` / `TF_PLATFORM`.
- `init` / `validate` / `plan` / `apply` loop over both layers in order.
- `up` applies foundation, then platform.
- `destroy` / `down` destroy only the platform layer, so data is kept.
- New `nuke` target runs `down` first and then destroys foundation.
- `output` / `credentials` read from platform. `fmt` / `lint` / `clean` still work recursively on `terraform/`.
- `ARGS` goes to both layers, so set variables with `TF_VAR_*` instead of `-var`.

**Verified**: `make lint` is clean. Ran `make up` → `make test` (16/16) → `make down` (both volumes kept) → `make up` → `make test` (16/16). Both bootstraps re-run cleanly against the persisted data. With no foundation state, platform fails with a clear "Unable to find remote state" error.

**Review**: the split is clean. Credentials sit in foundation together with the data, remote-state outputs keep `sensitive`, `project_name` has one source, and the relative state path works with `-chdir`. Smaller points:
1. Platform refers to volumes by **name only**. If a volume is missing, Docker silently creates an empty, unlabelled one. `make up` covers this because foundation is applied first and recreates any drifted volume, but a direct `terraform apply` in `platform/` does not.
2. The modules' `volume_name` outputs now only echo their input. They are dead and can be removed.
3. `terraform/foundation/.terraform.lock.hcl` is untracked. Commit it.
4. Rotating a foundation password (e.g. tainting `random_password.postgres["superuser"]`) breaks the bootstrap while the volume survives.
5. `make plan` on a fresh clone fails at platform until foundation is applied. Every layered-state setup has this; at most, worth a line in the README.
6. If you move to a remote backend later, only `data.terraform_remote_state.foundation` needs to change. Both states contain secrets.

Graph updated: networks and volumes are labelled `(foundation)`, and a short paragraph on the two layers was added under the graph.

</details>

---

<details>
<summary><strong>#14 · Prometheus tests & suggestions</strong></summary>

> **Prompt**
>
> added prometheus which scrapes from minio and pg-exporter. anything you would add? maybe add a couple test for prometheus healthcheck?

**Answer**

**Tests** (added to `tests/run.sh`; `make test` now passes 20/20 against the running stack):
- Prometheus `/-/ready` responds.
- Every active scrape target is `up`, checked through `/api/v1/targets`.
- `pg_up == 1`. The exporter's target can be up while the exporter is failing to reach the DB, so this checks the database connection itself.
- `minio_cluster_nodes_online_total == 1`.
- A `poll_eq` helper retries for about 60s, so a fresh `make up` doesn't fail while the first scrape is still pending.

**Suggestions**, most valuable first:
1. **Network isolation**: Prometheus is attached to `sdg-data`, which leaves `sdg-monitoring` mostly unused. Attach MinIO to `sdg-monitoring` instead (Prometheus only needs `:9000`) and keep Prometheus on `sdg-monitoring` only. The exporter is the only thing that needs both networks.
2. **Alert rules**: upload a `rules.yml` with `up == 0`, `pg_up == 0`, MinIO offline nodes / low free disk, and PG connections close to `max_connections`. A test can then check `/api/v1/rules`. Rules without Alertmanager still show up in the UI and make the setup look finished.
3. **Grafana**: provision a Prometheus datasource and dashboards from files (PG exporter dashboard 9628, MinIO 13502), with the admin password from `random_password` in foundation. It makes the monitoring part easy to demo.
4. **Drop `--web.enable-lifecycle`**: the config is supplied through `upload`, so a config change already replaces the container. The flag only exposes unauthenticated `/-/reload` and `/-/quit`.
5. **Smaller points**: `prometheus_port` / `scrape_interval` in the module have no `description`. `bootstrap.sql.tftpl` and the `PW_MONITORING` line in `bootstrap.tf` lack a trailing newline / trailing comma (`terraform fmt` won't catch the comma). MinIO metrics are `public`, which is fine because port 9000 binds to `127.0.0.1`, but it's worth one comment.

</details>

---

<details>
<summary><strong>#15 · Monitoring network isolation plan</strong></summary>

> **Prompt**
>
> please apply point 4 for me. about points 2 and 3, i'm planning to add grafana with alerts after this commit. explain and plan point 1 for me please

**Answer**

**Point 4 applied**: removed `--web.enable-lifecycle` from `terraform/modules/monitoring/prometheus.tf`. Ran `make up`, which replaced only the Prometheus container, then `make test`: 20/20 passed.

**Point 1, the problem**: there are two networks, but Prometheus joins both, so the split doesn't isolate anything. Prometheus has an unauthenticated UI on the host and can currently open connections to `postgres:5432` and to any future service on `sdg-data`. The only reason it joined `sdg-data` is to reach MinIO.

**Target layout**: each component joins only the networks it needs.
- `sdg-data`: minio, postgres, bootstraps, postgres-exporter.
- `sdg-monitoring`: prometheus, postgres-exporter, minio (for metrics only), and later grafana.
- The exporter is the controlled bridge to Postgres. It logs in as a `pg_monitor` role with a connection limit.

**Plan**:
1. `modules/minio`: add `variable "monitoring_network" { type = string, default = null }` and a `dynamic "networks_advanced"` that joins it with alias `minio` when it is set. The module still works without monitoring.
2. `platform/main.tf`: pass `monitoring_network = local.foundation.networks.monitoring` to the minio module.
3. `modules/monitoring/prometheus.tf`: remove the `data_network` block from Prometheus. Keep it on the exporter. `minio_target` stays `minio:9000` because the alias resolves on the monitoring network too.
4. Tests: add `expect_fail "monitoring network cannot reach postgres"`, which runs `pg_isready -h postgres` in a container on `sdg-monitoring`. This guards against regressions.
5. README graph: Prometheus loses "(also on sdg-data)", MinIO gains "(also on sdg-monitoring)".

**Caveats**:
- MinIO serves metrics on the same port as the S3 API (9000), so Prometheus can still reach the API. The API needs credentials, so that is acceptable.
- Changing `networks_advanced` forces the MinIO container to be replaced. Data stays in the foundation volume, and the bootstrap re-runs idempotently.
- `internal = true` on `sdg-monitoring` would also cut egress, but Docker can't publish ports from internal-only networks, so `:9090` (and Grafana later) would break.

No graph change for point 4.

</details>

---

<details>
<summary><strong>#16 · Isolation review & graph update</strong></summary>

> **Prompt**
>
> made the changes you planned on the last prompt. check if they make sense, update README graph

**Answer**

**Review**: the changes follow the plan and make sense. `terraform fmt` and `validate` pass. The stack is down, so `make test` was not run.
- MinIO joins `sdg-monitoring` through an optional `dynamic "networks_advanced"` with alias `minio`, so the module still works without monitoring.
- Prometheus is on `sdg-monitoring` only. The exporter is the only container on both networks, and it logs in as the `pg_monitor` role with `CONNECTION LIMIT 5`.
- The `expect_fail` test on `sdg-monitoring` guards the isolation. `pg_stat_statements` is preloaded and created, which matches `--collector.stat_statements`.

Small fixes:
1. In `modules/monitoring/variables.tf`, the `minio_target` description still says "as seen from the data network". It is now the monitoring network.
2. `prometheus_port`, `scrape_interval`, `prometheus_image` and `postgres_exporter_image` have no `description`.
3. `bootstrap.sql.tftpl` still has no trailing newline.
4. `MINIO_PROMETHEUS_AUTH_TYPE=public` has no comment explaining that it is safe because `:9000` is bound to `127.0.0.1`.

**README**: Added prometheus (monitoring network only), postgres-exporter (also on `sdg-data`), the `sdg-prometheus-data` volume, `:9090`, the scrape edges and the `pg_monitor` edge to the graph. MinIO is marked "also on sdg-monitoring". Added back the Prometheus bullet under Testing.

</details>

---

<details>
<summary><strong>#17 · PROMPTS.md readability</strong></summary>

> **Prompt**
>
> can you make PROMPTS.md a bit more readable? idk use spacing or boxes or whatever you see fit

**Answer**

Reformatted every entry. Prompts and answers are unchanged.
- An index table of `# | Topic` at the top.
- The summary is now a short title, `#N · topic`, so the collapsed list is scannable instead of showing the full prompt text.
- Inside each dropdown, the verbatim prompt sits in a quoted **Prompt** box, followed by an **Answer** label.
- `---` separators between entries.

Updated the rule in `CLAUDE.md` to describe the new format. No graph change.

</details>

---

<details>
<summary><strong>#18 · Grafana dashboard & alerts</strong></summary>

> **Prompt**
>
> can you set up a grafana-dashboards.yml and platform-overview.json files @terraform/modules/monitoring/grafana? with alerts possibly. i'll work on the rest

**Answer**

Added three files in `terraform/modules/monitoring/grafana/`:
- `grafana-dashboards.yml` is the file dashboard provider. It reads `/etc/grafana/dashboards`, puts dashboards in the "SDG Platform" folder and blocks UI edits, so Terraform stays the source of truth.
- `platform-overview.json` (uid `sdg-platform-overview`) has four rows. Overview: up/down per service, firing alerts, `data-bucket` objects. MinIO: nodes, capacity, S3 requests, errors and traffic, bucket sizes. PostgreSQL: uptime, connections, cache hit, deadlocks, TPS, DB sizes, rows/s. Prometheus: scrape duration and samples. It has `$datasource` and `$database` variables.
- `grafana-alerts.yml` holds unified alerting rules: target down, `pg_up` = 0, connections > 80%, deadlocks, MinIO node offline, free capacity < 10%, S3 error rate > 5%, and `data-bucket` missing.

To wire it up: provision the Prometheus datasource with `uid: prometheus` (the alerts reference it). Upload the provider yml to `provisioning/dashboards/`, the JSON to `/etc/grafana/dashboards/` and the alerts to `provisioning/alerting/`. The README graph is unchanged because the Grafana container doesn't exist yet.

</details>

---

<details>
<summary><strong>#19 · Grafana in `make credentials`</strong></summary>

> **Prompt**
>
> can you update the make credentials command to show grafana credentials

**Answer**

Added a **Monitoring** section to `make credentials`. It shows the Prometheus URL, Grafana URL, Grafana admin user (from the `monitoring` output) and Grafana admin password (from the sensitive `grafana_admin_password` output). Tested it against mock output JSON. No graph change.

</details>

---

<details>
<summary><strong>#21 · Grafana tests & graph</strong></summary>

> **Prompt**
>
> the grafana dashboards seem to work. add some tests if you deem necessary, then update the graph if needed

**Answer**

Added a **Grafana** section to `tests/run.sh` with five checks:
- `/api/health` responds.
- Anonymous API access gets a 401.
- The Prometheus datasource health check returns OK.
- Dashboard `sdg-platform-overview` exists and is provisioned.
- The number of provisioned `sdg-*` alert rules matches the count in `grafana-alerts.yml`.

Ran it against the live stack: 26 passed, 0 failed. Updated the README graph with the `grafana` container on `sdg-monitoring`, the `sdg-grafana-data` volume, host port `:3000` and the Grafana → Prometheus datasource edge.

</details>

---

<details>
<summary><strong>#22 · Persistence test & CI pipeline</strong></summary>

> **Prompt**
>
> please add a persistence test now.

**Answer**

- **Shared helpers**: moved the config and helpers from `tests/run.sh` into `tests/lib.sh`. Both test scripts source it.
- **`tests/persistence.sh`** (`make test-persistence`) runs in three steps:
  1. Writes a marker to MinIO (object), PostgreSQL (row) and Grafana (annotation), and records a timestamp Prometheus has samples for.
  2. Runs `make down` and `make up`. It checks that no stack container is left after `down`, that the four foundation volumes still exist, and that every container ID is new after `up`.
  3. Reads each marker back, then cleans up.

  It restarts the stack, so `make test` doesn't run it. Local run: 17 passed, 0 failed (`make test` is still 26 passed).

- **README**: added the Testing section. In the graph, the tests node is relabelled to include `persistence.sh`.

</details>

---

<details>
<summary><strong>#23 · Airflow requirements & graph rule</strong></summary>

> **Prompt**
>
> just received an answer to my email about the orchestrator, or if I needed to add one to the stack. the answer was yes, that they removed it from the challenge to simplify it, but to feel free to add it. i'll spend some time to study Airflow and how DAGs work. for now, please add the requirements to CLAUDE.md. you can maybe "invent" some DAG that would make sense in a data, analytics, AI consulting company. also please, add a rule in CLAUDE.md stating that the diagram in README.md should only entail the actual architecture, no tests

**Answer**

- **CLAUDE.md**: added an "Orchestrator (optional extension)" section with the Airflow requirements: Terraform-managed, `LocalExecutor`, metadata in the existing `airflow` DB, output to `warehouse`, MinIO and PostgreSQL connections injected from Terraform, `dags/` mount, a logs volume, Prometheus/Grafana monitoring, and tests. It also lists four example DAGs: `ingest_orders` (MinIO → staging), `sales_kpis_daily` (marts), `data_quality_checks`, and `ml_feature_export` (RFM features as Parquet in MinIO).
- **Graph rule**: the graph must show only the deployed architecture (no tests, CI or tooling). Applied it right away by removing the tests node and its two edges from the README graph.

</details>

---

<details>
<summary><strong>#24 · Airflow volumes</strong></summary>

> **Prompt**
>
> so, i'm going to start setting airflow up. consider me a full beginner on the topic, but i spent some time learning about it. i have a question. i know i will be able to set it up so that it uses the postgres instance as storage for run metadata etc. but does it need a volume for anything else?

**Answer**

Yes, one thing really needs persistent storage: the **logs**. Everything else is in PostgreSQL or comes from the repo.

| What | Where it lives | Needs a volume? |
|---|---|---|
| Run metadata: DAG runs, task states, XComs, connections, users | PostgreSQL (`airflow` DB) | No |
| **Task logs** | Files on disk (`/opt/airflow/logs`) | **Yes.** They are not stored in the DB |
| DAG code | Repo `dags/` folder | A **bind mount** (read-only), not a named volume |
| Plugins / custom config | `plugins/`, `airflow.cfg` | Only if used, as bind mounts too |
| Temp files a task writes | Container filesystem | No. Scratch space only; real output goes to MinIO or `warehouse` |

- **The logs volume must be shared.** With `LocalExecutor`, tasks run inside the scheduler container, so that's where log files get written. The UI (api-server) reads those same files, so mount the same volume in both containers or the UI shows "log not found".
- **Alternative: remote logging to MinIO.** Airflow can upload task logs to an S3 bucket (e.g. `data-bucket/airflow-logs/`), which makes the containers fully stateless. A volume is simpler to start with.

Not a volume, but the same kind of "state" concern: keys like the Fernet key must stay the same across container recreations. Airflow uses that key to encrypt the connection passwords it stores in the DB, so if it changes, the stored connections can no longer be decrypted. Generate it in Terraform (e.g. `random_password`) rather than letting the container make a new one.

The architecture graph needed no update.

</details>

---

<details>
<summary><strong>#25 · cryptography "Illegal instruction"</strong></summary>

> **Prompt**
>
> alright, i've got an issue. the airflow container im running manually just dies on every process or import with logs saying "Illegal instruction". I traced the issue to airflow shipping with the python cryptography package > 47. is creating a light Dockerfile based on the airflow image but installing a lower version of cryptography the way to go?

**Answer**

Yes, a small Dockerfile that extends the official image is the right fix. Extending the image is the method the Airflow docs recommend for changing its packages.

**Emulation is ruled out.** The host and the `apache/airflow:3.3.2` images are all native `arm64`, so the crash isn't from running an amd64 image through emulation. That fits the diagnosis: on Docker Desktop's Linux VM, the cryptography ≥47 wheel likely uses a CPU instruction the virtual CPU doesn't support (root cause not verified).

```dockerfile
FROM apache/airflow:3.3.2
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" "cryptography<47"
```

- **Keep the Airflow version pin in the same `pip install`.** `AIRFLOW_VERSION` is already set inside the image; pinning it stops pip from changing Airflow while it resolves the new cryptography version.
- **Check the result** with `python -c "import cryptography; print(cryptography.__version__)"` and `airflow version` in the built image.
- **Let Terraform build it**, so `make up` stays a single command: the `docker_image` resource's `build { context = ... }` block, plus `triggers = { dockerfile = filesha1(...) }` to rebuild when the Dockerfile changes.
- **Add a comment in the Dockerfile and a line in the README** explaining why the pin exists, and remove it once a fixed cryptography release ships.

The downside is small: one extra build artifact. A custom image will likely be needed anyway for DAG Python dependencies (e.g. `pyarrow`, the Amazon provider), so it's a good place for the pin.

</details>

---

<details>
<summary><strong>#26 · Passwords file permission denied</strong></summary>

> **Prompt**
>
> the airflow api server container creation hangs. the logs say "2026-10-21 09:53:07 PermissionError: [Errno 13] Permission denied: '/opt/airflow/passwords/passwords.json'"
>
> my guess is i need to assign perms to the user trying to access that file. any idea?

**Answer**

The guess is right: it's an ownership problem.

- **Terraform's `upload` writes the file as root.** Docker extracts uploaded files using the owner recorded in the archive (`root`), and creates `/opt/airflow/passwords/` as root too if it doesn't exist yet.
- **Airflow doesn't run as root.** The image runs as the `airflow` user (uid 50000), and the simple auth manager (as far as I know) *rewrites* the passwords file at startup, so it needs write access, not just read. Hence `Errno 13`.
- **The "hang" is a crash loop.** `restart = "unless-stopped"` keeps restarting the crashing api-server, and `wait = true` blocks Terraform for the whole 300s `wait_timeout` because it never reports healthy.

Not verified on a live container (none was running). To confirm: `docker exec <api-server> ls -la /opt/airflow/passwords` during the crash loop.

**A `chown` in the Dockerfile won't fix this**, because the upload happens after the image is built and the file is still owned by root. Simplest fix: have the container write the file itself, as `airflow`, at startup:

```hcl
# api-server only
env = concat(local.env, [
  "SIMPLE_AUTH_PASSWORDS=${jsonencode({ (var.admin_user) = var.admin_password })}",
])
command = ["bash", "-c", <<-EOT
  printf '%s' "$SIMPLE_AUTH_PASSWORDS" > /opt/airflow/passwords.json && exec airflow api-server
EOT
]
```

Then set `AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE=/opt/airflow/passwords.json`. `/opt/airflow` is writable by `airflow`, and the image's entrypoint passes `bash -c` commands through unchanged. The password ends up in an env var, like the DB password already does.

**Related cleanup:** only the api-server uses the passwords file. Remove the `upload` block and don't give this setting to the scheduler or dag-processor, e.g. via a per-service `extra_env`/`command` in `local.services`, or a separate api-server resource.

</details>

---

<details>
<summary><strong>#27 · Airflow tests & graph</strong></summary>

> **Prompt**
>
> i fixed it. assigned permissions to the airflow user in the upload block. everything is currently up and healthy, finally. could you please add a couple tests in run.sh? first check that api, scheduler, and dag processor are all healthy. then check that anonymous api reqs are rejected, then check that the admin user gets an api token. finally update graph

**Answer**

- **`tests/lib.sh`**: added `AIRFLOW`, `AIRFLOW_USER` and `AIRFLOW_PASSWORD` (read from `terraform output`), plus two helpers:
  - `airflow_health <component>` reads `/api/v2/monitor/health`.
  - `airflow_token` posts to `/auth/token` and returns the JWT. It builds the JSON body with `jq`, so special characters in the password are safe.
- **`tests/run.sh`**: new Airflow section with seven checks:
  - The api-server responds.
  - The metadata DB, scheduler and dag-processor report healthy. These are polled, because heartbeats can lag right after `make up`.
  - An anonymous `GET /api/v2/dags` returns 401.
  - The admin user gets a token, and the API accepts it with a 200. That last check is one extra beyond what was asked; it proves the token actually works.
- **README**: the graph now has an Airflow subgraph on `sdg-data` (init, api-server, scheduler, dag-processor), the `:8080` host port, metadata going to PostgreSQL, the scheduler calling the api-server's execution API, and the `sdg-airflow-logs-data` volume. The Testing section has a new Airflow bullet.

Verified: shellcheck is clean, and `make test` passes 33, fails 0.

</details>

---

<details>
<summary><strong>#28 · Connectivity check DAG</strong></summary>

> **Prompt**
>
> i wired the warehouse db and minio bucket via env vars to airflow. the ui says "Connections defined via environment variables or secrets managers are not listed here.
>
> These are resolved at runtime and are not visible in the UI. Learn more in the Airflow documentation."
>
> can you write a manual trigger dag to check connectivity?

**Answer**

Added `terraform/modules/airflow/dags/check_connections.py`: a DAG with `schedule=None`, so it only runs when triggered by hand. It has two tasks that run in parallel:

- **`check_warehouse`** uses `PostgresHook("warehouse")`. It logs the database, user and server version, then creates a temporary table and inserts a row into it to prove it can write. A temp table disappears when the session ends, so nothing is left behind.
- **`check_minio`** uses `S3Hook("minio")`. It checks that the bucket exists, then writes `_smoke/<run_id>.txt`, reads it back, compares the content, and deletes it. The app user's MinIO policy allows put, get and delete.

Verified: the DAG loads into Airflow's DagBag with no import errors inside `sdg-airflow:local`. It has not been run against the stack yet, because the new env vars aren't applied.

**Likely issue:** the `minio` connection has no `endpoint_url`, so `S3Hook` would call real AWS S3. Add `extra = { endpoint_url = "http://minio:9000" }` (or whatever the MinIO internal endpoint is) to that connection's JSON in `local.connections`.

**Graph:** added the two connections from the scheduler, where `LocalExecutor` runs tasks: to MinIO as the app user, and to the warehouse DB.

</details>

---

<details>
<summary><strong>#29 · Airflow DAG tests</strong></summary>

> **Prompt**
>
> could you add tests for the changes from last commit? probably test that the dags get imported and that the check_connections dag runs successfully. we will likely need some retries as airflow pulls the dags and runs thgem

**Answer**

Added an **Airflow DAGs** section to `tests/run.sh`:

- **Registered:** every top-level `dags/*.py` must show up as a DAG with the same name that is not stale and not paused. This is polled for up to 90s, since the dag-processor re-parses every 30s.
- **No import errors:** `/api/v2/importErrors` must be empty. This runs *after* the registration check, because before the first parse there are no errors yet and it would pass by accident.
- **E2E run:** `check_connections` is triggered through the REST API (`logical_date: null`), then its state is polled until it is `success`, for up to 3 minutes.

`tests/lib.sh` changes: `poll_eq` now takes its retry count from `POLL_TRIES` (default 30, so the old behaviour is the same). There is a new `airflow_api <token> <path>` helper, and a new `AIRFLOW_DAGS_DIR` variable.

Verified: shellcheck is clean, and `make test` passes 37, fails 0.

One thing to know: the DAG uses `retries: 1` with the default 5 min `retry_delay`. A failing task would make the poll time out (state `up_for_retry`/`running`) instead of reporting `failed`. The test still fails, and the reason shows in the FAIL message.

**Graph:** no change, since this only touches tests.

</details>

---

<details>
<summary><strong>#30 · StatsD mapping for Airflow</strong></summary>

> **Prompt**
>
> could you make me a statsd-mapping.yml file in the monitoring module that drops the legacy copy of the metrics that bake the ids into their name? and also the histogram settings

**Answer**

Added `terraform/modules/monitoring/statsd-mapping.yml`:

- **Drops** the legacy per-id copies with anchored regex rules, `action: drop`: `ti.start/finish/running/queued/deferred.*`, `dag.<dag>.<task>.*duration`, `dagrun.duration.{success,failed}.<dag>`, `dagrun.schedule_delay|dependency-check.<dag>`, `dagrun.<dag>.first_task_scheduling_delay`, `dag_processing.last_duration|last_run.seconds_ago.<file>`, `pool.*_slots|starving_tasks.<pool>`, `executor.*_slots.<class>`, `operator_{failures,successes}_*`, `task_instance_created_*`, `task_{removed_from,restored_to}_dag.<dag>`, `task.{cpu,mem}_usage.<dag>.<task>`. The tagged copies pass through, and their tags become labels.
- **Histograms:** `observer_type: histogram` by default, with buckets from 10ms to 60s. Longer buckets (up to 1–2h) for `dagrun.duration.*` and `task.*`.

Checked with `statsd-exporter --check-config` (v0.31.0): it passes.

**Graph:** no change, since nothing new is deployed yet.

</details>

---

<details>
<summary><strong>#31 · Airflow Grafana dashboard & alerts</strong></summary>

> **Prompt**
>
> the stack is running. statsd is up and prometheus is scraping metrics. please make a airflow.json grafana dashboard and add some sensible alerts to grafana-alerts.yaml. you can inspect the metrics emitted if needed

**Answer**

I looked at the live `airflow_*` series and their labels in Prometheus, then built both files on those names.

**`grafana/dashboards/airflow.json`** (uid `sdg-airflow`): same style as the platform overview, with `$datasource` and `$dag_id` variables.
- **Overview:** scheduler and DAG processor UP/DOWN (heartbeat counter increasing), DAGs loaded, import errors, successful and failed DAG runs in the time range.
- **DAG runs:** runs finished by outcome (stacked bars), duration p95, running runs, schedule delay.
- **Tasks:** task instances finished by state, task duration p95, executor slots, scheduled → queued latency.
- **Scheduler & DAG processing:** loop and critical-section p95, `default_pool` slots, DAG file parse time, seconds since last parse.

**`grafana-alerts.yml`:** new `sdg-airflow` group with 6 rules.
- Scheduler heartbeat missing (critical).
- DAG processor heartbeat missing (critical).
- DAG import errors (warning).
- DAG run failed, per `dag_id` (critical).
- Tasks starving for pool slots for 10m (warning).
- Executor saturated for 10m: no open slots while tasks are queued (warning).

Two gotchas from the data:
- **New counters:** StatsD counters only appear on their first event, so `increase()` misses a DAG's first failure. The failure queries use `x - (x offset 5m or x * 0)` instead.
- **Parse-time unit:** `dag_processing.last_duration` is sent in seconds, but the exporter treats it as ms and divides by 1000, so that panel multiplies by 1000.

Every query ran successfully against the live Prometheus, and the YAML parses. Not applied yet: `make up` re-uploads the files to Grafana.

**Graph:** no change, since there are no new containers, networks or ports.

</details>
