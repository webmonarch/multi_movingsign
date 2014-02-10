require 'yaml'

# Helper that reads a test YAML file and loads/executes the appropriate scripts
# {file:spec/noop_movingsign_sign.yml}
class TestRCLoader
  def self.load(testrc_path)
    base_dir = File.expand_path(File.dirname testrc_path)
    testrc_hash = YAML::load(File.read(testrc_path))

    script_path = testrc_hash['script']
    script_path = File.join(base_dir, script_path) if Pathname.new(script_path).relative?

    parameters = testrc_hash['parameters'] || {}

    Kernel.eval(File.read(script_path), binding, script_path)
  end
end