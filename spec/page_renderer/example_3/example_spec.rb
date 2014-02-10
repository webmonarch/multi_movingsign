require 'spec_helper'
require 'yaml'
require 'json'

describe "PageRenderer - Example 3" do
  [1, 3].each do |screens|
    describe "#{screens} screen(s)" do
      it "Renders as Expected" do
        page = YAML.load(File.read(File.join(File.dirname(__FILE__), 'page.yml')))

        expected = nil
        if File.exists?(path = File.join(File.dirname(__FILE__), "#{screens}.yml"))
          expected = YAML.load(File.read(path))
        else
          expected = JSON.load(File.read(File.join(File.dirname(__FILE__), "#{screens}.json")))
        end

        expect(MultiMovingsign::PageRenderer.new.render(page, :count => screens)).to eq(expected)
      end
    end
  end
end