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
The standalone `Trivy analysis` workflow (`.github/workflows/trivy-analysis.yml`) scans an image selected
manually. Both workflows use `.github/actions/trivy-scan` and `.github/trivy.yaml`.
Both also run an offline eMudhra certificate-trust regression check inside the selected image.
The release workflow runs independently and does not invoke these checks or depend on their results.

To trigger an analysis manually, open **Actions → Trivy analysis → Run workflow**, select the branch
containing the scan configuration, and enter the full `image-ref`. For a staged release candidate, use
`repox-sonarsource-docker-builds.jfrog.io/sonarsource/sonar-scanner-cli:<build>`, replacing `<build>` with
the build number from the release tag. The workflow authenticates to Repox and scans that existing image
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
- Include vulnerabilities without an upstream fix so they remain visible and enter policy evaluation.
- Prefer NVD CVSS v4, then v3, then v2; otherwise use the highest score from other sources, then Trivy severity.
- Fail on Medium, High, Critical, or Unknown findings. Low and a real CVSS score of zero pass.
- Allow temporary exceptions in `.trivyignore.yaml`, documented with an owner, justification, ticket, and
  `expired_at` date. Trivy applies the exceptions and restores expired findings to the policy evaluation.
  This repository starts with no exceptions; docker-sonarqube's image-specific exceptions are not copied.

JSON reports include all severity levels and suppressed findings. SARIF is converted from the same JSON report.
Both reports are uploaded as the `trivy-results` workflow artifact even when the policy fails. SARIF results
are also uploaded to GitHub Security for internal PRs, pushes, merge groups, and manual runs; fork PRs retain
the report artifact without attempting the privileged Security upload. The CVSS evaluator determines the
validation result; GitHub Security may display a different severity based on Trivy's vendor data.
The same artifact includes `emudhra-results.txt`, containing the certificate-trust check's output.

To scan a locally built image with Trivy installed:

```bash
trivy image --config .github/trivy.yaml --format json --output /tmp/trivy-results.json scanner-cli-local
python3 .github/workflows/scripts/evaluate-trivy-report.py /tmp/trivy-results.json
```

### Certificate-trust incident checks

The [October 2026 eMudhra incident](https://blog.cloudflare.com/emudhra-certificate-compromise/)
requires checking certificate trust as well as dependency advisories. A clean Trivy report does not
establish that a TLS client rejects compromised intermediate certificates. Python's standalone certifi,
pip's vendored certifi, the OS CA bundle, Java, and Node.js can use different trust stores.

`test/emudhra` contains twelve public TLS certificate chains from the
[incident checker](https://emudhra.we-have-a-problem.com/), their original roots, and offline regression checks.
The Python check verifies the system, standalone certifi, pip-vendored certifi, and Node default CA bundles
with OpenSSL. Java is checked separately using its default `X509TrustManager`, including Java's certificate
blocklist behavior. Node's check tests its exported default CA bundle, not a live Node TLS handshake.
Custom trust configurations supplied by downstream users and certificates downloaded later by analyzers
are outside this check's scope.

The checks fail if any tested store accepts a compromised chain. Each chain must first validate against
the original roots as a positive control. Missing tools, invalid fixture checksums, and expired fixtures
cause errors rather than being interpreted as successful distrust. The container has networking disabled;
neither checker availability nor DNS/TLS interception can make these tests pass. Refresh the fixtures from
the documented source before their leaf certificates expire in May 2027.

Run the same check locally against an existing image:

```bash
set -o pipefail
COPYFILE_DISABLE=1 tar -C test/emudhra -cf - . | docker run --rm -i --network none \
  --entrypoint /bin/sh scanner-cli-local -c '
    set -eu
    work_dir=$(mktemp -d)
    tar -xf - -C "$work_dir"
    python3 "$work_dir/check-trust.py"
  '
```

Updating pip or Homebrew on the developer's machine does not update the image. Rebuild with patched
container packages/base images and redeploy, then rerun these checks against the exact staged image.
Do not disable TLS verification to work around certificate errors.

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
