#!/usr/bin/env bash

# Disable self-signed certificate warning for BIG-IP
export PYTHONWARNINGS='ignore:Unverified HTTPS request'

export TIMESTAMP=$(date +'%Y-%m-%d_%H%M.%S')
robot --variable  "text_output_file_name:device_info_$TIMESTAMP.txt" --variable "host:10.1.1.4" --variable "user:admin" --variable "pass:f5c0nfig123!" --logtitle "F5 Stethoscope $TIMESTAMP" --output-dir /usr/share/nginx/html -f5-stethoscope.robot