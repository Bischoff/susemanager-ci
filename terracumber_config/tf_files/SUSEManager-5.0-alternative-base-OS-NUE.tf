// Mandatory variables for terracumber
variable "URL_PREFIX" {
  type = string
  default = "https://ci.suse.de/view/Manager/view/Manager-5.0/job/manager-5.0-qe-alternative-base-OS-NUE"
}

// Not really used as this is for --runall parameter, and we run cucumber step by step
variable "CUCUMBER_COMMAND" {
  type = string
  default = "export PRODUCT='SUSE-Manager' && run-testsuite"
}

variable "CUCUMBER_GITREPO" {
  type = string
  default = "https://github.com/SUSE/spacewalk.git"
}

variable "CUCUMBER_BRANCH" {
  type = string
  default = "Manager-5.0"
}

variable "CUCUMBER_RESULTS" {
  type = string
  default = "/root/spacewalk/testsuite"
}

variable "MAIL_SUBJECT" {
  type = string
  default = "Results 5.0 SLE Update $status: $tests scenarios ($failures failed, $errors errors, $skipped skipped, $passed passed)"
}

variable "MAIL_TEMPLATE" {
  type = string
  default = "../mail_templates/mail-template-jenkins.txt"
}

variable "MAIL_SUBJECT_ENV_FAIL" {
  type = string
  default = "Results 5.0 SLE Update: Environment setup failed"
}

variable "MAIL_TEMPLATE_ENV_FAIL" {
  type = string
  default = "../mail_templates/mail-template-jenkins-env-fail.txt"
}

variable "MAIL_FROM" {
  type = string
  default = "galaxy-noise@suse.de"
}

variable "MAIL_TO" {
  type = string
  default = "galaxy-noise@suse.de"
}

// sumaform specific variables
variable "SCC_USER" {
  type = string
}

variable "SCC_PASSWORD" {
  type = string
}

variable "SERVER_CONTAINER_REPOSITORY" {
  type = string
}

variable "PROXY_CONTAINER_REPOSITORY" {
  type = string
}

variable "SERVER_CONTAINER_IMAGE" {
  type = string
  default = ""
}

variable "GIT_USER" {
  type = string
  default = null
}

variable "GIT_PASSWORD" {
  type = string
  default = null
}

terraform {
  required_version = "1.0.10"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.8.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu+tcp://suma-11.mgr.suse.de/system"
}

module "base" {
  source            = "./modules/base"

  cc_username       = var.SCC_USER
  cc_password       = var.SCC_PASSWORD
  product_version   = "5.0-released"

  name_prefix       = "suma-alt-50-"
  use_avahi         = false
  domain            = "mgr.suse.de"
  images            = [ "sles15sp6o", "opensuse155o", "opensuse156o" ]

  mirror            = "minima-mirror-ci-bv.mgr.suse.de"
  use_mirror_images = true

  testsuite         = true

  provider_settings = {
    pool        = "ssd"
    bridge      = "br1"
  }
}

module "server_containerized" {
  source             = "./modules/server_containerized"
  base_configuration = module.base.configuration
  name               = "server"
  image              = "sles15sp6o"
  provider_settings = {
    mac                = "aa:b2:93:01:02:69"
    data_pool          = "ssd"
  }

  main_disk_size        = 1500
  runtime               = "podman"
  container_repository  = var.SERVER_CONTAINER_REPOSITORY
  container_image       = var.SERVER_CONTAINER_IMAGE
  container_tag         = "latest"
  server_mounted_mirror = "minima-mirror-ci-bv.mgr.suse.de"

  auto_accept                    = false
  monitored                      = true
  disable_firewall               = false
  allow_postgres_connections     = false
  skip_changelog_import          = false
  mgr_sync_autologin             = false
  create_sample_channel          = false
  create_sample_activation_key   = false
  create_sample_bootstrap_script = false
  publish_private_ssl_key        = false
  use_os_released_updates        = true
  disable_download_tokens        = false
  ssh_key_path                   = "./salt/controller/id_ed25519.pub"
  from_email                     = "root@suse.de"

  //server_additional_repos

}

module "proxy_containerized" {
  source             = "./modules/proxy_containerized"
  base_configuration = module.base.configuration
  name               = "proxy"
  image              = "sles15sp6o"
  provider_settings  = {
    mac                = "aa:b2:93:01:02:6a"
    memory             = 4096
  }
  server_configuration = {
    hostname = "suma-alt-50-server.mgr.suse.de"
    username = "admin"
    password = "admin"
  }

  runtime              = "podman"
  container_repository  = var.PROXY_CONTAINER_REPOSITORY
  container_tag        = "latest"

  auto_configure        = false
  ssh_key_path          = "./salt/controller/id_ed25519.pub"
}

module "sles15sp6_minion" {
  source             = "./modules/minion"
  base_configuration = module.base.configuration
  name               = "sles15sp6-minion"
  image              = "sles15sp6o"
  provider_settings  = {
    mac    = "aa:b2:93:01:02:6b"
    vcpu   = 2
    memory = 2048
  }

  auto_connect_to_master  = false
  use_os_released_updates = false
  ssh_key_path            = "./salt/controller/id_ed25519.pub"
}

module "controller" {
  source             = "./modules/controller"
  base_configuration = module.base.configuration
  name               = "controller"
  provider_settings = {
    mac                = "aa:b2:93:01:02:68"
    memory             = 16384
    vcpu               = 8
  }
  swap_file_size = null

  // Cucumber repository configuration for the controller
  git_username = var.GIT_USER
  git_password = var.GIT_PASSWORD
  git_repo     = var.CUCUMBER_GITREPO
  branch       = var.CUCUMBER_BRANCH

  server_configuration          = module.server_containerized.configuration
  proxy_configuration           = module.proxy_containerized.configuration
  sle15sp6_minion_configuration = module.sles15sp6_minion.configuration
}

output "configuration" {
  value = {
    controller = module.controller.configuration
  }
}
