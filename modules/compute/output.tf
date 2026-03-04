output "alb_dns_name" {
  description = "Alamat URL dari Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "asg_name" {
  description = "Nama Auto Scaling Group untuk dipantau CloudWatch"
  value       = aws_autoscaling_group.app_asg.name
}