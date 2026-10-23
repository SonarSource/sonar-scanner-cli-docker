<!-- Sonar Marketing hosts these approved brand assets on its Kentico Kontent CDN (assets-eu-01.kc-usercontent.com). Shared URLs are intentional; consult Marketing before replacing them. -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://assets-eu-01.kc-usercontent.com/ef593040-b591-0198-9506-ed88b30bc023/a23fc7ba-23f0-489a-829d-ed88c0748521/Sonar_Logo_Dark%20Backgrounds.svg">
    <img src="https://assets-eu-01.kc-usercontent.com/ef593040-b591-0198-9506-ed88b30bc023/82c13eba-d95c-4bb8-8007-7ce77c14e043/Sonar_Logo_Light%20Backgrounds.svg" alt="Sonar logo" width="400">
  </picture>
</p>

[![Build Status](https://github.com/SonarSource/sonar-scanner-cli-docker/actions/workflows/build.yml/badge.svg)](https://github.com/SonarSource/sonar-scanner-cli-docker/actions/workflows/build.yml)

<!-- sonar-marketing:start -->
<!-- Marketing maintains this section. For wording changes, consult the relevant Product Marketing Manager (PMM). Repository CODEOWNERS review accuracy and merge changes. -->

# SonarScanner CLI Docker images

This repository contains the source for the official SonarScanner CLI Docker images. The images let projects run SonarQube analysis without installing the scanner directly on the host.

Get the images from [Docker Hub](https://hub.docker.com/r/sonarsource/sonar-scanner-cli), read the [SonarScanner CLI documentation](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/sonarscanner), or learn more about the [SonarQube product family](https://www.sonarsource.com/products/sonarqube/).

<!-- sonar-marketing:end -->

NB: These Docker images are not compatible with C# and Objective-C projects. For C&C++, the docker images are only compatible with [AutoConfig mode](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/languages/c-family/analysis-modes/).

## Usage and configuration

For information on how to use and configure the image, head over to the Docker section of [SonarScanner CLI docs](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/).

## Questions or Feedback

For support questions ("How do I?", "I got this error, why?", ...), please first read the [documentation](https://docs.sonarqube.org) and then head to the [SonarSource forum](https://community.sonarsource.com/). There are chances that a question similar to yours has already been answered.

Be aware that this forum is a community, so the standard pleasantries ("Hi", "Thanks", ...) are expected. And if you don't get an answer to your thread, you should sit on your hands for at least three days before bumping it. Operators are not standing by. :-)

## Contributing

If you would like to see a new feature or report a bug, please create a new thread in our [forum](https://community.sonarsource.com/tags/c/sq/10/none/docker).

Please be aware that we are not actively looking for feature contributions. We typically accept minor improvements and bug fixes.

With that in mind, if you would like to submit a code contribution, please create a pull request for this repository. Please explain your motives to contribute this change: what problem you are trying to fix, what improvement you are trying to make.

## License

Copyright 2015-2025 SonarSource.

Licensed under the [GNU Lesser General Public License, Version 3.0](http://www.gnu.org/licenses/lgpl.txt)


## Certificate trust mitigation

The image temporarily distrusts the emSign ECC Root CA - G3 root through AL2023's native CA blocklist while Amazon's eMudhra fix is pending. Regenerating system trust also updates Corretto's default Java trust store. Node uses the system CA store through `NODE_OPTIONS=--use-openssl-ca`; Python's standalone certifi and pip's vendored bundle are updated independently.

This follows the [Java mitigation guidance](https://ops.java/emudhra) for the affected trust path present in this base. The other affected anchor, AAA Certificate Services, is already absent from the investigated AL2023 stores; alternate cross-signed paths must still be retested when updating the base. Distrusting the root can also reject legitimate certificates issued through that root. Review the mitigation when [Amazon's fixed packages](https://explore.alas.aws.amazon.com/CVE-2026-113470.html) become available. Its DER SHA-256 fingerprint is `86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b`.

Custom or mounted trust stores, overridden Node options, and JREs provisioned by SonarQube Server or Cloud need separate verification. Rebuild and replace existing images/containers to apply this mitigation.
