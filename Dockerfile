ARG VARIANT=bullseye-slim

################################################################################
# BASE BUILDER
# ------------
# base image containing the dependencies and setup for later build stages
################################################################################

FROM debian:bullseye-slim as builder-base

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update \
  && apt-get install --no-install-recommends -yqq \
    ca-certificates \
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
    python3-dev

# Install some utilities that make debugging builds easier
RUN apt-get update \
  && apt-get install --no-install-recommends -yqq \
    cmake-curses-gui

################################################################################
# VTK BUILDER
# -----------
# stage responsible for building VTK.
# vtk installation is comprised of the following files:
#  - /usr/local/lib/libvtk*
#  - /usr/local/lib/cmake/vtk-*
################################################################################

FROM builder-base as builder-vtk

# Download sources

ARG VTK_VERSION=9.2.6

RUN mkdir -p /src/vtk && cd /src/vtk \
  && curl -kL https://www.vtk.org/files/release/9.2/VTK-${VTK_VERSION}.tar.gz | tar zx --strip-components 1

# Build and install vtk

RUN mkdir -p /build/vtk \
  # https://github.com/Kitware/VTK/blob/master/Documentation/dev/build.md#optional-additions
  && cmake -B /build/vtk -S /src/vtk \
    -DVTK_USE_X=OFF \
    -DVTK_OPENGL_HAS_OSMESA=ON \
    -DVTK_BUILD_PYI_FILES=ON \ 
    -DVTK_ENABLE_WRAPPING=ON \
    -DVTK_WRAP_PYTHON=ON \
    -DVTK_VERSIONED_INSTALL=OFF \
  && cmake --build /build/vtk \
  && cmake --install /build/vtk


################################################################################
# VTK (to be published as stormymcstorm/vtk)
# ------------------------------------------
# An image containing a VTK installation
################################################################################

FROM debian:$VARIANT as vtk

# COPY --from=builder-vtk /usr/local/lib/libvtk* /usr/local/lib/


# FROM builder-base as builder-ttk

# 

# RUN mkdir -p /src/ttk && cd /src/ttk \
#   && curl -kL https://github.com/topology-tool-kit/ttk/archive/${TTK_VERSION}.tar.gz | tar zx --strip-components 1 \
#   && mkdir -p /build/ttk \
#   && cmake -B /build/ttk -S /src/ttk \
#     -DTTK_BUILD_DOCUMENTATION=OFF \ 
#     -DTTK_BUILD_PARAVIEW_PLUGINS=OFF \
#     -DTTK_BUILD_STANDALONE_APPS=OFF \
#     -DTTK_BUILD_VTK_PYTHON_MODULE=OFF \
#     -DTTK_BUILD_VTK_WRAPPERS=ON \
#     -DTTK_ENABLE_CPU_OPTIMIZATION=OFF \
#     # -DTTK_ENABLE_OPENMP=ON \
#     -DTTK_ENABLE_KAMIKAZE=ON \
#   && cmake --build /build/ttk \
#   && cmake --install /build/ttk