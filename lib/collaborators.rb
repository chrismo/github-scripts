require 'yaml'

require_relative 'dry_runner'
require_relative 'git_hub_client'

class Collaborators
  include DryRunner

  def initialize(dry_run, organization, config_yaml)
    @dry_run = dry_run
    @organization = organization
    @config = YAML.load_file(File.expand_path(config_yaml, __dir__))
    @config_collaborators = @config['collaborators']

    @c = GitHubClient.new
    @c.login
  end

  def sync_collaborators
    remove_unlisted
  end

  def remove_unlisted
    c = @c

    org = @organization
    puts "Working with organization: #{org}"

    org_member_logins = c.auto_paginate { c.organization_members(org).map(&:login) }

    ignore_repos = @config['repositories']['ignore']

    c.auto_paginate do
      repos = c.organization_repositories(org, type: 'all')
      repos.map(&:name).each do |repo_name|
        if ignore_repos.include?(repo_name)
          puts "Skipping #{repo_name.ljust(35)}: marked ignore"
          next
        end
        collaborator_and_member_logins = c.collaborators("#{org}/#{repo_name}").map { |h| h[:login] }
        collaborator_logins = collaborator_and_member_logins - org_member_logins

        collaborator_logins.reject! do |login|
          collaborator_marked_as_no_changes?(login).tap do |result|
            puts "No changes for any repos for #{login}." if result
          end
        end

        to_remove = collaborator_logins.reject { |login| login_allowed_in_repo?(login, repo_name) }

        dry_runner(to_remove,
                   ->(login) { c.remove_collaborator("#{org}/#{repo_name}", login) },
                   ->(login) { "Remove from #{repo_name.ljust(32)}: #{login}" })

        to_add = config_logins_for_repo(repo_name) - collaborator_logins
        dry_runner(to_add,
                   ->(login) { c.add_collaborator("#{org}/#{repo_name}", login, permission: 'push') },
                   ->(login) { "Add to #{repo_name.ljust(37)}: #{login}" })

        puts "No changes #{repo_name}" if to_remove.empty? && to_add.empty?
      end
    end
  end

  def collaborator_marked_as_no_changes?(login)
    login_config = @config_collaborators[login]
    login_config ? login_config['repos'] == ['*'] : false
  end

  def login_allowed_in_repo?(login, repo_name)
    login_config = @config_collaborators[login]
    unless login_config
      puts "* No configuration for login <#{login}>"
      return true # reject!
    end
    login_config_repos = login_config['repos']
    unless login_config_repos
      puts "* No configuration for repos for login <#{login}>"
      return true # reject!
    end
    login_config_repos.include?(repo_name)
  end

  def config_logins_for_repo(repo_name)
    @config_collaborators.each_with_object([]) do |(login, attr_hash), result|
      result << login if attr_hash['repos'].include?(repo_name)
    end
  end
end
