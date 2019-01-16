ARG BASE_IMAGE="debian"
ARG BASE_IMAGE_TAG="stretch"
FROM ${BASE_IMAGE}:${BASE_IMAGE_TAG}

# Arguments to instantiate as variables
ARG BASE_IMAGE
ARG BASE_IMAGE_TAG
ARG ARCH="amd64"
ARG PLATFORM="linux"
ARG TAG=""
ARG TAG_ROLLING=""
ARG BUILD_DATE=""
ARG IMAGE_VCS_REF=""
ARG VCS_REF=""
ARG FHEM_VERSION=""
ARG IMAGE_VERSION=""

# Re-usable variables during build
ARG L_AUTHORS="Julian Pawlowski (Forum.fhem.de:@loredo, Twitter:@loredo)"
ARG L_URL="https://hub.docker.com/r/fhem/alexa-fhem-${ARCH}_${PLATFORM}"
ARG L_USAGE="https://github.com/fhem/alexa-fhem-docker/blob/${IMAGE_VCS_REF}/README.md"
ARG L_VCS_URL="https://github.com/fhem/alexa-fhem-docker/"
ARG L_VENDOR="FHEM"
ARG L_LICENSES="MIT"
ARG L_TITLE="alexa-fhem-${ARCH}_${PLATFORM}"
ARG L_DESCR="FHEM supplementary Docker image for Amazon alexa voice assistant, based on Debian Stretch."

ARG L_AUTHORS_FHEM="https://github.com/justme-1968/alexa-fhem/graphs/contributors"
ARG L_URL_FHEM="https://fhem.de/"
ARG L_USAGE_FHEM="https://wiki.fhem.de/wiki/FHEM_Connector"
ARG L_VCS_URL_FHEM="https://github.com/justme-1968/alexa-fhem"
ARG L_VENDOR_FHEM="FHEM"
ARG L_LICENSES_FHEM="GPL-2.0"
ARG L_DESCR_FHEM="Amazon alexa voice assistant support for FHEM"

# annotation labels according to
# https://github.com/opencontainers/image-spec/blob/v1.0.1/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.authors=${L_AUTHORS}
LABEL org.opencontainers.image.url=${L_URL}
LABEL org.opencontainers.image.documentation=${L_USAGE}
LABEL org.opencontainers.image.source=${L_VCS_URL}
LABEL org.opencontainers.image.version=${IMAGE_VERSION}
LABEL org.opencontainers.image.revision=${IMAGE_VCS_REF}
LABEL org.opencontainers.image.vendor=${L_VENDOR}
LABEL org.opencontainers.image.licenses=${L_LICENSES}
LABEL org.opencontainers.image.title=${L_TITLE}
LABEL org.opencontainers.image.description=${L_DESCR}

# non-standard labels
LABEL org.fhem.alexa.authors=${L_AUTHORS_FHEM}
LABEL org.fhem.alexa.url=${L_URL_FHEM}
LABEL org.fhem.alexa.documentation=${L_USAGE_FHEM}
LABEL org.fhem.alexa.source=${L_VCS_URL_FHEM}
LABEL org.fhem.alexa.version=${FHEM_VERSION}
LABEL org.fhem.alexa.revision=${VCS_REF}
LABEL org.fhem.alexa.vendor=${L_VENDOR_FHEM}
LABEL org.fhem.alexa.licenses=${L_LICENSES_FHEM}
LABEL org.fhem.alexa.description=${L_DESCR_FHEM}

ENV TERM xterm
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install base environment
COPY ./src/qemu-* /usr/bin/
COPY src/entry.sh /entry.sh
COPY src/ssh_known_hosts.txt /ssh_known_hosts.txt
COPY src/health-check.sh /health-check.sh
RUN echo "org.opencontainers.image.created=${BUILD_DATE}\norg.opencontainers.image.authors=${L_AUTHORS}\norg.opencontainers.image.url=${L_URL}\norg.opencontainers.image.documentation=${L_USAGE}\norg.opencontainers.image.source=${L_VCS_URL}\norg.opencontainers.image.version=${IMAGE_VERSION}\norg.opencontainers.image.revision=${IMAGE_VCS_REF}\norg.opencontainers.image.vendor=${L_VENDOR}\norg.opencontainers.image.licenses=${L_LICENSES}\norg.opencontainers.image.title=${L_TITLE}\norg.opencontainers.image.description=${L_DESCR}\norg.fhem.alexa.authors=${L_AUTHORS_FHEM}\norg.fhem.alexa.url=${L_URL_FHEM}\norg.fhem.alexa.documentation=${L_USAGE_FHEM}\norg.fhem.alexa.source=${L_VCS_URL_FHEM}\norg.fhem.alexa.version=${FHEM_VERSION}\norg.fhem.alexa.revision=${VCS_REF}\norg.fhem.alexa.vendor=${L_VENDOR_FHEM}\norg.fhem.alexa.licenses=${L_LICENSES_FHEM}\norg.fhem.alexa.description=${L_DESCR_FHEM}" > /image_info \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        gnupg \
        locales \
    \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && /usr/sbin/update-locale LANG=en_US.UTF-8 \
    \
    && ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata \
    \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        curl \
        dnsutils \
        inetutils-ping \
        jq \
        lsb-release \
        openssh-client \
        wget \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/*

# Add alexa-fhem app layer
# Note: Manual checkout is required if build is not run by Travis:
#   git clone https://github.com/justme-1968/alexa-fhem.git ./src/alexa-fhem
COPY src/alexa-fhem/ /alexa-fhem.src/

# Add nodejs app layer
RUN if [ "${ARCH}" = "i386" ]; then \
        curl -sL https://deb.nodesource.com/setup_8.x | bash - \
      ; else \
        curl -sL https://deb.nodesource.com/setup_10.x | bash - \
      ; fi \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        build-essential \
        libssl-dev \
        nodejs \
    && npm update -g --unsafe-perm \
    && cd /alexa-fhem.src \
    && npm install -g --unsafe-perm \
    && apt-get purge -qqy \
        build-essential \
        libavahi-compat-libdnssd-dev \
        libssl-dev \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* \
  ; fi

VOLUME [ "/alexa-fhem" ]

EXPOSE 3000

HEALTHCHECK --interval=20s --timeout=10s --start-period=60s --retries=5 CMD /health-check.sh

WORKDIR "/alexa-fhem"
ENTRYPOINT [ "/entry.sh" ]
CMD [ "start" ]
