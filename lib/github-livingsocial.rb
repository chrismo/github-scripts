require_relative 'collaborators'
require_relative 'members'

Members.new(ARGV[0] != 'IRL', 'livingsocial', 'github_members.yaml').sync_members
Collaborators.new(ARGV[0] != 'IRL', 'livingsocial', 'github_contributors.yaml').sync_collaborators
