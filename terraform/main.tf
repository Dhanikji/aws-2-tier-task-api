# =========================================================
# VPC
# =========================================================

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "task-vpc"
  }
}

# =========================================================
# PUBLIC SUBNETS
# =========================================================

resource "aws_subnet" "public_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "task-public-subnet-az1"
  }
}

resource "aws_subnet" "public_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "task-public-subnet-az2"
  }
}

# =========================================================
# PRIVATE SUBNETS
# =========================================================

resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "task-private-subnet-az1"
  }
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "task-private-subnet-az2"
  }
}

# =========================================================
# INTERNET GATEWAY
# =========================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "task-igw"
  }
}

# =========================================================
# PUBLIC ROUTE TABLE
# =========================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "task-public-route-table"
  }
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

# =========================================================
# NAT GATEWAY
# =========================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "task-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az1.id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    Name = "task-nat-gateway"
  }
}

# =========================================================
# PRIVATE ROUTE TABLE AZ1
# =========================================================

resource "aws_route_table" "private_az1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "task-private-route-table-az1"
  }
}

# =========================================================
# PRIVATE ROUTE TABLE AZ2
# =========================================================

resource "aws_route_table" "private_az2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "task-private-route-table-az2"
  }
}

resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private_az1.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private_az2.id
}

# =========================================================
# ALB SECURITY GROUP
# =========================================================

resource "aws_security_group" "alb" {
  name        = "task-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-alb-sg"
  }
}

# =========================================================
# APPLICATION SECURITY GROUP
# =========================================================

resource "aws_security_group" "app" {
  name        = "task-app-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "task-app-sg"
  }
}
# =========================================================
# APPLICATION SECURITY GROUP RULES
# =========================================================

# ALB -> Application
resource "aws_vpc_security_group_ingress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id

  from_port   = 8080
  to_port     = 8080
  ip_protocol = "tcp"

  description = "Application traffic from ALB"
}

# SSH from my IP
resource "aws_vpc_security_group_ingress_rule" "my_ip_to_app" {
  security_group_id = aws_security_group.app.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  cidr_ipv4 = "119.252.206.188/32"

  description = "SSH from my IP"
}

# =========================================================
# RDS POSTGRESQL SECURITY GROUP
# =========================================================

resource "aws_security_group" "rds" {
  name        = "task-rds-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-rds-sg"
  }
}
# =========================================================
# RDS DB SUBNET GROUP
# =========================================================

resource "aws_db_subnet_group" "postgres" {
  name = "task-postgres-subnet-group"

  subnet_ids = [
    aws_subnet.private_az1.id,
    aws_subnet.private_az2.id
  ]

  tags = {
    Name = "task-postgres-subnet-group"
  }
}
# =========================================================
# EIC SECURITY GROUP
# =========================================================

resource "aws_security_group" "eic" {
  name        = "task-eic-sg"
  description = "Security group for EC2 Instance Connect Endpoint"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-eic-sg"
  }
}

# =========================================================
# EIC -> APPLICATION SSH RULE
# Separate resource prevents security-group cycle
# =========================================================

resource "aws_vpc_security_group_ingress_rule" "eic_to_app_ssh" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.eic.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "SSH from EC2 Instance Connect Endpoint"
}

# =========================================================
# IAM ROLE FOR EC2
# =========================================================

resource "aws_iam_role" "ec2_role" {
  name = "task-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "task-ec2-role"
  }
}

# =========================================================
# ECR READ ONLY
# =========================================================

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# =========================================================
# SSM MANAGED INSTANCE CORE
# =========================================================

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# =========================================================
# EC2 INSTANCE PROFILE
# =========================================================

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "task-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "task-ec2-profile"
  }
}

# =========================================================
# APPLICATION EC2 - AZ1
# =========================================================

resource "aws_instance" "app_az1" {
  ami           = "ami-0d15e9052c94acb75"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private_az1.id

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  key_name = "prod-key"

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    aws ecr get-login-password --region ap-south-1 | \
      docker login --username AWS --password-stdin \
      427025827458.dkr.ecr.ap-south-1.amazonaws.com

    docker pull \
      427025827458.dkr.ecr.ap-south-1.amazonaws.com/task-api:v1

    docker run -d \
      --name task-api \
      --restart unless-stopped \
      -p 8080:8080 \
      427025827458.dkr.ecr.ap-south-1.amazonaws.com/task-api:v1
  EOF

  tags = {
    Name = "task-app-az1"
  }
}

# =========================================================
# APPLICATION EC2 - AZ2
# =========================================================

resource "aws_instance" "app_az2" {
  ami           = "ami-0d15e9052c94acb75"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private_az2.id

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  key_name = "prod-key"

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    aws ecr get-login-password --region ap-south-1 | \
      docker login --username AWS --password-stdin \
      427025827458.dkr.ecr.ap-south-1.amazonaws.com

    docker pull \
      427025827458.dkr.ecr.ap-south-1.amazonaws.com/task-api:v1

    docker run -d \
      --name task-api \
      --restart unless-stopped \
      -p 8080:8080 \
      427025827458.dkr.ecr.ap-south-1.amazonaws.com/task-api:v1
  EOF

  tags = {
    Name = "task-app-az2"
  }
}

# =========================================================
# APPLICATION LOAD BALANCER
# =========================================================

resource "aws_lb" "app" {
  name               = "task-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_az1.id,
    aws_subnet.public_az2.id
  ]

  tags = {
    Name = "task-alb"
  }
}

# =========================================================
# TARGET GROUP
# =========================================================

resource "aws_lb_target_group" "app" {
  name     = "task-app-tg"
  port     = 8080
  protocol = "HTTP"

  vpc_id = aws_vpc.main.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "8080"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "task-app-target-group"
  }
}

# =========================================================
# TARGET GROUP ATTACHMENT AZ1
# =========================================================

resource "aws_lb_target_group_attachment" "app_az1" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_az1.id
  port             = 8080
}

# =========================================================
# TARGET GROUP ATTACHMENT AZ2
# =========================================================

resource "aws_lb_target_group_attachment" "app_az2" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_az2.id
  port             = 8080
}

# =========================================================
# ALB LISTENER
# =========================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# =========================================================
# EC2 INSTANCE CONNECT ENDPOINT
# =========================================================

resource "aws_ec2_instance_connect_endpoint" "admin" {
  subnet_id = aws_subnet.private_az1.id

  security_group_ids = [
    aws_security_group.eic.id
  ]

  preserve_client_ip = false

  tags = {
    Name = "task-eic-endpoint"
  }
}
# =========================================================
# APPLICATION EC2 -> RDS POSTGRESQL
# =========================================================

resource "aws_vpc_security_group_ingress_rule" "app_to_rds" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.app.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"

  description = "PostgreSQL access from application servers"
}

# =========================================================
# RDS POSTGRESQL INSTANCE
# =========================================================

resource "aws_db_instance" "postgres" {
  identifier = "task-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "taskdb"
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  # Keep this false for the learning project to avoid the
  # additional cost of a Multi-AZ standby.
  multi_az = false

  backup_retention_period = 0

  skip_final_snapshot = true

  tags = {
    Name = "task-postgres"
  }
}

# =========================================================
# RDS VARIABLES
# =========================================================

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "taskadmin"
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}
