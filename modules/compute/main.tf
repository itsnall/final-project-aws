# 1. Mengambil AMI Amazon Linux 2023 terbaru secara otomatis
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 2. Security Group untuk Eksternal ALB (Bisa diakses publik dari Internet)
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

# 3. Security Group untuk Web Tier EC2 (Hanya menerima trafik dari ALB)
resource "aws_security_group" "web_ec2_sg" {
  name   = "eduflow-web-ec2-sg"
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

# 4. Security Group untuk Internal ALB
resource "aws_security_group" "internal_alb_sg" {
  name   = "eduflow-internal-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_ec2_sg.id] # Hanya menerima dari Web Tier
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Security Group untuk App Tier EC2
resource "aws_security_group" "app_ec2_sg" {
  name   = "eduflow-app-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. IAM Role & Profile agar EC2 bisa membaca S3
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

resource "aws_iam_role_policy" "ec2_policy" {
  name = "eduflow_ec2_policy"
  role = aws_iam_role.ec2_s3_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Izin untuk membaca materi di S3
        Action = ["s3:GetObject", "s3:ListBucket", "s3:PutObject"]
        Effect = "Allow"
        Resource = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"]
      },
      {
        # Izin untuk mengirim Log server ke CloudWatch
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

## menyisipkan SSM Role ke dalam IAM Role yang sudah ada
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "eduflow_ec2_profile"
  role = aws_iam_role.ec2_s3_role.name
}

# 7. Application Load Balancer (ALB) & Target Group
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

  health_check {
  path                = "/"
  healthy_threshold   = 2
  unhealthy_threshold = 2
  timeout             = 3
  interval            = 30
}
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

### Load Balancer Internal
resource "aws_lb" "internal_alb" {
  name               = "eduflow-internal-alb"
  internal           = true 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb_sg.id]
  subnets            = var.private_app_subnets
}

# Target Group untuk App Tier (Private)
resource "aws_lb_target_group" "internal_app_tg" {
  name     = "eduflow-internal-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# Listener untuk Internal ALB
resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_app_tg.arn
  }
}

# 7. Launch Template & Auto Scaling Group
### Launch Template Web Tier
resource "aws_launch_template" "web_lt" {
  name_prefix   = "eduflow-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_ec2_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/web_user_data.sh", {
    internal_alb_dns_name = aws_lb.internal_alb.dns_name
  }))
}

# Auto Scaling Group untuk Web Tier 
resource "aws_autoscaling_group" "web_asg" {
  vpc_zone_identifier = var.public_subnets
  target_group_arns   = [aws_lb_target_group.app_tg.arn] 
  min_size            = 1
  max_size            = 2
  desired_capacity    = 2 

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }
}


### Launch Template App Tier
resource "aws_launch_template" "app_lt" {
  name_prefix   = "eduflow-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    security_groups = [aws_security_group.app_ec2_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh",{
    rds_endpoint = var.db_endpoint
    rds_password = var.db_password
  }))
}

resource "aws_autoscaling_group" "app_asg" {
  vpc_zone_identifier = var.private_app_subnets
  target_group_arns   = [aws_lb_target_group.internal_app_tg.arn]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2 

  launch_template {
    id      = aws_launch_template.app_lt.id 
    version = "$Latest"
  }
}

# 1. Policy untuk Web Tier
resource "aws_autoscaling_policy" "web_cpu_policy" {
  name                   = "web-cpu-target-tracking-policy"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0 
  }
}

# 2. Policy untuk App Tier
resource "aws_autoscaling_policy" "app_cpu_policy" {
  name                   = "app-cpu-target-tracking-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0 
  }
}

