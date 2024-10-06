provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"
  cloudwatch_log_group_name = "/ecs/nginx"
  log_retention_in_days = 1

  task_execution_role_name = "GitmoxiTaskExecutionRole"
  
  app_port = 80

  security_groups = [
    {
      name        = "allow_web"
      description = "Allow web inbound traffic"
      app_port    = 80
    }
  ]


  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/ecs-blueprints"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.6"

  cluster_name = local.name

  fargate_capacity_providers = {
    FARGATE      = {}
    FARGATE_SPOT = {}
  }

  tags = local.tags
}

################################################################################
# VPC and Subnets
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  tags = local.tags
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "allow_web" {
    for_each = { for sg in local.security_groups : sg.name => sg }

    name        = each.value.name
    description = each.value.description
    vpc_id      = module.vpc.vpc_id

    ingress {
        from_port   = each.value.app_port
        to_port     = each.value.app_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = each.value.name
    }
}

################################################################################
# CloudWatch LogGroup
################################################################################

resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = local.log_retention_in_days
}

################################################################################
# Task Execution IAM Role
################################################################################

resource "aws_iam_role" "task_execution_role" {
    name = local.task_execution_role_name

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Principal = {
                    Service = "ecs-tasks.amazonaws.com"
                }
                Effect = "Allow"
                Sid    = ""
            },
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
    role       = aws_iam_role.task_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
