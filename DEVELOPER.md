# How to build the Docker image

Each major version of the scanner gets its own image in a specific directory.

Eg. to build sonar-scanner 4.x under the image name `scanner-cli`:

```
docker build --tag scanner-cli 4
```

# How to run the Docker image

## On Linux

### With local SonarQube

With a SonarQube (SQ) running on default configuration (`http://localhost:9000`), the following will analyse the project in directory `/path/to/project`:

```
docker run --user="$(id -u):$(id -g)" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

To analyse the project in the current directory:

```
docker run --user="$(id -u):$(id -g)" -it -v "$PWD:/usr/src" sonarsource/sonar-scanner-cli
```

If SQ is running on another port, you can specify it by adding the following to the `docker run` command:

```
-e SONAR_HOST_URL=http://localhost:9010
```

### With SonarQube running in Docker

Create a network and boot SonarQube:

```
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```
# make sure SQ is up and running
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" --user="$(id -u):$(id -g)" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

## On Mac

### With local SonarQube

On Mac, `host.docker.internal` should be used instead of `localhost`.

To analyse the project located in `/path/to/project`, execute:

```
docker run -e SONAR_HOST_URL==http://host.docker.internal:9000 -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

To analyse the project in the current directory, execute:

```
docker run -e SONAR_HOST_URL==http://host.docker.internal:9000 -it -v "$(pwd):/usr/src" sonarsource/sonar-scanner-cli
```

### With SonarQube running in Docker

Create a network and boot SonarQube:

```
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```
# make sure SQ is up and running
docker run -e SONAR_HOST_URL==http://sq:9000 --network="scanner-sq-network" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

# How to publish the Docker image

## Docker-hub official image release

Sonar-scanner-cli is now part of docker hub official images, you can find more details on the release doc [here](./RELEASE.md)

## DEPRECATED release on SonarSource docker hub account

This image was built everyday on master trought the rebuild.yml and pushed to the docker hub SonarSource account [here](https://hub.docker.com/u/sonarsource), this workflow was used to rebuild the image in case a new base image patch was released.

The same workflow was also triggered when a github-release was created. 

We are removing entirely the rebuild workflow, replacing it with sonar-scanner-cli-docker being available as a [docker hub official image](https://docs.docker.com/docker-hub/official_images/). You can find more details on the doc [here](./RELEASE.md)

In the meantime, to allow everyone to use that new repo, we are keeping the release.yml workflow.

# Automatic tests

The qa is splited in two files, `hadolint-analysis.yml` and `qa.yml` which does multiple things:

- linting the dockerfile to make sure it comply with best practices
- build the image.
- test the image by running a scan on a sample-project.
- run a trivy scan to find potential vulnerabilities.
