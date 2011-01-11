Feature: Hooks

  VCR provides two global hooks that you can use to customize recording and
  playback:

    - `before_record`: Called before a cassette is written to disk.
    - `before_playback`: Called before a cassette sets up its stubs for playback.

  To use these, call `config.before_record` or `config.before_playback` in
  your `VCR.config` block.  Provide a block that accepts 0, 1 or 2 arguments.
  The first argument, if the block accepts it, will be an array of HTTP
  interactions.  You can modify any of them and/or remove them from the array
  to prevent them from being recorded or played back.  The second argument,
  if the block accepts it, will be the `VCR::Cassette` instance.  This may be
  useful for hooks that you want to behave differently for different cassettes.

  You can also use tagging to apply hooks to particular cassettes.  Consider
  this code:

      VCR.config do |c|
        c.before_record(:twitter) { ... } # modify the interactions somehow
      end

      VCR.use_cassette('cassette_1', :tag => :twitter) { ... }
      VCR.use_cassette('cassette_2') { ... }

  In this example, the hook would apply to the first cassette but not the
  second cassette.

  You can setup as many hooks as you like; each will be invoked at the
  appropriate time.

  Background:
    Given a previously recorded cassette file "cassettes/example.yml" with:
      """
      ---
      - !ruby/struct:VCR::HTTPInteraction
        request: !ruby/struct:VCR::Request
          method: :get
          uri: http://example.com:80/foo
          body:
          headers:
        response: !ruby/struct:VCR::Response
          status: !ruby/struct:VCR::ResponseStatus
            code: 200
            message: OK
          headers:
            content-type:
            - text/html;charset=utf-8
            content-length:
            - "20"
          body: example.com response
          http_version: "1.1"
      """

  Scenario: Replace sensitive data with before_record hook
    Given a file named "before_record_example.rb" with:
      """
      require 'vcr_cucumber_helpers'

      start_sinatra_app(:port => 7777) do
        get('/') { "Hello <secret>" }
      end

      require 'vcr'

      VCR.config do |c|
        c.stub_with :fakeweb
        c.cassette_library_dir = 'cassettes'

        c.before_record do |interactions|
          interactions.each do |i|
            i.response.body.sub!(/^Hello .*$/, 'Hello World')
          end
        end

      end

      VCR.use_cassette('recording_example', :record => :new_episodes) do
        Net::HTTP.get_response('localhost', '/', 7777)
      end
      """
    When I run "ruby before_record_example.rb"
    Then the file "cassettes/recording_example.yml" should contain "body: Hello World"
     And the file "cassettes/recording_example.yml" should not contain "secret"

  Scenario: Change playback with before_playback hook
    Given a file named "before_playback_example.rb" with:
      """
      require 'vcr'

      VCR.config do |c|
        c.stub_with                :fakeweb
        c.cassette_library_dir     = 'cassettes'

        c.before_playback do |interactions|
          interactions.each do |i|
            i.response.body = 'response from before_playback'
          end
        end
      end

      VCR.use_cassette('example', :record => :new_episodes) do
        response = Net::HTTP.get_response('example.com', '/foo')
        puts "Response: #{response.body}"
      end
      """
    When I run "ruby before_playback_example.rb"
    Then it should pass with "Response: response from before_playback"

  Scenario: Multiple hooks are run in order
    Given a file named "multiple_hooks.rb" with:
      """
      require 'vcr_cucumber_helpers'

      start_sinatra_app(:port => 7777) do
        get('/') { "Hello World" }
      end

      require 'vcr'

      VCR.config do |c|
        c.stub_with :fakeweb
        c.cassette_library_dir = 'cassettes'

        c.before_record { puts "In before_record hook 1" }
        c.before_record { puts "In before_record hook 2" }

        c.before_playback { puts "In before_playback hook 1" }
        c.before_playback { puts "In before_playback hook 2" }
      end

      VCR.use_cassette('example', :record => :new_episodes) do
        response = Net::HTTP.get_response('localhost', '/', 7777)
        puts "Response 1: #{response.body}"

        response = Net::HTTP.get_response('example.com', '/foo')
        puts "Response 2: #{response.body}"
      end
      """
    When I run "ruby multiple_hooks.rb"
    Then it should pass with:
      """
      In before_playback hook 1
      In before_playback hook 2
      Response 1: Hello World
      Response 2: example.com response
      In before_record hook 1
      In before_record hook 2
      """

  Scenario: Use tagging to apply hooks to only certain cassettes
    Given a file named "tagged_hooks.rb" with:
      """
      require 'vcr_cucumber_helpers'

      start_sinatra_app(:port => 7777) do
        get('/') { "Hello World" }
      end

      require 'vcr'

      VCR.config do |c|
        c.stub_with :fakeweb
        c.cassette_library_dir = 'cassettes'

        c.before_record(:tag_1)   { puts "In before_record hook for tag_1" }
        c.before_playback(:tag_2) { puts "In before_playback hook for tag_2" }
      end

      [:tag_1, :tag_2, nil].each do |tag|
        puts
        puts "Using tag: #{tag.inspect}"

        VCR.use_cassette('example', :record => :new_episodes, :tag => tag) do
          response = Net::HTTP.get_response('localhost', '/', 7777)
          puts "Response 1: #{response.body}"

          response = Net::HTTP.get_response('example.com', '/foo')
          puts "Response 2: #{response.body}"
        end
      end
      """
    When I run "ruby tagged_hooks.rb"
    Then it should pass with:
      """
      Using tag: :tag_1
      Response 1: Hello World
      Response 2: example.com response
      In before_record hook for tag_1

      Using tag: :tag_2
      In before_playback hook for tag_2
      Response 1: Hello World
      Response 2: example.com response

      Using tag: nil
      Response 1: Hello World
      Response 2: example.com response
      """
