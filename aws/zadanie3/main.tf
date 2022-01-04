provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cloud2-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "cloud2-subnet"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "cloud2-igw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  tags = {
    Name = "cloud2-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "cloud2-public-route-table"
  }
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

resource "aws_security_group" "default" {
  name        = "cloud2-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.main.id
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
  template = filebase64("main.yaml")
}


resource "aws_eip" "lb" {
  network_border_group = "us-east-1"
}

resource "aws_lb" "lb" {
  name               = "cloud2-lb"
  internal           = false
  load_balancer_type = "network"
  subnet_mapping {
    subnet_id     = aws_subnet.public_subnet.id
    allocation_id = aws_eip.lb.id
  }
}


resource "aws_lb_target_group" "main" {
  name     = "tg-cloud2"
  port     = 8080
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "8080"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

output "lb_ip" {
  value = "http://${aws_eip.lb.public_ip}:8080"
}

resource "aws_launch_template" "template" {
  name                   = "test-instance"
  image_id               = "ami-0ed9277fb7eb570c9"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.default.id]
  user_data              = data.template_file.user_data_server.rendered
}

resource "aws_autoscaling_group" "autoscaling_group" {
  vpc_zone_identifier = [aws_subnet.public_subnet.id]
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  health_check_type   = "ELB"
  launch_template {
    id      = aws_launch_template.template.id
    version = "$Latest"
  }
  force_delete              = true
  
}

resource "aws_autoscaling_attachment" "asg_attachment_lb" {
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.id
  alb_target_group_arn   = aws_lb_target_group.main.arn
}


resource "aws_autoscaling_policy" "asp" {
  name            = "cloud2-asp"
  policy_type     = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 10
  }
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}