#!/usr/bin/env bash
export TF_VAR_region="ap-southeast-2"
export TF_VAR_account_id="$(aws sts get-caller-identity --query Account --output text)"
