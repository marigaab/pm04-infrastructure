# Busca o Availability Domain (Data Center) disponível na região
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Busca automaticamente a imagem oficial mais recente do Ubuntu 22.04 compatível com o shape
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.instance_type
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# 1. Rede Virtual (VCN)
resource "oci_core_vcn" "todo_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${var.instance_name}-${var.environment}-vcn"
  dns_label      = "todovcn"
}

# 2. Internet Gateway (para acesso à internet)
resource "oci_core_internet_gateway" "todo_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.todo_vcn.id
  display_name   = "${var.instance_name}-${var.environment}-igw"
  enabled        = true
}

# 3. Tabela de Rotas
resource "oci_core_route_table" "todo_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.todo_vcn.id
  display_name   = "${var.instance_name}-${var.environment}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.todo_igw.id
  }
}

# 4. Security List da VM 1 (Aplicação - libera SSH, HTTP 80 e HTTPS 443)
resource "oci_core_security_list" "app_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.todo_vcn.id
  display_name   = "${var.instance_name}-${var.environment}-app-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH (22)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTP (80)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS (443)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
}

# 5. Security List da VM 2 (Banco de Dados - libera SSH e MongoDB APENAS para a rede privada)
resource "oci_core_security_list" "db_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.todo_vcn.id
  display_name   = "${var.instance_name}-${var.environment}-db-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH (22) para provisionamento via Ansible
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # MongoDB (27017) - RESTRITO apenas à sub-rede da aplicação (10.0.1.0/24)
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.1.0/24"
    tcp_options {
      min = 27017
      max = 27017
    }
  }
}

# 6. Sub-rede da Aplicação
resource "oci_core_subnet" "app_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.todo_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "${var.instance_name}-${var.environment}-app-subnet"
  dns_label         = "appsubnet"
  route_table_id    = oci_core_route_table.todo_rt.id
  security_list_ids = [oci_core_security_list.app_sl.id]
}

# 7. Sub-rede do Banco de Dados
resource "oci_core_subnet" "db_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.todo_vcn.id
  cidr_block        = "10.0.2.0/24"
  display_name      = "${var.instance_name}-${var.environment}-db-subnet"
  dns_label         = "dbsubnet"
  route_table_id    = oci_core_route_table.todo_rt.id
  security_list_ids = [oci_core_security_list.db_sl.id]
}

# 8. VM 1: Servidor da Aplicação (Nginx + React + API)
resource "oci_core_instance" "vm_app" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_name}-${var.environment}-app"
  shape               = var.instance_type

  dynamic "shape_config" {
    for_each = var.instance_type == "VM.Standard.A1.Flex" ? [1] : []
    content {
      ocpus         = 1
      memory_in_gbs = 6
    }
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.app_subnet.id
    assign_public_ip = true
    display_name     = "${var.instance_name}-app-vnic"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# 9. VM 2: Servidor Exclusivo do Banco de Dados (MongoDB)
resource "oci_core_instance" "vm_db" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_name}-${var.environment}-db"
  shape               = var.instance_type

  dynamic "shape_config" {
    for_each = var.instance_type == "VM.Standard.A1.Flex" ? [1] : []
    content {
      ocpus         = 1
      memory_in_gbs = 6
    }
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.db_subnet.id
    assign_public_ip = true
    display_name     = "${var.instance_name}-db-vnic"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# 10. Gera automaticamente o inventário do Ansible com os IPs reais criados
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app]
    ${oci_core_instance.vm_app.public_ip} ansible_user=ubuntu private_ip=${oci_core_instance.vm_app.private_ip}

    [db]
    ${oci_core_instance.vm_db.public_ip} ansible_user=ubuntu private_ip=${oci_core_instance.vm_db.private_ip}

    [all:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
}