variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "tags" { type = map(string) }
variable "db_allocated_storage" { 
    type = number
    default = 20
 }
variable "db_instance_class" { 
    type = string 
    default = "db.t3.micro" 
}
