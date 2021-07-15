# Security Groups (instance firewalls)

# Controller security group

resource "aws_security_group" "controller" {
  name        = "${var.cluster_name}-controller"
  description = "${var.cluster_name} controller security group"

  vpc_id = aws_vpc.network.id

  tags = merge(var.tags, {
    "Name" = "${var.cluster_name}-controller"
  })
}

resource "aws_security_group_rule" "controller-ssh" {
  security_group_id = aws_security_group.controller.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "controller-etcd" {
  security_group_id = aws_security_group.controller.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 2379
  to_port   = 2380
  self      = true
}

# Allow Prometheus to scrape etcd metrics
resource "aws_security_group_rule" "controller-etcd-metrics" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2381
  to_port                  = 2381
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "controller-apiserver" {
  security_group_id = aws_security_group.controller.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 6443
  to_port     = 6443
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow Prometheus to scrape node-exporter daemonset
resource "aws_security_group_rule" "controller-node-exporter" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 9100
  to_port                  = 9100
  source_security_group_id = aws_security_group.worker.id
}

# Allow Prometheus to scrape kube-proxy.
resource "aws_security_group_rule" "kube-proxy-metrics" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 10249
  to_port                  = 10249
  source_security_group_id = aws_security_group.worker.id
}

# Allow apiserver to access kubelets for exec, log, port-forward
resource "aws_security_group_rule" "controller-kubelet" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 10250
  to_port                  = 10250
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "controller-kubelet-self" {
  security_group_id = aws_security_group.controller.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250
  self      = true
}

resource "aws_security_group_rule" "controller-bgp" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 179
  to_port                  = 179
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "controller-bgp-self" {
  security_group_id = aws_security_group.controller.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 179
  to_port   = 179
  self      = true
}

resource "aws_security_group_rule" "controller-ipip" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = 4
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "controller-ipip-self" {
  security_group_id = aws_security_group.controller.id

  type      = "ingress"
  protocol  = 4
  from_port = 0
  to_port   = 0
  self      = true
}

resource "aws_security_group_rule" "controller-ipip-legacy" {
  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = 94
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "controller-ipip-legacy-self" {
  security_group_id = aws_security_group.controller.id

  type      = "ingress"
  protocol  = 94
  from_port = 0
  to_port   = 0
  self      = true
}

resource "aws_security_group_rule" "controller-egress" {
  security_group_id = aws_security_group.controller.id

  type             = "egress"
  protocol         = "-1"
  from_port        = 0
  to_port          = 0
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "controller-node-local-dns-metrics-port" {
  count = var.enable_node_local_dns ? 1 : 0

  security_group_id = aws_security_group.controller.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 9253
  to_port                  = 9253
  source_security_group_id = aws_security_group.worker.id
}


# Worker security group

resource "aws_security_group" "worker" {
  name        = "${var.cluster_name}-worker"
  description = "${var.cluster_name} worker security group"

  vpc_id = aws_vpc.network.id

  tags = merge(var.tags, {
    "Name" = "${var.cluster_name}-worker"
  })
}

resource "aws_security_group_rule" "worker-ssh" {
  security_group_id = aws_security_group.worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker-http" {
  security_group_id = aws_security_group.worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30080
  to_port     = 30080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker-https" {
  security_group_id = aws_security_group.worker.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30443
  to_port     = 30443
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow Prometheus to scrape node-exporter daemonset
resource "aws_security_group_rule" "worker-node-exporter" {
  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 9100
  to_port   = 9100
  self      = true
}

# Allow Prometheus to scrape kube-proxy.
resource "aws_security_group_rule" "worker-kube-proxy" {
  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 10249
  to_port   = 10249
  self      = true
}

# Allow apiserver to access kubelets for exec, log, port-forward
resource "aws_security_group_rule" "worker-kubelet" {
  security_group_id = aws_security_group.worker.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 10250
  to_port                  = 10250
  source_security_group_id = aws_security_group.controller.id
}

# Allow Prometheus to scrape kubelet metrics
resource "aws_security_group_rule" "worker-kubelet-self" {
  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250
  self      = true
}

resource "aws_security_group_rule" "worker-bgp" {
  security_group_id = aws_security_group.worker.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 179
  to_port                  = 179
  source_security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "worker-bgp-self" {
  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 179
  to_port   = 179
  self      = true
}

resource "aws_security_group_rule" "worker-ipip" {
  security_group_id = aws_security_group.worker.id

  type                     = "ingress"
  protocol                 = 4
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "worker-ipip-self" {
  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = 4
  from_port = 0
  to_port   = 0
  self      = true
}

resource "aws_security_group_rule" "worker-ipip-legacy" {
  security_group_id = aws_security_group.worker.id

  type                     = "ingress"
  protocol                 = 94
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "worker-ipip-legacy-self" {
  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = 94
  from_port = 0
  to_port   = 0
  self      = true
}

resource "aws_security_group_rule" "worker-egress" {
  security_group_id = aws_security_group.worker.id

  type             = "egress"
  protocol         = "-1"
  from_port        = 0
  to_port          = 0
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "worker-nodeport" {
  count = var.expose_nodeports ? 1 : 0

  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 30000
  to_port   = 32767
  self      = true
}

resource "aws_security_group_rule" "worker-node-local-dns-metrics-port" {
  count = var.enable_node_local_dns ? 1 : 0

  security_group_id = aws_security_group.worker.id

  type      = "ingress"
  protocol  = "tcp"
  from_port = 9253
  to_port   = 9253
  self      = true
}
