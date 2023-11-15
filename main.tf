terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#Configuration the AWS provider
provider "aws" {
  region     = "us-east-1"
  access_key = "your-aws-access-key"
  secret_key = "your-aws-secret-key"
}

# 1- Create vpc
resource "aws_vpc" "project-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "project-vpc"
  }
}

# 2- Create Internet Gateway 
resource "aws_internet_gateway" "project-gw" {
  vpc_id = aws_vpc.project-vpc.id
  tags = {
    Name = "project-gw"
  }
}

# 3- Create Custom Route Table 
resource "aws_route_table" "project-rt" {
  vpc_id = aws_vpc.project-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.project-gw.id
  }

  tags = {
    Name = "project-rt"
  }
}

# 4- Create a Subnet
resource "aws_subnet" "project-subnet" {
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "project-subnet"
  }
}

# 5- Associate subnet with route table
resource "aws_route_table_association" "project-sb-rt" {
  subnet_id      = aws_subnet.project-subnet.id
  route_table_id = aws_route_table.project-rt.id
}

# 6- Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

# 7- Create a network interface with an ip the subnet that was created in step 4
resource "aws_network_interface" "project-nt" {
  subnet_id       = aws_subnet.project-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}
# 8- Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.project-nt.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.project-gw]
}
# 9- Create Ubuntu server and install/enbale apache2 

resource "aws_instance" "web-server-instance" {
  ami               = "ami-0230bd60aa48260c6"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "terraform-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.project-nt.id
  }
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install httpd -y
    sudo bash -c 'echo "Hello World" > /var/www/html/index.html'
    sudo systemctl start httpd
    sudo systemctl enable httpd
    EOF
  tags = {
    name = "web server"
  }
}
