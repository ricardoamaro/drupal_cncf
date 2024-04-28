#!/bin/bash -x

curl -L https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml > pipeline.yaml
curl -L https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml > dashboard.yaml
