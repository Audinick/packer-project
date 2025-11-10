#!/bin/bash

# Ensure plugins and dependencies are initialized
packer init .

# Run the build (replace with your desired options)
packer build -var-file=variables.pkrvars.hcl windows-server-2022.pkr.hcl
