#!/bin/sh
set -e -x

# This container needs the following to run. These could be set as ENV parameters at container runtime, or
# they could all be passed as MessageAttributes in the SQS message. (All but the SSH key.)
# 
# 1. id_rsa private key for Rivanna in /root/.ssh/id_rsa (can also be used for pulling from private Git repo.
#    In DCOS this should be passed to the container as a secret.
# 2. ENV_VAR: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY with SQS read/write access
# 3. ENV_VAR: $USERID - mst3k for UVA
# 4. ENV_VAR: $RIVANNA_SCRIPT - full path to a bash script to be executed. This script should invoke sbatch
#    according to your parameters -- allocation, partition, script to execute, etc.
# 5. ENV_VAR: $GIT_REPO - the org/repo for GitHub repository "organization/repo-name"
# 6. ENV_VAR: $QURL Amazon SQS message queue URL.
# 7. SQS Attribute: $VERSION - specify release number, i.e. 0.1.0, 1.0.3, 5.0.0, etc.
# 


chmod 600 /root/.ssh/id_rsa

# Check Amazon SQS queue for any messages - i.e. any GitHub release messages
QCOUNT=`/usr/local/bin/aws sqs get-queue-attributes \
  --queue-url "$QURL" \
  --attribute-names "ApproximateNumberOfMessages" | \
  /usr/local/bin/jq -r .Attributes.ApproximateNumberOfMessages`
echo $QCOUNT

if [ "$QCOUNT" -gt 0 ]; then
  # Do something with the queue
  RAW=`/usr/local/bin/aws sqs receive-message \
    --message-attribute-names "All" \
    --max-number-of-messages 1 \
    --queue-url "$QURL" \
    --wait-time-seconds 20`;

  VERSION=`echo $RAW | /usr/local/bin/jq -r .Messages[0].MessageAttributes.version.StringValue`;
  PARAMETER1=`echo $RAW | /usr/local/bin/jq -r .Messages[0].MessageAttributes.parameter1.StringValue`;
  PARAMETER2=`echo $RAW | /usr/local/bin/jq -r .Messages[0].MessageAttributes.parameter2.StringValue`;

  # Clone the repository if needed
  # /usr/bin/git clone $GIT_REPO
  # cd into dir
  # ... do things ...  

  # Fetch the tarball of a release
  # curl -o v$VERSION.tar.gz https://codeload.github.com/$GIT_REPO/tar.gz/v$VERSION
  # unpack the release
  # tar -xzvf v$VERSION.tar.gz
  # ... do things ...

  # PROD :: Submit a SLURM job using these values by calling a remote script on Rivanna. Pass additional parameters
  # if needed.
  RCMD+="/bin/bash "
  RCMD+="$RIVANNA_SCRIPT"
  /usr/bin/ssh -oStrictHostKeyChecking=no -i ~/.ssh/id_rsa $USERID@rivanna.hpc.virginia.edu $RCMD $VERSION

  # Delete the SQS message once 
  RECEIPTHANDLE=`echo $RAW | /usr/local/bin/jq -r .Messages[0].ReceiptHandle`;
  /usr/local/bin/aws sqs delete-message \
    --queue-url "$QURL" \
    --receipt-handle "$RECEIPTHANDLE";

else

  # There are no SQS messages. Do nothing.
  echo "No files"
  exit 0

fi

exit 0
