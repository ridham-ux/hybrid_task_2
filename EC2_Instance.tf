provider "aws" {
  region     = "ap-south-1"
  profile    = "task"
}

resource "aws_key_pair" "key" {
key_name = "mykeyy"
public_key="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAryh7wbLe3IvfHCLmrc1fbXw1d1dwM7VQN029wAphsKi/gzzWdTLlafUi+Teuo1Ze84sPAb3IxUw5ewwED/N0hTy/7YgvBEX08FTU8X1eH06AtD8Zyf6kAbwXrjO2SGkz/TJ3gebhqfrDu3iYEG1Uo1JKgg284ce8cAd9G3/U5FD/LKdajGmLTAHLIoxp3WHBpRW9ciOK9+JQL9SGnYYF62+++h4fMCc/lyX4A/Sy7UJ7pCFP+ZjsRZ8V6SOXTpy+4PrrdqoDC/NMqs/5pBdBn8ORRk43WjUP8LsvTBEw3AvkMSMgazWl/Ov68tVN3UiwUE9vEQbB0mExsZrixvNYJw== rsa-key-20200713"
}

resource "aws_security_group" "t2_sg" {
  name        = "add_rules"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "vpc-00968b68"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp" 
    cidr_blocks=["0.0.0.0/0"]
 }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp" 
    cidr_blocks=["0.0.0.0/0"]
 }
  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   egress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp" 
    cidr_blocks=["0.0.0.0/0"]
  }
   egress {
    description = "HTTP from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp" 
    cidr_blocks=["0.0.0.0/0"]
  }
  tags = {
    Name = "t2_sg"
  }
}

data "aws_vpc" "default" {
  default="true"
}
data "aws_subnet" "subnet" {
  vpc_id = data.aws_vpc.default.id
  availability_zone="ap-south-1a"
}

resource "aws_efs_file_system" "t2_efs" {
  creation_token = "t2_efs"

  tags = {
    Name = "efssystem"
  }
}
resource "aws_efs_mount_target" "mount" {
  depends_on = [aws_efs_file_system.t2_efs]
  file_system_id = aws_efs_file_system.t2_efs.id
  subnet_id      = data.aws_subnet.subnet.id
  security_groups = [ aws_security_group.t2_sg.id ]
}


resource "aws_instance" "inst" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "mykeyy"
  vpc_security_group_ids=[aws_security_group.t2_sg.id]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Ridham/Desktop/hybrid multi-cloud/mykeyy.pem")
    host     = aws_instance.inst.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo setenforce 0",
      "sudo yum install amazon-efs-utils -y",
      "sudo yum install nfs-utils -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      ]
  }

  tags = {
    Name = "task2os"
  }

}

resource "null_resource" "local1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.inst.public_ip} > publicip.txt"
  	}
}


resource "null_resource" "remote2"  {

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Ridham/Desktop/hybrid multi-cloud/mykeyy.pem")
    host     = aws_instance.inst.public_ip
  }

provisioner "remote-exec" {
    inline = [
       "sudo mount -t efs ${aws_efs_file_system.t2_efs.id}:/ /var/www/html",
       "echo '${aws_efs_file_system.t2_efs.id}:/ /var/www/html efs _netdev 0 0' | sudo tee -a sudo tee -a /etc/fstab",
       "sudo rm -rf /var/www/html/*",
       "sudo git clone https://github.com/ridham-ux/hybrid_task_2.git /var/www/html/",
    ]
  }
}






