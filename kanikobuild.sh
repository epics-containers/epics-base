#!/bin/bash
# Script to be called by .gitlab-ci.yml to perform container build using gitlab kubernetes executor

echo 'Building image...'
GROUP=`echo ${CI_PROJECT_NAMESPACE} | cut -f 2 -d "/"`

test -z "${CI_COMMIT_TAG}" && CMD="/kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile --destination $CI_REGISTRY/$GROUP/$CI_PROJECT_NAME:$CI_COMMIT_REF_NAME"
test -n "${CI_COMMIT_TAG}" && CMD="/kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile --destination $CI_REGISTRY/$GROUP/$CI_PROJECT_NAME:$CI_COMMIT_TAG --destination gcr.io/$CI_REGISTRY/$GROUP/$CI_PROJECT_NAME:latest"

echo "Command to execute is..."
echo $CMD
$CMD