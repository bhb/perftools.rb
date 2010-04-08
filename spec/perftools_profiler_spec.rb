require File.join(File.dirname(__FILE__), 'spec_helper')

ITERATIONS = case RUBY_VERSION
             when /1\.9\.1/ 
               350_000   # Ruby 1.9.1 is that we need to add extra iterations to get profiling data
             else 
               30_000
             end

# From the Rack spec (http://rack.rubyforge.org/doc/files/SPEC.html) :
# The Body must respond to each and must only yield String values. The Body should not be an instance of String.
# ... The Body commonly is an Array of Strings, the application instance itself, or a File-like object. 

class RackResponseBody
  include Spec::Matchers

  def initialize(body)
    body.should_not be_instance_of(String)
    @body = body
  end

  def to_s
    str = ""
    @body.each do |part|
      str << part
    end
    str
  end

end

class TestApp

  def call(env)
    case env['PATH_INFO']
    when /method1/
      ITERATIONS.times do
        self.class.new.method1
      end
    when /method2/
      ITERATIONS.times do 
        self.class.new.method2
      end
    end
    [200, {}, ['Done']]
  end

  def method1
    100.times do 
      1+2+3+4+5
    end
  end

  def method2
    100.times do
      1+2+3+4+5
    end
  end

end

include Rack::PerftoolsProfiler

context "testing Rack::PerftoolsProfiler" do

  before do
    @app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['Oh hai der']] }
    @slow_app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['slow app']] }
    @start_env = Rack::MockRequest.env_for('/__start__')
    @stop_env = Rack::MockRequest.env_for('/__stop__')
    @data_env = Rack::MockRequest.env_for('/__data__')
    @root_request_env = Rack::MockRequest.env_for("/")    
    @profiled_request_env = Rack::MockRequest.env_for("/", :params => "profile=true")
    @profiled_request_env_with_times = Rack::MockRequest.env_for("/", :params => "profile=true&times=2")
  end

  context 'Rack::Lint checks' do

    specify 'passes all Lint checks with text printer' do
      app = Rack::Lint.new(Rack::PerftoolsProfiler.with_profiling_off(@slow_app, :default_printer => 'text'))
      app.call(@root_request_env)
      app.call(@profiled_request_env)
      app.call(@profiled_request_env_with_times)
      app.call(@start_env)
      app.call(@stop_env)
      app.call(@data_env)
    end

    specify 'passes all Lint checks with text printer' do
      app = Rack::Lint.new(Rack::PerftoolsProfiler.with_profiling_off(@slow_app, :default_printer => 'gif'))
      app.call(@root_request_env)
      app.call(@profiled_request_env)
      app.call(@profiled_request_env_with_times)
      app.call(@start_env)
      app.call(@stop_env)
      app.call(@data_env)
    end

  end

  specify 'raises error if options contains invalid key' do
    lambda {
      Rack::PerftoolsProfiler.with_profiling_off(@app, :mode => 'walltime', :default_printer => 'gif', :foobar => 'baz')
    }.should raise_error ProfilerArgumentError, /Invalid option\(s\)\: foobar/
  end
  
  specify 'raises error if printer is invalid' do
    lambda {
      Rack::PerftoolsProfiler.with_profiling_off(@app, :mode => 'walltime', :default_printer => 'badprinter')
    }.should raise_error ProfilerArgumentError, /Invalid printer type\: badprinter/
  end
  
  specify 'options hash not modified' do
    options = {:mode => 'walltime', :default_printer => 'gif'}
    old_options = options.clone
    Rack::PerftoolsProfiler.with_profiling_off(@app, options)
    options.should == old_options
  end

  context 'without profiling' do

    specify 'calls app directly' do
      status, headers, body = Rack::PerftoolsProfiler.with_profiling_off(@app).call(@root_request_env)
      status.should == 200
      headers['Content-Type'].should == 'text/plain'
      RackResponseBody.new(body).to_s.should == 'Oh hai der'
    end
    
    specify '__data__ provides no data by default' do
      Rack::PerftoolsProfiler.clear_data
      status, headers, body = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text').call(@data_env)
      status.should == 404
      headers['Content-Type'].should == 'text/plain'
      RackResponseBody.new(body).to_s.should =~ /No profiling data available./
    end

  end

  context 'simple profiling mode' do
    
    specify 'printer defaults to text' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app).call(@profiled_request_env)
      headers['Content-Type'].should == "text/plain"
    end

    specify "setting mode to 'walltime' sets CPUPROFILE_REALTIME to 1" do
      realtime = ENV['CPUPROFILE_REALTIME']
      realtime.should == nil
      app = lambda do |env|
        realtime = ENV['CPUPROFILE_REALTIME']
        [200, {}, ["hi"]]
      end
      Rack::PerftoolsProfiler.new(app, :mode => 'walltime').call(@profiled_request_env)
      realtime.should == '1'
    end

    specify 'setting frequency will alter CPUPROFILE_FREQUENCY' do
      frequency = ENV['CPUPROFILE_FREQUENCY']
      frequency.should == nil
      app = lambda do |env|
        frequency = ENV['CPUPROFILE_FREQUENCY']
        [200, {}, ["hi"]]
      end
      Rack::PerftoolsProfiler.new(app, :frequency => 500).call(@profiled_request_env)
      frequency.should == '500'
    end

    specify 'text printer returns profiling data' do
      _, _, body = Rack::PerftoolsProfiler.new(@slow_app, :default_printer => 'text').call(@profiled_request_env)
      RackResponseBody.new(body).to_s.should =~ /Total: \d+ samples/
    end

    specify 'text printer has Content-Type text/plain' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'text').call(@profiled_request_env)
      headers['Content-Type'].should == "text/plain"
    end

    specify 'text printer has Content-Length' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@slow_app, :default_printer => 'text').call(@profiled_request_env)
      headers.fetch('Content-Length').to_i.should > 500
    end

    specify 'gif printer has Content-Type image/gif' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'gif').call(@profiled_request_env)
      headers['Content-Type'].should == "image/gif"
    end

    specify 'gif printer has Content-Length' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@slow_app, :default_printer => 'gif').call(@profiled_request_env)
      headers.fetch('Content-Length').to_i.should > 25_000
    end

    specify 'pdf printer has Content-Type application/pdf' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf').call(@profiled_request_env)
      headers['Content-Type'].should == "application/pdf"
    end

    specify 'pdf printer has default filename' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf').call(@profiled_request_env)
      headers['Content-Disposition'].should == %q{attachment; filename="profile_data.pdf"}
    end

    specify 'app can be called multiple times' do
      env = Rack::MockRequest.env_for('/', :params => 'profile=true&times=3')
      app = @app.clone
      app.should_receive(:call).exactly(3).times
      Rack::PerftoolsProfiler.new(app, :default_printer => 'text').call(env)
    end

    specify "'printer' param overrides :default_printer option'" do
      env = Rack::MockRequest.env_for('/', :params => 'profile=true&printer=gif')
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf').call(env)
      headers['Content-Type'].should == 'image/gif'
    end

    specify 'gives 400 if printer is invalid' do
      env = Rack::MockRequest.env_for('/', :params => 'profile=true&printer=badprinter')
      status, _, _ = Rack::PerftoolsProfiler.new(@app).call(env)
      status.should == 400
    end

    specify 'Rack environment is sent to underlying application (minus special profiling GET params)' do
      env = Rack::MockRequest.env_for('/', :params => 'profile=true&times=1&param=value&printer=gif&focus=foo&ignore=bar')
      old_env = env.clone
      expected_env = env.clone
      expected_env["QUERY_STRING"] = 'param=value'
      app = @app.clone
      app.should_receive(:call).with(expected_env)
      Rack::PerftoolsProfiler.new(app, :default_printer => 'gif').call(env)
      old_env.should == env
    end

    specify "'focus' param works" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      custom_env = Rack::MockRequest.env_for('/method1', :params => 'profile=true&focus=method1')
      status, headers, body = response = profiled_app.call(custom_env)
      RackResponseBody.new(body).to_s.should_not =~ /garbage/
    end

    specify "'ignore' param works" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      custom_env = Rack::MockRequest.env_for('/method1', :params => 'profile=true&ignore=method1')
      status, headers, body = response = profiled_app.call(custom_env)
      RackResponseBody.new(body).to_s.should =~ /garbage/
      RackResponseBody.new(body).to_s.should_not =~ /method1/
    end
    
  end

  context 'start/stop profiling' do

    specify "setting mode to 'walltime' sets CPUPROFILE_REALTIME to 1" do
      realtime = ENV['CPUPROFILE_REALTIME']
      realtime.should == nil
      app = lambda do |env|
        realtime = ENV['CPUPROFILE_REALTIME']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'walltime')
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      profiled_app.call(@stop_env)
      realtime.should == '1'
    end

    specify 'setting frequency alters CPUPROFILE_FREQUENCY' do
      frequency = ENV['CPUPROFILE_FREQUENCY']
      frequency.should == nil
      app = lambda do |env|
        frequency = ENV['CPUPROFILE_FREQUENCY']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app, :frequency => 250)
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      frequency.should == '250'
    end

    specify 'when profiling is on, __data__ does not provide profiling data' do
      Rack::PerftoolsProfiler.clear_data
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      status, _, body = profiled_app.call(@data_env)
      status.should == 400
      RackResponseBody.new(body).to_s.should =~ /No profiling data available./
    end

    specify 'when profiling is on, profiling params in environment are passed on' do
      env = Rack::MockRequest.env_for('/', :params => 'times=2')
      old_env = env.clone
      app = @app.clone
      expected_env = env.clone
      expected_env['rack.request.query_string'] = 'times=2'
      expected_env['rack.request.query_hash'] = {'times' => '2'}
      app.should_receive(:call).with(expected_env)
      profiled_app = Rack::PerftoolsProfiler.new(app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(env)
      old_env.should == env
    end

    specify 'when profiling is on, non-profiling params in environment are passed on' do
      env = Rack::MockRequest.env_for('/', :params => 'param=value')
      old_env = env.clone
      app = @app.clone
      expected_env = env.clone
      expected_env['rack.request.query_string'] = 'param=value'
      expected_env['rack.request.query_hash'] = {'param' => 'value'}
      app.should_receive(:call).with(expected_env)
      profiled_app = Rack::PerftoolsProfiler.new(app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(env)
      old_env.should == env
    end

    specify 'after profiling is finished, __data__ returns profiled data' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'gif')
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      profiled_app.call(@stop_env)
      status, headers, body = profiled_app.call(@data_env)
      status.should == 200
      headers['Content-Type'].should == "image/gif"
    end
    
    specify 'with profiling on, regular calls are unchanged' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'gif')
      profiled_app.call(@start_env)
      status, headers, body = response = profiled_app.call(@root_request_env)
      status.should == 200
      headers['Content-Type'].should == 'text/plain'
      RackResponseBody.new(body).to_s.should == 'Oh hai der'
    end

    specify 'keeps data from multiple calls' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      profiled_app.call(@start_env)
      profiled_app.call(Rack::MockRequest.env_for('/method1'))
      profiled_app.call(Rack::MockRequest.env_for('/method2'))
      profiled_app.call(@stop_env)
      status, headers, body = response = profiled_app.call(@data_env)
      RackResponseBody.new(body).to_s.should =~ /method1/
      RackResponseBody.new(body).to_s.should =~ /method2/
    end

    specify "'printer' param overrides :default_printer option'" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf')
      profiled_app.call(@start_env)
      profiled_app.call(@root_request_env)
      profiled_app.call(@stop_env)
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'printer=gif')
      _, headers, _ = profiled_app.call(custom_data_env)
      headers['Content-Type'].should == 'image/gif'
    end

    specify "'focus' param works" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      profiled_app.call(@start_env)
      profiled_app.call(Rack::MockRequest.env_for('/method1'))
      profiled_app.call(Rack::MockRequest.env_for('/method2'))
      profiled_app.call(@stop_env)
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'focus=method1')
      status, headers, body = response = profiled_app.call(custom_data_env)
      RackResponseBody.new(body).to_s.should_not =~ /method2/
    end

    specify "'ignore' param works" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      profiled_app.call(@start_env)
      profiled_app.call(Rack::MockRequest.env_for('/method1'))
      profiled_app.call(Rack::MockRequest.env_for('/method2'))
      profiled_app.call(@stop_env)
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'ignore=method1')
      status, headers, body = response = profiled_app.call(custom_data_env)
      RackResponseBody.new(body).to_s.should_not =~ /method1/
    end

  end
end

