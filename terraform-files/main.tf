//This Terraform Template creates 3 Ansible Machines on EC2 Instances
//Ansible Machines will run on ubuntu 22.04 with custom security group
//allowing SSH (22), HTTP (80) and MYSQL/Aurora (3306) connections from anywhere.
//User needs to select appropriate variables form "tfvars" file when launching the instance.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  # secret_key = ""
  # access_key = ""
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # This is the owner ID for Canonical, which provides official Ubuntu AMIs, so don't change this
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "nodes" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "${count.index == 0 ? var.control-node-type : var.worker-node-type}"
  count = var.num
  key_name = var.mykey
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2full.name
  tags = {
    Name = "${element(var.name_tags, count.index)}_phonebook"
    Environment = "${element(var.env_tags, count.index)}"
    Role = count.index >= (var.num - 2) ? "${element(var.web_tags, count.index)}" : null
  }
}

# iam role and instance profile for EC2 full access
resource "aws_iam_role" "ec2full" {
  name = "projectec2full_phonebook"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2full_attach" {
  role       = aws_iam_role.ec2full.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_instance_profile" "ec2full" {
  name = "projectec2full_phonebook"
  role = aws_iam_role.ec2full.name
}

# Security Group for EC2 Instances

resource "aws_security_group" "tf-sec-gr" {
  name = "ansible-project-sec-gr_phonebook"
  tags = {
    Name = "ansible-project-sec-gr_phonebook"
  }

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    protocol    = "tcp"
    to_port     = 3306
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# # load balancer config

# data "aws_vpc" "default" {
#   default = true
# }

# data "aws_subnets" "default" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.default.id]
#   }
# }

# resource "aws_lb" "app_lb" {
#   name               = "phonebook-alb"
#   internal           = false
#   load_balancer_type = "application"
#   subnets            = data.aws_subnets.default.ids  # subnet_id'lerini variable olarak tanımla
#   security_groups    = [aws_security_group.tf-sec-gr.id]
# }

# resource "aws_lb_target_group" "blue" {
#   name        = "phonebook-tg-blue"
#   port        = 80
#   protocol    = "HTTP"
#   target_type = "instance"
#   vpc_id   = data.aws_vpc.default.id

#   health_check {
#     path                = "/"
#     protocol            = "HTTP"
#     matcher             = "200-399"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }
# }

# resource "aws_lb_target_group" "green" {
#   name        = "phonebook-tg-green"
#   port        = 80
#   protocol    = "HTTP"
#   target_type = "instance"
#   vpc_id   = data.aws_vpc.default.id

#   health_check {
#     path                = "/"
#     protocol            = "HTTP"
#     matcher             = "200-399"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }
# }

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.blue.arn
#   }
# }

# # Target Group’a EC2’leri bağlama
# resource "aws_lb_target_group_attachment" "blue_attachment" {
#   target_group_arn = aws_lb_target_group.blue.arn
#   target_id        = aws_instance.nodes[2].id
#   port             = 80
# }

# resource "aws_lb_target_group_attachment" "green_attachment" {
#   target_group_arn = aws_lb_target_group.green.arn
#   target_id        = aws_instance.nodes[3].id
#   port             = 80
# }

# # Route53 Alias Kaydı
# resource "aws_route53_record" "phonebook" {
#   zone_id = var.hosted_zone_id
#   name    = "phonebook.<your_domain_name>.com"
#   type    = "A"

#   alias {
#     name                   = aws_lb.app_lb.dns_name
#     zone_id                = aws_lb.app_lb.zone_id
#     evaluate_target_health = true
#   }
# }

# Null Resource for Ansible Configuration
resource "null_resource" "config" {
  depends_on = [aws_instance.nodes[0]]
  connection {
    host = aws_instance.nodes[0].public_ip
    type = "ssh"
    user = "ubuntu"
    private_key = file("./${var.mykey}.pem")    # Do not forget to define your key file path correctly!
  }

  provisioner "file" {
    source = "./ansible.cfg"
    destination = "/home/ubuntu/.ansible.cfg"
  }

  provisioner "file" {
    # Do not forget to define your key file path correctly!
    source = "./${var.mykey}.pem"
    destination = "/home/ubuntu/${var.mykey}.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname Control-Node",
      "sudo apt update -y",
      "sudo apt install -y awscli",
      "sudo apt install -y software-properties-common",
      "sudo add-apt-repository -y ppa:ansible/ansible",
      "sudo apt update -y",
      "sudo apt install -y ansible",
      "echo [servers] > inventory.ini",
      "echo db_server_phonebook ansible_host=${aws_instance.nodes[1].private_ip} ansible_ssh_private_key_file=/home/ubuntu/${var.mykey}.pem ansible_user=ubuntu >> inventory.ini",
      "echo blue_server_phonebook ansible_host=${aws_instance.nodes[2].private_ip} ansible_ssh_private_key_file=/home/ubuntu/${var.mykey}.pem ansible_user=ubuntu >> inventory.ini",
      "echo green_server_phonebook ansible_host=${aws_instance.nodes[3].private_ip} ansible_ssh_private_key_file=/home/ubuntu/${var.mykey}.pem ansible_user=ubuntu >> inventory.ini",
      "echo [web_servers] >> inventory.ini",
      "echo blue_server_phonebook ansible_host=${aws_instance.nodes[2].private_ip} ansible_ssh_private_key_file=/home/ubuntu/${var.mykey}.pem ansible_user=ubuntu >> inventory.ini",
      "echo green_server_phonebook ansible_host=${aws_instance.nodes[3].private_ip} ansible_ssh_private_key_file=/home/ubuntu/${var.mykey}.pem ansible_user=ubuntu >> inventory.ini",
      "echo [db_server] >> inventory.ini",
      "echo db_server_phonebook ansible_host=${aws_instance.nodes[1].private_ip} ansible_ssh_private_key_file=/home/ubuntu/${var.mykey}.pem ansible_user=ubuntu >> inventory.ini",
      "chmod 400 ${var.mykey}.pem"
    ]
  }
}

output "region" {
  value = var.region
}

output "control_node_ip" {
  value = aws_instance.nodes[0].public_ip
}

# output "phonebook_tg_green_arn" {
#   value = aws_lb_target_group.green.arn
# }

# output "phonebook_tg_blue_arn" {
#   value = aws_lb_target_group.blue.arn
# }

# output "alb_listener_arn" {
#   value = aws_lb_listener.http.arn
# }

# output "blue_and_green_server_subnet_ids" {
#   value = [
#     aws_instance.nodes[2].subnet_id,
#     aws_instance.nodes[3].subnet_id
#   ]
# }

# output "security_group_id" {
#   value = aws_security_group.tf-sec-gr.id
# }

# output "green_server_phonebook_ip" {
#   value = aws_instance.nodes[3].public_ip
# }


# output "alb_dns_name" {
#   value = aws_lb.app_lb.dns_name
# }

