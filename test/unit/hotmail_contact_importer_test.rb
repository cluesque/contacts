dir = File.dirname(__FILE__)
require "#{dir}/../test_helper"
require 'contacts'
require 'mocha'

class HotmailContactImporterTest < ContactImporterTestCase
  def setup
    super
    @account = TestAccounts[:hotmail]
  end

  def test_successful_login
    Contacts.new(:hotmail, @account.username, @account.password)
  end

  def test_importer_fails_with_invalid_password
    assert_raise(Contacts::AuthenticationError) do
      Contacts.new(:hotmail, @account.username,"wrong_password")
    end
  end

  def test_fetch_contacts
    contacts = Contacts.new(:hotmail, @account.username, @account.password).contacts
    @account.contacts.each do |contact|
      assert contacts.include?(contact), "Could not find: #{contact.inspect} in #{contacts.inspect}"
    end
  end

  def test_importer_fails_with_invalid_msn_password
    assert_raise(Contacts::AuthenticationError) do
      Contacts.new(:hotmail, "test@msn.com","wrong_password")
    end
  end

  # Since the hotmail scraper doesn't read names, test email
  def test_fetch_email
    contacts = Contacts.new(:hotmail, @account.username, @account.password).contacts
    @account.contacts.each do |contact|
      assert contacts.any?{|book_contact| book_contact.last == contact.last }, "Could not find: #{contact.inspect} in #{contacts.inspect}"
    end
  end

  def test_parsing
    Contacts::Hotmail.any_instance.stubs(:connected?).returns true
    Contacts::Hotmail.any_instance.stubs(:real_connect).returns true
    output = File.read(File.join File.dirname(__FILE__), '..', 'fixtures', 'hotmail.html')
    Net::HTTP.any_instance.stubs(:get).returns [Net::HTTPOK.new(nil,nil,nil), output]

    contacts = Contacts.new(:hotmail, 'user', 'pass').contacts
    assert_equal contacts.size, 2
    assert contacts.flatten.include?('Test Mouse')
    assert contacts.flatten.include?('mouse@example.com')
  end
end
