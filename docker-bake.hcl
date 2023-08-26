// Defaults are set assume a local build
variable "REGISTRY" {
    default = "docker.io"
}

variable "NAMESPACE" {
    default = "stormymcstorm"
}

variable "REMOTE_CACHE" {
    default = false
}

group "default" {
    targets = ["vtk", "ttk"]
}

variable "_latest_variant" {
    default = "bookworm"
}

variable "_latest_vtk" {
    default = "9.3.0.rc1"
}

variable "_latest_ttk" {
    default = "1.2.0"
}

variable "_latest_py" {
    default = "3.11"
}

target "vtk" {
    name = "vtk${format_ver(vtk_ver)}-${variant}"
    matrix = {
        vtk_ver = ["9.2.6", "9.3.0.rc1"]
        variant = ["bullseye", "bookworm"]
    }

    dockerfile = "base.Dockerfile"
    target = "vtk"
    args = {
        VTK_VERSION = "${vtk_ver}"
        VARIANT = "${variant}"
    }

    tags = compact([
        "${REGISTRY}/${NAMESPACE}/vtk:${vtk_ver}-${variant}",
        // Add a tag without the variant if using the latest variant
        (variant == _latest_variant ? "${REGISTRY}/${NAMESPACE}/vtk:${vtk_ver}" : null),
        // Add a latest tag if all software is at latest
        (vtk_ver == _latest_vtk && variant == _latest_variant? 
            "${REGISTRY}/${NAMESPACE}/vtk:latest" : null),
    ])

    cache-to = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:vtk${vtk_ver}-${variant},mode=max"
    ] : []
    
    cache-from = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:vtk${vtk_ver}-${variant}"
    ] : []
}

target "ttk" {
    name = "ttk${format_ver(ttk_ver)}-vtk${format_ver(vtk_ver)}-${variant}"

    matrix = {
        ttk_ver = ["1.1.0", "1.2.0"]
        vtk_ver = ["9.2.6", "9.3.0.rc1"]
        variant = ["bullseye", "bookworm"]
    }

    dockerfile = "base.Dockerfile"
    target = "ttk"
    args = {
        TTK_VERSION = "${ttk_ver}"
        VTK_VERSION = "${vtk_ver}"
        VARIANT = "${variant}"
    }

    tags = compact([
        "${REGISTRY}/${NAMESPACE}/ttk:ttk${ttk_ver}-vtk${vtk_ver}-${variant}",
        (variant == _latest_variant && vtk_ver == _latest_vtk ? 
            "${REGISTRY}/${NAMESPACE}/ttk:${ttk_ver}" : null),
        (variant == _latest_variant && vtk_ver == _latest_vtk && ttk_ver == _latest_ttk ?
            "${REGISTRY}/${NAMESPACE}/ttk:latest" : null)
    ])

    cache-to = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:ttk${ttk_ver}-vtk${vtk_ver}-${variant},mode=max"
    ] : []
    
    cache-from = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:ttk${ttk_ver}-vtk${vtk_ver}-${variant}",
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:vtk${vtk_ver}-${variant}"
    ] : []
}

target "vtk-python" {
    name = "vtk${format_ver(vtk_ver)}-py${format_ver(py_ver)}-${variant}"
    matrix = {
        py_ver = ["3.9", "3.11"]
        vtk_ver = ["9.2.6", "9.3.0.rc1"]
        variant = ["bullseye", "bookworm"]
    }

    dockerfile = "python.Dockerfile"
    target = "vtk-python"
    args = {
        VTK_VERSION = "${vtk_ver}"
        PYTHON_VERSION = "${py_ver}"
        VARIANT = "${variant}"
    }

    tags = compact([
        "${REGISTRY}/${NAMESPACE}/vtk-python:vtk${vtk_ver}-py${py_ver}-${variant}",
        (variant == _latest_variant && vtk_ver == _latest_vtk && py_ver == _latest_py ?
            "${REGISTRY}/${NAMESPACE}/vtk-python:latest" : null),
    ])

    cache-to = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:vtk${vtk_ver}-py${py_ver}-${variant},mode=max"
    ] : []
    
    cache-from = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:vtk${vtk_ver}-py${py_ver}-${variant}",
    ] : []
}

target "ttk-python" {
    name = "ttk${format_ver(ttk_ver)}-vtk${format_ver(vtk_ver)}-py${format_ver(py_ver)}-${variant}"
    matrix = {
        py_ver = ["3.9", "3.11"]
        ttk_ver = ["1.1.0", "1.2.0"]
        vtk_ver = ["9.2.6", "9.3.0.rc1"]
        variant = ["bullseye", "bookworm"]
    }

    dockerfile = "python.Dockerfile"
    target = "ttk-python"
    args = {
        TTK_VERSION = "${ttk_ver}"
        VTK_VERSION = "${vtk_ver}"
        PYTHON_VERSION = "${py_ver}"
        VARIANT = "${variant}"
    }

    tags = compact([
        "${REGISTRY}/${NAMESPACE}/ttk-python:ttk${ttk_ver}-vtk${vtk_ver}-py${py_ver}-${variant}",
        (variant == _latest_variant && ttk_ver == _latest_ttk && vtk_ver == _latest_vtk && py_ver == _latest_py ?
            "${REGISTRY}/${NAMESPACE}/ttk-python:latest" : null),
    ])

    cache-to = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:ttk${ttk_ver}-vtk${vtk_ver}-py${py_ver}-${variant},mode=max"
    ] : []
    
    cache-from = REMOTE_CACHE ? [
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:ttk${ttk_ver}-vtk${vtk_ver}-py${py_ver}-${variant}",
        "type=registry,ref=${REGISTRY}/${NAMESPACE}/build-cache:vtk${vtk_ver}-py${py_ver}-${variant}",
    ] : []
}

function "format_ver" {
    params = [ver]
    result = replace(ver, ".", "_")
}