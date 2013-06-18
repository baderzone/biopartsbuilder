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
role :web, "10.0.1.20"                          # Your HTTP server, Apache/etc
role :app, "10.0.1.20"                          # This may be the same as your `Web` server
role :db,  "10.0.1.20", :primary => true        # This is where Rails migrations will run

set :user, "deployer"
set :use_sudo, false
ssh_options[:keys] = [File.join(ENV["HOME"], "credentials", "baderlabvpc", "id_baderlabvpc_deployer")]
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
    run "cd #{current_path}; bundle exec pumactl -S #{current_path}/tmp/pids/puma.state stop"
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
         ln -s #{shared_path}/config/partsbuilder.yml config/partsbuilder.yml;
         ln -s #{shared_path}/partsBuilder_processing/parts public/parts; 
         ln -s #{shared_path}/partsBuilder_processing/designs public/designs; 
         ln -s #{shared_path}/partsBuilder_processing/orders public/orders; 
         ln -s #{shared_path}/partsBuilder_processing/uploads public/uploads;" 
  end

  task :pipeline_precompile do
    run "cd #{current_path}; RAILS_ENV=production bundle exec rake assets:precompile"
  end

end

after "deploy:create_symlink", "deploy:config_symlink"
after "deploy:create_symlink", "deploy:pipeline_precompile"

# remove old releases
after "deploy", "deploy:cleanup"
