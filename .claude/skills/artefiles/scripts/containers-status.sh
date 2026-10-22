#!/bin/sh
# Whether containers work (containers module, macOS): Colima running, docker
# reachable, the buildx plugin found, lazydocker present, no Docker Desktop.
# Prints the fix for each problem. Changes nothing.
set -eu

if ! command -v colima > /dev/null 2>&1; then
  echo "colima: not installed (containers module)"
elif colima status > /dev/null 2>&1; then
  echo "colima: running"
else
  echo "colima: stopped: colima start"
fi

if ! command -v docker > /dev/null 2>&1; then
  echo "docker: not installed (containers module)"
else
  if docker info > /dev/null 2>&1; then
    echo "docker: reachable"
  else
    echo "docker: cannot reach a daemon: start Colima (colima start)"
  fi
  if docker buildx version > /dev/null 2>&1; then
    echo "buildx: found"
  else
    echo "buildx: missing: chezmoi apply links it into ~/.docker/cli-plugins"
  fi
fi

if command -v lazydocker > /dev/null 2>&1; then
  echo "lazydocker: installed"
else
  echo "lazydocker: not installed (containers module)"
fi

if [ -d /Applications/Docker.app ]; then
  echo "Docker Desktop: installed, which is not allowed: remove /Applications/Docker.app"
fi
