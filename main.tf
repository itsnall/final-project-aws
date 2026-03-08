module "networking" {
  source       = "./modules/networking"
  vpc_cidr     = "10.0.0.0/16"
  public_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  app_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
  db_cidrs     = ["10.0.20.0/24", "10.0.21.0/24"]
  azs          = ["ap-southeast-1a", "ap-southeast-1b"]
  
}

module "database" {
  source        = "./modules/database"
  vpc_id        = module.networking.vpc_id
  db_subnet_ids = module.networking.db_subnet_ids
}

module "storage" {
  source                 = "./modules/storage"
  bucket_name            = "eduflow-tfstate-final-project4"
  region                 = var.region
  vpc_id                 = module.networking.vpc_id
  private_route_table_id = module.networking.private_route_table_id
}

module "compute" {
  source              = "./modules/compute"
  vpc_id              = module.networking.vpc_id
  public_subnets      = module.networking.public_subnets
  private_app_subnets = module.networking.private_app_subnets
  s3_bucket_arn       = module.storage.bucket_arn
  acm_certificate_arn = var.acm_certificate_arn
  db_endpoint         = module.database.db_endpoint
  db_password         = var.db_password
}
output "eduflow_url" {
  value = "https://${module.compute.alb_dns_name}"
}

module "monitoring" {
  source      = "./modules/monitoring"
  asg_name    = module.compute.asg_name
  admin_email = var.admin_email
}