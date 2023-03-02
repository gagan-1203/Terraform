#---------------------------------------------------------------------------
# 1. Create a VPC
#---------------------------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16" // completely private 10.0 are fixed
  enable_dns_hostnames = true

  tags = {
    Name = "My VPC"
  }
}


#---------------------------------------------------------------------------
# 2. Create a Gateway 
#---------------------------------------------------------------------------

/* Gateway should be inside the VPC created above and will allow our
instances to communicate to the outside world.*/

resource "aws_internet_gateway" "vpc" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "My IGW"
  }
}


#---------------------------------------------------------------------------
# 3. Create a Route Table
#---------------------------------------------------------------------------


#Route tables allows our subnets to access the internet through the internet gateway

resource "aws_route_table" "allow-outgoing-access" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc.id
  }

  tags = {
    Name = "My Route Table"
  }
}


#---------------------------------------------------------------------------
# 4 Create Subnet
#---------------------------------------------------------------------------
resource "aws_subnet" "subnet" {
  cidr_block = "10.0.0.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "My Subnet"
  }
}

#---------------------------------------------------------------------------
# 5 Create a Route Table Association --> associate subnet to route table
#---------------------------------------------------------------------------

#We associate the subnet with the route table to allow outgoing traffic.

resource "aws_route_table_association" "subnet-association" {
  subnet_id = aws_subnet.subnet.id
  route_table_id = aws_route_table.allow-outgoing-access.id
}

#---------------------------------------------------------------------------
# 6 Create a AWS Instance
#---------------------------------------------------------------------------

resource "aws_instance" "web" {
  ami           = "ami-09cd747c78a9add63"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet.id

  tags = {
    Name = "First_instance"
  }
}
