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
