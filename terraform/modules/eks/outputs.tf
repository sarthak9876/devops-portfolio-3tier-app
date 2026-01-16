output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA cert"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = aws_security_group.eks_cluster_sg.id
}

output "node_group_role_arn" {
  description = "IAM role ARN for node group"
  value       = aws_iam_role.node_role.arn
}

output "nodes_security_group_id" {
  description = "Security group for worker nodes"
  value       = aws_security_group.eks_nodes_sg.id
}
