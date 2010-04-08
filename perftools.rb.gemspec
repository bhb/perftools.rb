spec = Gem::Specification.new do |s|
  s.name = 'perftools.rb'
  s.version = '0.3.9'
  s.date = '2009-11-11'
  s.rubyforge_project = 'perftools-rb'
  s.summary = 'google-perftools for ruby code'
  s.description = 'A sampling profiler for ruby code based on patches to google-perftools'

  s.homepage = "http://github.com/tmm1/perftools.rb"

  s.authors = ["Aman Gupta"]
  s.email = "perftools@tmm1.net"

  s.has_rdoc = false
  s.extensions = 'ext/extconf.rb'
  s.bindir = 'bin'
  s.executables << 'pprof.rb'

  s.add_dependency('rack', '>= 1.1.0')
  s.add_dependency('ruby_core_source', '>= 0.1.4')
  s.add_dependency('open4', '>= 1.0.1')

  s.add_development_dependency('rspec', '>= 1.3.0')

  # ruby -rpp -e' pp `git ls-files | grep -v examples`.split("\n").sort '
  s.files = [
    "README",
    "Rakefile",
    "bin/pprof.rb",
    "ext/extconf.rb",
    "ext/perftools.c",
    "ext/src/google-perftools-1.4.tar.gz",
    "lib/rack/perftools_profiler.rb",
    "lib/rack/perftools_profiler/action.rb",
    "lib/rack/perftools_profiler/call_app_directly.rb",
    "lib/rack/perftools_profiler/profile_data_action.rb",
    "lib/rack/perftools_profiler/profile_once.rb",
    "lib/rack/perftools_profiler/profiler.rb",
    "lib/rack/perftools_profiler/profiler_middleware.rb",
    "lib/rack/perftools_profiler/return_data.rb",
    "lib/rack/perftools_profiler/start_profiling.rb",
    "lib/rack/perftools_profiler/stop_profiling.rb",
    "patches/perftools-debug.patch",
    "patches/perftools-gc.patch",
    "patches/perftools-notests.patch",
    "patches/perftools-osx-106.patch",
    "patches/perftools-osx.patch",
    "patches/perftools-pprof.patch",
    "patches/perftools-realtime.patch",
    "patches/perftools.patch",
    "perftools.rb.gemspec",
    "spec/perftools_profiler_spec.rb",
    "spec/spec_helper.rb"
  ]
end
