# 1. Membuat Saluran Notifikasi (SNS Topic)
resource "aws_sns_topic" "eduflow_alerts" {
  name = "eduflow-admin-alerts"
}

# 2. Mendaftarkan Email Admin ke Saluran Tersebut
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.eduflow_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

# 3. Membuat Alarm CloudWatch untuk CPU Usage
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "eduflow-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"               
  period              = "120"             
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average" 
  threshold           = "80"              # Batas CPU 80%
  alarm_description   = "Mengirim email jika rata-rata CPU EC2 di ASG melebihi 80%"
  
  # Tindakan jika alarm terpicu: Kirim pesan ke SNS Topic
  alarm_actions       = [aws_sns_topic.eduflow_alerts.arn]
  
  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# 4. Autoscaling Policy for Scale-In
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "eduflow-scale-in-policy"
  scaling_adjustment     = -1  # Mengurangi 1 instans EC2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 
  autoscaling_group_name = var.asg_name
}

# 5. Alarm CloudWatch untuk Low CPU Usage (Scale-In)
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "eduflow-low-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"                
  period              = "60"               
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  threshold           = "30"               
  alarm_description   = "Mengurangi instans jika rata-rata CPU di bawah 30% selama 1 menit"

  # Tindakan jika alarm terpicu: Jalankan policy scale-in
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}
