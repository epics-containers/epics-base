#!/bin/bash
# Script to be called by .gitlab-ci.yml to perform container build using gitlab kubernetes executor

# this script is designed for projects below the namespace <group name>/containers
# and deploys images to:
#     $CI_REGISTRY/$GROUP/work/$PROJECT_PATH for untagged commits
#     $CI_REGISTRY/$GROUP/work/$PROJECT_PATH for tagged commits
# where PROJECT_PATH is the namespace minus <group name>/containers

echo 'Building image...'
GROUP=${CI_PROJECT_NAMESPACE%%/containers*}
PROJECT_PATH=${CI_PROJECT_NAMESPACE##*containers/}

if [ -z "${CI_COMMIT_TAG}" ]
then
  DESTINATION=$CI_REGISTRY/$GROUP/work/$PROJECT_PATH
  CI_COMMIT_TAG=$CI_COMMIT_REF_NAME
else
  DESTINATION=$CI_REGISTRY/$GROUP/prod/$PROJECT_PATH
fi

CMD="/kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile"
CMD=$CMD" --destination $DESTINATION:$CI_COMMIT_TAG"
CMD=$CMD" --destination $DESTINATION:latest"

echo "Command to execute is..."
echo $CMD
$CMD