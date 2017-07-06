require "bundler"
Bundler.require(:default)

require_relative "payday_runner.rb"

puts "PAYDAY RUNNER".green
puts "-------------".green

puts "\n"

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

github_client = Octokit::Client.new(access_token: gh_token)

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

puts "Searching for existing droplet...".yellow

droplet = PaydayRunner.find_existing_droplet(do_token)

if droplet
  puts "Found droplet.".green
else
  puts "No existing droplet found, creating Digital Ocean droplet...\n".yellow

  droplet = PaydayRunner.create_droplet(do_token, do_ssh_key_id)
  puts "Droplet with ID #{droplet.id} created successfully!".green
end

ip_address = PaydayRunner.get_droplet_ip(do_token, droplet.id)
puts "Droplet IP is #{ip_address}".green

PaydayRunner.clear_github_keys(github_client) # Remove any existing keys created by this script

Net::SSH.start(ip_address, "root", keys: ["~/.ssh/id_rsa"]) do |ssh|
  puts "Creating SSH key...".yellow
  ssh.exec!("rm /root/.ssh/id_rsa") # TODO: Log if we actually removed a key
  ssh.exec!("ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N \"\"")
  output = ssh.exec!("cat /root/.ssh/id_rsa.pub")
  puts "SSH key created.".green

  puts "Uploading SSH key to github...".yellow
  PaydayRunner.create_github_key(github_client, output)
  puts "Uploaded SSH key to github.".green

  ssh.exec!("git config --global user.name 'Paul Kuruvilla'")
  ssh.exec!("git config --global user.email 'rohitpaulk@gmail.com'")

  ssh.exec!("ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts") { |_, stream, data| puts "[#{stream}] #{data}" }

  ssh.exec!("rm -rf gratipay.com") # Log if we removed
  ssh.exec!("git clone git@github.com:gratipay/gratipay.com") { |_, stream, data| puts "[#{stream}] #{data}" }

  # How to make this reversible?
  ssh.exec!("git clone git@github.com:gratipay/logs") { |_, stream, data| puts "[#{stream}] #{data}" }
end

# puts "Destroying droplet..."
# PaydayRunner.destroy_droplet(do_token, droplet.id)

# create Droplet with that key
# SSH into machine
#   - [x] create public/private key pair
#   - [x] add public/private key pair to Github
#   - configure git with username/password?
#   - [x] git clone gratipay.com
#   - [x] git clone logs
#   - enter gratipay repo, run bootstrap.sh
