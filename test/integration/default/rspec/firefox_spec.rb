require 'rspec_helper'

describe 'Firefox Grid' do
  before(:all) do
    @selenium = Selenium::WebDriver.for(:remote, desired_capabilities: :firefox)
  end

  after(:all) do
    @selenium.quit
  end

  res = if MACOSX
          '1024 x 768'
        elsif WINDOWS
          '1440 x 900'
        else
          '1280 x 1024'
        end

  it "Should return display resolution of #{res}" do
    @selenium.get 'http://www.whatismyscreenresolution.com/'
    element = @selenium.find_element(:id, 'resolutionNumber')
    expect(element.text).to eq(res)
  end
end
