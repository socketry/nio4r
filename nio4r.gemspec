# frozen_string_literal: true

require_relative "lib/nio/version"

Gem::Specification.new do |spec|
  spec.name = "nio4r"
  spec.version = NIO::VERSION

  spec.summary = "New IO for Ruby"
  spec.authors = ["Tony Arcieri", "Samuel Williams", "Olle Jonsson", "Gregory Longtin", "Tiago Cardoso", "Joao Fernandes", "Thomas Dziedzic", "Boaz Segev", "Logan Bowers", "Pedro Paiva", "Jun Aruga", "Omer Katz", "Upekshe Jayasekera", "Tim Carey-Smith", "Benoit Daloze", "Sergey Avseyev", "Tomoya Ishida", "Usaku Nakamura", "Cédric Boutillier", "Daniel Berger", "Dirkjan Bussink", "Hiroshi Shibata", "Jesús Burgos Maciá", "Luis Lavena", "Pavel Rosický", "Sadayuki Furuhashi", "Stephen von Takach", "Vladimir Kochnev", "Vít Ondruch", "Anatol Pomozov", "Bernd Ahlers", "Charles Oliver Nutter", "Denis Washington", "Elad Eyal", "Jean byroot Boussier", "Jeffrey Martin", "John Thornton", "Jun Jiang", "Lars Kanis", "Marek Kowalcze", "Maxime Demolin", "Orien Madgwick", "Pavel Lobashov", "Per Lundberg", "Phillip Aldridge", "Ravil Bayramgalin", "Shannon Skipper", "Tao Luo", "Thomas Kuntz", "Tsimnuj Hawj", "Zhang Kang"]
  spec.licenses = ["MIT", "BSD-2-Clause"]

  unless defined? JRUBY_VERSION
    spec.cert_chain  = ['release.cert']
    spec.signing_key = File.expand_path('~/.gem/release.pem')
  end

  spec.homepage = "https://github.com/socketry/nio4r"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/socketry/nio4r/issues",
    "changelog_uri" => "https://github.com/socketry/nio4r/blob/main/changes.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/nio4r",
    "funding_uri" => "https://github.com/sponsors/ioquatix/",
    "source_code_uri" => "https://github.com/socketry/nio4r.git",
    "wiki_uri" => "https://github.com/socketry/nio4r/wiki",
  }

  spec.files = Dir.glob(['{ext,lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
  spec.require_paths = ['lib']

  spec.extensions = ["ext/nio4r/extconf.rb"]

  spec.required_ruby_version = ">= 2.4"

  if defined? JRUBY_VERSION
    spec.files << "lib/nio4r_ext.jar"
    spec.platform = "java"
  else
    spec.extensions = ["ext/nio4r/extconf.rb"]
  end
end
