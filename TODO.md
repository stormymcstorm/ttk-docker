# TODO
- [ ] Install VTK package as a wheel.
    - Using `-DVTK_WHEEL_BUILD=ON` sets up the VTK build to build a wheel, but does not seem to be compatible with the TTK build. Resulting in the error
        ```
        Traceback (most recent call last):
        File "<stdin>", line 1, in <module>
        File "/usr/local/lib/python3.9/site-packages/topologytoolkit/__init__.py", line 2, in <module>
            from .ttkWRLExporter import *
        ImportError: Initialization failed for ttkWRLExporter, not compatible with vtkmodules.vtkFiltersCore
        ```
        This is related to how VTK wrappers are initialized (found [here](https://gitlab.kitware.com/vtk/vtk/-/blob/master/Wrapping/Tools/vtkWrapPythonInit.c#L111)).

        Not entirely clear why the wheel build causes this issue. Maybe the wheel build wraps VTK differently.
    
    - May be possible to manually setup a wheel from standard python wrapping, but it should mirror the one produced by `VTK_WHEEL_BUILD`

    - [ ] Consider installing  `topologytoolkit` as a wheel if VTK is installed as a wheel.
        - This less important since `topologytoolkit` is not published to pypi, but it would not require modifying `$PYTHONPATH`