# config the storage stats worker launch config, autoscaling group, alarms, etc

resource "aws_launch_configuration" "storage_stats_worker_launch_config" {
  name_prefix          = "${var.stack_name}-storage_stats-worker-launch-config_"
  image_id             = local.node_image_id
  instance_type        = var.worker_instance_class
  iam_instance_profile = data.aws_iam_instance_profile.duracloud.name
  security_groups      = [aws_security_group.mill_instance.id]
  key_name             = var.ec2_keypair
  spot_price           = var.worker_spot_price
  user_data            = templatefile("${path.module}/resources/cloud-init.tpl", merge(local.cloud_init_props, { node_type = "storage_stats-worker" }))
  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "storage_stats_worker_asg" {
  name                 = "${var.stack_name}-storage_stats-worker-asg"
  launch_configuration = aws_launch_configuration.storage_stats_worker_launch_config.name
  vpc_zone_identifier  = [data.aws_subnet.duracloud_a.id, data.aws_subnet.duracloud_c.id, data.aws_subnet.duracloud_d.id]
  max_size             = 1
  min_size             = 0
  tag {
    key                 = "Name"
    value               = "${var.stack_name}-storage-stats-worker"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "storage_stats_worker_scale_up" {
  name                   = "${var.stack_name}-storage_stats_worker_scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.storage_stats_worker_asg.name
}

resource "aws_autoscaling_policy" "storage_stats_worker_scale_down" {
  name                   = "${var.stack_name}-storage_stats_worker_scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.storage_stats_worker_asg.name
}

resource "aws_cloudwatch_metric_alarm" "storage_stats_worker_scale_up_alarm" {
  alarm_name          = "${var.stack_name}-non-empty-storage-stats-queue"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "30"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"

  dimensions = {
    QueueName = aws_sqs_queue.storage_stats.name
  }

  alarm_description = "storage stats queue is not empty"
  alarm_actions     = [aws_autoscaling_policy.storage_stats_worker_scale_up.arn]
}


resource "aws_cloudwatch_metric_alarm" "storage_stats_worker_scale_down_alarm" {
  alarm_name          = "${var.stack_name}-empty-storage-stats-queue"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "6"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"

  dimensions = {
    QueueName = aws_sqs_queue.storage_stats.name
  }

  alarm_description = "storage stats queue is empty"
  alarm_actions     = [aws_autoscaling_policy.storage_stats_worker_scale_down.arn]
}
