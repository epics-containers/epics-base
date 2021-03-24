#!/bin/bash
# Script to be called by .gitlab-ci.yml to perform container build using gitlab kubernetes executor

# this script is designed for projects below the group controls/containers

echo 'Building image...'
read GROUP CONTAINERS PROJECT <<<$(IFS="/"; echo $CI_PROJECT_NAMESPACE)

if [ -z "${CI_COMMIT_TAG}" ]
then
  DESTINATION=$CI_REGISTRY/$GROUP/work/$CI_PROJECT_NAME
  CI_COMMIT_TAG=$CI_COMMIT_REF_NAME
else
  DESTINATION=$CI_REGISTRY/$GROUP/prod/$CI_PROJECT_NAME
fi

CMD="/kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile"
CMD=$CMD" --destination $DESTINATION:$CI_COMMIT_TAG"
CMD=$CMD" --destination $DESTINATION:latest"

echo "Command to execute is..."
echo $CMD
$CMD