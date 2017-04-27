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

# Alternatively, allow user to create key from current system?
do_ssh_key_id = PaydayRunner.get_config_value(".secrets.yml", "digital_ocean_ssh_key_id")

unless do_ssh_key_id && do_ssh_key_id != ""
  ssh_keys = PaydayRunner.get_digital_ocean_ssh_keys(do_token)

  puts "Which Digital Ocean SSH key would you like to place on the droplet?".yellow
  puts ssh_keys.each_with_index.map{|key, i| "#{i+1}) #{key[:name]} (ID: #{key[:id]})"}.join("\n").yellow

  choice = PaydayRunner.ask("Enter your choice: (1/2/3 etc.) ".yellow)
  do_ssh_key_id = ssh_keys[choice.to_i - 1][:id]
  PaydayRunner.set_config_value(".secrets.yml", "digital_ocean_ssh_key_id", do_ssh_key_id)
end

puts "Creating Digital Ocean droplet...\n".yellow

droplet = PaydayRunner.create_droplet(do_token, do_ssh_key_id)
puts "Droplet with ID #{droplet.id} created successfully!".green

ip_address = PaydayRunner.get_droplet_ip(do_token, droplet.id)
puts "Droplet IP is #{ip_address}".green

Net::SSH.start(ip_address, "root", keys: ["~/.ssh/id_rsa"]) do |ssh|
  puts "Creating SSH key...".yellow
  ssh.exec!("rm /root/.ssh/id_rsa") # Log if we actually removed a key
  output = ssh.exec!("ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N \"\"")
  puts "Done.".green
end

# puts "Destroying droplet..."
# PaydayRunner.destroy_droplet(do_token, droplet.id)

# create Droplet with that key
# SSH into machine
#   - create public/private key pair
#   - add public/private key pair to Github
#   - install git
#   - configure git with username/password?
#   - git clone gratipay.com
#   - git clone logs
#   - enter gratipay repo, run bootstrap.sh
