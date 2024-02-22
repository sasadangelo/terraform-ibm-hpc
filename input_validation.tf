###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

// Module for the private cluster_subnet and login subnet cidr validation.
module "ipvalidation_cluster_subnet" {
  count              = length(var.vpc_cluster_private_subnets_cidr_blocks)
  source             = "./modules/custom/subnet_cidr_check"
  subnet_cidr        = var.vpc_cluster_private_subnets_cidr_blocks[count.index]
  vpc_address_prefix = [local.prefixes_in_given_zone_1, local.prefixes_in_given_zone_2][count.index]
}

module "ipvalidation_login_subnet" {
  source             = "./modules/custom/subnet_cidr_check"
  subnet_cidr        = var.vpc_cluster_login_private_subnets_cidr_blocks[0]
  vpc_address_prefix = local.prefixes_in_given_zone_login
}

locals {
  // Copy address prefixes and CIDR of given zone into a new tuple
  prefixes_in_given_zone_login = [
    for prefix in data.ibm_is_vpc_address_prefixes.existing_vpc.*.address_prefixes[0] :
  prefix.cidr if prefix.zone.0.name == var.zones[0]]

  // To get the address prefix of zone1
  prefixes_in_given_zone_1 = [
    for prefix in data.ibm_is_vpc_address_prefixes.existing_vpc.*.address_prefixes[0] :
  prefix.cidr if var.zones[0] == prefix.zone.0.name]

  //To get the address prefix of zone2
  prefixes_in_given_zone_2 = [
    for prefix in data.ibm_is_vpc_address_prefixes.existing_vpc.*.address_prefixes[0] :
  prefix.cidr if var.zones[1] == prefix.zone.0.name]

  # // Validation for the private cluster_subnet CIDR input of zone 1
  #   validate_private_subnet_cidr_1 = anytrue(concat([length(var.cluster_subnet_ids) != 0], module.ipvalidation_cluster_subnet[0].results))
  #   // Validation for the private cluster_subnet CIDR input of zone 2
  #   validate_private_subnet_cidr_2   = anytrue(concat([length(var.cluster_subnet_ids) != 0], module.ipvalidation_cluster_subnet[1].results))
  #   validate_private_subnet_cidr_msg = "Provide appropriate range of subnet CIDR value in vpc_cluster_private_subnets_cidr_blocks from the existing VPC’s CIDR block."
  #   validate_private_subnet_cidr_chk = regex("^${local.validate_private_subnet_cidr_msg}$", (local.validate_private_subnet_cidr_1 && local.validate_private_subnet_cidr_2 ? local.validate_private_subnet_cidr_msg : ""))

  #   // Validation for the login cluster_subnet CIDR input should be in zone1 address prefix
  #   validate_login_subnet_cidr     = anytrue(module.ipvalidation_login_subnet.results)
  #   validate_login_subnet_cidr_msg = "Provide appropriate range of subnet CIDR value in vpc_cluster_login_private_subnets_cidr_blocks from the existing VPC’s CIDR block."
  #   validate_login_subnet_cidr_chk = regex("^${local.validate_login_subnet_cidr_msg}$", (local.validate_login_subnet_cidr ? local.validate_login_subnet_cidr_msg : ""))

  # // Validate that the vpc_cluster_login_private_subnets_cidr_blocks do not conflict with the subnet entries in the primary zone.
  # login_cidr   = var.vpc_cluster_login_private_subnets_cidr_blocks[0]
  # cluster_cidr = length(var.cluster_subnet_ids) > 1 && var.vpc_name != null ? data.ibm_is_subnet.existing_subnet[0].ipv4_cidr_block : var.vpc_cluster_private_subnets_cidr_blocks[0]
  # //Convert the login CIDR, cluster CIDR beginning and ending IP addresses to integers for validation.
  # validate_login = [for i in [cidrhost(local.login_cidr, 0), cidrhost(local.login_cidr, -1), cidrhost(local.cluster_cidr, 0), cidrhost(local.cluster_cidr, -1)] : (((split(".", i)[0]) * pow(256, 3)) #192
  #   + ((split(".", i)[1]) * pow(256, 2))
  #   + ((split(".", i)[2]) * pow(256, 1))
  # + ((split(".", i)[3]) * pow(256, 0)))]
  # //Assign values to new variables for readability.
  # login_cidr_first_ip   = local.validate_login[0]
  # login_cidr_last_ip    = local.validate_login[1]
  # cluster_cidr_first_ip = local.validate_login[2]
  # cluster_cidr_last_ip  = local.validate_login[3]
  # //The logic for CIDR conflict validation is that the entire login CIDR range should either be less than or greater than the cluster CIDR range.
  # validate_login_conflict     = anytrue([local.login_cidr_first_ip > local.cluster_cidr_first_ip && local.login_cidr_first_ip > local.cluster_cidr_last_ip, local.login_cidr_first_ip < local.cluster_cidr_first_ip && local.login_cidr_last_ip < local.cluster_cidr_first_ip])
  # validate_login_conflict_msg = "The vpc_cluster_login_private_subnets_cidr_blocks conflicts with the subnet entry in the primary zone."
  # validate_login_conflict_chk = regex("^${local.validate_login_conflict_msg}$",
  # (local.validate_login_conflict ? local.validate_login_conflict_msg : ""))

  // validation for the boot volume encryption toggling.
  validate_enable_customer_managed_encryption     = anytrue([alltrue([var.kms_key_name != null, var.kms_instance_name != null]), (var.kms_key_name == null), (var.key_management != "key_protect")])
  validate_enable_customer_managed_encryption_msg = "Please make sure you are passing the kms_instance_name if you are passing kms_key_name."
  validate_enable_customer_managed_encryption_chk = regex(
    "^${local.validate_enable_customer_managed_encryption_msg}$",
  (local.validate_enable_customer_managed_encryption ? local.validate_enable_customer_managed_encryption_msg : ""))

  // validation for the boot volume encryption toggling.
  validate_null_customer_managed_encryption     = anytrue([alltrue([var.kms_instance_name == null, var.key_management != "key_protect"]), (var.key_management == "key_protect")])
  validate_null_customer_managed_encryption_msg = "Please make sure you are setting key_management as key_protect if you are passing kms_instance_name, kms_key_name."
  validate_null_customer_managed_encryption_chk = regex(
    "^${local.validate_null_customer_managed_encryption_msg}$",
  (local.validate_null_customer_managed_encryption ? local.validate_null_customer_managed_encryption_msg : ""))

  // validate application center gui password
  password_msg                = "Password should be at least 8 characters, must have one number, one lowercase letter, and one uppercase letter, at least one unique character. Password Should not contain username"
  validate_app_center_gui_pwd = (var.enable_app_center && can(regex("^.{8,}$", var.app_center_gui_pwd) != "") && can(regex("[0-9]{1,}", var.app_center_gui_pwd) != "") && can(regex("[a-z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[A-Z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.app_center_gui_pwd) != "") && trimspace(var.app_center_gui_pwd) != "") || !var.enable_app_center
  validate_app_center_gui_pwd_chk = regex(
    "^${local.password_msg}$",
  (local.validate_app_center_gui_pwd ? local.password_msg : ""))

  // Validate existing cluster subnet should be the subset of vpc_name entered
  validate_subnet_id_vpc_msg = "Provided cluster subnets should be within the vpc entered."
  validate_subnet_id_vpc     = anytrue([length(var.cluster_subnet_ids) == 0, length(var.cluster_subnet_ids) > 1 && var.vpc_name != null ? alltrue([for subnet_id in var.cluster_subnet_ids : contains(data.ibm_is_vpc.existing_vpc[0].subnets.*.id, subnet_id)]) : false])
  validate_subnet_id_vpc_chk = regex("^${local.validate_subnet_id_vpc_msg}$",
  (local.validate_subnet_id_vpc ? local.validate_subnet_id_vpc_msg : ""))

  // Validate existing cluster subnet should be in the appropriate zone.
  validate_subnet_id_zone_msg = "Provided cluster subnets should be in appropriate zone."
  validate_subnet_id_zone     = anytrue([length(var.cluster_subnet_ids) == 0, length(var.cluster_subnet_ids) > 1 && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_subnet[0].zone == var.zones[0] && data.ibm_is_subnet.existing_subnet[1].zone == var.zones[1]]) : false])
  validate_subnet_id_zone_chk = regex("^${local.validate_subnet_id_zone_msg}$",
  (local.validate_subnet_id_zone ? local.validate_subnet_id_zone_msg : ""))

  // Validate existing login subnet should be the subset of vpc_name entered
  validate_login_subnet_id_vpc_msg = "Provided login subnet should be within the vpc entered."
  validate_login_subnet_id_vpc     = anytrue([var.login_subnet_id == null, var.login_subnet_id != null && var.vpc_name != null ? alltrue([for subnet_id in [var.login_subnet_id] : contains(data.ibm_is_vpc.existing_vpc[0].subnets.*.id, subnet_id)]) : false])
  validate_login_subnet_id_vpc_chk = regex("^${local.validate_login_subnet_id_vpc_msg}$",
  (local.validate_login_subnet_id_vpc ? local.validate_login_subnet_id_vpc_msg : ""))

  // Validate existing login subnet should be in the appropriate zone.
  validate_login_subnet_id_zone_msg = "Provided login subnet should be in appropriate zone."
  validate_login_subnet_id_zone     = anytrue([var.login_subnet_id == null, var.login_subnet_id != null && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_login_subnet[0].zone == var.zones[0]]) : false])
  validate_login_subnet_id_zone_chk = regex("^${local.validate_login_subnet_id_zone_msg}$",
  (local.validate_login_subnet_id_zone ? local.validate_login_subnet_id_zone_msg : ""))

  // Contract ID validation
  validate_contract_id     = length("${var.cluster_id}${var.contract_id}") > 129 ? false : true
  validate_contract_id_msg = "The length of contract_id and cluster_id combination should not exceed 128 characters."
  validate_contract_id_chk = regex(
    "^${local.validate_contract_id_msg}$",
  (local.validate_contract_id ? local.validate_contract_id_msg : ""))

  validate_contract_id_api     = contains(["200", "204"], tostring(data.http.contract_id_validation.status_code)) ? true : false
  validate_contract_id_api_msg = "The contractID name must be unique globally. The Status code of validation is: ${data.http.contract_id_validation.status_code}"
  validate_contract_id_api_chk = regex(
    "^${local.validate_contract_id_api_msg}$",
  (local.validate_contract_id_api ? local.validate_contract_id_api_msg : ""))

  ## Validate custom fileshare
  ## Construct a list of Share size(GB) and IOPS range(IOPS)from values provided in https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui#dp2-profile
  ## List values [[sharesize_start,sharesize_end,min_iops,max_iops], [..]....]
  custom_fileshare_iops_range = [[10, 39, 100, 1000], [40, 79, 100, 2000], [80, 99, 100, 4000], [100, 499, 100, 6000], [500, 999, 100, 10000], [1000, 1999, 100, 20000], [2000, 3999, 200, 40000], [4000, 7999, 300, 40000], [8000, 15999, 500, 64000], [16000, 32000, 2000, 96000]]
  ## List with input iops value, min and max iops for the input share size.
  size_iops_lst = [for values in var.custom_file_shares : [for list_val in local.custom_fileshare_iops_range : [values.iops, list_val[2], list_val[3]] if(values.size >= list_val[0] && values.size <= list_val[1])]]
  ## Validate the input iops falls inside the range.
  validate_custom_file_share     = alltrue([for iops in local.size_iops_lst : iops[0][0] >= iops[0][1] && iops[0][0] <= iops[0][2]])
  validate_custom_file_share_msg = "Provided iops value is not valid for given file share size. Please refer 'File Storage for VPC profiles' page in ibm cloud docs for a valid iops and file share size combination."
  validate_custom_file_share_chk = regex(
    "^${local.validate_custom_file_share_msg}$",
  (local.validate_custom_file_share ? local.validate_custom_file_share_msg : ""))

  // LDAP base DNS Validation
  validate_ldap_basedns = (var.enable_ldap && trimspace(var.ldap_basedns) != "") || !var.enable_ldap
  ldap_basedns_msg      = "If LDAP is enabled, then the base DNS should not be empty or null. Need a valid domain name."
  validate_ldap_basedns_chk = regex(
    "^${local.ldap_basedns_msg}$",
  (local.validate_ldap_basedns ? local.ldap_basedns_msg : ""))

  // LDAP base existing LDAP server
  validate_ldap_server = (var.enable_ldap && trimspace(var.ldap_server) != "") || !var.enable_ldap
  ldap_server_msg      = "IP of existing LDAP server. If none given a new ldap server will be created. It should not be empty."
  validate_ldap_server_chk = regex(
    "^${local.ldap_server_msg}$",
  (local.validate_ldap_server ? local.ldap_server_msg : ""))

  // LDAP Admin Password Validation
  validate_ldap_adm_pwd = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_admin_password) >= 8 && length(var.ldap_admin_password) <= 20 && can(regex("^(.*[0-9]){2}.*$", var.ldap_admin_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_admin_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_admin_password)) && can(regex("^.*[~@_+:].*$", var.ldap_admin_password)) && can(regex("^[^!#$%^&*()=}{\\[\\]|\\\"';?.<,>-]+$", var.ldap_admin_password)) : local.ldap_server_status
  ldap_adm_password_msg = "Password that is used for LDAP admin.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character. Make sure that the password doesn't include the username."
  validate_ldap_adm_pwd_chk = regex(
    "^${local.ldap_adm_password_msg}$",
  (local.validate_ldap_adm_pwd ? local.ldap_adm_password_msg : ""))

  // LDAP User Validation
  validate_ldap_usr = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_user_name) >= 4 && length(var.ldap_user_name) <= 32 && var.ldap_user_name != "" && can(regex("^[a-zA-Z0-9_-]*$", var.ldap_user_name)) && trimspace(var.ldap_user_name) != "") : local.ldap_server_status
  ldap_usr_msg      = "The input for 'ldap_user_name' is considered invalid. The username must be within the range of 4 to 32 characters and may only include letters, numbers, hyphens, and underscores. Spaces are not permitted."
  validate_ldap_usr_chk = regex(
    "^${local.ldap_usr_msg}$",
  (local.validate_ldap_usr ? local.ldap_usr_msg : ""))

  // LDAP User Password Validation
  validate_ldap_usr_pwd = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_user_password) >= 8 && length(var.ldap_user_password) <= 20 && can(regex("^(.*[0-9]){2}.*$", var.ldap_user_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_user_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_user_password)) && can(regex("^.*[~@_+:].*$", var.ldap_user_password)) && can(regex("^[^!#$%^&*()=}{\\[\\]|\\\"';?.<,>-]+$", var.ldap_user_password)) : local.ldap_server_status
  ldap_usr_password_msg = "Password that is used for LDAP user.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character. Make sure that the password doesn't include the username."
  validate_ldap_usr_pwd_chk = regex(
    "^${local.ldap_usr_password_msg}$",
  (local.validate_ldap_usr_pwd ? local.ldap_usr_password_msg : ""))

  // Validate existing subnet public gateways
  validate_subnet_name_pg_msg = "Provided existing cluster_subnet_ids should have public gateway attached."
  validate_subnet_name_pg     = anytrue([length(var.cluster_subnet_ids) == 0, length(var.cluster_subnet_ids) > 1 && var.vpc_name != null ? (data.ibm_is_subnet.existing_subnet[0].public_gateway != "" && data.ibm_is_subnet.existing_subnet[1].public_gateway != "") : false])
  validate_subnet_name_pg_chk = regex("^${local.validate_subnet_name_pg_msg}$",
  (local.validate_subnet_name_pg ? local.validate_subnet_name_pg_msg : ""))

  // Validate existing vpc public gateways
  validate_existing_vpc_pgw_msg = "Provided existing vpc should have the public gateways created in the provided zones."
  validate_existing_vpc_pgw     = anytrue([(var.vpc_name == null), alltrue([var.vpc_name != null, length(var.cluster_subnet_ids) > 1]), alltrue([var.vpc_name != null, length(var.cluster_subnet_ids) == 0, var.login_subnet_id == null, length(local.zone_1_pgw_id) > 0, length(local.zone_2_pgw_id) > 0])])
  validate_existing_vpc_pgw_chk = regex("^${local.validate_existing_vpc_pgw_msg}$",
  (local.validate_existing_vpc_pgw ? local.validate_existing_vpc_pgw_msg : ""))

  // Validate in case of existing subnets provide both login_subnet_id and cluster_subnet_ids.
  validate_login_subnet_id_msg = "In case of existing subnets provide both login_subnet_id and cluster_subnet_ids."
  validate_login_subnet_id     = anytrue([alltrue([length(var.cluster_subnet_ids) == 0, var.login_subnet_id == null]), alltrue([length(var.cluster_subnet_ids) != 0, var.login_subnet_id != null])])
  validate_login_subnet_id_chk = regex("^${local.validate_login_subnet_id_msg}$",
  (local.validate_login_subnet_id ? local.validate_login_subnet_id_msg : ""))

  // Validate the subnet_id user input value
  validate_subnet_id_msg = "If the cluster_subnet_ids are provided, the user should also provide the vpc_name."
  validate_subnet_id     = anytrue([var.vpc_name != null && length(var.cluster_subnet_ids) > 0, length(var.cluster_subnet_ids) == 0])
  validate_subnet_id_chk = regex("^${local.validate_subnet_id_msg}$",
  (local.validate_subnet_id ? local.validate_subnet_id_msg : ""))

  // IBM Cloud Database for MySQL Resource Allocation Validation
  validate_db_template = (var.enable_app_center && var.ENABLE_HIGH_AVAILABILITY && var.management_node_count >= 2) || !var.ENABLE_HIGH_AVAILABILITY || !var.enable_app_center
  db_template_msg      = "When the Application Center is installed in High Availability, at least two management nodes must be installed."
  validate_db_template_chk = regex(
    "^${local.db_template_msg}$",
  (local.validate_db_template ? local.db_template_msg : ""))

  // Management node count validation when Application Center is in High Availability
  validate_management_node_count = (var.enable_app_center && var.ENABLE_HIGH_AVAILABILITY && length(var.DB_TEMPLATE) == 4 && var.DB_TEMPLATE[0] == 3 && var.DB_TEMPLATE[1] >= 1024 && var.DB_TEMPLATE[1] <= 114688 && var.DB_TEMPLATE[2] >= 122880 && var.DB_TEMPLATE[2] <= 4194304 && var.DB_TEMPLATE[3] >= 0 && var.DB_TEMPLATE[3] <= 28) || !var.ENABLE_HIGH_AVAILABILITY || !var.enable_app_center
  management_node_count_msg      = "IBM Cloud Database for MySQL resource allocation must have 3 members, RAM size in the 1024-114688 Mb range, Disk size in the 122880-4194304 Mb range, CPU core in the 0-28 dedicated cores range."
  validate_management_node_count_chk = regex(
    "^${local.management_node_count_msg}$",
  (local.validate_management_node_count ? local.management_node_count_msg : ""))

  // Validate the dns_custom_resolver_id should not be given in case of new vpc case
  validate_custom_resolver_id_msg = "If it is the new vpc deployment, do not provide existing dns_custom_resolver_id as that will impact the name resolution of the cluster."
  validate_custom_resolver_id     = anytrue([var.vpc_name != null, var.vpc_name == null && var.dns_custom_resolver_id == null])
  validate_custom_resolver_id_chk = regex("^${local.validate_custom_resolver_id_msg}$",
  (local.validate_custom_resolver_id ? local.validate_custom_resolver_id_msg : ""))
}
