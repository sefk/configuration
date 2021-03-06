#!/bin/bash -x
# This script is meant to be run from jenkins and expects the
# following variables to be set:
#   - BUILD_ID - set by jenkins, Unique ID of build
#   - BUILD_NUMBER - set by jenkins, Build number
#   - refs - repo revisions to pass to abbey. This is provided in YAML syntax,
#            and we put the contents in a file that abbey reads. Refs are
#            different from 'vars' in that each ref is set as a tag on the
#            output AMI.
#   - vars - other vars to pass to abbey. This is provided in YAML syntax,
#            and we put the contents in a file that abby reads.
#   - deployment - edx, edge, etc
#   - environment - stage,prod, etc
#   - play - forum, edxapp, xqueue, etc
#   - base_ami - Optional AMI to use as base AMI for abby instance
#   - configuration - the version of the configuration repo to use
#   - configuration_secure - the version of the secure repo to use
#   - jenkins_admin_ec2_key - location of the ec2 key to pass to abbey
#   - jenkins_admin_configuration_secure_repo - the git repo to use for secure vars
#   - use_blessed - whether or not to use blessed AMIs

if [[ -z "$BUILD_ID" ]]; then
  echo "BUILD_ID not specified."
  exit -1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "BUILD_NUMBER not specified."
  exit -1
fi

if [[ -z "$refs" ]]; then
  echo "refs not specified."
  exit -1
fi

if [[ -z "$deployment" ]]; then
  echo "deployment not specified."
  exit -1
fi

if [[ -z "$environment" ]]; then
  echo "environment not specified."
  exit -1
fi

if [[ -z "$play" ]]; then
  echo "play not specified."
  exit -1
fi

if [[ -z "$jenkins_admin_ec2_key" ]]; then
  echo "jenkins_admin_ec2_key not specified."
  exit -1
fi

if [[ -z "$jenkins_admin_configuration_secure_repo" ]]; then
  echo "jenkins_admin_configuration_secure_repo not specified."
  exit -1
fi

export PYTHONUNBUFFERED=1

if [[ -z $configuration ]]; then
  cd configuration
  configuration=`git rev-parse HEAD`
  cd ..
fi

if [[ -z $configuration_secure ]]; then
  cd configuration-secure
  configuration_secure=`git rev-parse HEAD`
  cd ..
fi

base_params=""
if [[ -n "$base_ami" ]]; then
  base_params="-b $base_ami"
fi

blessed_params=""
if [[ "$use_blessed" == "true" ]]; then
  blessed_params="--blessed"
fi

playbookdir_params=""
if [[ ! -z "$playbook_dir" ]]; then
  playbookdir_params="--playbook-dir $playbook_dir"
fi

configurationprivate_params=""
if [[ ! -z "$configurationprivaterepo" ]]; then
  configurationprivate_params="--configuration-private-repo $configurationprivaterepo"
  if [[ ! -z "$configurationprivateversion" ]]; then
    configurationprivate_params="$configurationprivate_params --configuration-private-version $configurationprivateversion"
  fi
fi

cd configuration
pip install -r requirements.txt

cd util/vpc-tools/

echo "$refs" > /var/tmp/$BUILD_ID-refs.yml
cat /var/tmp/$BUILD_ID-refs.yml

echo "$vars" > /var/tmp/$BUILD_ID-extra-vars.yml
cat /var/tmp/$BUILD_ID-extra-vars.yml

python -u abbey.py -p $play -t c1.medium  -d $deployment -e $environment -i /edx/var/jenkins/.ssh/id_rsa $base_params $blessed_params $playbookdir_params --vars /var/tmp/$BUILD_ID-extra-vars.yml --refs /var/tmp/$BUILD_ID-refs.yml -c $BUILD_NUMBER --configuration-version $configuration --configuration-secure-version $configuration_secure -k $jenkins_admin_ec2_key --configuration-secure-repo $jenkins_admin_configuration_secure_repo $configurationprivate_params
