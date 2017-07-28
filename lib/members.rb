require 'yaml'
require 'pp'

require_relative 'dry_runner'
require_relative 'git_hub_client'

class Members
  include DryRunner

  def initialize(dry_run, organization, members_yaml)
    @dry_run = dry_run
    @organization = organization

    @members = YAML.load_file(File.expand_path(members_yaml, __dir__))

    @c = GitHubClient.new
    @c.login
  end

  def sync_members
    c = @c

    org = @organization
    puts "Working with organization: #{org}"

    upsert_member_role('admin')
    upsert_member_role('member')

    org_members = c.auto_paginate { c.organization_members(org) }
    org_logins = org_members.map(&:login)

    members = @members
    to_remove = org_logins - members['admin'] - members['member']
    dry_runner(to_remove,
               ->(login) { @c.remove_organization_member(org, login) },
               ->(login) { "Remove #{login} from #{org}" })

    c.auto_paginate do
      c.org_teams(org).each do |team|
        team_members = members['teams'][team.name]
        if team_members
          sync_team(team, team_members)
        else
          puts "* Found team <#{team.name}> in org <#{org}>, but not configured in yaml: skipping."
        end
      end
    end
  end

  def upsert_member_role(role)
    org_members = @c.auto_paginate { @c.organization_members(@organization, {role: role}) }
    org_logins = org_members.map(&:login)

    to_add = (@members[role]) - org_logins
    dry_runner(to_add,
               ->(login) { @c.update_organization_membership(@organization, {role: role, user: login}) },
               ->(login) { "Adding/updating #{login} to #{@organization} as #{role}" })
  end

  def sync_team(team, members)
    current_members = @c.auto_paginate { @c.team_members(team.id).map(&:login) }
    to_remove = current_members - members
    dry_runner(to_remove,
               ->(login) { @c.remove_team_member(team.id, login) },
               ->(login) { "Remove #{login} from #{team.name}" })

    to_add = members - current_members
    dry_runner(to_add,
               ->(login) { @c.add_team_member(team.id, login) },
               ->(login) { "Add #{login} to #{team.name}" })
  end
end
