
output "ld_dns_name" {
  value = aws_elb.gitlab_loadbalancer.dns_name
  description = "Domain Name Load Balance GitLab"
}