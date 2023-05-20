# TTK Docker
A collection of Docker images containing installations of [Topology Toolkit](https://topology-tool-kit.github.io/)
and [Visualization Toolkit](https://vtk.org/).

This project is still a work in progresses, so expect it to be buggy.

## Images
 * __`ttk-python`__: An image with TTK, VTK and the python bindings for both.
    ```Dockerfile
    FROM ghcr.io/stormymcstorm/ttk-python
    ```
 * __`ttk`__: An image with TTK and VTK.
    ```Dockerfile
    FROM ghcr.io/stormymcstorm/ttk
    ```
 * __`vtk-python`__: An image VTK and it's python bindings.
    ```Dockerfile
    FROM ghcr.io/stormymcstorm/vtk-python
    ```
 * __`vtk`__: An image with VTK
    ```Dockerfile
    FROM ghcr.io/stormymcstorm/vtk
    ```

## Building the Images Locally
__Warning__: This will take about 4 hours to build everything. 

The available targets are: `ttk`, `ttk-python`, `vtk`, `vtk-python`. Then to build
an image
```bash
docker build -t stormymcstorm/ttk-python --target ttk-python .
```
