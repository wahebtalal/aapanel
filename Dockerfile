FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    container=docker \
    TZ=Asia/Riyadh

ARG AAPANEL_INSTALLER_URL=https://www.aapanel.com/script/install_panel_en.sh

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bzip2 \
        ca-certificates \
        cron \
        curl \
        gzip \
        gnupg \
        iproute2 \
        less \
        lsb-release \
        lsof \
        nano \
        net-tools \
        openssh-server \
        procps \
        python3 \
        python3-pip \
        sudo \
        tar \
        tzdata \
        unzip \
        vim \
        wget \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Install the current aaPanel release at build time from the official installer.
RUN cd /tmp \
    && curl -fsSL "${AAPANEL_INSTALLER_URL}" -o install_panel_en.sh \
    && bash install_panel_en.sh forum \
    && rm -f install_panel_en.sh

# Preserve the freshly installed aaPanel tree so a first-run /www Docker volume can be initialized.
RUN mkdir -p /opt/aapanel-seed \
    && if [[ -d /www ]]; then cp -a /www/. /opt/aapanel-seed/; fi

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 21 22 80 443 888 7800

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
