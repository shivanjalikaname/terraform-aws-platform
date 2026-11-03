output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, in AZ order."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, in AZ order."
  value       = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs, one per AZ (useful for VPC endpoints)."
  value       = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs (empty when nat_mode is none)."
  value       = aws_nat_gateway.this[*].id
}
