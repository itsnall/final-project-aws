# 1. Mengambil AMI Amazon Linux 2023 terbaru secara otomatis
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 2. Security Group untuk ALB (Bisa diakses publik dari Internet)
resource "aws_security_group" "alb_sg" {
  name   = "eduflow-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS ingress untuk ALB
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Security Group untuk EC2 (Hanya menerima trafik dari ALB)
resource "aws_security_group" "ec2_sg" {
  name   = "eduflow-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. IAM Role & Profile agar EC2 bisa membaca S3
resource "aws_iam_role" "ec2_s3_role" {
  name = "eduflow_ec2_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "eduflow_s3_access"
  role = aws_iam_role.ec2_s3_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:GetObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "eduflow_ec2_profile"
  role = aws_iam_role.ec2_s3_role.name
}

# 5. Application Load Balancer (ALB) & Target Group
resource "aws_lb" "app_alb" {
  name               = "eduflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "app_tg" {
  name     = "eduflow-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener HTTPS: forward ke target group dengan sertifikat ACM
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Standar AWS
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 6. Launch Template & Auto Scaling Group
resource "aws_launch_template" "app_lt" {
  name_prefix   = "eduflow-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    security_groups = [aws_security_group.ec2_sg.id]
  }

  # Script otomatis saat EC2 menyala (Bootstrap)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Welcome to EduFlow LMS - Running on AWS Auto Scaling!</h1>" > /var/www/html/index.html
              
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Welcome to EduFlow LMS - Running on AWS Auto Scaling!</h1>" > /var/www/html/index.html
              EOF
  )
}

resource "aws_autoscaling_group" "app_asg" {
  vpc_zone_identifier = var.private_app_subnets
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2 

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}

