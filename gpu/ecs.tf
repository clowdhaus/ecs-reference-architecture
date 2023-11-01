################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.0"

  cluster_name = local.name

  # Capacity provider - autoscaling groups
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    (local.name) = {
      auto_scaling_group_arn         = module.autoscaling.autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }

      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    }
  }

  tags = module.tags.tags
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 7.0"

  name = local.name

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_gpu_ami.value)["image_id"]
  instance_type = "g5.xlarge"

  security_groups = [module.autoscaling_sg.security_group_id]
  user_data = base64encode(
    <<-EOT
      #!/bin/bash

      cat <<'EOF' >> /etc/ecs/ecs.config
      ECS_CLUSTER=${local.name}
      ECS_LOGLEVEL=debug
      ECS_ENABLE_TASK_IAM_ROLE=true
      ECS_ENABLE_GPU_SUPPORT=true

      echo "ip_resolve=4" >> /etc/yum.conf
    EOT
  )
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  tags = module.tags.tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Autoscaling group"
  vpc_id      = module.vpc.vpc_id

  egress_rules = ["all-all"]

  tags = module.tags.tags
}

################################################################################
# ECS Service
################################################################################

# We are creating everything but tasks - we'll use the RunTask API for this example
# since it is a job (run to completion and stop) and not a continuously running process
module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = local.name
  desired_count      = 0
  cluster_arn        = module.ecs_cluster.arn
  enable_autoscaling = false

  # Task Definition
  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    default = {
      capacity_provider = module.ecs_cluster.cluster_capacity_providers[local.name].id
      weight            = 1
      base              = 1
    }
  }

  container_definitions = {
    vectoradd = {
      image = "nvidia/samples:vectoradd-cuda11.6.0-ubi8"

      resource_requirements = [{
        type  = "GPU"
        value = 1
      }]
      environment = [
        {
          name  = "NVIDIA_DRIVER_CAPABILITIES",
          value = "compute,utility"
        },
        {
          name  = "NVIDIA_REQUIRE_CUDA",
          value = "cuda>=11.0"
        },
      ]
    }
  }

  subnet_ids = module.vpc.private_subnets
  security_group_rules = {
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = module.tags.tags
}

################################################################################
# ECS Run Task Config
################################################################################

resource "local_file" "this" {
  filename = "config.json"
  content = jsonencode(
    {
      capacityProviderStrategy = [{
        capacityProvider = module.ecs_cluster.cluster_capacity_providers[local.name].id
        weight           = 1
        base             = 1
      }]
      cluster = module.ecs_cluster.name
      count   = 1
      networkConfiguration = {
        awsvpcConfiguration = {
          subnets = module.vpc.private_subnets
          securityGroups : [module.ecs_service.security_group_id]
          assignPublicIp = "DISABLED"
        }
      }
      taskDefinition = "${module.ecs_service.task_definition_family}:${module.ecs_service.task_definition_revision}"
    }
  )
}
