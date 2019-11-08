# Variables


variable "aws_region" {
  default = "us-east-1"
}

variable "subnet_cidr_public" {
  type = "list"
  default = ["172.16.10.0/24", "172.16.20.0/24"]
}

variable "subnet_cidr_private" {
  type = "list"
  default = ["172.16.30.0/24", "172.16.40.0/24"]
}

variable "available_zone" {
  type = "list"
  default = ["us-east-1a", "us-east-1b"]
}

variable "balancer_port" {
  default = 80
}

variable "gitlab_port" {
  default = 80
}