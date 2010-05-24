# desc "Explaining what the task does"
# task :jpmobile do
#   # Task goes here
# end

begin
  require 'spec'
  require 'spec/rake/spectask'
  namespace :spec do
    desc 'run unit testing (core test)'
    Spec::Rake::SpecTask.new(:unit) do |t|
      spec_dir = File.join(File.dirname(__FILE__), '..', 'spec')
      t.spec_opts = File.read(File.join(spec_dir, 'spec.opts')).split
      t.spec_files = FileList[File.join(spec_dir, 'unit', '**', '*_spec.rb')]
    end
  end
rescue LoadError
  warn "RSpec is not installed. Some tasks were skipped. please install rspec"
end

namespace :test do
  desc "Generate rails app and run jpmobile tests in the app"
  task :rails, [:versions] do |t, args|
    rails_versions = args.versions.split("/") rescue ["2.3.6"]
    rails_versions.each do |rails_version|
      Rake::Task["test:prepare"].invoke(rails_version)
      Rake::Task["test:spec"].invoke(rails_version)
    end
  end

  desc "Generate rails app"
  task :prepare, [:rails_version] do |t, args|
    rails_version = args.rails_version || "2.3.6"
    rails_root    = "test/rails/rails_root"
    relative_root = "../../../"

    puts "Building Rails application in #{rails_version}"
    # generate rails app
    FileUtils.rm_rf(rails_root)
    FileUtils.mkdir_p(rails_root)
    system "rails _#{rails_version}_ --force #{rails_root}"

    # setup jpmobile-mail
    plugin_path = File.join(rails_root, 'vendor', 'plugins', 'jpmobile-mail')
    FileUtils.mkdir_p(plugin_path)
    FileList["*"].exclude("test").each do |file|
      FileUtils.cp_r(file, plugin_path)
    end

    # setup tests
    FileList["test/rails/overrides/*"].each do |file|
      FileUtils.cp_r(file, rails_root)
    end

    # for 2.3.2
    if rails_version == "2.3.2"
      FileList["test/rails/2.3.2/*"].each do |file|
        FileUtils.cp_r(file, rails_root)
      end
    end
    # for cookie_only option
    config_path = File.join(rails_root, 'config', 'environment.rb')
    File.open(config_path, 'a') do |file|
      file.write <<-END

ActionController::Base.session = {
  :secret      => "1234567890",
  :key         => "_session_id",
  :cookie_only => false
}
END
    end
  end

  desc "Run jpmobile tests in the app"
  task :spec, [:versions] do |t, args|
    rails_version = args.rails_version || "2.3.5"
    rails_root    = "test/rails/rails_root"
    relative_root = "../../../"

    puts "Run spec in #{rails_version}"
    puts pwd

    cd rails_root
    sh 'ruby script/plugin install git://github.com/darashi/jpmobile.git'
    sh "rake db:migrate"
    sh "rake spec"

    cd relative_root
  end
end
