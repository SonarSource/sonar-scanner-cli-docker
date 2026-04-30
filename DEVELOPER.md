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

The QA process is handled on `.cirrus.yml`, which is responsible for the following:

- linting the Dockerfile to make sure it complies with best practices
- build the image
- test the image by running a scan on a sample project
- run scans to find potential vulnerabilities

## Releasing

Releases are triggered manually through the `Release` workflow (`.github/workflows/release.yml`).

### How to release

1. Go to the [Release workflow](../../actions/workflows/release.yml) on GitHub Actions.
2. Click **Run workflow** and select the branch to release from (see [Branch to dispatch from](#branch-to-dispatch-from) below).
3. Provide the `tag_name` input in the format `{major}.{minor}.{patch}.{build}_{scanner_major}.{scanner_minor}.{scanner_patch}` (e.g. `4.8.0.2699_6.2.1`).

The workflow validates the tag format, creates and pushes the git tag at HEAD of the dispatched branch, generates the SBOM, promotes the staged Docker image, pushes it to Docker Hub, and finally publishes the GitHub release.

### Branch to dispatch from

The git tag is created at HEAD of the branch the workflow is dispatched from. Choose the branch accordingly:

- **Latest release**: dispatch from `master`.
- **Maintenance release on a long-lived branch** (e.g. `branch-4.8`): dispatch from that `branch-*` branch, **not** from `master`. Dispatching from `master` would tag a commit that does not belong to the maintenance line.

### Recovering from a failed release

If the workflow fails after the git tag has been pushed, re-dispatching with the same tag will fail at the pre-flight check. To recover:

1. Delete the tag from the remote: `git push origin :refs/tags/<TAG_NAME>`
2. If a draft GitHub release was created for that tag, delete it from the [Releases page](../../releases) before re-dispatching.
