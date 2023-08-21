ARG PYTHON_VERSION=3.9

ARG VTK_VERSION=9.2.6
ARG VTK_BUILD_ARGS=-DVTK_USE_X=OFF -DVTK_BUILD_PYI_FILES=ON

################################################################################
# BASE BUILDER
################################################################################

FROM python:${PYTHON_VERSION}-slim-bullseye as builder-base

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update \
  && apt-get install --no-install-recommends -yqq \
    ca-certificates \
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
    libboost-system-dev 

################################################################################
# BUILDER VTK
# -----------
# stage responsible for building VTK.
# vtk installation is comprised of the following files:
#  - /usr/local/include/vtk/**/*
#  - /usr/local/lib/vtk/**/*
#  - /usr/local/lib/python*/site-packages/vtk.py
#  - /usr/local/lib/python*/site-packages/vtkmodules
#  - /usr/local/lib/libvtk*
#  - /usr/local/lib/cmake/vtk/**/*
#  - /usr/local/share/licenses/VTK/**/*
#  - /usr/local/share/vtk/**/*
#  - /usr/local/bin/vtk*
################################################################################

FROM builder-base as builder-vtk

ARG VTK_VERSION
ARG VTK_BUILD_ARGS

# Download source
RUN VTK_VERSION_SHORT=$(echo ${VTK_VERSION} | cut -d. -f1-2) \
  && mkdir -p /src/vtk && cd /src/vtk \
  && curl -kL https://www.vtk.org/files/release/${VTK_VERSION_SHORT}/VTK-${VTK_VERSION}.tar.gz | tar zx --strip-components 1

# Build and install
RUN mkdir -p /build/vtk \
  # https://github.com/Kitware/VTK/blob/master/Documentation/dev/build.md#optional-additions
  && cmake -B /build/vtk -S /src/vtk \
    -DVTK_OPENGL_HAS_OSMESA=ON \
    -DVTK_VERSIONED_INSTALL=OFF \
    -DVTK_ENABLE_WRAPPING=ON \
    -DVTK_WRAP_PYTHON=ON \
    ${VTK_BUILD_ARGS} \
  && cmake --build /build/vtk \
  && cmake --install /build/vtk

################################################################################
# BUILDER VTK PYTHON
# ------------------
# stage responsible for building VTK python wheel.
# Image contains the following artifacts
#  - /dist/vtk-wheel/*.whl
################################################################################

FROM builder-base as builder-vtk-python

ARG VTK_VERSION
ARG VTK_BUILD_ARGS

# Download source
RUN VTK_VERSION_SHORT=$(echo ${VTK_VERSION} | cut -d. -f1-2) \
  && mkdir -p /src/vtk && cd /src/vtk \
  && curl -kL https://www.vtk.org/files/release/${VTK_VERSION_SHORT}/VTK-${VTK_VERSION}.tar.gz | tar zx --strip-components 1

# Build
RUN mkdir -p /build/vtk \
  # https://github.com/Kitware/VTK/blob/master/Documentation/dev/build.md#optional-additions
  && cmake -B /build/vtk -S /src/vtk \
    -DVTK_OPENGL_HAS_OSMESA=ON \
    -DVTK_VERSIONED_INSTALL=OFF \
    -DVTK_ENABLE_WRAPPING=ON \
    -DVTK_WRAP_PYTHON=ON \
    -DVTK_WHEEL_BUILD=ON \
    ${VTK_BUILD_ARGS} \
  && cmake --build /build/vtk 

RUN mkdir -p /dist/vtk-wheel \
  && cd /build/vtk-wheel \
  && python3 setup.py bdist_wheel --dist-dir /dist/vtk-wheel

################################################################################
# BUILDER TTK
# -----------
# stage responsible for building TTK.
# ttk installation is comprised of the following files:
#  - /usr/local/include/vtk/**/*
#  - /usr/local/include/ttk/**/*
#  - /usr/local/lib/vtk/**/*
#  - /usr/local/lib/libvtk*
#  - /usr/local/lib/libttk*
#  - /usr/local/lib/cmake/vtk/**/*
#  - /usr/local/lib/cmake/ttkBase/**/*
#  - /usr/local/lib/cmake/ttkVTK/**/*
#  - /usr/local/lib/cmake/ttkPython/**/*
#  - /usr/local/share/licenses/VTK/**/*
#  - /usr/local/share/vtk/**/*
#  - /usr/local/scripts/ttk/**/*
#  - /usr/local/bin/vtk*
#  - /dist/ttk-wheel/*.whl
################################################################################

FROM builder-base as builder-ttk

# Download build dependencies
RUN apt-get update \
  && apt-get install --no-install-recommends -yqq \
    libcgns-dev             \
    libeigen3-dev           \
    libexpat1-dev           \
    libfreetype6-dev        \
    libhdf5-dev             \
    libjpeg-dev             \
    libjsoncpp-dev          \
    liblz4-dev              \
    liblzma-dev             \
    libnetcdf-cxx-legacy-dev\
    libnetcdf-dev           \
    libogg-dev              \
    libpng-dev              \
    libprotobuf-dev         \
    libpugixml-dev          \
    libsqlite3-dev          \
    libgraphviz-dev	        \
    libtheora-dev           \
    libtiff-dev             \
    libxml2-dev             \
    protobuf-compiler       \
    python3-numpy-dev       \
    zlib1g-dev

# Copy VTK installation from builder-vtk
COPY --from=builder-vtk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-vtk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-vtk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-vtk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-vtk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK
COPY --from=builder-vtk /usr/local/bin/vtk* /usr/local/bin/

ARG PYTHON_VERSION
COPY --from=builder-vtk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules
COPY --from=builder-vtk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py

ARG TTK_VERSION=1.1.0
ARG TTK_BUILD_ARGS=""

# Download sources
RUN mkdir -p /src/ttk && cd /src/ttk \
  && curl -kL https://github.com/topology-tool-kit/ttk/archive/${TTK_VERSION}.tar.gz | tar zx --strip-components 1

# Patch if necessary
COPY ttk-patches /tmp/ttk-patches

RUN if test -e /tmp/ttk-patches/ttk.${TTK_VERSION}.patch; then \
    cd /src/ttk && patch -p1 < /tmp/ttk-patches/ttk.${TTK_VERSION}.patch; \
  fi

# Build and install
RUN mkdir -p /build/ttk \
  && cmake -B /build/ttk -S /src/ttk \
    -DTTK_BUILD_PARAVIEW_PLUGINS=OFF \
    -DTTK_BUILD_STANDALONE_APPS=OFF \
    -DTTK_BUILD_VTK_WRAPPERS=ON \
    -DTTK_BUILD_VTK_PYTHON_MODULE=OFF \
    -DTTK_ENABLE_CPU_OPTIMIZATION=OFF \
    -DTTK_ENABLE_DOUBLE_TEMPLATING=ON \
    -DTTK_BUILD_DOCUMENTATION=OFF \
    -DVTK_MODULE_ENABLE_ttkWebSocketIO=NO \
    -DTTK_ENABLE_KAMIKAZE=ON \
    ${TTK_BUILD_ARGS} \
  && cmake --build /build/ttk \
  && cmake --install /build/ttk

# Setup package for topology toolkit
RUN mkdir -p /dist/ttk-wheel \
  && cd /build/ttk/lib/python*/site-packages \
  && echo "from setuptools import setup; setup(name='topologytoolkit', version='${TTK_VERSION}', packages=['topologytoolkit'])" > setup.py \
  && python setup.py bdist_wheel --dist-dir /dist/ttk-wheel
  
################################################################################
# VTK
################################################################################

FROM debian:bullseye-slim as vtk

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy VTK installation from builder-vtk
COPY --from=builder-vtk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-vtk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-vtk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-vtk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-vtk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK
COPY --from=builder-vtk /usr/local/bin/vtk* /usr/local/bin/

# Modify cmake configuration to not use python
RUN sed -i 's/set("\${CMAKE_FIND_PACKAGE_NAME}_WRAP_PYTHON" "ON")/set("\${CMAKE_FIND_PACKAGE_NAME}_WRAP_PYTHON" "OFF")/' \
  /usr/local/lib/cmake/vtk/vtk-config.cmake

################################################################################
# TTK
################################################################################

FROM debian:bullseye-slim as ttk

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy VTK installation from builder-ttk
COPY --from=builder-ttk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-ttk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-ttk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-ttk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-ttk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK
COPY --from=builder-ttk /usr/local/bin/vtk* /usr/local/bin/

# Copy TTK installation from builder-ttk
COPY --from=builder-ttk /usr/local/include/ttk /usr/local/include/ttk
COPY --from=builder-ttk /usr/local/lib/cmake/ttkBase /usr/local/lib/cmake/ttkBase
COPY --from=builder-ttk /usr/local/lib/cmake/ttkVTK /usr/local/lib/cmake/ttkVTK
COPY --from=builder-ttk /usr/local/lib/libttk* /usr/local/lib/
COPY --from=builder-ttk /usr/local/scripts/ttk /usr/local/scripts/ttk

# Modify cmake configuration to not use python
RUN sed -i 's/set("\${CMAKE_FIND_PACKAGE_NAME}_WRAP_PYTHON" "ON")/set("\${CMAKE_FIND_PACKAGE_NAME}_WRAP_PYTHON" "OFF")/' \
  /usr/local/lib/cmake/vtk/vtk-config.cmake

################################################################################
# VTK PYTHON
################################################################################

FROM python:${PYTHON_VERSION}-slim-bullseye as vtk-python

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

COPY --from=builder-vtk-python /dist/vtk-wheel /dist/vtk-wheel
RUN pip install /dist/vtk-wheel/*.whl && rm -rf /dist/vtk-wheel

################################################################################
# TTK PYTHON
################################################################################
FROM python:${PYTHON_VERSION}-slim-bullseye as ttk-python

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
    libgomp1 \
    libgraphviz-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

COPY --from=builder-vtk-python /dist/vtk-wheel /dist/vtk-wheel
RUN pip install /dist/vtk-wheel/*.whl && rm -rf /dist/vtk-wheel

COPY --from=builder-ttk /dist/ttk-wheel /dist/ttk-wheel
RUN pip install /dist/ttk-wheel/*.whl && rm -rf /dist/ttk-wheel