require 'spec_helper'
require 'tempfile'

describe MultiMovingsign::Settings do
  let(:tempfile) { Tempfile.new(['spec_settings', '.yml']) }

  describe "Empty Settings File" do
    subject { described_class.load (tempfile.path) }

    it "#signs returns []" do
      expect(subject.signs.length).to eq 0
    end

    it "#signs? returns false" do
      expect(subject.signs?).to be_false
    end
  end

  describe "Example Settings File - 1" do
    subject { described_class.load(File.join(File.dirname(__FILE__), 'settings_1.yml'))}

    it "#signs? returns true" do
      expect(subject.signs?).to be_true
    end

    it "#signs.length == 1" do
      expect(subject.signs.length).to eq 1
    end

    it "#signs contains path '/dev/ttyUSB0'" do
      paths = subject.signs.map { |s| s.path }
      expect(paths.include?('/dev/ttyUSB0')).to be_true
    end

  end
end