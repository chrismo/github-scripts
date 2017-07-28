# This script will go through the listed orgs and make (or list with dry_run) any necessary rights changes.

require_relative 'git_hub_client'

class BotWrangler
  DRY_RUN = 1
  FOR_REAL = 2

  def all_bot_orgs(bot_token=ENV['GH_ENT_ACCESS_TOKEN'])
    # GitHubClient.config_github_enterprise('http://mygithub-enterprise-hostname/api/v3/')
    c = GitHubClient.new(bot_token)
    c.login

    c.auto_paginate do
      orgs_from_teams = c.user_teams.map(&:organization).map(&:login)

      repos = c.repositories.select { |r| !r.fork }
      orgs_from_repos = repos.map(&:full_name).map { |full_name| full_name.split('/')[0] }.flatten.uniq.sort

      p (orgs_from_teams.concat(orgs_from_repos).uniq.sort)
    end
  end

  def execute(org, bot_name, permission, mode=DRY_RUN)
    # GitHubClient.config_github_enterprise('http://mygithub-enterprise-hostname/api/v3/')
    c = GitHubClient.new(ENV['GH_ENT_ACCESS_TOKEN'])
    c.login

    puts "Analyzing organization <#{org}> for <#{bot_name}>"

    org_members = c.auto_paginate { c.organization_members(org).map(&:login) }
    if org_members.include?(bot_name)
      case mode
      when DRY_RUN
        puts "Would remove #{bot_name} from as a member of #{org}"
      when FOR_REAL
        puts "Removing #{bot_name} from as a member of #{org}"
        c.remove_org_member(org, bot_name)
      end
    end

    c.auto_paginate do
      repos = c.organization_repositories(org, {type: 'all'})
      repos.map(&:name).each do |repo_name|
        bot_collaborator = c.collaborators("#{org}/#{repo_name}").
          map { |h| {login: h[:login], permissions: h[:permissions]} }.
          detect { |h| h[:login] == bot_name }

        if bot_collaborator
          current_perm = resolve_permission(bot_collaborator[:permissions])
          action_description = "Change collaborator access from #{current_perm} to #{permission}"
        else
          action_description = "Add collaborator with #{permission} access"
        end

        print "#{org}/#{repo_name}: "

        case mode
        when DRY_RUN
          puts "Would #{action_description.downcase}"
        when FOR_REAL
          puts action_description
          c.add_collaborator("#{org}/#{repo_name}", bot_name, {permission: permission})
        end
      end
    end
  end

  def resolve_permission(permissions_hash)
    # these escalate, so you really only have one, even though the hash returned has all three listed separately
    [:admin, :push, :pull].each { |perm| return perm.to_s if permissions_hash[perm] }
    'unknown'
  end
end


bot_orgs = [] # list of organizations to manage bot account for

bot_orgs.each do |org|
  begin
    BotWrangler.new.execute(org, 'mybotname', 'pull', BotWrangler::DRY_RUN)
    # BotWrangler.new.execute(org, 'mybotname', 'pull', BotWrangler::FOR_REAL)
  rescue => e
    puts "#{org}: #{e.message}"
  end
end
