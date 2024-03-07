module "compute_key" {
  count            = local.enable_compute ? 1 : 0
  source           = "./../key"
  private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

# module "storage_key" {
#   count            = local.enable_storage ? 1 : 0
#   source           = "./../key"
#   private_key_path = "storage_id_rsa" #checkov:skip=CKV_SECRET_6
# }

# module "login_sg" {
#   count                        = local.enable_login ? 1 : 0
#   source                       = "terraform-ibm-modules/security-group/ibm"
#   version                      = "1.0.1"
#   add_ibm_cloud_internal_rules = true
#   resource_group               = var.resource_group
#   security_group_name          = format("%s-login-sg", local.prefix)
#   security_group_rules         = local.login_security_group_rules
#   vpc_id                       = var.vpc_id
# }

module "compute_sg" {
  count                        = local.enable_compute ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.0"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-cluster-sg", local.prefix)
  security_group_rules         = local.compute_security_group_rules
  vpc_id                       = var.vpc_id
  tags                         = local.tags
}

# module "storage_sg" {
#   count                        = local.enable_storage ? 1 : 0
#   source                       = "terraform-ibm-modules/security-group/ibm"
#   version                      = "1.0.1"
#   add_ibm_cloud_internal_rules = true
#   resource_group               = var.resource_group
#   security_group_name          = format("%s-strg-sg", local.prefix)
#   security_group_rules         = local.storage_security_group_rules
#   vpc_id                       = var.vpc_id
# }


# module "login_vsi" {
#   count                         = length(var.login_instances)
#   source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
#   version                       = "3.2.1"
#   vsi_per_subnet                = var.login_instances[count.index]["count"]
#   create_security_group         = false
#   security_group                = null
#   image_id                      = local.login_image_id
#   machine_type                  = var.login_instances[count.index]["profile"]
#   prefix                        = count.index == 0 ? local.login_node_name : format("%s-%s", local.login_node_name, count.index)
#   resource_group_id             = var.resource_group
#   enable_floating_ip            = false
#   security_group_ids            = module.login_sg[*].security_group_id
#   ssh_key_ids                   = local.login_ssh_keys
#   subnets                       = local.login_subnets
#   tags                          = local.tags
#   user_data                     = data.template_file.login_user_data.rendered
#   vpc_id                        = var.vpc_id
#   kms_encryption_enabled        = var.kms_encryption_enabled
#   skip_iam_authorization_policy = local.skip_iam_authorization_policy
#   boot_volume_encryption_key    = var.boot_volume_encryption_key
# }

module "management_vsi" {
  count = 1
  # count                       = length(var.management_instances)
  source         = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version        = "3.2.1"
  vsi_per_subnet = 1
  # vsi_per_subnet              = var.management_instances[count.index]["count"]
  create_security_group = false
  security_group        = null
  image_id              = local.image_mapping_entry_found ? local.new_image_id : data.ibm_is_image.management[0].id
  # image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.compute.id
  machine_type = data.ibm_is_instance_profile.management_node.name
  prefix       = format("%s-%s", local.management_node_name, count.index + 1)
  # prefix                      = count.index == 0 ? local.management_node_name : format("%s-%s", local.management_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = [local.compute_subnets[0]]
  tags                          = local.tags
  user_data                     = "${data.template_file.management_user_data.rendered} ${file("${path.module}/templates/lsf_management.sh")}"
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  # placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.management_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "management_candidate_vsi" {
  count                         = var.management_node_count - 1
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "3.2.1"
  create_security_group         = false
  security_group                = null
  security_group_ids            = module.compute_sg[*].security_group_id
  vpc_id                        = var.vpc_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = [local.compute_subnets[0]]
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  user_data                     = "${data.template_file.management_user_data.rendered} ${file("${path.module}/templates/lsf_management_candidate.sh")}"
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  image_id                      = local.image_mapping_entry_found ? local.new_image_id : data.ibm_is_image.management[0].id
  # image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.compute.id
  prefix         = format("%s-%s", local.management_node_name, count.index + 2)
  machine_type   = data.ibm_is_instance_profile.management_node.name
  vsi_per_subnet = 1
  tags           = local.tags
}

module "login_vsi" {
  count                         = 1
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "3.2.1"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.compute[0].id
  machine_type                  = var.login_node_instance_type
  prefix                        = local.login_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = [var.bastion_security_group_id]
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = length(var.bastion_subnets) == 3 ? [local.bastion_subnets[2]] : [local.bastion_subnets[0]]
  tags                          = local.tags
  user_data                     = "${data.template_file.login_user_data.rendered} ${file("${path.module}/templates/login_vsi.sh")}"
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
}

module "ldap_vsi" {
  count = local.sagar
  # count                       = length(var.management_instances)
  source         = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version        = "3.2.1"
  vsi_per_subnet = 1
  # vsi_per_subnet              = var.management_instances[count.index]["count"]
  create_security_group = false
  security_group        = null
  image_id              = local.ldap_instance_image_id
  # image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.compute.id
  machine_type = var.ldap_vsi_profile
  prefix       = local.ldap_node_name
  # prefix                      = count.index == 0 ? local.management_node_name : format("%s-%s", local.management_node_name, count.index)
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = [local.compute_subnets[0]]
  tags                          = local.tags
  user_data                     = var.enable_ldap == true && var.ldap_server == "null" ? "${data.template_file.ldap_user_data[0].rendered} ${file("${path.module}/templates/ldap_user_data.sh")}" : ""
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  #placement_group_id = var.placement_group_ids[(var.management_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "generate_db_password" {
  count            = var.enable_app_center && var.app_center_high_availability ? 1 : 0
  source           = "../../modules/security/password"
  length           = 15
  special          = true
  override_special = "-_"
  min_numeric      = 1
}

# module "compute_vsi" {
#   count                         = length(var.static_compute_instances)
#   source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
#   version                       = "3.2.1"
#   vsi_per_subnet                = var.static_compute_instances[count.index]["count"]
#   create_security_group         = false
#   security_group                = null
#   image_id                      = local.compute_image_id
#   machine_type                  = var.static_compute_instances[count.index]["profile"]
#   prefix                        = count.index == 0 ? local.compute_node_name : format("%s-%s", local.compute_node_name, count.index)
#   resource_group_id             = var.resource_group
#   enable_floating_ip            = false
#   security_group_ids            = module.compute_sg[*].security_group_id
#   ssh_key_ids                   = local.compute_ssh_keys
#   subnets                       = local.compute_subnets
#   tags                          = local.tags
#   user_data                     = data.template_file.compute_user_data.rendered
#   vpc_id                        = var.vpc_id
#   kms_encryption_enabled        = var.kms_encryption_enabled
#   skip_iam_authorization_policy = local.skip_iam_authorization_policy
#   boot_volume_encryption_key    = var.boot_volume_encryption_key
#   placement_group_id            = var.placement_group_ids
#   #placement_group_id = var.placement_group_ids[(var.static_compute_instances[count.index]["count"])%(length(var.placement_group_ids))]
# }

# module "storage_vsi" {
#   count                         = length(var.storage_instances)
#   source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
#   version                       = "3.2.1"
#   vsi_per_subnet                = var.storage_instances[count.index]["count"]
#   create_security_group         = false
#   security_group                = null
#   image_id                      = local.storage_image_id
#   machine_type                  = var.storage_instances[count.index]["profile"]
#   prefix                        = count.index == 0 ? local.storage_node_name : format("%s-%s", local.storage_node_name, count.index)
#   resource_group_id             = var.resource_group
#   enable_floating_ip            = false
#   security_group_ids            = module.storage_sg[*].security_group_id
#   ssh_key_ids                   = local.storage_ssh_keys
#   subnets                       = local.storage_subnets
#   tags                          = local.tags
#   user_data                     = data.template_file.storage_user_data.rendered
#   vpc_id                        = var.vpc_id
#   block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
#   kms_encryption_enabled        = var.kms_encryption_enabled
#   skip_iam_authorization_policy = local.skip_iam_authorization_policy
#   boot_volume_encryption_key    = var.boot_volume_encryption_key
#   placement_group_id            = var.placement_group_ids
#   #placement_group_id = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
# }

# module "protocol_vsi" {
#   count                         = length(var.protocol_instances)
#   source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
#   version                       = "3.2.1"
#   vsi_per_subnet                = var.protocol_instances[count.index]["count"]
#   create_security_group         = false
#   security_group                = null
#   image_id                      = local.protocol_image_id
#   machine_type                  = var.protocol_instances[count.index]["profile"]
#   prefix                        = count.index == 0 ? local.protocol_node_name : format("%s-%s", local.protocol_node_name, count.index)
#   resource_group_id             = var.resource_group
#   enable_floating_ip            = false
#   security_group_ids            = module.storage_sg[*].security_group_id
#   ssh_key_ids                   = local.protocol_ssh_keys
#   subnets                       = local.storage_subnets
#   tags                          = local.tags
#   user_data                     = data.template_file.protocol_user_data.rendered
#   vpc_id                        = var.vpc_id
#   kms_encryption_enabled        = var.kms_encryption_enabled
#   skip_iam_authorization_policy = local.skip_iam_authorization_policy
#   boot_volume_encryption_key    = var.boot_volume_encryption_key
#   # Bug: 5847 - LB profile & subnets are not configurable
#   # load_balancers        = local.enable_load_balancer ? local.load_balancers : []
#   secondary_allow_ip_spoofing = true
#   secondary_security_groups   = local.protocol_secondary_security_group
#   secondary_subnets           = local.protocol_subnets
#   placement_group_id          = var.placement_group_ids
#   #placement_group_id = var.placement_group_ids[(var.protocol_instances[count.index]["count"])%(length(var.placement_group_ids))]
# }

module "ssh_key" {
  source = "./../key"
}
