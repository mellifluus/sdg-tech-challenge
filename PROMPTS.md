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
