# terraform{
#   backend "s3"{
#     encrypt = false
#     bucket = "tf-artifact-bucket1"
#     dyanmodb_table = "tf-state-test"
#     key = "path/path/tf-state-test"
#     region =  "us-east-1" 
#   }

# }


#---------------------------------------------------------------------------
# 1. Create a VPC
#---------------------------------------------------------------------------

resource "aws_vpc" "strapi-vpc" {
  cidr_block = "10.0.0.0/16" // completely private 10.0 are fixed
  enable_dns_hostnames = true

  tags = {
    Name = "Strapi App VPC"
  }
}


#---------------------------------------------------------------------------
# 2. Create a Gateway 
#---------------------------------------------------------------------------

/* Gateway should be inside the VPC created above and will allow our
instances to communicate to the outside world.*/

resource "aws_internet_gateway" "strapi-vpc" {
  vpc_id = aws_vpc.strapi-vpc.id
  tags = {
    Name = "StrapiIGW"
  }
}


#---------------------------------------------------------------------------
# 3. Create a Route Table
#---------------------------------------------------------------------------


#Route tables allows our subnets to access the internet through the internet gateway

resource "aws_route_table" "allow-outgoing-access" {
  vpc_id = aws_vpc.strapi-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.strapi-vpc.id
  }

  tags = {
    Name = "Strapi Route Table"
  }
}


#---------------------------------------------------------------------------
# 4 Create Subnet
#---------------------------------------------------------------------------
resource "aws_subnet" "strapi-subnet1" {
  cidr_block = "10.0.0.0/24"
  vpc_id = aws_vpc.strapi-vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "Strapi Subnet1"
  }
}

resource "aws_subnet" "strapi-subnet2" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.strapi-vpc.id
  availability_zone = "us-east-1b"

  tags = {
    Name = "Strapi Subnet2"
  }
}

resource "aws_subnet" "strapi-subnet3" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.strapi-vpc.id
  availability_zone = "us-east-1c"

  tags = {
    Name = "Strapi Subnet3"
  }
}

#---------------------------------------------------------------------------
# 5 Create a Route Table Association --> associate subnet to route table
#---------------------------------------------------------------------------

#We associate the subnet with the route table to allow outgoing traffic.

resource "aws_route_table_association" "subnet1-association" {
  subnet_id = aws_subnet.strapi-subnet1.id
  route_table_id = aws_route_table.allow-outgoing-access.id
}

resource "aws_route_table_association" "subnet2-association" {
  subnet_id = aws_subnet.strapi-subnet2.id
  route_table_id = aws_route_table.allow-outgoing-access.id
}


#---------------------------------------------------------------------------
# 6 Create a Security Group
#---------------------------------------------------------------------------

resource "aws_security_group" "strapi-SG" {
  name = "allow-ssh-traffic"
  description = "Allow SSH inbound traffic"
  vpc_id = aws_vpc.strapi-vpc.id
  tags = {
    Name = "StrapiSGInbound/Outbound"
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {

    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {

    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------------------------------------------------------------------------
#7 Create Loadbalancer
#---------------------------------------------------------------------------


resource "aws_lb" "strapi-lb" {
  name               = "strapi-lb"
  internal           = false           # set lb for public access
  load_balancer_type = "application" # use Application Load Balancer
  security_groups    = [aws_security_group.strapi-SG.id]
  subnets = [ aws_subnet.strapi-subnet1.id, aws_subnet.strapi-subnet2.id]
  tags = {
    Environment  = "StrapiLoadBalancer"
  }
}

#---------------------------------------------------------------------------
#8 Create Loadbalancer Listner
#---------------------------------------------------------------------------

resource "aws_lb_listener" "strapi-listener" {
  load_balancer_arn = aws_lb.strapi-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.strapi-target-group.arn
    type             = "forward"
  }
}


resource "aws_lb_listener_rule" "external_alb_rules" {
  listener_arn = aws_lb_listener.strapi-listener.arn

  priority = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi-target-group.arn
  }
  condition {
    path_pattern {
      values = ["/app1/*"]
    }
  }
}

#---------------------------------------------------------------------------
#9 Create Loadbalancer Target Group
#---------------------------------------------------------------------------

resource "aws_lb_target_group" "strapi-target-group" {
  name                 = "strapi-target-group"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.strapi-vpc.id
  tags = {
    Name = "StrapLBTargetGroup"
}

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

 
}

#---------------------------------------------------------------------------
#10 Launch configuration for the auto-scaling.
#---------------------------------------------------------------------------

resource "aws_launch_configuration" "strapi-configuration" {
  name = "Strapi-Instance"
  image_id =  "ami-0500e6cffe668eb27"
  instance_type = "t2.small"
  key_name        = "Public" # EC2_servers_key
  security_groups = [aws_security_group.strapi-SG.id]
  associate_public_ip_address = true
  lifecycle {
    # ensure the new instance is only created before the other one is destroyed.
    create_before_destroy = true
  }
  user_data = "${file("installation1.sh")}"
}
#---------------------------------------------------------------------------
#11 Create Autoscaling Group
#---------------------------------------------------------------------------

resource "aws_autoscaling_group" "strapi_autoscaling_group" {
  name                      = "Strapi-ASG"
  desired_capacity          = 1 
  min_size                  = 1 
  max_size                  = 3
  health_check_type         = "ELB" 
  health_check_grace_period = 10
  force_delete = true
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  launch_configuration = aws_launch_configuration.strapi-configuration.id
  vpc_zone_identifier = [
    aws_subnet.strapi-subnet1.id,
    aws_subnet.strapi-subnet2.id
  ]
  timeouts {
    delete = "15m" # timeout duration for instances
  }
  lifecycle {
    # ensure the new instance is only created before the other one is destroyed.
    create_before_destroy = true
  }

}

#---------------------------------------------------------------------------
#12 Attach Autoscaling to Target Group
#---------------------------------------------------------------------------

resource "aws_autoscaling_attachment" "strapi_autoscaling_attachment" {
  lb_target_group_arn    = aws_lb_target_group.strapi-target-group.arn
  autoscaling_group_name = aws_autoscaling_group.strapi_autoscaling_group.id
}



data "template_file" "buildspec" {
  template = "${file("buildspec.yml")}"
  vars = {
    env          = "dev"
  }
}


#---------------------------------------------------------------------------
#13 Roles and policies
#---------------------------------------------------------------------------

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild_policy"
  role = aws_iam_role.codebuild_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
       
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::tf-artifact-bucket1/*"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        },
        {
          "Effect": "Allow",
          "Resource": [
            "*"
          ],
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "codepipeline_role2" {
  name                 = "codepipeline-role2"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role2.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codedeploy:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "codepipeline_policyEC2" {
  name = "codepipeline_policyEC2"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codedeploy:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#---------------------------------------------------------------------------
#14 AWS CodeBuild script
#---------------------------------------------------------------------------

resource "aws_codebuild_project" "strapi_build" {
  badge_enabled  = false
  build_timeout  = 60
  name           = "strapi-web-build"
  queued_timeout = 480
  service_role   =  aws_iam_role.codebuild_role.arn
  tags = {
    Environment = "dev"
  }

  artifacts {
    encryption_disabled    = false
    name                   = "strapi-build-dev"
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:2.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  source {
    buildspec           = data.template_file.buildspec.rendered
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }
}


#---------------------------------------------------------------------------
#15 Create pipeline and use CodeBuild
#---------------------------------------------------------------------------

resource "aws_codepipeline" "strapi_pipeline" {
  name     = "strapi_pipeline"
  role_arn = aws_iam_role.codepipeline_role2.arn
  tags     = {
    Environment = "dev"
  }

  artifact_store {
    location = "tf-artifact-bucket1"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        OAuthToken = "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"
        "Branch"               = "main"
        "Owner"                = "gagan-1203"
        "PollForSourceChanges" = "false"
        "Repo"                 = "Terraform"
      }
      input_artifacts = []
      name            = "Source"
      output_artifacts = ["SourceArtifact"]
      owner     = "ThirdParty"
      provider  = "GitHub"
      run_order = 1
      version   = "2"
    }
  }
  stage {
    name = "Build"

    action {
      category = "Build"
      configuration = {
        "EnvironmentVariables" = jsonencode(
          [
            {
              name  = "environment"
              type  = "PLAINTEXT"
              value = "dev"
            },
          ]
        )
        "ProjectName" = "strapi-build"
      }
      input_artifacts = [
        "SourceArtifact",
      ]
      name = "Build"
      output_artifacts = [
        "BuildArtifact",
      ]
      owner     = "AWS"
      provider  = "CodeBuild"
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
        "BucketName" = "tf-artifact-bucket1"
        "Extract"    = "true"
      }
      input_artifacts = [
        "BuildArtifact",
      ]
      name             = "Deploy"
      output_artifacts = []
      owner            = "AWS"
      provider         = "S3"
      run_order        = 1
      version          = "1"
    }
  }
}


# #---------------------------------------------------------------------------
# #16 Webhooks for AWS and GitHub, using random secret key
# #---------------------------------------------------------------------------

# resource "aws_codepipeline_webhook" "codepipeline_webhook" {
#   authentication  = "GITHUB_HMAC"
#   name            = "codepipeline-webhook"
#   target_action   = "Source"
#   target_pipeline = aws_codepipeline.strapi_pipeline.name

#   authentication_configuration {
#     secret_token = random_string.github_secret.result
#   }

#   filter {
#     json_path    = "$.ref"
#     match_equals = "refs/heads/{Branch}"
#   }
#   tags = {}
# }

# resource "github_repository_webhook" "github_hook" {
#   repository = "Terraform"
#   events     = ["push"]

#   configuration {
#     url          = aws_codepipeline_webhook.codepipeline_webhook.url
#     insecure_ssl = "0"
#     content_type = "json"
#     secret       = random_string.github_secret.result
#   }
# }

# resource "random_string" "github_secret" {
#   length  = 99
#   special = false
# }
