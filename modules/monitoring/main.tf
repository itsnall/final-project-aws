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