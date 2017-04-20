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
    YAML.load_file(config_file)[key]
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

    do_client.droplets.all # Sanity test for API keys
    return true
    # TODO: Figure out exception to catch!
  end

  def self.get_digital_ocean_ssh_keys(token)
    do_client = DropletKit::Client.new(access_token: token)

    # require 'pry'; binding.pry
    # TODO: This doesn't work!!!
    # Hash[do_client.ssh_keys.all.map{|key| [key.id, key.name]}]
    {}
  end

  def self.create_droplet(token, ssh_key_id)
    do_client = DropletKit::Client.new(access_token: token)

    droplet = DropletKit::Droplet.new(
      name: 'Payday (Created via payday_runner)',
      region: 'nyc2',
      image: 'ubuntu-14-04-x64',
      size: '512mb',
      ssh_keys: [ssh_key_id]
    )

    # do_client.droplets.create(droplet)
    # TODO: Wait for networks to appear?

    # For now, return created droplet.
    # TODO: Only return required fields, don't leak DO type
    do_client.droplets.find(id: 46391189)
  end
end
