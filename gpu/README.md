# ECS Cluster w/ GPU EC2 Instances

## Features

If there are features that you think are missing, please feel free to open up a discussion via a GitHub issue. This is a great way to collaborate within the community and capture any shared knowledge for all to see; I will do my best to ensure that knowledge is captured somewhere within this project so that others can benefit from it.

- ECS cluster w/ EC2 Auto Scaling Group that provides GPU instances

## Steps to Provision

### Prerequisites

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deployment

1. Provision resources defined:

  ```sh
  terraform init -upgrade=true
  terraform apply
  ```

2. Once the resources have been provisioned, you should see an output command like shown below:

  ```sh
  Outputs:

  run_task = "aws ecs run-task --cli-input-json file://config.json  --region us-east-1"
  ```

  Copy the command and execute it to run the defined test task on the cluster. This task is a simple test container that performs vector addition on GPUs using NVIDIA CUDA libraries.

  ```sh
  aws ecs run-task --cli-input-json file://config.json  --region us-east-1
  ```

  Log into the AWS console and navigate to the ECS Tasks and view the logs of the task that was just run. You should see output similar to the following:

  ```text
  November 01, 2023 at 19:48 (UTC-4:00) [Vector addition of 50000 elements] vectoradd
  November 01, 2023 at 19:48 (UTC-4:00) Copy input data from the host memory to the CUDA device vectoradd
  November 01, 2023 at 19:48 (UTC-4:00) CUDA kernel launch with 196 blocks of 256 threads vectoradd
  November 01, 2023 at 19:48 (UTC-4:00) Copy output data from the CUDA device to the host memory vectoradd
  November 01, 2023 at 19:48 (UTC-4:00) Test PASSED vectoradd
  November 01, 2023 at 19:48 (UTC-4:00) Done vectoradd
  ```

### Tear Down & Clean-Up

Remove the resources created by Terraform:

```bash
terraform destroy
```
