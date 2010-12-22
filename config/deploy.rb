set :application, "readability_service"


# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location

# additional settings
default_run_options[:pty] = true  # Forgo errors when deploying from windows
set :use_sudo, false
# GitHub settings #######################################################################################
set :repository,  "git@github.com:7republic/whatpop.git"
set :scm, "git"
set :branch, "master"
set :scm_verbose, true
set :ssh_options, { :forward_agent => true }

 
# Don't change this stuff, but you may want to set shared files at the end of the file ##################
# deploy config
# via the :deploy_to variable:
set :deploy_to, "/var/www/whatpop.com"
#set :deploy_via, :remote_cache
set :deploy_via, :remote_cache
# If you aren't using Subversion to manage your source code, specify

set :rails_env, 'production'
role :app, "whatpop.com"
role :web, "whatpop.com"
role :db,  "whatpop.com", :primary => true

namespace :mod_rails do
  desc "Restart the application altering tmp/restart.txt for mod_rails."
  task :restart, :roles => :app do
    run "touch  #{current_path}/tmp/restart.txt"
  end
end

namespace :deploy do
  %w(start restart).each { |name| task name, :roles => :app do mod_rails.restart end }
  
  [:stop, :finalize_update, :cold].each do |t|
    desc "#{t} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end
  
  desc "Run the migrate rake task."
  task :migrate, :roles => :db, :only => { :primary => true } do
    rake = fetch(:rake, "rake")
    rails_env = fetch(:stage, "production")
    migrate_env = fetch(:migrate_env, "")
    migrate_target = fetch(:migrate_target, :latest)

    directory = case migrate_target.to_sym
      when :current then current_path
      when :latest  then current_release
      else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
      end

    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:migrate"
  end
end

before "deploy:update_code" do
  run_locally "git push origin master"
#  run "RAILS_ENV=#{rails_env} #{current_path}/script/daemons stop"
end
#for use with shared files (e.g. config files)
after "deploy:update_code" do
  run "ln -s #{shared_path}/database.yml #{release_path}/config/database.yml"
  run "ln -s #{shared_path}/system/assets #{release_path}/public/assets"
  run "rm -Rf #{release_path}/log && ln -s #{shared_path}/log #{release_path}/log"
  run "rm -Rf #{release_path}/tmp && ln -s #{shared_path}/tmp #{release_path}/tmp"
#  run "RAILS_ENV=#{rails_env} #{release_path}/script/daemons start"
end

#after "deploy:setup" do
#  run "mkdir -p #{shared_path}/tmp #{shared_path}/system/assets"
#end