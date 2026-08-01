data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web.id, aws_security_group.ssh.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>Hello from $(hostname -f)</h1>" > /usr/share/nginx/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-web"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}