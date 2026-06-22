variable "GEM_VERSION" {
  default = "1.0"
}

group "all" {
  targets = [ "build", "test" ]
}

target "build" {
  description = "Image for building the gem. Meant for the source tree to be mounted into."
  dockerfile = "Dockerfile.build"
  tags = ["gem_build"]
}

target "test" {
  description = "Image for testing the gem. With local installation of the built gem."
  args = {
    "GEM_VERSION" = GEM_VERSION
  }
  contexts = {
    "gem_build" = "target:build"
  }
  dockerfile = "Dockerfile.test"
  tags = ["gem_test"]
}