# AI Prompts Log

Every prompt given to the AI assistant (Claude Code, model Claude Opus 5.5) during this
challenge, in chronological order. Expand each entry to see the answer.

---

<details>
<summary><strong>#1</strong> — Bootstrap a git repo called sdg-tech-challenge for this tech challenge: "/Users/massi/Downloads/_SDG Data Infrastructure - Prova Tecnica Engineer - Semplificata.pdf". Point remote to the same repo name, by "mellifluus". Pin the latest stable Terraform version in a .terraform-version file for tfenv users. Create a CLAUDE.md file concisely explaining the challenge and acceptance criterias. AI use is allowed, but needs to be documented. Create a PROMPTS.md file which shows all prompts made in this project ( including this one ) as expandable dropdowns that show your answers. Also set this rule in CLAUDE.md.</summary>

<br>

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

<details>
<summary><strong>#2</strong> — Does it make sense to set up common labels on each thing this repo spawns in Docker as a fallback for corrupted state or for maybe automate testing later? Answer concisely, no hard examples.</summary>

<br>

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

<details>
<summary><strong>#3</strong> — can you please, on a new README.md file, mantain a mermaid graph of the stack while I work? for now you can just draw a big bounding box representing Docker, and two other bounding boxes inside, representing the sdg-data and sdg-monitoring "networks". add a rule to CLAUDE.md to also check if the graph needs updating on each prompt.</summary>

<br>

- Created `README.md` with a Mermaid `flowchart`: an outer `Docker` subgraph containing two
  (still empty) subgraphs, `sdg-data network` and `sdg-monitoring network`.
- Added an "Architecture graph rule" to `CLAUDE.md`: on every prompt, check whether the changes
  (containers, networks, volumes, ports, connections) require updating the graph, and update it
  if so.

</details>

<details>
<summary><strong>#4</strong> — please remind me of the multiline string syntax in terraform. like the classic UNIX one</summary>

<br>

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

<details>
<summary><strong>#5</strong> — so the challenge states everything needs to be provisioned in one command. that basically means that using the minio provider to create the required data bucket is out of the question. is there any way to run a startup job or similar that fails the terraform apply if it doesn't succeed? if so, what should i search for? if not, any advice?</summary>

<br>

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

<details>
<summary><strong>#6</strong> — finally managed to make the bootstrap job for minio work. is there anything worth adding there?</summary>

<br>

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

<details>
<summary><strong>#7</strong> — addressing feedback. 1. tried running terraform apply -replace=module.minio.docker_container.minio after a full apply but everything succeded. are you saying it will break when i add storage persistence? 2. the image doesn't ship with timeout. added a timeout to the bootstrap resource in terraform. should work the same, right? 3. i don't understand your feedback. 4. i plan to add smoke tests later, no need 5. that's alright for this challenge. also added versioning with a variable, looks good?</summary>

<br>

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
