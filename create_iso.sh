#!/usr/bin/bash

mkdir -p ./iso-output
sudo podman run --rm --privileged --volume ./iso-output:/build-container-installer/build --security-opt label=disable --pull=newer \
ghcr.io/jasonn3/build-container-installer:latest \
IMAGE_REPO=ghcr.io/tomrutsaert \
IMAGE_NAME=myos-gnome-main \
IMAGE_TAG=latest \
VERSION=40 \
VARIANT=Silverblue
