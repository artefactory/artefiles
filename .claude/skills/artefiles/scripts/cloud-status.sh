#!/bin/sh
# Who the cloud CLIs are signed in as, and what to run when they are not:
# gcloud (account, project), az (subscription), kubectl (context). Changes nothing.
set -eu

if command -v gcloud > /dev/null 2>&1; then
  account=$(gcloud config get-value account 2> /dev/null || true)
  project=$(gcloud config get-value project 2> /dev/null || true)
  if [ -n "$account" ]; then
    echo "gcloud: $account, project ${project:-none (gcloud config set project <id>)}"
  else
    echo "gcloud: not signed in: gcloud init"
  fi
else
  echo "gcloud: not installed (gcloud module)"
fi

if command -v az > /dev/null 2>&1; then
  if sub=$(az account show --query '[name, user.name]' -o tsv 2> /dev/null | paste -sd' ' -) && [ -n "$sub" ]; then
    echo "az: $sub"
  else
    echo "az: not signed in: az login"
  fi
else
  echo "az: not installed (azure module)"
fi

if command -v kubectl > /dev/null 2>&1; then
  if ctx=$(kubectl config current-context 2> /dev/null) && [ -n "$ctx" ]; then
    echo "kubectl: context $ctx"
  else
    echo "kubectl: no context: gcloud container clusters get-credentials <cluster>, or az aks get-credentials -g <group> -n <cluster>"
  fi
else
  echo "kubectl: not installed (kubernetes module)"
fi
