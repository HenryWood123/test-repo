
terraform {
  backend "s3" {
    bucket         = "self-heal-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "self-heal-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_sns_topic" "alerts" {
  name = "self_healing_alerts"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "admin@example.com"
}

resource "aws_cloudwatch_metric_alarm" "alarm_0_cpuutilization" {
  alarm_name          = "alarm_0_cpuutilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm for CPUUtilization GreaterThanThreshold 80 on i-0123456789abcdef0"
  dimensions = {
    InstanceId = "i-0123456789abcdef0"
  }
  alarm_actions = [aws_lambda_function.restart_instance.arn]
  ok_actions    = [aws_lambda_function.restart_instance.arn]
}

resource "aws_iam_role" "iam_for_lambda_restart_instance" {
  name = "iam_for_lambda_restart_instance"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }]
  })
}

resource "aws_lambda_function" "restart_instance" {
  function_name = "restart_instance"
  role          = aws_iam_role.iam_for_lambda_restart_instance.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  s3_bucket     = "self-heal-lambdas"
  s3_key        = "lambda-functions/restart_instance.zip"
}

resource "aws_lambda_permission" "allow_cloudwatch_restart_instance" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.restart_instance.function_name
  principal     = "cloudwatch.amazonaws.com"
}
