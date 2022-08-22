# Portage Philosophy

Portage is designed to have a minimal footprint, and be easy to use to install all software you need.

Portage has two types of installations, `pbuild` and `e-build`.

PBuild is a working-directory based building format while E-builds are an entirely net based installation format.

## E-Build

E-Builds are just a file, you download everything on the fly, which allows for more flexible kits.

This is a sample E-Build:

```bash
author=( "Your name here" )
repository=( "https://git-repo-here.com" )

instruction() {
  <build commands for this repository>
}
```

While, this is more flexible, `pbuild` is much easier to use.

## PBuild

> **Warning:** `pbuild` currently only supports github urls, if you want non-github urls use the `ebuild` format.

PBuilds are project formats which are like the opposite of E-Builds,
your entire working dir should be with the PBuild file, your structure like:

```
- Project
  pbuild
  src/
  meson.build (or makefile or whatever build u use)
```

The PBuild file contains the author info, and also the build commands for building the project.

An example PBuild file is:

```bash
author=( "Your Name Here" )

build() {
  <project build commands>
}
```

as an example, for a Pbuild project with a makefile, your build function would look like:

```
build() {
  make
}
```
