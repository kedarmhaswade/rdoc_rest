namespace :rest do
  desc "Generates routing info for URL discovery"
  task :generate => :environment do
    data = {}

    Rails.application.routes.routes.each do |route|
      next unless route.app.class.name.to_s =~ /^ActionDispatch::Routing/
      reqs = route.requirements
      data["app/controllers/#{reqs[:controller]}_controller.rb/#{reqs[:action]}"] = {:path => route.path, :type => route.verb.to_s}
    end

    file = File.open(File.join(Rails.root, "tmp", "routes.txt"), "w+")
    file.write(data.to_yaml)
    file.close
  end
end