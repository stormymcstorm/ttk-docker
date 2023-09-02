ARG PYTHON_VERSION=3.9
ARG VARIANT=bullseye

################################################################################
# BUILDER BASE
# ------------
# Contains some common build dependencies
################################################################################

FROM python:${PYTHON_VERSION}-slim-${VARIANT} as builder-base

COPY scripts/kitware-archive.sh /tmp/kitware-archive.sh
RUN chmod +x /tmp/kitware-archive.sh

# Install common build dependencies
RUN export DEBIAN_FRONTEND=noninteractive \
    # kitware provides a more up-to-date version of cmake
    && /tmp/kitware-archive.sh \
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
        gettext-base \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

################################################################################
# BUILDER VTK
# -----------
# Builds vtk. The installation is comprised of the following files:
#  - /usr/local/include/vtk/**/*
#  - /usr/local/lib/vtk/**/*
#  - /usr/local/lib/libvtk*
#  - /usr/local/lib/cmake/vtk/**/*
#  - /usr/local/bin/vtk*
#  - /usr/local/share/vtk/**/*
#  - /usr/local/share/licenses/VTK/**/*
#  - /usr/local/lib/python*/site-packages/vtk.py          (python)
#  - /usr/local/lib/python*/site-packages/vtkmodules/**/* (python)
################################################################################

FROM builder-base as builder-vtk

ARG VTK_VERSION="9.2.6"

# Download source
RUN VTK_VERSION_SHORT=$(echo ${VTK_VERSION} | cut -d. -f1-2) \
  && mkdir -p /src/vtk && cd /src/vtk \
  && curl -kL https://www.vtk.org/files/release/${VTK_VERSION_SHORT}/VTK-${VTK_VERSION}.tar.gz | tar zx --strip-components 1

ARG VTK_BUILD_ARGS=-DVTK_USE_X=OFF -DVTK_BUILD_PYI_FILES=ON -DVTK_GROUP_ENABLE_Web:STRING=WANT

# Build and install
RUN mkdir -p /build/vtk \
    # https://gitlab.kitware.com/vtk/vtk/-/blob/v9.2.6/Documentation/dev/build.md
    && cmake -B /build/vtk -S /src/vtk -G Ninja \
        -DVTK_OPENGL_HAS_OSMESA=ON \
        -DVTK_VERSIONED_INSTALL=OFF \
        -DVTK_ENABLE_WRAPPING=ON \
        -DVTK_WRAP_PYTHON=ON \
        ${VTK_BUILD_ARGS} \
    && cmake --build /build/vtk \
    && cmake --install /build/vtk

COPY vtk/setup.py.in /build/vtk-wheel/setup.py.in

RUN mkdir -p /dist/vtk-wheel \
    && envsubst < /build/vtk-wheel/setup.py.in > /build/vtk-wheel/setup.py \
    && cp /build/vtk/lib/python*/site-packages/vtk.py /build/vtk-wheel \
    && cp -r /build/vtk/lib/python*/site-packages/vtkmodules /build/vtk-wheel \
    && cd /build/vtk-wheel \
    && python3 setup.py bdist_wheel --dist-dir /dist/vtk-wheel

################################################################################
# BUILDER TTK
# -----------
# Builds ttk. The installation is comprised of the following files:
#  - /usr/local/include/vtk/**/*
#  - /usr/local/include/ttk/**/*
#  - /usr/local/lib/vtk/**/*
#  - /usr/local/lib/libvtk*
#  - /usr/local/lib/libttk*
#  - /usr/local/lib/cmake/vtk/**/*
#  - /usr/local/lib/cmake/ttkBase/**/*
#  - /usr/local/lib/cmake/ttkVTK/**/*
#  - /usr/local/bin/vtk*
#  - /usr/local/share/vtk/**/*
#  - /usr/local/scripts/ttk/**/*
#  - /usr/local/share/licenses/VTK/**/*
#  - /usr/local/lib/python*/site-packages/vtk.py          (python)
#  - /usr/local/lib/python*/site-packages/vtkmodules/**/* (python)
#  - /usr/local/lib/python*/site-packages/topologytoolkit/**/* (python)
################################################################################

FROM builder-base as builder-ttk

# Download build dependencies
RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install --no-install-recommends -yqq  ca-certificates \
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
    # python3-numpy-dev       \
    zlib1g-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy vtk installation
COPY --from=builder-vtk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-vtk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-vtk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-vtk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-vtk /usr/local/bin/vtk* /usr/local/bin/
COPY --from=builder-vtk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK
COPY --from=builder-vtk /usr/local/share/vtk /usr/local/share/vtk

ARG PYTHON_VERSION
COPY --from=builder-vtk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtkmodules
COPY --from=builder-vtk /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py \
  /usr/local/lib/python${PYTHON_VERSION}/site-packages/vtk.py

ARG TTK_VERSION=1.1.0
ARG TTK_BUILD_ARGS=-DTTK_ENABLE_KAMIKAZE=ON -DTTK_ENABLE_DOUBLE_TEMPLATING=ON

# Download sources
RUN mkdir -p /src/ttk && cd /src/ttk \
  && curl -kL https://github.com/topology-tool-kit/ttk/archive/${TTK_VERSION}.tar.gz | tar zx --strip-components 1

# Patch if necessary
COPY ttk/patches /tmp/ttk-patches

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
    -DTTK_BUILD_DOCUMENTATION=OFF \
    -DVTK_MODULE_ENABLE_ttkWebSocketIO=NO \
    ${TTK_BUILD_ARGS} \
  && cmake --build /build/ttk \
  && cmake --install /build/ttk

COPY ttk/setup.py.in /build/ttk-wheel/setup.py.in

RUN mkdir -p /dist/ttk-wheel \
    && envsubst < /build/ttk-wheel/setup.py.in > /build/ttk-wheel/setup.py \
    && cp -r /build/ttk/lib/python*/site-packages/topologytoolkit /build/ttk-wheel \
    && cd /build/ttk-wheel \
    && python3 setup.py bdist_wheel --dist-dir /dist/ttk-wheel


################################################################################
# VTK PYTHON
################################################################################

FROM python:${PYTHON_VERSION}-slim-${VARIANT} as vtk-python

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy vtk installation
COPY --from=builder-vtk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-vtk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-vtk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-vtk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-vtk /usr/local/bin/vtk* /usr/local/bin/
COPY --from=builder-vtk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK
COPY --from=builder-vtk /usr/local/share/vtk /usr/local/share/vtk

# Copy python wrappers
ARG PYTHON_VERSION

COPY --from=builder-vtk /dist/vtk-wheel /dist/vtk-wheel
RUN pip install /dist/vtk-wheel/*.whl \
    && rm -rf /dist

# Test install
RUN python -c "import vtk"

################################################################################
# TTK PYTHON
################################################################################

FROM python:${PYTHON_VERSION}-slim-${VARIANT} as ttk-python

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install --no-install-recommends -yqq \
    libosmesa6-dev \
    libgomp1 \
    libgraphviz-dev \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy vtk installation
COPY --from=builder-ttk /usr/local/include/vtk /usr/local/include/vtk
COPY --from=builder-ttk /usr/local/lib/vtk /usr/local/lib/vtk
COPY --from=builder-ttk /usr/local/lib/cmake/vtk /usr/local/lib/cmake/vtk
COPY --from=builder-ttk /usr/local/lib/libvtk* /usr/local/lib/
COPY --from=builder-ttk /usr/local/bin/vtk* /usr/local/bin/
COPY --from=builder-ttk /usr/local/share/licenses/VTK /usr/local/share/licenses/VTK
COPY --from=builder-ttk /usr/local/share/vtk /usr/local/share/vtk

# Copy ttk installation
COPY --from=builder-ttk /usr/local/include/ttk /usr/local/include/ttk
COPY --from=builder-ttk /usr/local/lib/cmake/ttkBase /usr/local/lib/cmake/ttkBase
COPY --from=builder-ttk /usr/local/lib/cmake/ttkVTK /usr/local/lib/cmake/ttkVTK
COPY --from=builder-ttk /usr/local/lib/libttk* /usr/local/lib/
COPY --from=builder-ttk /usr/local/scripts/ttk /usr/local/scripts/ttk

# Copy python wrappers
ARG PYTHON_VERSION

COPY --from=builder-vtk /dist/vtk-wheel /dist/vtk-wheel
COPY --from=builder-ttk /dist/ttk-wheel /dist/ttk-wheel
RUN pip install /dist/vtk-wheel/*.whl \
    && pip install /dist/ttk-wheel/*.whl \
    && rm -rf /dist

# Test install
RUN python -c "import vtk; import topologytoolkit"