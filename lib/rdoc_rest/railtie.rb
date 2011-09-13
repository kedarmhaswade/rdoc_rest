module RDocREST
  class Railtie < Rails::Railtie
    rake_tasks do
      require "rdoc_rest/rake"
    end
  end
end