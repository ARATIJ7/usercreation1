provider "aws" {
  region = "ap-southeast-2"  # Specify your desired region
}

resource "aws_instance" "mongodb" {
  count         = 3  # Create three instances
  ami           = "ami-024ebc7de0fc64e44"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"  # Use a free-tier instance type or your desired instance type

  user_data = <<-EOM
              #!/bin/bash
              # Update the package list
              sudo yum update -y

              # Install MongoDB
              sudo tee /etc/yum.repos.d/mongodb-org-4.4.repo <<EOF
              [mongodb-org-4.4]
              name=MongoDB Repository
              baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/
              gpgcheck=1
              enabled=1
              gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
              EOF

              sudo yum install -y mongodb-org

              # Start MongoDB
              sudo systemctl start mongod
              sudo systemctl enable mongod

              # Wait for MongoDB to start
              sleep 10

              # Create MongoDB users and databases based on the instance index
              case ${count.index} in
                0)
                  mongo <<EOD
                  use admin
                  db.createUser({
                    user: "adminUser",
                    pwd: "adminPass",
                    roles: [{ role: "userAdminAnyDatabase", db: "admin" }]
                  })
                  EOD
                  ;;
                1)
                  mongo <<EOD
                  use database2
                  db.createUser({
                    user: "readWriteUser",
                    pwd: "readWritePass",
                    roles: [{ role: "readWrite", db: "database2" }]
                  })
                  EOD
                  ;;
                2)
                  mongo <<EOD
                  use database3
                  db.createUser({
                    user: "readOnlyUser",
                    pwd: "readOnlyPass",
                    roles: [{ role: "read", db: "database3" }]
                  })
                  EOD
                  ;;
              esac
              EOM

  tags = {
    Name = "MongoDBInstance${count.index}"
  }

  # Create a security group that allows SSH and MongoDB access
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]

  # Specify a key pair for SSH access
  key_name = "project"
}

resource "aws_security_group" "mongodb_sg" {
  name        = "mongodb_sg"
  description = "Allow SSH and MongoDB access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
