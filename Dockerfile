ARG PYTHON_VERSION=3.9

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
#  - /usr/local/include/vtk/**/*
#  - /usr/local/lib/vtk/**/*
#  - /usr/local/lib/libvtk*
#  - /usr/local/lib/cmake/vtk/**/*
#  - /usr/local/lib/python3.9/site-packages/vtkmodules/**/* (python)
#  - /usr/local/lib/python3.9/site-packages/vtk.py          (python)
#  - /usr/local/share/licenses/VTK/**/*
#  - /usr/local/share/vtk/**/*
#  - /usr/local/bin/vtk*
################################################################################

FROM builder-base as builder-vtk

# Download sources

ARG VTK_VERSION=9.2.6

RUN mkdir -p /src/vtk && cd /src/vtk \
  && VTK_VERSION_SHORT=$(echo ${VTK_VERSION} | cut -d. -f1-2) \
  && curl -kL https://www.vtk.org/files/release/${VTK_VERSION_SHORT}/VTK-${VTK_VERSION}.tar.gz | tar zx --strip-components 1

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
# TTK BUILDER
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
#  - /usr/local/lib/python3.9/site-packages/vtkmodules/**/*       (python)
#  - /usr/local/lib/python3.9/site-packages/topologytoolkit/**/*  (python)
#  - /usr/local/lib/python3.9/site-packages/vtk.py                (python)
#  - /usr/local/share/licenses/VTK/**/*
#  - /usr/local/share/vtk/**/*
#  - /usr/local/scripts/ttk/**/*
#  - /usr/local/bin/vtk*
################################################################################

FROM builder-vtk as builder-ttk

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

# Download sources

ARG TTK_VERSION=1.1.0

RUN mkdir -p /src/ttk && cd /src/ttk \
  && curl -kL https://github.com/topology-tool-kit/ttk/archive/${TTK_VERSION}.tar.gz | tar zx --strip-components 1

COPY ttk.patch /tmp/ttk.patch

RUN cd /src/ttk && patch -p1 < /tmp/ttk.patch

# Build and install ttk

RUN mkdir -p /build/ttk  \
  && cmake -B /build/ttk -S /src/ttk \
    -DTTK_BUILD_PARAVIEW_PLUGINS=OFF \
    -DTTK_BUILD_STANDALONE_APPS=OFF \
    -DTTK_BUILD_VTK_WRAPPERS=ON \
    -DTTK_BUILD_VTK_PYTHON_MODULE=OFF \
    -DTTK_ENABLE_CPU_OPTIMIZATION=OFF \
    -DTTK_ENABLE_DOUBLE_TEMPLATING=OFF \
    -DTTK_BUILD_DOCUMENTATION=OFF \
    -DVTK_MODULE_ENABLE_ttkWebSocketIO=NO \
    -DTTK_ENABLE_KAMIKAZE=ON \
  && cmake --build /build/ttk \
  && cmake --install /build/ttk 

################################################################################
# VTK 
# ------------------------------------------
# An image containing a VTK installation
################################################################################

FROM debian:bullseye-slim as vtk

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
# Copy vtk installation from builder-vtk
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
# VTK PYTHON
# ----------
# An image containing a VTK installation and the python wrapper
################################################################################

FROM python:${PYTHON_VERSION}-slim-bullseye as vtk-python

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
# Copy vtk installation from builder-vtk
COPY --from=builder-vtk /usr/local/include/vtk /usr/local/include/vtk

COPY --from=builder-vtk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-vtk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-vtk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-vtk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules
COPY --from=builder-vtk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py

COPY --from=builder-vtk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK

COPY --from=builder-vtk /usr/local/bin/vtk* /usr/local/bin/

ENV PYTHONPATH=$PYTHONPATH:/usr/local/lib/python${PYTHON_VERSION}/site-packages/

################################################################################
# TTK
# ---
# An image containing a TTK installation
################################################################################

FROM debian:bullseye-slim as ttk

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
    libgomp1 \
    libgraphviz-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
# Copy vtk installation from builder-vtk
COPY --from=builder-ttk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-ttk /usr/local/include/ttk /usr/local/include/ttk

COPY --from=builder-ttk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-ttk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-ttk /usr/local/lib/cmake/ttkBase /usr/local/lib/cmake/ttkBase
COPY --from=builder-ttk /usr/local/lib/cmake/ttkVTK /usr/local/lib/cmake/ttkVTK
COPY --from=builder-ttk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-ttk /usr/local/lib/libttk* /usr/local/lib/

COPY --from=builder-ttk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK

COPY --from=builder-ttk /usr/local/scripts/ttk /usr/local/scripts/ttk

COPY --from=builder-ttk /usr/local/bin/vtk* /usr/local/bin/

# Modify cmake configuration to not use python
RUN sed -i 's/set("\${CMAKE_FIND_PACKAGE_NAME}_WRAP_PYTHON" "ON")/set("\${CMAKE_FIND_PACKAGE_NAME}_WRAP_PYTHON" "OFF")/' \
  /usr/local/lib/cmake/vtk/vtk-config.cmake

################################################################################
# TTK PYTHON
# ----------
# An image containing a TTK installation and the python bindings
################################################################################

FROM python:${PYTHON_VERSION}-slim-bullseye as ttk-python

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
    libgomp1 \
    libgraphviz-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    
# Copy vtk installation from builder-vtk
COPY --from=builder-ttk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-ttk /usr/local/include/ttk /usr/local/include/ttk

COPY --from=builder-ttk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-ttk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-ttk /usr/local/lib/cmake/ttkBase /usr/local/lib/cmake/ttkBase
COPY --from=builder-ttk /usr/local/lib/cmake/ttkVTK /usr/local/lib/cmake/ttkVTK
COPY --from=builder-ttk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-ttk /usr/local/lib/libttk* /usr/local/lib/

COPY --from=builder-ttk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules
COPY --from=builder-ttk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py
COPY --from=builder-ttk /usr/local/lib/python${PYTHON_VERSION}/site-packages/topologytoolkit \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/topologytoolkit

COPY --from=builder-ttk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK

COPY --from=builder-ttk /usr/local/scripts/ttk /usr/local/scripts/ttk

COPY --from=builder-ttk /usr/local/bin/vtk* /usr/local/bin/

ENV PYTHONPATH=$PYTHONPATH:/usr/local/lib/python${PYTHON_VERSION}/site-packages/

################################################################################
# VTK TEST
# --------
# An image which tests that vtk was installed properly
################################################################################

FROM vtk as vtk-test

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends -yqq \
    curl \
    nano \
    ninja-build \
    build-essential \
    cmake \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /test && cd /test \
  && curl -kL https://github.com/Kitware/vtk-examples/raw/gh-pages/Tarballs/Cxx/CylinderExample.tar | tar x --strip-components 1 \
  && cmake . \
  && make 

CMD ["/bin/sh", "-c", "/test/CylinderExample && echo It works!"]