require_relative "lib/telex/version"

Gem::Specification.new do |spec|
  spec.name        = "telex"
  spec.version     = Telex::VERSION
  spec.authors     = [ "B.O.X" ]
  spec.homepage    = "https://github.com/boxprod/telex"
  spec.summary     = "Email for our Rails apps through Lettermint."
  spec.description = "Action Mailer sends through Lettermint's SMTP relay; Action Mailbox receives from Lettermint's inbound webhooks."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3"

  # Private: installed from GitHub, never pushed to RubyGems.
  spec.metadata["allowed_push_host"] = "https://rubygems.invalid"
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0"
end
