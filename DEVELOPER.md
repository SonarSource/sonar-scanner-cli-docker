# How to build the Docker image

```bash
docker build --tag scanner-cli-local .
```

## How to run the Docker image

### On Linux with a local SonarQube

With a SonarQube (SQ) running on default configuration (`http://localhost:9000`), the following will analyze the project in the directory `/path/to/project`:

```bash
docker run -it -v "/path/to/project:/usr/src" --network="host" -e SONAR_HOST_URL=http://localhost:9000 scanner-cli-local
```

To analyze the project in the current directory:

```bash
docker run -it -v "$PWD:/usr/src" --network="host"  -e SONAR_HOST_URL=http://localhost:9000 scanner-cli-local
```

### On Linux with SonarQube running in Docker

Create a network and boot SonarQube:

```bash
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```bash
# make sure SQ is up and running
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" -it -v "/path/to/project:/usr/src" scanner-cli-local
```

### On Mac with local SonarQube

On Mac, `host.docker.internal` should be used instead of `localhost`.

To analyze the project located in `/path/to/project`, execute:

```bash
docker run -e SONAR_HOST_URL=http://host.docker.internal:9000 -it -v "/path/to/project:/usr/src" scanner-cli-local
```

To analyze the project in the current directory, execute:

```bash
docker run -e SONAR_HOST_URL=http://host.docker.internal:9000 -it -v "$(pwd):/usr/src" scanner-cli-local
```

### On Mac with SonarQube running in Docker

Create a network and boot SonarQube:

```bash
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```bash
# make sure SQ is up and running
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" -it -v "/path/to/project:/usr/src" scanner-cli-local
```
## Automatic tests

The QA process is handled by GitHub Actions:

- `.github/workflows/hadolint-analysis.yml` lints the Dockerfile to make sure it complies with best practices
- `.github/workflows/build.yml` builds the image and pushes it to the Repox builds registry, tests it by running a
  scan on a sample project (`test/qa.bats`), validates it with Trivy, and analyzes this repository with SonarQube

### Docker image vulnerability validation

The build workflow scans the image identified by `needs.build.outputs.docker-image` in Repox.
The standalone `Trivy analysis` workflow (`.github/workflows/trivy-analysis.yml`) scans the latest
release published to Docker Hub (`sonarsource/sonar-scanner-cli:latest`) Monday–Friday at 01:15 UTC
(`15 1 * * 1-5`). The schedule becomes active once the workflow is merged into the default branch.
It scans the existing published image without rebuilding it and produces the same run summary and
report artifacts as a manual scan. It also supports manually selecting an image, defaulting to
the Docker Hub `latest` tag. Both workflows use `.github/actions/trivy-scan` and `.github/trivy.yaml`.
The release workflow runs independently and does not invoke Trivy or depend on its result.

To trigger an analysis manually, open **Actions → Trivy analysis → Run workflow**, select the branch
containing the scan configuration, and enter the full `image-ref`. For a staged release candidate, use
`repox-sonarsource-docker-builds.jfrog.io/sonarsource/sonar-scanner-cli:<build>`, replacing `<build>` with
the build number from the release tag. The workflow authenticates when scanning Repox and scans that existing image
without rebuilding it. Review the run's result and its `trivy-results` artifact; policy violations fail
only the analysis run and do not block the release workflow.

Before `Trivy analysis` is merged into the default branch, use the existing `Build` workflow's
optional `image-ref` input to validate a published image from the PR branch. This skips building,
integration tests, and SonarQube analysis and runs image validation against that exact reference:

```bash
gh workflow run build.yml \
  --repo SonarSource/sonar-scanner-cli-docker \
  --ref alban/SCANDOCKER-91 \
  -f image-ref=sonarsource/sonar-scanner-cli:12.2.0.4256_8.1.0
```

Omit `image-ref` to keep the normal build-and-validate behavior.

The implementation follows the production mechanism found by searching SonarSource's GitHub organization
for `trivy` and `aquasecurity`, including workflow files. Among the indexed repositories accessible to the
search, [docker-sonarqube's workflow](https://github.com/SonarSource/docker-sonarqube/blob/e53552b18ffc641a8481bb07e6747c8db29624ed/.github/workflows/push_and_pr.yml)
was the production image-validation implementation; other matches were primarily analyzer test corpora,
training reports, and documentation. No shared Trivy action was found in `ci-github-actions`.

The [CVSS evaluator](https://github.com/SonarSource/docker-sonarqube/blob/e53552b18ffc641a8481bb07e6747c8db29624ed/.github/workflows/scripts/evaluate-trivy-report.py)
is adapted from that revision. The policy is:

- Scan OS packages and application dependencies, including Python packages, JARs, and npm packages.
- Enable secret scanning, matching Trivy's defaults used by docker-sonarqube. Secret findings are reported
  in JSON and SARIF; the CVSS evaluator gates vulnerability findings.
- Include vulnerabilities without an upstream fix so they remain visible and enter policy evaluation.
- Prefer NVD CVSS v4, then v3, then v2; otherwise use the highest score from other sources, then Trivy severity.
- Fail on Medium, High, Critical, or Unknown findings. Low and a real CVSS score of zero pass.
- Allow temporary exceptions in `.trivyignore.yaml`, documented with an owner, justification, ticket, and
  `expired_at` date. Trivy applies the exceptions and restores expired findings to the policy evaluation.
  This repository starts with no exceptions; docker-sonarqube's image-specific exceptions are not copied.

Coverage is a superset of docker-sonarqube's Trivy workflow: that workflow scans only OS packages and
ignores unfixed vulnerabilities, while this repository includes application packages and unfixed findings.
Both enable vulnerability and secret scanning, include all severities, including UNKNOWN, expose suppressed findings, refresh the vulnerability
database, and use a ten-minute scan timeout. This repository does not exclude `node_modules`, `vendor`,
or `.git`, and has no vulnerability exceptions enabled by default.

JSON reports include all severity levels and suppressed findings. SARIF and HTML are converted from the
same JSON report. All three reports are uploaded as the `trivy-results` workflow artifact even when the
policy fails. The run summary shows the policy outcome, counts by policy severity, and expandable tables
of the findings that cause failure, including advisory links, installed/fixed versions and CVSS sources.
Up to 200 failing findings are displayed; all findings remain in the artifacts.
The job summary also links to the artifact: download it and open `trivy-results.html` in a browser
for tables of packages, vulnerability IDs, severities, installed/fixed versions, and advisory links.
The HTML uses Trivy's official v0.70.0 template pinned to its release commit. Suppressed findings remain
available in the JSON and evaluator logs; the upstream HTML template lists active vulnerabilities and
does not display secret findings. JSON and SARIF retain the secret results. SARIF results are also
uploaded to GitHub Security for internal PRs, pushes, merge groups, and manual runs; fork PRs retain
the report artifact without attempting the privileged Security upload. The CVSS evaluator determines the
validation result; HTML and GitHub Security may display a different severity based on Trivy's vendor data.

To scan a locally built image with Trivy installed:

```bash
trivy image --config .github/trivy.yaml --format json --output /tmp/trivy-results.json scanner-cli-local
python3 .github/workflows/scripts/evaluate-trivy-report.py /tmp/trivy-results.json
```

## Releasing

Releases are triggered manually through the `Release` workflow (`.github/workflows/release.yml`).

### How to release

1. Go to the [Release workflow](../../actions/workflows/release.yml) on GitHub Actions.
2. Click **Run workflow** and select the branch to release from (see [Branch to dispatch from](#branch-to-dispatch-from) below).
3. Provide the `tag_name` input in the format `{major}.{minor}.{patch}.{build}_{scanner_major}.{scanner_minor}.{scanner_patch}` (e.g. `4.8.0.2699_6.2.1`).

The workflow validates the tag format, creates (or reuses) a draft GitHub release targeting the dispatched commit, generates the SBOM, promotes the staged Docker image, pushes it to Docker Hub, and finally publishes the GitHub release — which is what creates the git tag.

### Branch to dispatch from

The draft release (and, on publish, the git tag) targets HEAD of the branch the workflow is dispatched from. Choose the branch accordingly:

- **Latest release**: dispatch from `master`.
- **Maintenance release on a long-lived branch** (e.g. `branch-4.8`): dispatch from that `branch-*` branch, **not** from `master`. Dispatching from `master` would tag a commit that does not belong to the maintenance line.

### Recovering from a failed release

If the workflow fails before the release is published, re-dispatch with the same tag from the **same commit** so the existing draft is reused. If the dispatch branch has moved, delete the draft from the [Releases page](../../releases) first, then re-dispatch. `workflow_dispatch` cannot target a raw SHA. If the release was already published, the tag and release are immutable — release a new tag instead.
