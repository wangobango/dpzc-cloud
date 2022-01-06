terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.example.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}


resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "example" {
  name        = "cloud2-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.example.id
  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTP from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

data "template_file" "user_data_server" {
  template = filebase64("cloud_config")
}


resource "aws_instance" "server" {
  count                  = 2
  ami                    = "ami-0ed9277fb7eb570c9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.example.id]
  user_data              = data.template_file.user_data_server.rendered

  tags = {
    Name = "cloud-server-${count.index}"
  }
}

resource "aws_eip" "lb" {
  network_border_group = "us-east-1"
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "network"
  enable_deletion_protection = false

  subnet_mapping {
    subnet_id     = aws_subnet.public_subnet.id
    allocation_id = aws_eip.lb.id
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = aws_vpc.example.id
}

resource "aws_lb_target_group_attachment" "test" {
  count            = 2 
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.server[count.index].id
  port             = 8080
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "8080"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

output "ip" {
  value = "http://${aws_lb.test.dns_name}:8080/factors/10"
}

resource "aws_launch_template" "test" {
  name = "webservice_launch_template"
  image_id = "ami-0ed9277fb7eb570c9"
  instance_type = "t2.micro"
  monitoring {
    enabled = true
  }

  placement {
    availability_zone = "us-east-1c"
  }
  vpc_security_group_ids = [aws_security_group.example.id]
  user_data = data.template_file.user_data_server.rendered
}

resource "aws_autoscaling_group" "test" {
  name                      = "test-group"
  max_size                  = 5
  min_size                  = 2
  health_check_type         = "ELB"
  health_check_grace_period = 100
  desired_capacity          = 4
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.public_subnet.id]

  launch_template {
    id      = aws_launch_template.test.id
    version = "$Latest"
  }

  timeouts {
    delete = "15m"
  }

}


resource "aws_elb" "test" {
  name               = "elastic-load-balancer-test"
  subnets            = [aws_subnet.public_subnet.id]
  security_groups    = [aws_security_group.example.id]
  internal           = false

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 8080
    lb_protocol        = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "http:8080/factors/10"
    interval            = 30
  }
}


resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.test.id
  elb                    = aws_elb.test.id
}

resource "aws_autoscaling_policy" "bat" {
  name                   = "policy-test"
  autoscaling_group_name = aws_autoscaling_group.test.name
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 5.0
  }

}

output "ip-2" {
  value = "http://${aws_elb.test.dns_name}:8080/factors/10"
}