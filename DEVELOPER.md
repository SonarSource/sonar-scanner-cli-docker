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

To analysis the project in the current directory:

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

The [Travis](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker) job building this repository is publishing every successful build of the master branch to the [SonarSource organization](https://hub.docker.com/r/sonarsource/sonar-scanner-cli) on Docker Hub.

Credentials to Docker Hub are provided as Travis environment variables to the build script (coded directly into [`.travis.yml`](.travis.yml)).

The latest version of the scanner is published under the alias `latest`. Each scanner version is published under at least one version alias (`X`, `X.0`, `X.Y`, ...).

# Automatic tests

The [Travis](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker) job builds the docker image for sonar-scanner 4 and tests it against the demo project `sonarqube-scanner` from SonarSource services maintained repository [`sonar-scanning-examples`](https://github.com/SonarSource/sonar-scanning-examples).

For details, see [run-tests.sh](run-tests.sh).

This test is run on any branch. Test is successful if scanner ran and exited with code 0.

To test another version of the scanner, update the script part of [`.travis.yml`](.travis.yml).

[run-tests.sh](run-tests.sh) can also be used on a developer machine with Docker installed.
