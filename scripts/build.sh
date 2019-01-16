#!/bin/bash
set -e
echo "Building for platform: `uname -a`"
TRAVIS_BRANCH=${TRAVIS_BRANCH:-`git branch | sed -n -e 's/^\* \(.*\)/\1/p'`}
LABEL=${LABEL:-`uname -m`_linux}
echo "TRAVIS_BRANCH = ${TRAVIS_BRANCH}"
echo "TRAVIS_TAG = ${TRAVIS_TAG}"
[[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" ]] && set -x

cd "$(readlink -f "$(dirname "${BASH_SOURCE}")")"/..

BUILD_DATE=$( date --iso-8601=seconds --utc )
BASE="fhem/alexa-fhem-${LABEL}"
BASE_IMAGE="debian"
BASE_IMAGE_TAG="stretch"

# Download dependencies if not existing
if [ ! -d ./src/alexa-fhem ]; then
  git clone --single-branch --branch master https://github.com/justme-1968/alexa-fhem.git ./src/alexa-fhem;
fi
ALEXAFHEM_VERSION="$(cat ./src/alexa-fhem/package.json | jq -r ".version")"
ALEXAFHEM_REVISION_LATEST="$( cd ./src/alexa-fhem; git rev-parse --short HEAD )"

if [[ -n "${ARCH}" && "${ARCH}" != "amd64" ]]; then
  BASE_IMAGE="${ARCH}/${BASE_IMAGE}"
  if [ "${ARCH}" != "i386" ]; then
    echo "Starting QEMU environment for multi-arch build ..."
    docker run --rm --privileged --name qemu multiarch/qemu-user-static:register --reset
  fi
fi

IMAGE_VERSION=$(git describe --tags --dirty --match "v[0-9]*")
IMAGE_VERSION=${IMAGE_VERSION:-1}
IMAGE_BRANCH=$( [[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" && "${TRAVIS_BRANCH}" != "${TRAVIS_TAG}" ]] && echo -n "${TRAVIS_BRANCH}" || echo -n "" )
VARIANT_FHEM="${ALEXAFHEM_VERSION}-g${ALEXAFHEM_REVISION_LATEST}"
VARIANT_IMAGE="${IMAGE_VERSION}$( [ -n "${IMAGE_BRANCH}" ] && echo -n "-${IMAGE_BRANCH}" || echo -n "" )"
VARIANT="${VARIANT_FHEM}_${VARIANT_IMAGE}"

echo -e "\n\nNow building variant ${VARIANT} ...\n\n"

# Only run build if not existing on Docker hub yet
function docker_tag_exists() {
  if [[ "x${DOCKER_USER}" == "x" || "x${DOCKER_PASS}" == "x" ]]; then
    return 1
  fi
  set +x
  TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_USER}'", "password": "'${DOCKER_PASS}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
  EXISTS=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/$1/tags/?page_size=10000 | jq -r "[.results | .[] | .name == \"$2\"] | any")
  [[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" ]] && set -x
  test $EXISTS = true
}
if docker_tag_exists ${BASE} ${VARIANT}; then
  echo "Variant ${VARIANT} already existig on Docker Hub - skipping build."
  continue
fi

# Detect rolling tag for this build
if [[ -z "${TRAVIS_BRANCH}" || "${TRAVIS_BRANCH}" == "master" || "${TRAVIS_BRANCH}" == "${TRAVIS_TAG}" ]]; then
      TAG="latest"
else
  TAG="${TRAVIS_BRANCH}"
fi

# Check for image availability on Docker hub registry
if docker_tag_exists ${BASE} ${TAG}; then
  echo "Found prior build ${BASE}:${TAG} on Docker Hub registry"
  CACHE_TAG=${TAG}
  docker pull "${BASE}:${CACHE_TAG}"
else
  echo "No prior build found for ${BASE}:${TAG} on Docker Hub registry"
fi

docker build \
  $( [ -n "${CACHE_TAG}" ] && echo -n "--cache-from "${BASE}:${CACHE_TAG}"" ) \
  --tag "${BASE}:${VARIANT}" \
  --build-arg BASE_IMAGE=${BASE_IMAGE} \
  --build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG} \
  --build-arg ARCH=${ARCH} \
  --build-arg PLATFORM="linux" \
  --build-arg BUILD_DATE=${BUILD_DATE} \
  --build-arg TAG=${VARIANT} \
  --build-arg TAG_ROLLING=${TAG} \
  --build-arg IMAGE_VERSION=${VARIANT} \
  --build-arg IMAGE_VCS_REF=${TRAVIS_COMMIT} \
  --build-arg ALEXAFHEM_VERSION=${VARIANT_FHEM} \
  --build-arg VCS_REF=${ALEXAFHEM_REVISION_LATEST} \
  .

# Add rolling tag to this build
[ -n "${TAG}" ] && docker tag "${BASE}:${VARIANT}" "${BASE}:${TAG}"

exit 0
