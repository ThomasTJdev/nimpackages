# nimpackages

Wupti. I like Nim. Go to [https://nimpackages.com/](https://nimpackages.com/)

![Nim Packages Website Screenshot](screenshot.png)

Nim Packages is a website that lists all Nim packages based on the official package.json containing all indexed Nim packages.

The website allows browsing the packages through the browser, but also provides a REST API.

The packages are updated and indexed every 12 hours.

## Running

```bash
nimble build
./nimpackages
```

### Environment variables

```bash
export HTML_HEAD="custom head"
export GITHUB_TOKEN=...
export GITLAB_TOKEN=...
export CODEBERG_TOKEN=...
```

## Dependencies

The dependencies are located locally in the `nimbledeps` folder.

## CI: Container image

See the Github Actions workflow for the container image. It includes the CI pipeline to compile, generate and publish the container image.
