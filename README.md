# BII Relay Container

A simple container to trigger a SLURM job in Rivanna whenever a GitHub repoistory receives a push or releases a version.

## Pull Architecture

To link GitHub and Rivanna, this architecture uses a messaging queueing service, Amazon SQS. Activities in GitHub trigger
a message to be published to an SQS queue. Messages in the queue are then picked up by a constantly cycling container in
DCOS that is looking for messages. Upon receipt of a message, it gathers specific variables from the message and acts
accordingly.

A pull or "polling" design is useful here for two reasons:

- GitHub and Travis-CI sit outside of the UVA networks and cannot directly reach a Rivanna interactive node.
- Should Rivanna be offline (maintenance, updates, etc.), messages in the queue continue to accumulate and can be processed later.

## 1. Publishing to SQS - Travis-CI is an easy solution for this step since it can act programmatically with elements of your GitHub
repository and variables related to it (version, committer, commit hash, branch, tag, release, etc.) See the included `travis.yml` file
for inclusion in your source code repository. That repository can trigger any number of actions using Travis, such as unit tests,
builds, compiles, file shipping (to someplace like S3), as well as sending an SQS message. The `aws sqs` command in that template
also shows how to pass along custom MessageAttributes.

In order for Travis to send SQS messages you will need three environment variables in the Travis environment:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` - should be set to `us-east-1`.

You will also need to set the URL of the Amazon SQS queue in your `.travis.yml` file.

```
language: bash

services:
  - docker

before_install:
  - sudo pip install --upgrade pip
  - pip install --user awscli
  - export PATH=$PATH:$HOME/.local/bin

install:
    aws sqs send-message --queue-url 'https://queue.amazonaws.com/123456789012/queue-name' --message-body 'release' --message-attributes '{"item1": {"StringValue":"this-is-value-1","DataType":"String"}, "item2": {"StringValue":"this-is-value-2","DataType":"String"}, "item3": {"StringValue":"this-is-value-3","DataType":"String"}}' || exit 1;

notifications:
  email:
    on_success: change
    on_failure: always
    recipients:
    - mst3k@virginia.edu
```

## 2. Message Processing - The container in this repository is designed for multiple uses and can be adapted to do a number of things.
But the central idea is (A) to look for messages on a continual basis (see the run command below); (B) pick up and parse a message
when one is available in the queue, then do something with that information; and (C) delete the message when B has completed
successfully.

In order to run on a continous cycle, the container can be run with this command:

```bash
while [ true ]; do /bin/sh /run.sh; sleep 30; done
```

The container also requires several variables in order to do its work. These can be set as environment variables within your
container platform (DCOS, Kubernetes, Docker Swarm, etc.) or most of them could also be sent as MessageAttributes within the SQS
message itself.

2. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` - with SQS read/write access
6. `QURL` - Amazon SQS message queue URL.
3. `USERID` - mst3k for UVA
4. `RIVANNA_SCRIPT` - full path to a bash script to be executed. This script should invoke sbatch according to your parameters -- allocation, partition, script to execute, etc.
5. `GIT_REPO` - the org/repo for GitHub repository "organization/repo-name"
7. SQS Attribute: `$VERSION` - specify release number, i.e. 0.1.0, 1.0.3, 5.0.0, etc.

- `id_rsa` private key for Rivanna access (can also be used for pulling from private Git repo. In DCOS this should be passed to the container as a secret.)
