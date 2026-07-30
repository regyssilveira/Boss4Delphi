# Declarative Delphi build matrix

This example declares runtime and design-time packages across Delphi 10.1, 11,
12, and 13, on Win32/Win64 and Debug/Release.

The runtime package participates in the complete matrix. The design-time
package is restricted to Delphi 11–13, Win32, and Release, and declares its
dependency on the runtime project.

Until the build execution phases are connected, this example documents and
exercises the manifest model and deterministic target expansion contract.
