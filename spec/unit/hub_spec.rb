require 'spec_helper'

describe 'selenium_test::hub' do
  let(:shellout) { double(run_command: nil, error!: nil, stdout: ' ') }

  before do
    allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
  end

  context 'windows' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'windows', version: '2008R2', step_into: ['selenium_hub']) do |node|
        ENV['SYSTEMDRIVE'] = 'C:'
        node.override['selenium']['url'] =
          'https://selenium-release.storage.googleapis.com/3.0/selenium-server-standalone-3.0.1.jar'
        node.override['java']['windows']['url'] = 'http://ignore/jdk-windows-64x.tar.gz'
        stub_command('netsh advfirewall firewall show rule name="selenium_hub" > nul').and_return(false)
      end.converge(described_recipe)
    end

    it 'installs selenium_hub server' do
      expect(chef_run).to install_selenium_hub('selenium_hub')
    end

    it 'creates hub config file' do
      expect(chef_run).to create_template('C:/selenium/config/selenium_hub.json').with(
        source: 'hub_config.erb',
        cookbook: 'selenium'
      )
    end

    it 'install selenium_hub' do
      expect(chef_run).to install_nssm('selenium_hub').with(
        program: 'C:\java\bin\java.exe',
        args: '-jar "C:/selenium/server/selenium-server-standalone.jar"'\
          ' -role hub -hubConfig "C:/selenium/config/selenium_hub.json"',
        parameters: {
          AppDirectory: 'C:/selenium',
        }
      )
    end

    it 'creates firewall rule' do
      expect(chef_run).to run_execute('Firewall rule selenium_hub for port 4444')
    end

    it 'reboots windows server' do
      expect(chef_run).to_not request_reboot('Reboot to start selenium_hub')
    end
  end

  context 'linux' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'centos', version: '7.3.1611', step_into: ['selenium_hub']) do |node|
        node.override['selenium']['url'] =
          'https://selenium-release.storage.googleapis.com/3.0/selenium-server-standalone-3.0.1.jar'
        allow_any_instance_of(Chef::Provider).to receive(:selenium_systype).and_return('systemd')
      end.converge(described_recipe)
    end

    it 'installs selenium_hub server' do
      expect(chef_run).to install_selenium_hub('selenium_hub')
    end

    it 'creates selenium user' do
      expect(chef_run).to create_user('ensure user selenium exits for selenium_hub').with(username: 'selenium')
    end

    it 'creates hub config file' do
      expect(chef_run).to create_template('/opt/selenium/config/selenium_hub.json').with(
        source: 'hub_config.erb',
        cookbook: 'selenium'
      )
    end

    it 'install selenium_hub' do
      expect(chef_run).to create_template('/etc/systemd/system/selenium_hub.service').with(
        source: 'systemd.erb',
        cookbook: 'selenium',
        mode: '0755',
        variables: {
          name: 'selenium_hub',
          user: 'selenium',
          exec: '/usr/bin/java',
          args: '-jar "/opt/selenium/server/selenium-server-standalone.jar" -role hub ' \
          '-hubConfig "/opt/selenium/config/selenium_hub.json"',
          port: 4444,
          xdisplay: nil,
        }
      )
    end

    it 'start selenium_hub' do
      expect(chef_run).to start_service('selenium_hub')
    end
  end

  context 'mac_os_x' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'mac_os_x', version: '10.10', step_into: ['selenium_hub']) do |node|
        node.override['selenium']['url'] =
          'https://selenium-release.storage.googleapis.com/3.0/selenium-server-standalone-3.0.1.jar'
        node.override['selenium']['hub']['log'] = '/var/log/selenium/org.seleniumhq.selenium_hub.log'
        allow_any_instance_of(Chef::Recipe).to receive(:java_version_on_macosx?).and_return(false)
      end.converge(described_recipe)
    end

    it 'installs selenium_hub server' do
      expect(chef_run).to install_selenium_hub('selenium_hub')
    end

    it 'creates hub config file' do
      expect(chef_run).to create_template('/opt/selenium/config/selenium_hub.json').with(
        source: 'hub_config.erb',
        cookbook: 'selenium'
      )
    end

    it 'creates log directory' do
      expect(chef_run).to create_directory('/var/log/selenium').with(user: nil)
    end

    it 'adds permissions to log file' do
      expect(chef_run).to touch_file('/var/log/selenium/org.seleniumhq.selenium_hub.log').with(user: nil, mode: '0664')
    end

    it 'install selenium_hub' do
      expect(chef_run).to create_template('/Library/LaunchDaemons/org.seleniumhq.selenium_hub.plist').with(
        source: 'org.seleniumhq.plist.erb',
        cookbook: 'selenium',
        mode: '0755',
        variables: {
          name: 'org.seleniumhq.selenium_hub',
          exec: '/usr/bin/java',
          args: ['-jar', '"/opt/selenium/server/selenium-server-standalone.jar"', '-role', 'hub',
                 '-hubConfig', '"/opt/selenium/config/selenium_hub.json"'],
        }
      )
    end

    it 'executes launchd reload' do
      expect(chef_run).to_not run_execute('reload org.seleniumhq.selenium_hub')
    end
  end
end
