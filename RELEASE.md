# Releasing

Docker image release cycle and sonar-scanner-cli product
---
We consider the **docker image** as part of the sonar-scanner-cli **product**. Therefore, it follows the same release process.

Overview
--------

Release of a new version of the official sonar-scanner-cli Docker images is made of several operations, that needs to be done after the release of sonar-scanner-cli itself:

1. bump the version of sonar-scanner-cli in Dockerfiles
3. Update the docker hub sonar-scanner-cli documentation (if applicable)
4. Update Docker Hub's sonar-scanner-cli images
5. add a GIT tag for the new version and create a release on GitHub.

## Important note on github release step 5

Creating a github release will trigger the `release.yml` workflow which will build and push the docker images to the **organisation sonarsource account** on docker hub (see [here](https://hub.docker.com/u/sonarsource)). Which is different from the official image workflow.

This organization release is now **deprecated**, nonetheless we will keep triggering it until it is properly communicated to the users.

One can expect this workflow to follow the SonarSource deprecation model, which means we will stop pushing to the organization account 1 year after the deprecation announcement.

## Tips

Bump the version of sonar-scanner-cli in Dockerfiles
-----------------------------

The version of sonar-scanner-cli is hardcoded in each Dockerfile of this repository and must be updated in master branch.

Update the docker hub sonar-scanner-cli's documentation (if applicable)
-------------------------------

If needed, prepare PR of Docker Hub documentation [https://github.com/docker-library/docs](https://github.com/docker-library/docs)

> Note: Please use your own fork like seen in [this closed PR](https://github.com/docker-library/docs/pull/1660)

To create a good PR:

1. The markdown format must follow a certain standard, otherwise automated tests will fail. You can test with the `markdownfmt.sh` tool included in the repository, for example `./markdownfmt.sh -d sonar-scanner-cli/content.md` will output the diff that would have to be done to make the tests pass. You can use the `patch` command to apply the changes, for example: `./markdownfmt.sh -d sonar-scanner-cli/content.md | patch sonar-scanner-cli/content.md`
2. Verify the Pull Request passes the automated tests (visible in the status of the PR)

To control the generated content of the Docker Hub page, look around in the files in `.template-helpers` of the [`docs` repository][docs]. For example, the "Where to get help" section is customized by a copy of `.template-helpers/get-help.md` in `sonar-scanner-cli/get-help.md`.

Until sonar-scanner-cli is released and the public artifacts are available, keep your PR a draft PR to make it clear it is not ready to be merged yet.

For more and up to date documentation, see https://github.com/docker-library/docs.


Update Docker Hub's sonar-scanner-cli images
-----------------------

In order to update the Docker Hub images, a Pull Request must be created on the [official-images](https://github.com/docker-library/official-images) repository.

To do so you should use your own personal fork

Create a feature branch on the fork:
* `GitCommit` must be updated to this repository master branch's HEAD.
* `Tags` and `Directory` must be added/updated appropriately for each edition
* see https://github.com/docker-library/official-images/pull/8837/files as an example

Until sonar-scanner-cli is released and the public artifacts are available, keep your PR a draft PR to make it clear it is not ready to be merged yet.
* Create the PR [here](https://github.com/docker-library/official-images/compare)
    * If the documentation was updated in the step before, reference that PR in this PR.
* Click on *compare across fork* to be able to use the fork as head repository.


For more and up to date documentation, see https://github.com/docker-library/official-images.


Add a GIT tag for the new version 
----------------

The commit referenced in the DockerHub Pull Request must be tagged with the sonar-scanner-cli version.
