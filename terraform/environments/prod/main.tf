# Coka Production Environment - Terraform Configuration
# Region: cn-shanghai (华东 2)

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.220.0"
    }
  }
  
  backend "oss" {
    bucket         = "coka-terraform-state"
    prefix         = "prod"
    region         = "cn-shanghai"
    encrypt        = true
    kms_key_id     = "alias/acs/oss"
  }
}

provider "alicloud" {
  region = "cn-shanghai"
}

# ============================================
# Variables
# ============================================

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "coka"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "172.16.0.0/16"
}

variable "ecs_instance_type" {
  description = "ECS instance type"
  type        = string
  default     = "ecs.g7.2xlarge"
}

variable "rds_instance_type" {
  description = "RDS instance type"
  type        = string
  default     = "mysql.n2.large.4c"
}

variable "redis_instance_type" {
  description = "Redis instance type"
  type        = string
  default     = "redis.master.mid"
}

# ============================================
# VPC Network
# ============================================

module "vpc" {
  source = "../../modules/vpc"
  
  environment    = var.environment
  project        = var.project
  vpc_cidr       = var.vpc_cidr
  availability_zones = ["cn-shanghai-a", "cn-shanghai-b"]
  
  vswitch_configs = [
    {
      name              = "vsw-prod-a"
      cidr_block        = "172.16.10.0/24"
      availability_zone = "cn-shanghai-a"
    },
    {
      name              = "vsw-prod-b"
      cidr_block        = "172.16.11.0/24"
      availability_zone = "cn-shanghai-b"
    },
    {
      name              = "vsw-db"
      cidr_block        = "172.16.20.0/24"
      availability_zone = "cn-shanghai-a"
    }
  ]
  
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ============================================
# Security Groups
# ============================================

module "security_groups" {
  source = "../../modules/security-group"
  
  vpc_id = module.vpc.vpc_id
  
  security_groups = {
    web = {
      name        = "sg-web"
      description = "Web server security group"
      ingress = [
        {
          port_range  = "80/80"
          protocol    = "tcp"
          source_cidr = "0.0.0.0/0"
        },
        {
          port_range  = "443/443"
          protocol    = "tcp"
          source_cidr = "0.0.0.0/0"
        }
      ]
    },
    app = {
      name        = "sg-app"
      description = "Application server security group"
      ingress = [
        {
          port_range  = "3000/3000"
          protocol    = "tcp"
          source_cidr = module.vpc.vpc_cidr
        }
      ]
    },
    db = {
      name        = "sg-db"
      description = "Database security group"
      ingress = [
        {
          port_range  = "3306/3306"
          protocol    = "tcp"
          source_cidr = module.vpc.vpc_cidr
        }
      ]
    },
    redis = {
      name        = "sg-redis"
      description = "Redis security group"
      ingress = [
        {
          port_range  = "6379/6379"
          protocol    = "tcp"
          source_cidr = module.vpc.vpc_cidr
        }
      ]
    }
  }
}

# ============================================
# SLB (Server Load Balancer)
# ============================================

module "slb" {
  source = "../../modules/slb"
  
  name          = "${var.project}-prod-slb"
  vpc_id        = module.vpc.vpc_id
  vswitch_ids   = module.vpc.vswitch_ids
  instance_type = "slb.s2.large"
  
  listeners = [
    {
      port          = 80
      protocol      = "http"
      backend_port  = 3000
      health_check  = true
      redirect_https = true
    },
    {
      port          = 443
      protocol      = "https"
      backend_port  = 3000
      health_check  = true
      certificate_id = alicloud_ssl_certificate.coka_cert.id
    }
  ]
}

# ============================================
# Auto Scaling Group
# ============================================

module "auto_scaling" {
  source = "../../modules/auto-scaling"
  
  name                = "${var.project}-prod-asg"
  vpc_id              = module.vpc.vpc_id
  vswitch_ids         = module.vpc.vswitch_ids
  security_group_ids  = [module.security_groups.security_group_ids["app"]]
  slb_ids             = [module.slb.slb_id]
  
  instance_type       = var.ecs_instance_type
  image_id            = "aliyun_20_3_x64_20G_alibase_20260315.vhd"
  
  min_size            = 6
  max_size            = 20
  desired_capacity    = 8
  
  scaling_rules = [
    {
      name              = "cpu-scale-up"
      adjustment_type   = "TotalCapacity"
      adjustment_value  = 2
      cooldown          = 300
      metric_name       = "CPUUtilization"
      threshold         = 60
      comparison_operator = "GreaterThan"
    },
    {
      name              = "cpu-scale-down"
      adjustment_type   = "TotalCapacity"
      adjustment_value  = -1
      cooldown          = 300
      metric_name       = "CPUUtilization"
      threshold         = 30
      comparison_operator = "LessThan"
    }
  ]
}

# ============================================
# RDS MySQL
# ============================================

module "rds" {
  source = "../../modules/rds"
  
  name                = "${var.project}-prod-rds"
  vpc_id              = module.vpc.vpc_id
  vswitch_id          = module.vpc.vswitch_ids[2] # DB vSwitch
  security_group_id   = module.security_groups.security_group_ids["db"]
  
  engine              = "MySQL"
  engine_version      = "8.0"
  instance_type       = var.rds_instance_type
  storage_type        = "cloud_essd_pl1"
  allocated_storage   = 500
  
  instance_charge_type = "Postpaid"
  availability_zone    = "cn-shanghai-a"
  
  # High Availability: Primary + Standby
  ha_config = {
    enabled         = true
    secondary_zone  = "cn-shanghai-b"
    automatic_failover = true
  }
  
  # Backup configuration
  backup_config = {
    retention_period = 30
    backup_time      = "02:00Z-03:00Z"
  }
  
  # Monitoring
  monitoring_config = {
    enabled              = true
    slow_query_log       = true
    sql_collector        = true
    audit_log            = true
  }
}

# ============================================
# Redis Cluster
# ============================================

module "redis" {
  source = "../../modules/redis"
  
  name                = "${var.project}-prod-redis"
  vpc_id              = module.vpc.vpc_id
  vswitch_id          = module.vpc.vswitch_ids[2] # DB vSwitch
  security_group_id   = module.security_groups.security_group_ids["redis"]
  
  instance_type       = var.redis_instance_type
  engine_version      = "7.0"
  architecture        = "cluster" # Cluster mode
  shard_count         = 3
  
  instance_charge_type = "Postpaid"
  availability_zone    = "cn-shanghai-a"
}

# ============================================
# OSS (Object Storage Service)
# ============================================

module "oss" {
  source = "../../modules/oss"
  
  bucket_name         = "${var.project}-prod-shanghai"
  location            = "cn-shanghai"
  storage_class       = "Standard"
  
  versioning          = true
  encryption          = true
  
  lifecycle_rules = [
    {
      id                      = "transition-to-ia"
      enabled                 = true
      prefix                  = "uploads/"
      transition_days         = 30
      transition_storage_class = "IA"
    },
    {
      id                      = "transition-to-archive"
      enabled                 = true
      prefix                  = "backups/"
      transition_days         = 365
      transition_storage_class = "Archive"
    },
    {
      id                      = "expiration"
      enabled                 = true
      prefix                  = "tmp/"
      expiration_days         = 7
    }
  ]
  
  cors_rules = [
    {
      allowed_origins = ["*"]
      allowed_methods = ["GET", "PUT", "POST"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  ]
}

# ============================================
# CDN (Content Delivery Network)
# ============================================

module "cdn" {
  source = "../../modules/cdn"
  
  domain_name         = "static.coka.com"
  origin              = module.oss.bucket_domain
  origin_type         = "oss"
  
  https_enabled       = true
  certificate_id      = alicloud_ssl_certificate.coka_cert.id
  
  cache_configs = [
    {
      path            = "*.jpg;*.png;*.gif;*.webp"
      ttl             = 2592000 # 30 days
      weight          = 100
    },
    {
      path            = "*.css;*.js"
      ttl             = 604800  # 7 days
      weight          = 100
    },
    {
      path            = "*.html"
      ttl             = 0       # No cache
      weight          = 100
    }
  ]
}

# ============================================
# SSL Certificate
# ============================================

resource "alicloud_ssl_certificate" "coka_cert" {
  name        = "${var.project}-prod-cert"
  domain_name = "*.coka.com"
}

# ============================================
# WAF (Web Application Firewall)
# ============================================

module "waf" {
  source = "../../modules/waf"
  
  name                = "${var.project}-prod-waf"
  domain              = "www.coka.com"
  slb_id              = module.slb.slb_id
  slb_port            = 443
  
  rules = [
    {
      name            = "sql-injection"
      action          = "block"
      rule_group_id   = "sqli"
    },
    {
      name            = "xss-protection"
      action          = "block"
      rule_group_id   = "xss"
    },
    {
      name            = "cc-protection"
      action          = "monitor"
      qps_threshold   = 100
      block_duration  = 600
    }
  ]
}

# ============================================
# CloudMonitor & Alerts
# ============================================

module "monitor" {
  source = "../../modules/monitor"
  
  project               = var.project
  environment           = var.environment
  ecs_instance_ids      = module.auto_scaling.ecs_instance_ids
  rds_instance_id       = module.rds.rds_instance_id
  redis_instance_id     = module.redis.redis_instance_id
  slb_instance_id       = module.slb.slb_id
  
  alert_groups = [
    {
      name              = "infrastructure-team"
      contacts          = ["admin@coka.com"]
      phone_numbers     = ["+86-13800000000"]
      dingtalk_webhook  = var.dingtalk_webhook
    }
  ]
  
  alert_rules = [
    # CPU
    {
      name              = "cpu-high"
      metric_name       = "CPUUtilization"
      threshold         = 80
      comparison_operator = "GreaterThan"
      period            = 300
      evaluation_count  = 3
      level             = "Critical"
    },
    # Memory
    {
      name              = "memory-high"
      metric_name       = "MemoryUtilization"
      threshold         = 85
      comparison_operator = "GreaterThan"
      period            = 300
      evaluation_count  = 3
      level             = "Critical"
    },
    # Disk
    {
      name              = "disk-high"
      metric_name       = "DiskUtilization"
      threshold         = 85
      comparison_operator = "GreaterThan"
      period            = 300
      evaluation_count  = 1
      level             = "Critical"
    },
    # RDS
    {
      name              = "rds-cpu-high"
      metric_name       = "CpuUsage"
      threshold         = 80
      comparison_operator = "GreaterThan"
      period            = 300
      evaluation_count  = 3
      level             = "Critical"
    },
    # Redis
    {
      name              = "redis-memory-high"
      metric_name       = "MemoryUsage"
      threshold         = 80
      comparison_operator = "GreaterThan"
      period            = 300
      evaluation_count  = 3
      level             = "Critical"
    }
  ]
}

# ============================================
# Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vswitch_ids" {
  description = "VSwitch IDs"
  value       = module.vpc.vswitch_ids
}

output "slb_public_ip" {
  description = "SLB Public IP"
  value       = module.slb.public_ip
}

output "rds_connection_string" {
  description = "RDS Connection String"
  value       = module.rds.connection_string
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis Connection String"
  value       = module.redis.connection_string
  sensitive   = true
}

output "oss_bucket_name" {
  description = "OSS Bucket Name"
  value       = module.oss.bucket_name
}

output "cdn_domain" {
  description = "CDN Domain"
  value       = module.cdn.domain_name
}
