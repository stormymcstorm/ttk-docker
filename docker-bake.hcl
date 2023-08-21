group "default" {
    targets = ["vtk"]
}

target "vtk" {
    name = "vtk-${sterver(ver)}"
    matrix = {
        ver = ["9.2.6"]
    }
    target = "vtk"
    args = {
        VTK_VERSION = "${ver}"
    }
}

target "foo" {
    
}

function "sterver" {
    params = [ver]
    result = replace(ver, ".", "_")
}