# 1. VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "eduflow-vpc" }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "eduflow-igw" }
}

# 3. Public Subnets (Untuk ALB)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index + 1}" }
}

# 4. Private Subnets (Untuk EC2/App)
resource "aws_subnet" "private_app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "app-private-subnet-${count.index + 1}" }
}

# 5. Private Subnets (Untuk RDS/Database)
resource "aws_subnet" "private_db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "db-private-subnet-${count.index + 1}" }
}

# 6. Route Table Publik
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 7. Elastic IP untuk NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "eduflow-nat-eip" }
}

# 8. NAT Gateway (Diletakkan di Public Subnet pertama)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "eduflow-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

# 9. Route Table Private (Agar EC2 bisa ke Internet via NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "private-rt" }
}

# 10. Menggabungkan Route Table Private ke Subnet App & DB
resource "aws_route_table_association" "private_app" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private.id
}