FROM node:15.14.0-buster-slim
ARG TARGETPLATFORM

ENV TERM xterm
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install base environment
COPY src/entry.sh /entry.sh
COPY src/ssh_known_hosts.txt /ssh_known_hosts.txt
COPY src/health-check.sh /health-check.sh

#RUN  sed -i "s/buster main/buster main contrib non-free/g" /etc/apt/sources.list \
#    && sed -i "s/buster-updates main/buster-updates main contrib non-free/g" /etc/apt/sources.list \
#    && sed -i "s/buster\/updates main/buster\/updates main contrib non-free/g" /etc/apt/sources.list \
RUN  DEBIAN_FRONTEND=noninteractive apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
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

ARG ALEXAFHEM_VERSION="0.5.64"

# Add alexa-fhem app layer
RUN if [ "${IMAGE_LAYER_NODEJS_EXT}" != "0" ]; then \
          npm install -g --unsafe-perm --production \
          alexa-fhem@${ALEXAFHEM_VERSION} \
      ; fi \
    && rm -rf /tmp/* /var/tmp/* ~/.[^.] ~/.??* ~/* 

# Add alexa-fhem app layer
COPY src/config.json /alexa-fhem.src/alexa-fhem-docker.config.json

# Arguments to instantiate as variables
ARG TAG=""
ARG TAG_ROLLING=""
ARG BUILD_DATE=""
ARG IMAGE_VCS_REF=""
ARG IMAGE_VERSION=""

# Re-usable variables during build
ARG L_AUTHORS="Julian Pawlowski (Forum.fhem.de:@loredo, Twitter:@loredo)"
ARG L_URL="https://hub.docker.com/r/fhem/alexa-fhem-${TARGETPLATFORM}"
ARG L_USAGE="https://github.com/fhem/alexa-fhem-docker/blob/${IMAGE_VCS_REF}/README.md"
ARG L_VCS_URL="https://github.com/fhem/alexa-fhem-docker/"
ARG L_VENDOR="FHEM"
ARG L_LICENSES="MIT"
ARG L_TITLE="alexa-fhem-${TARGETPLATFORM}"
ARG L_DESCR="FHEM complementary Docker image for Amazon alexa voice assistant, based on Debian Buster."

ARG L_AUTHORS_ALEXAFHEM="https://github.com/justme-1968/alexa-fhem/graphs/contributors"
ARG L_URL_ALEXAFHEM="https://fhem.de/"
ARG L_USAGE_ALEXAFHEM="https://wiki.fhem.de/wiki/FHEM_Connector"
ARG L_VCS_URL_ALEXAFHEM="https://github.com/justme-1968/alexa-fhem"
ARG L_VENDOR_ALEXAFHEM="FHEM"
ARG L_LICENSES_ALEXAFHEM="GPL-2.0"
ARG L_DESCR_ALEXAFHEM="Amazon alexa voice assistant support for FHEM"

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
LABEL org.fhem.alexa.authors=${L_AUTHORS_ALEXAFHEM}
LABEL org.fhem.alexa.url=${L_URL_ALEXAFHEM}
LABEL org.fhem.alexa.documentation=${L_USAGE_ALEXAFHEM}
LABEL org.fhem.alexa.source=${L_VCS_URL_ALEXAFHEM}
LABEL org.fhem.alexa.version=${ALEXAFHEM_VERSION}
LABEL org.fhem.alexa.vendor=${L_VENDOR_ALEXAFHEM}-${TARGETPLATFORM}
LABEL org.fhem.alexa.licenses=${L_LICENSES_ALEXAFHEM}
LABEL org.fhem.alexa.description=${L_DESCR_ALEXAFHEM}

RUN echo "org.opencontainers.image.created=${BUILD_DATE}\norg.opencontainers.image.authors=${L_AUTHORS}\norg.opencontainers.image.url=${L_URL}\norg.opencontainers.image.documentation=${L_USAGE}\norg.opencontainers.image.source=${L_VCS_URL}\norg.opencontainers.image.version=${IMAGE_VERSION}\norg.opencontainers.image.revision=${IMAGE_VCS_REF}\norg.opencontainers.image.vendor=${L_VENDOR}-${TARGETPLATFORM}\norg.opencontainers.image.licenses=${L_LICENSES}\norg.opencontainers.image.title=${L_TITLE}\norg.opencontainers.image.description=${L_DESCR}\norg.fhem.alexa.authors=${L_AUTHORS_ALEXAFHEM}\norg.fhem.alexa.url=${L_URL_ALEXAFHEM}\norg.fhem.alexa.documentation=${L_USAGE_ALEXAFHEM}\norg.fhem.alexa.source=${L_VCS_URL_ALEXAFHEM}\norg.fhem.alexa.version=${ALEXAFHEM_VERSION}\norg.fhem.alexa.revision=${VCS_REF}\norg.fhem.alexa.vendor=${L_VENDOR_ALEXAFHEM}\norg.fhem.alexa.licenses=${L_LICENSES_ALEXAFHEM}\norg.fhem.alexa.description=${L_DESCR_ALEXAFHEM}" > /image_info


VOLUME [ "/alexa-fhem" ]

EXPOSE 3000

HEALTHCHECK --interval=20s --timeout=10s --start-period=10s --retries=5 CMD /health-check.sh

WORKDIR "/alexa-fhem"
ENTRYPOINT [ "/entry.sh" ]
CMD [ "start" ]
