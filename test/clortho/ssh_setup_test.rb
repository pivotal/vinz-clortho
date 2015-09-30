require 'yaml'
require 'minitest/autorun'
require 'mocha/mini_test'
require_relative '../../lib/clortho/ssh_setup'


module Clortho
  class SSHSetupTest < Minitest::Test

    def setup
      initial_committers = {"authors" => {"hp" => "Harry Potter", "hg" => "Hermione Granger"},
                            "emails" => {"hp" => "hpotter@pivotal.io", "hg" => "hgranger@pivotal.io"},
                            "sshkey_paths" =>
                                {"hp" => "/Volumes/hpotter/.ssh/id_rsa",
                                 "hg" => "/Volumes/hgranger/.ssh/id_rsa"}}
      File.expects(:exist?).with(File.join(Dir.pwd, '.git-authors')).returns true
      YAML.expects(:load_file).with(File.join(Dir.pwd, '.git-authors')).returns initial_committers
      SSHSetup.any_instance.stubs(:ssh_add)
      File.stubs(:exist?).with("/Volumes/hpotter/.ssh/id_rsa").returns(true)
    end

    def test_login_calls_ssh_add
      ssh_setup = SSHSetup.new
      Time.stubs(:now).returns Time.new(2015, 9, 28, 6, 0)
      expected_ttl = 23400
      ssh_setup.expects(:ssh_add).with expected_ttl, "/Volumes/hpotter/.ssh/id_rsa"
      ssh_setup.login("hp")
    end

    def test_login_sets_key_expiry_to_lunchtime_during_morning
      expected_expiration = Time.new(2015, 9, 28, 12, 30)
      ssh_setup = login_at Time.new(2015, 9, 28, 6, 0)
      assert_equal expected_expiration, ssh_setup.key_expiry
    end

    def test_login_sets_key_expiry_to_6pm_during_afternoon
      expected_expiration = Time.new(2015, 9, 28, 18, 0)
      ssh_setup = login_at(Time.new(2015, 9, 28, 13, 0))

      assert_equal expected_expiration, ssh_setup.key_expiry
    end

    def test_instant_login_calls_ssh_add_with_1sec_ttl
      ssh_setup = SSHSetup.new
      File.expects(:exist?).with("/Volumes/hpotter/.ssh/id_rsa").returns false
      File.expects(:exist?).with("/Volumes/hgranger/.ssh/id_rsa").returns true
      ssh_setup.expects(:ssh_add).with 1, "/Volumes/hgranger/.ssh/id_rsa"
      ssh_setup.instant_login
    end

    def test_instant_login_does_not_call_ssh_add_if_no_key_exists
      ssh_setup = SSHSetup.new
      File.expects(:exist?).with("/Volumes/hpotter/.ssh/id_rsa").returns false
      File.expects(:exist?).with("/Volumes/hgranger/.ssh/id_rsa").returns false
      ssh_setup.expects(:ssh_add).never
      ssh_setup.instant_login
    end

    def test_login_sets_key_expiry_to_within_15_minutes_as_default
      expected_expiration = Time.new(2015, 9, 28, 18, 15)
      ssh_setup = login_at(Time.new(2015, 9, 28, 18, 0))

      assert_equal expected_expiration, ssh_setup.key_expiry
    end

    def test_login_throws_exception_when_unable_to_find_key_file
      File.expects(:exist?).with("/Volumes/hpotter/.ssh/id_rsa").returns(false)
      ssh_setup = SSHSetup.new
      error = assert_raises(Errno::ENOENT) {
        ssh_setup.login("hp")
      }
      # assert_match /Unable to find committer initials in mapping/, error.message
    end

    private

    def login_at(time)
      SSHSetup.new.tap do |ssh_setup|
        Time.stubs(:now).returns(time)
        ssh_setup.login("hp")
      end
    end
  end
end