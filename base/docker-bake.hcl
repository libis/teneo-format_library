variable "RUBY_VERSION"  {
  default = "3.4.9"
}

variable "OS_VERSION" {
  default = "slim"
}

variable "BUNDLER_VERSION" {
  default = "4.0.12"
}

group "all" {
  targets = [ "ruby_base", "gem_base" ]
}

target "ruby_base" {
  description = "Base image for ruby run-time images. With ruby, bundler and postgres client installed."
  dockerfile = "Dockerfile.ruby"
  tags = ["ruby_base"]
  args = {
    RUBY_VERSION = RUBY_VERSION
    OS_VERSION = OS_VERSION
    BUNDLER_VERSION = BUNDLER_VERSION
  }
}

target "gem_base" {
  description = "Base image for gem development. Builds on top of 'ruby_base' and adds development libraries."
  contexts = {
    ruby_base = "target:ruby_base"
  }
  dockerfile = "Dockerfile.gem"
  tags = ["gem_base"]
}