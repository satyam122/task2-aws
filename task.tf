provider "aws" {
  region    = "ap-south-1"
  profile = "default"
}

resource "aws_key_pair" "key" {
  key_name   = "mykey"
  public_key = file("mykey.pub")
}

resource "aws_security_group" "my_sg" {
  name        = "sg_tr"
  description = "Security group for terraform"
  


  ingress {
    description = "TCP"
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
    Name = "my_sg_tr"
  }
}

resource "aws_instance" "task2" {
  ami             = "ami-052c08d70def0ac62"
  instance_type   = "t2.micro"
  key_name        = "mykey"
  security_groups = ["${aws_security_group.my_sg.name}"]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("mykey")
    host        = aws_instance.task2.public_ip
  }
  provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd git -y",
       "sudo systemctl restart httpd",
       "sudo systemctl enable httpd",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd amazon-efs-utils -y",
       "sudo sleep 3m",
       "sudo mount -t efs '${aws_efs_file_system.myefs.id}':/ /var/www/html",
       "sudo su -c \"echo '${aws_efs_file_system.myefs.id}:/ /var/www/html nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab\"",
    ]
    
  }
  tags = {
    Name = "OS-task2"
  }
}
output "InstancePIP" {  
  value = aws_instance.task2.public_ip
}

resource "aws_efs_file_system" "myefs" {
   creation_token = "myefs"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "Task2-EFS-File-System"
   }
 }
resource "aws_efs_mount_target" "efs-mta" {
   file_system_id  = aws_efs_file_system.myefs.id
   subnet_id = "subnet-5c076c10"
   security_groups = [aws_security_group.my_sg.id]
}
resource "aws_efs_mount_target" "efs-mtb" {
   file_system_id  = aws_efs_file_system.myefs.id
   subnet_id = "subnet-5c0dbf27"
   security_groups = [aws_security_group.my_sg.id]
}
resource "aws_efs_mount_target" "efs-mtc" {
   file_system_id  = aws_efs_file_system.myefs.id
   subnet_id = "subnet-c4f5cfac"
   security_groups = [aws_security_group.my_sg.id]
}

resource "aws_s3_bucket" "task2tfbucket" {
    bucket = "task2tfbucket"
    acl = "public-read"
    }
    
resource "aws_s3_bucket_object" "task2bucket" {
    bucket = "${aws_s3_bucket.task2tfbucket.bucket}"
    key = "download.jpg"
    source = "C:/Users/KIIT/Downloads/download.jpg"
    acl = "public-read"
    }


locals {
s3_origin_id = aws_s3_bucket.task2tfbucket.id
}


resource "aws_cloudfront_distribution" "cloudfront" {    
    origin {
        domain_name = "${aws_s3_bucket.task2tfbucket.bucket_regional_domain_name}"
        origin_id = "${local.s3_origin_id}"
        }
    enabled = true
    is_ipv6_enabled = true
    comment = "Cloud Front S3 distribution"
    
    default_cache_behavior{
    allowed_methods = ["DELETE",  "GET" , "HEAD" , "OPTIONS", "PATCH" , "POST", "PUT"]
    cached_methods = ["GET" , "HEAD"]
    target_origin_id = local.s3_origin_id
    
    forwarded_values{
    query_string = false
    cookies {
    forward = "none"
    }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
    }
    restrictions {
    geo_restriction {
    restriction_type = "whitelist"
    locations = ["IN"]
    }
    }
    
    tags = {
    Name = "my_webserver1"
    Environment = "production_main"
    }
    
    viewer_certificate {
    cloudfront_default_certificate = true
    }
    retain_on_delete = true
  
  }

resource "null_resource" "null_resource"  {
depends_on = [
      aws_cloudfront_distribution.cloudfront,
  ]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KIIT/Desktop/task2/mykey")
    host     = aws_instance.task2.public_ip
  }
  provisioner "remote-exec" {
    inline = [
	"sudo git clone https://github.com/satyam122/task1.git /var/www/html/"
    ]
  }
}
resource "null_resource" "mywebsite"  {
depends_on = [
     null_resource.null_resource,
  ]
	provisioner "local-exec" {
	    command = "start chrome ${aws_instance.task2.public_ip}/file.html"
  	}
}