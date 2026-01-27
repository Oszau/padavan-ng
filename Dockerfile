FROM ubuntu:24.04

ARG PADAVAN_REPO=https://github.com/nilabsent/padavan-ng
ARG PADAVAN_BRANCH=master
ARG PADAVAN_COMMIT=HEAD

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /opt

RUN apt update
RUN apt install --no-install-recommends -y \
        autoconf automake autopoint cmake \
        bison build-essential flex gawk \
        gettext git gperf libtool libtool-bin \
        pkg-config fakeroot kmod cpio doxygen \
        texinfo help2man libncurses5-dev \
        zlib1g-dev libsqlite3-dev gcc-multilib \
        curl dos2unix unzip wget locales xxd libltdl-dev \
        libgmp3-dev libmpfr-dev libarchive-tools libblkid-dev \
        ca-certificates zstd mc
RUN locale-gen --no-purge en_US.UTF-8 ru_RU.UTF-8

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

WORKDIR $WORKDIR

RUN git config --global --add safe.directory '*'
RUN git clone -b "${PADAVAN_BRANCH}" "${PADAVAN_REPO}" padavan-ng --depth=1
RUN git -C padavan-ng checkout "${PADAVAN_COMMIT}"

RUN [ -n "${PADAVAN_TOOLCHAIN_URL}" ] && TAR_ARCH="" && \
    case "${PADAVAN_TOOLCHAIN_URL}" in \
        *.tzst|*.tar.zst) TAR_ARCH="--zstd" ;; \
        *.txz|*.tar.xz) TAR_ARCH="--xz" ;; \
    esac && \
    wget -qO- "${PADAVAN_TOOLCHAIN_URL}" | tar -C padavan-ng $TAR_ARCH -xf - || :
