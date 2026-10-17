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
