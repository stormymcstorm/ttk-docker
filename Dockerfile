ARG PYTHON_VERSION=3.9

ARG VTK_VERSION="9.2.6"
ARG VTK_BUILD_ARGS=-DVTK_USE_X=OFF -DVTK_BUILD_PYI_FILES=ON

################################################################################
# BUILDER BASE
# ------------
# Contains some common build dependencies
################################################################################

FROM python:${PYTHON_VERSION}-slim-bullseye as builder-base

# Install common build dependencies
RUN --mount=type=cache,target=/var/cache/apt \
  export DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install --no-install-recommends -yqq  ca-certificates \
  # kitware provides a more up-to-date version of cmake
  && echo "deb [trusted=yes] https://apt.kitware.com/ubuntu/ focal main" > /etc/apt/sources.list.d/kitware.list \
  && apt-get update \
  && apt-get install --no-install-recommends -yqq \
    build-essential \
    curl \
    cmake \
    ninja-build \
    mesa-common-dev \
    mesa-utils \
    libosmesa6-dev \
    freeglut3-dev \
    libboost-system-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

################################################################################
# BUILDER VTK
################################################################################

FROM builder-base as builder-vtk

ARG VTK_VERSION

# Download source
RUN VTK_VERSION_SHORT=$(echo ${VTK_VERSION} | cut -d. -f1-2) \
  && mkdir -p /src/vtk && cd /src/vtk \
  && curl -kL https://www.vtk.org/files/release/${VTK_VERSION_SHORT}/VTK-${VTK_VERSION}.tar.gz | tar zx --strip-components 1
