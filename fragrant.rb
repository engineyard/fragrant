require 'grape'
require 'uuid'
require 'vagrant'

class Fragrant < Grape::API
  version 'v1', :using => :header, :vendor => 'nextgen'
  format :json

  ENV_REGEX = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/

  helpers do

    def box_name
      @box_name ||= 'nextgen64'
    end

    def box_url
      @box_url ||= 'http://shunterus.s3.amazonaws.com/nextgen64.box'
    end

    def env_dir
      @env_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'vboxes'))
    end

    def env_glob
      Dir.entries(env_dir).select do |d|
        next if d.start_with?('.')
        File.exists?(File.join(env_dir, d, 'Vagrantfile'))
      end
    end

    def env_rand
      UUID.generate
    end

    def v_action
      route.route_path.split(/[\/\(]/)[2]
    end

    def v_env(id = params[:id])
      Vagrant::Environment.new({ :cwd => File.join(env_dir, id) })
    end

  end

  resource :environments do

    desc "Destroys a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :vm_name, :desc => 'single vm to act on'
    end
    delete '/destroy/:id' do
      args = [v_action, params[:vm_name], '--force']
      v_env.cli(args.compact)
      params[:id]
    end

    desc "Lists Vagrant environments"
    get :list do
      env_glob
    end

    desc "Halts a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :force, :desc => 'Force shut down (equivalent of pulling power)'
      optional :vm_name, :desc => 'single vm to act on'
    end
    post '/halt/:id' do
      force = params[:force] == true ? '--force' : nil
      args = [v_action, params[:vm_name], force]
      v_env.cli(args.compact)
      params[:id]
    end

    desc "Initializes a Vagrant environment"
    params do
      optional :vagrantfile, :desc => "Vagrant environment configuration", :type => String
    end
    post :init do
      machine = env_rand
      machine_dir = File.join(env_dir, machine)
      begin
        Dir.mkdir(machine_dir, 0755)
      rescue Errno::EEXIST
        error!({ "error" => "#{machine_dir} already exists!" }, 409)
      end
      if params[:vagrantfile].nil?
        v_env(machine).cli(v_action, box_name, box_url)
      else
        File.open(File.join(machine_dir, 'Vagrantfile'), 'w') {|f| f.write(params[:vagrantfile])}
      end
      machine
    end

    desc "Provisions a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :vm_name, :desc => 'single vm to act on'
    end
    post '/provision/:id' do
      args = [v_action, params[:vm_name]]
      v_env.cli(args.compact)
      params[:id]
    end

    desc "Purges a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/purge/:id' do
      if v_env.vms.all? {|vm| vm.last.state == 'not_created'}
        machine_dir = File.join(env_dir, params[:id])
        FileUtils.remove_entry_secure(machine_dir)
      else
        error!({ "error" => "Environment contains undestroyed machines!" }, 409)
      end
      params[:id]
    end

    desc "Reloads a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :no_provision, :desc => 'disable provisioning'
      optional :vm_name, :desc => 'single vm to act on'
    end
    post '/reload/:id' do
      provision = params[:no_provision] == true ? '--no-provision' : '--provision'
      args = [v_action, params[:vm_name], provision]
      v_env.cli(args.compact)
      params[:id]
    end

    desc "Resumes a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :vm_name, :desc => 'single vm to act on'
    end
    post '/resume/:id' do
      args = [v_action, params[:vm_name]]
      v_env.cli(args.compact)
      params[:id]
    end

    desc "Prints the status of a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    get '/status/:id' do
      state = {}
      v_env.vms.each do |vm|
        state[vm.first] = vm.last.state
      end
      state
    end

    desc "Suspends a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :vm_name, :desc => 'single vm to act on'
    end
    post '/suspend/:id' do
      args = [v_action, params[:vm_name]]
      v_env.cli(args.compact)
      params[:id]
    end

    desc "Boots a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      optional :no_provision, :desc => 'disable provisioning'
      optional :vm_name, :desc => 'single vm to act on'
    end
    post '/up/:id' do
      provision = params[:no_provision] == true ? '--no-provision' : '--provision'
      args = [v_action, params[:vm_name], provision]
      v_env.cli(args.compact)
      params[:id]
    end

  end

  resource :vms do

    desc "Lists registered virtual machines"
    get :registered do
      out = %x{VBoxManage list vms}
      out.split('\n')
    end

    desc "Lists running virtual machines"
    get :running do
      out = %x{VBoxManage list runningvms}
      out.split('\n')
    end

  end

end
