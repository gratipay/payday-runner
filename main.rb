require "bundler"
Bundler.require(:default)

require_relative "payday_runner.rb"

puts "PAYDAY RUNNER".green
puts "-------------".green

puts "\n"

ready = PaydayRunner.ask("Shall we begin? (y/n)".blue)
puts "Aborting...".red unless ready == "y"

puts "Okay! Verifying values in .secrets.yml ...\n".yellow

gh_token = PaydayRunner.get_config_value(".secrets.yml", "github_token")
puts "Checking Github token validity... ".blue
if PaydayRunner.verify_github_token(gh_token)
  puts "Valid!".green
else
  puts "Github token not valid, aborting!".red
  exit(1)
end

do_token = PaydayRunner.get_config_value(".secrets.yml", "digital_ocean_token")
puts "Checking Digital Ocean Token validity... ".blue
if PaydayRunner.verify_digital_ocean_token(do_token)
  puts "Valid!".green
else
  puts "Digital Ocean token not valid, aborting!".red
  exit(1)
end

puts "\n"

puts "Creating Digital Ocean droplet...".yellow

# Prompt for Digital Ocean key name?
# do_ssh_keys = PaydayRunner.get_digital_ocean_ssh_keys(do_token)
do_ssh_key_id = '7943071'

droplet = PaydayRunner.create_droplet(do_token, do_ssh_key_id)
puts "Droplet with ID #{droplet.id} created successfully!".green
ip_address = droplet.networks.v4.first.ip_address
puts "Droplet IP is #{ip_address}".green

# create Droplet with that key
# SSH into machine
#   - create public/private key pair
#   - add public/private key pair to Github
#   - install git
#   - configure git with username/password?
#   - git clone gratipay.com
#   - git clone logs
#   - enter gratipay repo, run bootstrap.sh
