# config the low priority dup worker launch config, autoscaling group, alarms, etc

resource "aws_launch_configuration" "low_priority_dup_worker_launch_config" {
  name_prefix          = "${var.stack_name}-low_priority_dup-worker-launch-config_"
  image_id             = local.node_image_id
  instance_type        = var.worker_instance_class
  iam_instance_profile = data.aws_iam_instance_profile.duracloud.name
  security_groups      = [aws_security_group.mill_instance.id]
  key_name             = var.ec2_keypair
  spot_price           = var.worker_spot_price
  user_data            = templatefile("${path.module}/resources/cloud-init.tpl", merge(local.cloud_init_props, { node_type = "dup-worker" }))
  root_block_device {
    volume_type = "gp2"
    volume_size = 60
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "low_priority_dup_worker_asg" {
  name                 = "${var.stack_name}-low_priority_dup-worker-asg"
  launch_configuration = aws_launch_configuration.low_priority_dup_worker_launch_config.name
  vpc_zone_identifier  = [data.aws_subnet.duracloud_a.id, data.aws_subnet.duracloud_c.id, data.aws_subnet.duracloud_d.id]
  max_size             = var.low_priority_dup_worker_max
  min_size             = 0
  tag {
    key                 = "Name"
    value               = "${var.stack_name}-low-priority-duplicate-worker"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "low_priority_dup_worker_scale_up" {
  name                   = "${var.stack_name}-low_priority_dup_worker_scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.low_priority_dup_worker_asg.name
}

resource "aws_autoscaling_policy" "low_priority_dup_worker_scale_down" {
  name                   = "${var.stack_name}-low_priority_dup_worker_scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  cooldown               = 900
  autoscaling_group_name = aws_autoscaling_group.low_priority_dup_worker_asg.name
}

resource "aws_cloudwatch_metric_alarm" "low_priority_dup_worker_scale_up_alarm" {
  alarm_name          = "${var.stack_name}-large-low_priority_dup_queue-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"

  dimensions = {
    QueueName = aws_sqs_queue.low_priority_dup.name
  }

  alarm_description = "This metric monitors low_priority_dup queue size"
  alarm_actions     = [aws_autoscaling_policy.low_priority_dup_worker_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "low_priority_dup_worker_scale_down_alarm" {
  alarm_name          = "${var.stack_name}-small-low_priority_dup-queue-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "4"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"

  dimensions = {
    QueueName = aws_sqs_queue.low_priority_dup.name
  }

  alarm_description = "This metric monitors low_priority_dup queue size"
  alarm_actions     = [aws_autoscaling_policy.low_priority_dup_worker_scale_down.arn]
}



