# This object is disabled until docs/03-import.md. Once enabled, create the
# actual SG outside Terraform first and import it into this address.
resource "aws_security_group" "imported" {
  count = var.manage_imported_security_group ? 1 : 0

  name        = "${var.name_prefix}-imported"
  description = "Imported observer security group"
  vpc_id      = aws_vpc.consumer.id

  ingress = []

  egress {
    description = "All IPv4 egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-imported"
  })
}
