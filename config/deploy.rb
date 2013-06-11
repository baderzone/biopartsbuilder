require "bundler/capistrano"
require 'sidekiq/capistrano'

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

#puma setup
set :puma_binary, "puma"
set :puma_config, "#{current_path}/config/puma.rb"

namespace :deploy do
  #start task
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path}; bundle exec #{puma_binary} -C #{puma_config}"
  end

  #stop task
  task :stop, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path}; bundle exec pumactl -S #{shared_path}/pids/puma.state stop"
  end

  #restart task
  task :restart, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end


  #linking data directory
  task :config_symlink do
    run "cd #{current_path}; 
         ln -s #{shared_path}/config/database.yml config/database.yml; 
         ln -s #{shared_path}/config/partsbuilder.yml config/partsbuilder.yml"
  end

  task :pipeline_precompile, :roles => :web, :except => { :no_release => true} do
      from = source.next_revision(current_revision)
      if capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ app/assets/ | wc -l").to_i > 0
        run "cd #{current_path}; RAILS_ENV=production bundle exec rake assets:precompile"
        run "cp -rf #{current_path}/public/assets #{shared_path}"
      else
        run "ln -s #{shared_path}/assets #{current_path}/public/assets"
        logger.info "Skipping asset pre-compilation because there were no asset changes"
      end
    end

end

after "deploy:create_symlink", "deploy:config_symlink"
after "deploy:stop", "deploy:pipeline_precompile"

# remove old releases
after "deploy", "deploy:cleanup"
