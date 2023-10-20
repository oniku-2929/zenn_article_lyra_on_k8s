provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

locals {
  region          = "ap-northeast-1"
  eks_version     = "1.27"
  cluster_name    = "lyra-on-eks"
  cluster_version = local.eks_version

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name = "lyra-on-eks"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = local.cluster_name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  cluster_ip_family              = "ipv4"

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      resolve_conflicts        = "OVERWRITE"
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }

    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t2.large"]
    capacity_type  = "SPOT"

    use_custom_launch_template = true

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true

    disk_size       = 10
    name            = "eks-mng-default-${local.cluster_name}"
    use_name_prefix = true

    subnet_ids = module.vpc.private_subnets

    min_size     = 1
    max_size     = 4
    desired_size = 3

    ami_id                   = data.aws_ami.eks_default.image_id
    create_iam_role          = true
    iam_role_name            = "eks-node-group-default-${local.cluster_name}"
    iam_role_use_name_prefix = true
    iam_role_description     = "EKS managed node group for cluster ${local.cluster_name}"
    iam_role_tags            = local.tags

    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    enable_bootstrap_user_data = true
  }

  eks_managed_node_groups = {
    gameserver = {
      name          = "${local.cluster_name}-gameserver"
      subnet_ids    = module.vpc.public_subnets
      capacity_type = "SPOT"
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }
        }
      }
    }

    prometheus = {
      #prometheus requires 2CPU, 4GBmem, so t2.small and t2.medium are not enough.
      name            = "${local.cluster_name}-prometheus"
      capacity_type   = "SPOT"
      instance_types  = ["t2.xlarge"]
      min_size        = 1
      max_size        = 1
      desired_size    = 1
      create_iam_role = true
      iam_role_name   = "node-group-prometheus-${local.cluster_name}"
      #vpc_security_group_ids = []
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }
        }
      }
    }
  }

  create_aws_auth_configmap = false
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = "root"
      groups   = ["system:masters"]
    },
  ]

  create_node_security_group = true
  node_security_group_additional_rules = {
    ingress_agones_gameserver = {
      description = "Agones Game Server ports"
      protocol    = "udp"
      from_port   = 7000
      to_port     = 8000
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress_agones_webhooks = {
      description              = "for Agones MutatingWebhook ports(cluster to agones-controller)"
      protocol                 = "tcp"
      from_port                = 1025
      to_port                  = 65535
      type                     = "ingress"
      source_security_group_id = module.eks.cluster_security_group_id
    }
  }
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = true
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = true
  }

  tags = local.tags
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  create_role           = true
  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = false
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "Customer managed key to encrypt EKS managed node group volumes"

  # Policy
  key_administrators = [
    data.aws_caller_identity.current.arn
  ]

  key_service_roles_for_autoscaling = [
    # required for the ASG to manage encrypted volumes for nodes
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    # required for the cluster / persistentvolume-controller to create encrypted PVCs
    module.eks.cluster_iam_role_arn,
  ]

  # Aliases
  aliases = ["eks/${local.cluster_name}/ebs"]

  tags = local.tags
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}
