FROM quay.io/pypa/manylinux2014_aarch64

RUN yum -y update && \
    yum -y install \
      autoconf \
      automake \
      bzip2 \
      bzip2-devel \
      cmake \
      curl \
      elfutils-libelf \
      elfutils-libelf-devel \
      epel-release \
      expat-devel \
      fontconfig-devel \
      freetype-devel \
      gcc \
      gcc-c++ \
      git \
      libpng-devel \
      libtool \
      make \
      pkgconfig \
      tar \
      wget \
      xz \
      xz-devel \
      zlib-devel \
      && yum -y install ctags \
      && yum clean all

RUN curl -L https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0.tar.bz2 -o /tmp/patchelf.tar.bz2 \
    && mkdir -p /tmp/patchelf \
    && tar -xf /tmp/patchelf.tar.bz2 -C /tmp/patchelf --strip-components=1 \
    && cd /tmp/patchelf \
    && ./configure --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/patchelf /tmp/patchelf.tar.bz2

WORKDIR /work/scancode-plugins
