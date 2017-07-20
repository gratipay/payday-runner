require 'yaml'

module PaydayRunner
  def self.ask(message, hidden=false)
    print message

    self._toggle_echo false if hidden # Let's turn off output if it is a password

    # Receive input
    print " "
    input = STDIN.gets.chomp
    print("\n")

    input
  ensure
    self._toggle_echo true
  end

  def self._toggle_echo(state)
    setting = state ? '' : '-'
    `stty #{setting}echo`
  end

  def self.get_config_value(config_file, key)
    YAML.load(File::read(config_file))[key]
  end

  def self.set_config_value(config_file, key, value)
    config = YAML.load(File::read(config_file))
    config[key] = value

    # This erases all comments. Fine for now,
    # .secrets.env.sample will still have them
    File::write(config_file, YAML.dump(config))
  end

  def self.verify_github_token(token)
    github_client = Octokit::Client.new(access_token: token)

    begin
      github_client.user # Sanity test for API keys
      return true
    rescue Octokit::Unauthorized
      return false
    end
  end

  def self.verify_digital_ocean_token(token)
    do_client = DropletKit::Client.new(access_token: token)

    do_client.droplets.all.first # Sanity test for API keys
    return true
    # TODO: Figure out exception to catch!
  end

  def self.verify_heroku_token(email, token)
    begin
      return PlatformAPI.connect(token).account.info["email"] == email
    rescue Excon::Error::Unauthorized
      return false
    end
  end

  def self.get_digital_ocean_ssh_keys(token)
    do_client = DropletKit::Client.new(access_token: token)

    do_client.ssh_keys.all.map{ |key| {id: key.id, name: key.name} }
  end

  def self.create_droplet(token, ssh_key_id)
    do_client = DropletKit::Client.new(access_token: token)

    droplet = DropletKit::Droplet.new(
      name: 'payday',
      region: 'nyc1',
      image: 'ubuntu-16-04-x64',
      size: '512mb',
      tags: ['payday-runner'],
      ssh_keys: [ssh_key_id]
    )

    # TODO: Only return required fields, don't leak DO type
    do_client.droplets.create(droplet)

    # TEMP: do_client.droplets.find(id: 47128371)
  end

  def self.find_existing_droplet(token)
    do_client = DropletKit::Client.new(access_token: token)

    droplets = do_client.droplets.all(tag_name: 'payday-runner')

    if droplets.count > 1
      raise 'More than 1 payday droplets found!'
    end

    droplets.count.zero? ? nil : droplets.first
  end

  def self.destroy_droplet(token, droplet_id)
    do_client = DropletKit::Client.new(access_token: token)

    do_client.droplets.delete(id: droplet_id)
  end

  def self.get_droplet_ip(token, droplet_id)
    do_client = DropletKit::Client.new(access_token: token)

    # It takes a while for droplets to get assigned IP addresses,
    # we keep looping until we get one
    #
    # TODO: Possibility of an infinite loop
    begin
      droplet = do_client.droplets.find(id: droplet_id)
      ip_address = droplet.networks.v4.first.ip_address

      return ip_address if ip_address
    end
  end

  def self.clear_github_keys(github_client)
    keys = github_client.keys.select{ |x| x.title.include?("#payday-runner") }
    github_client.remove_key(keys.first.id) if keys.first # Delete more than one key!
  end

  def self.create_github_key(github_client, key)
    github_client.add_key("Payday #payday-runner", key)
  end
end
