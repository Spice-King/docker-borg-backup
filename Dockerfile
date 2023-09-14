################################################################################
#                             PIN PACKAGE VERSIONS                             #
################################################################################
ARG BORGBACKUP_VERSION="1.2.6"
ARG PYTHON_VERSION="3.11"
ARG OPENSSH_VERSION="9.3_p2-r0"
ARG SED_VERSION="4.9-r2"
ARG BASH_VERSION="5.2.15-r5"
ARG SHADOW_VERSION="4.13-r4"
ARG OPENSSL_VERSION="3.1.2-r0"
ARG PKG_CONF_VERSION="1.9.5-r0"
ARG GCC_VERSION="12.2.1_git20220924-r10"
ARG MUSL_VERSION="1.2.4-r1"
ARG ACL_VERSION="2.3.1-r3"
ARG XXHASH_VERSION="0.8.2-r0"
ARG ZSTD_VERSION="1.5.5-r4"
ARG LZ4_VERSION="1.9.4-r4"
ARG LINUX_HEADERS_VERSION="6.3-r0"

################################################################################
#                    BUILD BORGBACKUP FROM SOURCE USING PIP                    #
################################################################################
FROM python:"${PYTHON_VERSION}"-alpine AS builder

# Re-define needed ARGS
ARG BORGBACKUP_VERSION
ARG PKG_CONF_VERSION
ARG OPENSSL_VERSION
ARG GCC_VERSION
ARG MUSL_VERSION
ARG ACL_VERSION
ARG XXHASH_VERSION
ARG ZSTD_VERSION
ARG LZ4_VERSION
ARG LINUX_HEADERS_VERSION

RUN set -x && \
    apk add --no-cache \
        pkgconf="${PKG_CONF_VERSION}" \
        openssl-dev="${OPENSSL_VERSION}" \
        gcc="${GCC_VERSION}" \
        musl-dev="${MUSL_VERSION}" \
        acl-dev="${ACL_VERSION}" \
        zstd-dev="${ZSTD_VERSION}" \
        lz4-dev="${LZ4_VERSION}" \
        xxhash-dev="${XXHASH_VERSION}" \
        linux-headers="${LINUX_HEADERS_VERSION}" \
    && mkdir /wheel \
    && pip wheel borgbackup=="${BORGBACKUP_VERSION}" -w /wheel


################################################################################
#                INSTALL BUILT BORGBACKUP PACKAGE IN NEW STAGE                 #
################################################################################
FROM python:"${PYTHON_VERSION}"-alpine AS runtime-image

# Re-define needed ARGS
ARG OPENSSH_VERSION
ARG SED_VERSION
ARG BASH_VERSION
ARG SHADOW_VERSION
ARG OPENSSL_VERSION
ARG XXHASH_VERSION
ARG ZSTD_VERSION
ARG LZ4_VERSION
ARG ACL_VERSION
ARG LINUX_HEADERS_VERSION

# Add author and github link to image metadata
LABEL org.opencontainers.image.authors="André Büsgen <andre.buesgen@posteo.de>"
LABEL org.opencontainers.image.source="https://github.com/AnotherStranger/docker-borg-backup"
LABEL org.opencontainers.image.url="https://github.com/AnotherStranger/docker-borg-backup"
LABEL org.opencontainers.image.documentation="https://github.com/AnotherStranger/docker-borg-backup"
LABEL org.opencontainers.image.description="A dockerized borgbackup server"
LABEL org.opencontainers.image.title="borg-server"

# Define supported Environment variables
ENV BORG_SERVE_ADDITIONAL_ARGS=""
ENV BORG_UID=""
ENV BORG_GID=""
ENV BORG_AUTHORIZED_KEYS=""

RUN set -x && \
    apk add --no-cache \
        openssh-server="${OPENSSH_VERSION}" \
        sed="${SED_VERSION}" \
        bash="${BASH_VERSION}" \
        shadow="${SHADOW_VERSION}" \
        openssl="${OPENSSL_VERSION}" \
        xxhash="${XXHASH_VERSION}" xxhash-dev="${XXHASH_VERSION}" \
        acl="${ACL_VERSION}" acl-dev="${ACL_VERSION}" \
        zstd="${ZSTD_VERSION}" zstd-dev="${ZSTD_VERSION}" \
        lz4="${LZ4_VERSION}" lz4-dev="${LZ4_VERSION}" \
        linux-headers="${LINUX_HEADERS_VERSION}" \
    && adduser -D -u 500 borg borg \
    && mkdir -p /var/run/sshd /var/backups/borg /var/lib/docker-borg/ssh \
    && mkdir /home/borg/.ssh \
    && chown borg:borg /home/borg/.ssh \
    && chmod 700 /home/borg/.ssh

COPY --from=builder /wheel /wheel
RUN pip --no-cache-dir install /wheel/*.whl

# Configure SSH
RUN set -x \
    && sed -i \
        -e 's/^#PasswordAuthentication yes$/PasswordAuthentication no/g' \
        -e 's/^PermitRootLogin without-password$/PermitRootLogin no/g' \
        -e 's/^X11Forwarding yes$/X11Forwarding no/g' \
        -e 's/^#LogLevel .*$/LogLevel ERROR/g' \
        /etc/ssh/sshd_config \
&& mkdir -p /var/lib/docker-borg/ssh \
&& mkdir -p /home/borg/backups

VOLUME ["/home/borg/backups/", "/var/lib/docker-borg"]

COPY ./entrypoint.sh /

EXPOSE 22
CMD ["/entrypoint.sh"]
