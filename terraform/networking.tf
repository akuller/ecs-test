
data "aws_availability_zones" "available"{ state = "available"}

locals {
  azs_count = 2
  azs_names = data.aws_availability_zones.available.names
}


resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = { Name = "demo-vpc"}
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  count = local.azs_count
  availability_zone = local.azs_names[count.index]
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 10 + count.index)
  map_public_ip_on_launch = true
  tags = {Name = "demo-public-${local.azs_names[count.index]}"}
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "demo-igw"}
}

resource "aws_eip" "main" {
  count = local.azs_count
  depends_on = [aws_internet_gateway.main]
  tags = {Name = "demo-eip-${local.azs_names[count.index]}"}
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {Name = "demo-rt-public"}

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  count = local.azs_count
  subnet_id = aws_subnet.public[count.index].id
}

resource "aws_security_group" "ecs_node_sg" {
  name_prefix = "demo-ecs-node-sg-"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_task" {
  name_prefix = "ecs-task-sg-"
  description = "Allow all traffic within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
