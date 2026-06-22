variable "GEM_VERSION" {
  default = "1.0"
}

variable "USER_ID" {
  default = 1000
}

variable "GROUP_ID" {
  default = 1000
}

target "development" {
  description = "Image for development of the REST API server. Meant for the source tree to be mounted into."
  dockerfile = "Dockerfile.dev"
  args = {
    "USER_ID" = USER_ID
    "GROUP_ID" = GROUP_ID
  }
  tags = ["api/rest"]
}

target "production" {
  description = "Image for a production deployment of the REST API server."
  dockerfile = "Dockerfile.prod"
  args = {
    "USER_ID" = USER_ID
    "GROUP_ID" = GROUP_ID
    "GEM_VERSION" = GEM_VERSION
  }
  tags = ["teneo/format_library/api/rest"]
}