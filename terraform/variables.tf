variable "tenancy_ocid" {
  type        = string
  description = "OCID do Tenancy da Oracle Cloud"
}

variable "user_ocid" {
  type        = string
  description = "OCID do Usuário da Oracle Cloud"
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint da chave API"
}

variable "private_key_path" {
  type        = string
  description = "Caminho local da chave privada da API OCI"
  default     = "/tmp/oci_api_key.pem"
}

variable "region" {
  type        = string
  description = "Região da Oracle Cloud"
  default     = "sa-saopaulo-1"
}

variable "compartment_ocid" {
  type        = string
  description = "OCID do Compartimento onde os recursos serão criados"
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública SSH para acesso às VMs"
}

variable "environment" {
  type        = string
  description = "Ambiente de destino (dev, homolog, prod)"
  default     = "prod"
}

variable "instance_name" {
  type        = string
  description = "Prefixo do nome das máquinas virtuais"
  default     = "vm-pm04"
}

variable "instance_type" {
  type        = string
  description = "Shape da VM na Oracle Cloud (Always Free: VM.Standard.E2.1.Micro ou VM.Standard.A1.Flex)"
  default     = "VM.Standard.E2.1.Micro"
}