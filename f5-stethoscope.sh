#!/usr/bin/env bash

# Disable self-signed certificate warning for BIG-IP
export PYTHONWARNINGS='ignore:Unverified HTTPS request'

export TIMESTAMP=$(date +'%Y-%m-%d_%H%M.%S')
robot \
  --variable "bigip_host:10.1.1.4"              \
  --variable "bigip_username:admin"             \
  --variable "bigip_password:f5c0nfig123!"      \
  --logtitle "F5 Stethoscope $TIMESTAMP"        \
  --output-dir /usr/share/nginx/html            \
  f5-stethoscope.robot

