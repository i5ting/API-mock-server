require 'bundler/setup'
Bundler.require(:default)

$: << File.expand_path(".")
require 'api-mock-server'
require 'config'
