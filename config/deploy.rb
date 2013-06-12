require "bundler/capistrano"
require 'sidekiq/capistrano'
require 'puma/capistrano'

set :default_environment, {
  'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
}

#application info
set :application, "partsBuilder"

default_run_options[:pty] = true 
ssh_options[:forward_agent] = true

#repository information
set :repository, "https://jhudeployer@bitbucket.org/giapeto/partsbuilder.git"
set :scm, :git
set :scm_username, "jhudeployer"

#deploy information
role :web, "54.235.171.60"                          # Your HTTP server, Apache/etc
role :app, "54.235.171.60"                          # This may be the same as your `Web` server
role :db,  "54.235.171.60", :primary => true        # This is where Rails migrations will run

set :user, "deployer"
set :use_sudo, false
ssh_options[:keys] = [File.join(ENV["HOME"], ".ec2", "deployer")]
set :deploy_to, "/home/deployer/applications/#{application}"

set :rails_env, :production

namespace :deploy do

  #linking data directory
  task :config_symlink do
    run "cd #{current_path}; 
         ln -s #{shared_path}/config/database.yml config/database.yml; 
         ln -s #{shared_path}/config/partsbuilder.yml config/partsbuilder.yml"
  end

  task :pipeline_precompile do
    run "cd #{current_path}; RAILS_ENV=production bundle exec rake assets:precompile"
  end

end

after "deploy:create_symlink", "deploy:config_symlink"
after "deploy:create_symlink", "deploy:pipeline_precompile"

# remove old releases
after "deploy", "deploy:cleanup"
