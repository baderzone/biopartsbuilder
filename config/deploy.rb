require "bundler/capistrano"

#set :bundle_flags, "--deployment --quiet --binstubs --shebang ruby-local-exec"
#set (:bundle_cmd) { "/home/deployer/.rbenv/shims/bundle" }
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
role :web, "54.235.254.95"                          # Your HTTP server, Apache/etc
role :app, "54.235.254.95"                          # This may be the same as your `Web` server
role :db,  "54.235.254.95", :primary => true        # This is where Rails migrations will run

set :user, "deployer"
set :use_sudo, false
ssh_options[:keys] = [File.join(ENV["HOME"], ".ec2", "deployer")]
set :deploy_to, "/home/deployer/applications/#{application}"

set :rails_env, :production

#unicorn setup
set :unicorn_binary, "/home/deployer/.rbenv/shims/unicorn_rails"
set :unicorn_config, "#{current_path}/config/unicorn.rb"
set :unicorn_pid, "#{shared_path}/pids/unicorn.pid" 

def run_remote_rake(rake_cmd)
  rake_args = ENV['RAKE_ARGS'].to_s.split(',')
  cmd = "cd #{current_path} && #{fetch(:rake, "rake")} RAILS_ENV=#{fetch(:rails_env, "production")} #{rake_cmd}"
  cmd += "['#{rake_args.join("','")}']" unless rake_args.empty?
  run cmd
  set :rakefile, nil if exists?(:rakefile)
end

namespace :deploy do
  #start task
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && #{try_sudo} #{unicorn_binary} -c #{unicorn_config} -E #{rails_env} -D"
  end

  #stop task
  task :stop, :roles => :app, :except => { :no_release => true } do
    run "if ps aux | awk '{print $2 }' | grep `cat #{unicorn_pid}` > /dev/null; then kill `cat #{unicorn_pid}`; else echo 'Unicorn was already shutdown'; fi"
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
         ln -s #{shared_path}/tasks/resque.rake lib/tasks/resque.rake"
  end

  task :pipeline_precompile do
    run "cd #{current_path}; RAILS_ENV=production rake assets:precompile"
  end

  #restart resque workers
  task :restart_workers, :roles => :db do
    run_remote_rake "resque:restart_workers"
  end

end

after "deploy:create_symlink", "deploy:config_symlink"
after "deploy:create_symlink", "deploy:pipeline_precompile"
after "deploy:create_symlink", "deploy:restart_workers"

# remove old releases
after "deploy", "deploy:cleanup"
