require 'octokit'

class GitHubClient
  def self.config_github_enterprise(api_endpoint)
    Octokit.configure do |c|
      c.api_endpoint = api_endpoint
    end
  end

  attr_reader :client

  def initialize(token=nil)
    @client = ::Octokit::Client.new(:access_token => (token || ENV['GITHUB_ACCESS_TOKEN']))
  end

  def login
    p "Logged in as #{@client.user.login}"
  end

  def auto_paginate
    @client.auto_paginate = true
    yield
  ensure
    @client.auto_paginate = false
  end

  def method_missing(meth_id, *args, &block)
    @client.send(meth_id, *args, &block)
  end
end
