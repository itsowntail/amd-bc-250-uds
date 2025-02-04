# amd-bc-250-udss
Amd bc-250 universal driver setup script

Automated setup script to configure AMDGPU drivers, including support for Cyan Skillfish (AMD BC-250) on multiple Linux distributions such as Arch, Fedora, Ubuntu, Debian, and CentOS.

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration Options](#configuration-options)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This script simplifies the installation process of AMDGPU drivers and ensures compatibility with specific hardware like the AMD BC-250 series. It includes options for configuring kernel parameters, enabling sensor support via NCT6686 SuperIO, and handling Vulkan/OpenGL issues by setting environment variables.

## Features

- Supports multiple Linux distributions: Arch, Fedora, Ubuntu, Debian, CentOS.
- Provides options to install official AMDGPU drivers or patched Mesa drivers.
- Configures kernel parameters (`amdgpu.sg_display=0`) for resolving boot issues on newer kernels.
- Sets up `RADV_DEBUG=nocompute` to fix Vulkan-related visual problems.
- Enables sensor monitoring through `nct6775` for NCT6686 SuperIO chips.
- Allows removal of existing drivers before installing new ones.

## Prerequisites

Before running the script, ensure the following:

- You have administrative privileges (`root` or `sudo`).
- Your system has an active internet connection.
- The necessary package manager (`pacman`, `dnf`, `apt`) is installed based on your distribution.

## Installation

To download and execute the script directly from GitHub, run the following command in your terminal:

```bash
curl -s https://github.com/itsowntail/amd-bc-250-udss/blob/main/bc250udss.sh | sh
