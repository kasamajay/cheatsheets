locals {
  ep_region = "eu-west-2"
  # wld_ep_service_names = toset ([ "ssm" ])
  wld_ep_service_names = toset ([ "ssm", "ssmmessages", "ec2messages" ])
}
resource "aws_vpc" "tooling" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "tooling"
  }
}

resource "aws_vpc" "workload" {
  cidr_block = "10.10.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "workload"
  }
}

resource "aws_route53_zone" "nl_tooling" {
  name = "nl.tooling.home.co.uk"

  vpc {
    vpc_id = aws_vpc.tooling.id
  }

  tags = {
    Environment = "nonlive.tooling"
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_zone_association" "associate_tld_r53_to_wld_vpc" {
  zone_id = aws_route53_zone.nl_tooling.zone_id
  vpc_id  = aws_vpc.workload.id
}

# create a test record A pointing test.nl.tooling.home.co.uk to 11.22.33.44
resource "aws_route53_record" "test" {
  zone_id = aws_route53_zone.nl_tooling.zone_id
  name    = "test"
  type    = "A"
  ttl     = 300
  records = ["11.22.33.44"]
}


# create private subnet in workload vpc
resource "aws_subnet" "workload_sub1" {
  vpc_id     = aws_vpc.workload.id
  cidr_block = "10.10.0.0/25"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "sub1"
  }
}

# security group for ec2 instances
resource "aws_security_group" "sg_for_ec2" {
  name        = "empty"
  description = "empty inbound traffic"
  vpc_id      = aws_vpc.workload.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "empty"
  }
}


# create security group for vpc endpoints ssm, ec2messages, ssmmessages
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.workload.cidr_block]
  }

  tags = {
    Name = "allow_tls"
  }
}

# create vpc endpoints ssm, ec2messages, ssmmessages
resource "aws_vpc_endpoint" "wld_ep_ssm" {
  for_each = local.wld_ep_service_names

  vpc_id       = aws_vpc.workload.id
  service_name = "com.amazonaws.${local.ep_region}.${each.value}"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [ aws_subnet.workload_sub1.id ]
  security_group_ids = [ aws_security_group.allow_tls.id ]

  tags = {
    Name = "${each.value}-ep"
    env = "test"
  }
}

# iam role for ec2 to access ssm, this will enable shell access to ec2 instance
resource "aws_iam_role" "role_ec2ssm" {
  name = "ec2ssm"

  assume_role_policy = file("${path.module}/files/ec2ssmroleassume.json")
}

data "aws_iam_policy" "ec2ssm_managedpolicy" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2ssm_managedpolicy_attachpolicy" {
  role       = aws_iam_role.role_ec2ssm.name
  policy_arn = data.aws_iam_policy.ec2ssm_managedpolicy.arn
}

resource "aws_iam_instance_profile" "ec2ssm_instanceprofile" {
  name = "ec2ssm_instanceprofile"
  role = aws_iam_role.role_ec2ssm.name
}

# create ec2 instance in private subnet
resource "aws_instance" "testdns" {
  ami           = "ami-06672d07f62285d1d" # eu-west-2 amazonlinux2
  instance_type = "t2.micro"
  availability_zone = "eu-west-2a"
  iam_instance_profile = aws_iam_instance_profile.ec2ssm_instanceprofile.name
  subnet_id = aws_subnet.workload_sub1.id
  vpc_security_group_ids = [ "${aws_security_group.sg_for_ec2.id}" ]

  tags = {
    Name = "testdns"
  }

  depends_on = [
    aws_vpc_endpoint.wld_ep_ssm
  ]
}

# access the ec2 instance using the systems manager > sessions manager console - wait for couple of mins after the creation of ec2 instance



