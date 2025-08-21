terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

provider "aws" {
  region = var.region
}

############################
# Networking (VPC/Subnets)
############################
resource "aws_vpc" "this" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "tpspeek-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "tpspeek-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.42.101.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "tpspeek-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.42.102.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true
  tags = { Name = "tpspeek-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "tpspeek-public-rt" }
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_a.id
}
resource "aws_route_table_association" "pub_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_b.id
}

############################
# Security Groups
############################
resource "aws_security_group" "alb_sg" {
  name        = "tpspeek-alb-sg"
  description = "Allow HTTP/HTTPS"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # ถ้ามี TLS ให้เปิด 443 ด้วย แล้วแนบ ACM cert ที่ listener ด้านล่าง
  # ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "tpspeek-alb-sg" }
}

resource "aws_security_group" "ecs_sg" {
  name        = "tpspeek-ecs-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "tpspeek-ecs-sg" }
}

############################
# KMS for Logs
############################
resource "aws_kms_key" "logs" {
  description         = "KMS for TPSpeek CloudWatch Logs"
  enable_key_rotation = true
}
resource "aws_kms_alias" "logs" {
  name          = "alias/tpspeek-cw-logs"
  target_key_id = aws_kms_key.logs.key_id
}

############################
# CloudWatch Log Group
############################
resource "aws_cloudwatch_log_group" "app" {
  name              = "TPSpeek-App-Logs"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn
}

############################
# Storage + Config
############################
resource "aws_s3_bucket" "data" {
  bucket        = "tpspeek-data-${var.account_id}"
  force_destroy = true
}

resource "aws_dynamodb_table" "config" {
  name         = "TPSpeekConfig"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ConfigID"
  attribute { name = "ConfigID"; type = "S" }
}

resource "aws_secretsmanager_secret" "tpspeek_api_key" {
  name        = "TPspeekApiKey"
  description = "API key for TPSpeek internal"
}

# ใส่ค่าจริงด้วย CLI: aws secretsmanager put-secret-value --secret-id TPspeekApiKey --secret-string 'YOUR_KEY'

############################
# ECR (เก็บภาพ Docker)
############################
resource "aws_ecr_repository" "tpspeek" {
  name                 = "tpspeek-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

############################
# ECS (Fargate) + ALB
############################
resource "aws_ecs_cluster" "this" {
  name = "tpspeek-cluster"
}

resource "aws_lb" "app" {
  name               = "tpspeek-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "app" {
  name     = "tpspeek-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ถ้าต้องการ HTTPS:
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.app.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = var.acm_certificate_arn
#   default_action { type = "forward"; target_group_arn = aws_lb_target_group.app.arn }
# }

############################
# IAM for ECS Task Execution
############################
data "aws_iam_policy_document" "ecs_task_exec_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service"; identifiers = ["ecs-tasks.amazonaws.com"] }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_exec" {
  name               = "TPSpeekTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_assume.json
}

# นโยบายพื้นฐานดึงภาพจาก ECR + ส่ง log ไป CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_exec_ecr" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# อนุญาตอ่าน Secrets
resource "aws_iam_policy" "secrets_read" {
  name   = "TPSpeekSecretsRead"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow",
        Action = ["secretsmanager:GetSecretValue"],
        Resource = [aws_secretsmanager_secret.tpspeek_api_key.arn]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_exec_secrets" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

############################
# Task Definition + Service
############################
resource "aws_ecs_task_definition" "tpspeek" {
  family                   = "tpspeek-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([
    {
      name      = "tpspeek",
      image     = "${aws_ecr_repository.tpspeek.repository_url}:${var.image_tag}",
      essential = true,
      portMappings = [{ containerPort = 8000, hostPort = 8000, protocol = "tcp" }],
      environment = [
        { name = "AWS_REGION", value = var.region }
      ],
      secrets = [
        { name = "TPSPEEK_API_KEY", valueFrom = aws_secretsmanager_secret.tpspeek_api_key.arn }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "tpspeek"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "tpspeek" {
  name            = "tpspeek-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.tpspeek.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "tpspeek"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.http]
}

############################
# API Gateway (HTTP API proxy → ALB)
############################
resource "aws_apigatewayv2_api" "http" {
  name          = "tpspeek-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "alb_proxy" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb.app.dns_name              # proxy ไป ALB HTTP
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.alb_proxy.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

############################
# Simple Healthcheck URL
############################
output "alb_http_url" {
  value = "http://${aws_lb.app.dns_name}"
}
output "api_gateway_invoke_url" {
  value = aws_apigatewayv2_api.http.api_endpoint
}
output "ecr_repo" {
  value = aws_ecr_repository.tpspeek.repository_url
}
output "log_group" {
  value = aws_cloudwatch_log_group.app.name
}
