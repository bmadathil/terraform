# jenkins custom

## Build

Nothing fancy - installing plugins ahead of time to speed things up a bit during deployment. Log in to GitHub container registry, build, and push to GitHub as needed:

```
export GHCR_PAT=YOUR_TOKEN

echo $GHCR_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin

docker build -t ghcr.io/cvpcorp/jenkins:2.461-alpine-jdk17
docker push ghcr.io/cvpcorp/jenkins:2.461-alpine-jdk17
```
