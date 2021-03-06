require 'spec_helper'

describe 'chef_nginx::source' do
  shared_examples_for 'all platforms' do
    it 'creates nginx user' do
      expect(chef_run).to create_user('www-data').with(
        system: true,
        shell: '/bin/false',
        home: '/var/www'
      )
    end

    %w(
      ohai_plugin
      commons_dir
      commons_script
      commons_conf
    ).each do |recipe|
      it "includes the #{recipe} recipe" do
        expect(chef_run).to include_recipe("chef_nginx::#{recipe}")
      end
    end

    it 'includes build-essential recipe' do
      expect(chef_run).to include_recipe('build-essential::default')
    end

    it 'downloads nginx sources' do
      src_file = "#{Chef::Config['file_cache_path']}/nginx-#{@ngx_version}.tar.gz"
      expect(chef_run).to create_remote_file(src_file).with(
        backup: false
      )
    end

    it 'creates mime.types file' do
      expect(chef_run).to create_cookbook_file('/etc/nginx/mime.types')
    end

    it 'marks nginx to be reloaded when we change the mime.types file' do
      expect(chef_run.cookbook_file("#{chef_run.node['nginx']['dir']}/mime.types")).to notify('service[nginx]').to(:reload).delayed
    end

    it 'unarchives source' do
      expect(chef_run).to run_bash('unarchive_source')
    end

    it 'includes all the source modules recipes' do
      expect(chef_run).to include_recipe('chef_nginx::http_gzip_static_module')
      expect(chef_run).to include_recipe('chef_nginx::http_ssl_module')
    end

    it 'compiles nginx source' do
      expect(chef_run).to run_bash('compile_nginx_source')
    end

    it 'marks nginx to be reloaded when we compile nginx source' do
      expect(chef_run.bash('compile_nginx_source')).to notify('service[nginx]').to(:restart).delayed
    end

    it 'marks ohai nginx to be reloaded when we compile nginx source' do
      expect(chef_run.bash('compile_nginx_source')).to notify('ohai[reload_nginx]').to(:reload).immediately
    end

    it 'enables nginx service' do
      expect(chef_run).to enable_service('nginx')
    end
  end

  cached(:chef_run) do
    ChefSpec::ServerRunner.new(platform: 'debian', version: '7.10').converge(described_recipe)
  end

  before do
    stub_command('which nginx').and_return(nil)

    @ngx_version = chef_run.node['nginx']['source']['version']
  end

  it 'enables daemon mode in nginx' do
    expect(chef_run.node['nginx']['daemon_disable']).to be(false)
  end

  it 'creates init script' do
    expect(chef_run).to render_file('/etc/init.d/nginx')
  end

  it 'generates defaults configuration' do
    expect(chef_run).to render_file('/etc/default/nginx')
  end

  it 'installs packages dependencies' do
    expect(chef_run).to install_package(['libpcre3', 'libpcre3-dev', 'libssl-dev', 'tar'])
  end

  context 'On Debian 8' do
    cached(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'debian', version: '8.5').converge(described_recipe)
    end

    it 'creates systemd unit file' do
      expect(chef_run).to render_file('/lib/systemd/system/nginx.service')
    end

    it 'generates defaults configuration' do
      expect(chef_run).to render_file('/etc/default/nginx')
    end
  end

  context 'Freebsd familly' do
    cached(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'freebsd', version: '10.3').converge(described_recipe)
    end

    it 'does not create the init script' do
      expect(chef_run).to_not render_file('/etc/init.d/nginx')
    end

    it 'does not generate defaults configuration' do
      expect(chef_run).to_not render_file('/etc/default/nginx')
      expect(chef_run).to_not render_file('/etc/sysconfig/nginx')
    end
  end

  context 'On RHEL 6' do
    cached(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'centos', version: '6.8').converge(described_recipe)
    end

    it 'creates init script' do
      expect(chef_run).to render_file('/etc/init.d/nginx')
    end

    it 'generates defaults configuration' do
      expect(chef_run).to render_file('/etc/sysconfig/nginx')
    end
  end

  context 'On RHEL 7' do
    cached(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'centos', version: '7.2.1511').converge(described_recipe)
    end

    it 'creates systemd unit file' do
      expect(chef_run).to render_file('/lib/systemd/system/nginx.service')
    end

    it 'generates defaults configuration' do
      expect(chef_run).to render_file('/etc/sysconfig/nginx')
    end
  end

  context 'On openSUSE 13.2' do
    cached(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'opensuse', version: '13.2').converge(described_recipe)
    end

    it 'creates systemd unit file' do
      expect(chef_run).to render_file('/usr/lib/systemd/system/nginx.service')
    end

    it 'generates defaults configuration' do
      expect(chef_run).to render_file('/etc/sysconfig/nginx')
    end
  end

  context 'with Runit init system set' do
    cached(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'debian', version: '8.5') do |node|
        node.normal['nginx']['init_style'] = 'runit'
      end.converge(described_recipe)
    end

    it 'includes runit recipe' do
      expect(chef_run).to include_recipe('runit::default')
    end

    it 'defined runit_service' do
      expect(chef_run).to enable_runit_service('nginx')
    end
  end
end
