#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY EC2 GitLab INSTANCE
#This template runs HA-GitLab on a EC2 Instance
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#REQUIRE A SPECIFIC TERRAFORM VERSION
#This module has been update with Terraform 0.12 syntax.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
    required_version = ">= 0.12"
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#AWS PROVIDER
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
    region = var.aws_region
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY VPC
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_vpc" "vpc_gitlab" {
    cidr_block = "172.16.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "VPC GitLab Instance"
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY INTERNET GATEWAY
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_internet_gateway" "gateway_gitlab" {
    vpc_id = aws_vpc.vpc_gitlab.id
    tags = {
        Name = "Gateway GitLab"
    }

}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY SUBNET
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_subnet" "subnet_public" {
    count = length(var.subnet_cidr_public)
    cidr_block = element(var.subnet_cidr_public, count.index)
    vpc_id = aws_vpc.vpc_gitlab.id
    availability_zone = element(var.available_zone, count.index)
    tags = {
        Name = "gitlab_public_${count.index+1}"
    }
}

resource "aws_subnet" "subnet_private" {
    count = length(var.subnet_cidr_private)
    cidr_block = element(var.subnet_cidr_private, count.index)
    vpc_id = aws_vpc.vpc_gitlab.id
    availability_zone = element(var.available_zone, count.index )
    tags = {
        Name = "gitlab_private_${count.index+1}"
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY ROUTE TABLE
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_route_table" "default_route" {
    vpc_id = aws_vpc.vpc_gitlab.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gateway_gitlab.id
    }
    tags = {
        Name = "GitLab-Public"
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY ROUTE TABLE ASSOCIATION
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_route_table_association" "gitlab_public" {
    count = length(var.subnet_cidr_public)
    subnet_id = element(aws_subnet.subnet_public.*.id, count.index)
    route_table_id = aws_route_table.default_route.id
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY SECURITY GROUP
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_security_group" "gitlab_allow_connection" {
    name = "Security Group - GitLab"
    description = "Allow connection SSH HTTP & HTTPS"
    vpc_id = aws_vpc.vpc_gitlab.id

    ingress {
        from_port = 22
        protocol = "tcp"
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        protocol = "tcp"
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        protocol = "tcp"
        to_port = 443
        cidr_blocks = ["0.0.0.0/0"]
    }

}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY LOAD BALANCER
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_elb" "gitlab_loadbalancer" {
    name = "GitLab-ELB"
    security_groups = [aws_security_group.elb_allow_connection.id]
    availability_zones = var.available_zone

    health_check {
        healthy_threshold = 2
        interval = 30
        target = "HTTP:${var.gitlab_port}/"
        timeout = 3
        unhealthy_threshold = 2
    }

    # This adds a listener for incoming HTTP requests.
    listener {
        instance_port = var.gitlab_port
        instance_protocol = "http"
        lb_port = var.balancer_port
        lb_protocol = "http"
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY SECURITY GROUP - CONTROLS WHAT GO IN & OUT IN LOAD BALANCER
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_security_group" "elb_allow_connection" {
    name = "GitLab ELB - Security Group"

    # Allow all outbound
    egress {
        from_port = 0
        protocol = "-1"
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Inbound HTTP from anywhere
    ingress {
        from_port = var.balancer_port
        protocol = "tcp"
        to_port = var.balancer_port
        cidr_blocks = ["0.0.0.0/24"]
    }
}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#DEPLOY EC2 GitLab INSTANCE
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_autoscaling_group" "gitlab_autoscaling" {
    launch_configuration = aws_launch_configuration.gitlab_launch.id
    count = length(var.available_zone)
    availability_zones = element(var.available_zone, count.index)
    max_size = 4
    min_size = 2

    load_balancers = [aws_elb.gitlab_loadbalancer.name]
    health_check_type = "ELB"

    tag {
        key = "Name"
        propagate_at_launch = true
        value = "GitLab_Autoscaling"
    }
}

resource "aws_launch_configuration" "gitlab_launch" {
    # CentOS 7 img created by Packer Script
    image_id = ""
    instance_type = "t2.micro"
    security_groups = [aws_security_group.gitlab_allow_connection.id]
    key_name = aws_key_pair.ssh_default.key_name

    # Whenever using a launch configuration with an auto scaling group, you must set create_before_destroy = true.
    lifecycle {
        create_before_destroy = true
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create AWS Key Pair
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_key_pair" "ssh_default" {
    key_name = "ssh_gitlab"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDWpKTQ+kEUhMT8dJzzRwBo51N7xQNe5Fh5UhOz2aikW9MQn+IcegjYegf4+ZLsi4c9wo/qvOniBFgQl7agNE07HQoDsB+2Mw1D8D8DeCqF+kkachlVdFw5WkNjdk1UhNTwUh0njxh6tT939cZl/9gOQ/l7u/YaTVNdtyhyb0i80tffmICOiXYTNVHXJ40ZFrXkqOWkuB60O6PqRrZE+evFoIhfpPwUW1jEEYZKlh+YoVCcRSQIzOdTi2Yla9q0SgxQDAKKODNDGvqJLlTdDxE5oE4vA+/8haJbvfGDurxtpx9IATUeuibyhGRIF0lNB7P6HTTN7GqoGI5rZtv0nJhdmaUYTa25m39a5axa7S4mC3/fa+tCkktIi+v6tQDPiIGHi0+LkgxNs4oR6MkYGQ4E+xJjolvCkQpmRteAz7JCF6zesowPIH0uUfr9aozz3MyPhYram89xAEe8rYj6CElM9pxcDVIfGVUW9Xhkr+y5dmyXHN+PMl2I6Kthn0XTAFM+BIxVDSlthDUv3Buf18SAvzhqLPW1yYZtI3dSGN1FEe/UjafAnA5JhXotRp29a1ytjOxqiuesbT/hkgXORnmGE9aPkCbdXnep3XRGDkHA729lszoBlfSFGIAd83uEJA04jKxcKLf822Ti4uRlTz/EGztpfcx25O4hPnb3pqCXvw== jontambi.business@gmail.com"
}




#Referencia:
#https://github.com/gruntwork-io/intro-to-terraform
#https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d
