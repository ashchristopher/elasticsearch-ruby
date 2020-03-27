# Licensed to Elasticsearch B.V under one or more agreements.
# Elasticsearch B.V licenses this file to you under the Apache 2.0 License.
# See the LICENSE file in the project root for more information

# Match the `length` of a field.
RSpec::Matchers.define :match_response_field_length do |expected_pairs, test|

  match do |response|
    expected_pairs.all? do |expected_key, expected_value|

      # ssl test returns results at '$body' key. See ssl/10_basic.yml
      expected_pairs = expected_pairs['$body'] if expected_pairs['$body']

      split_key = TestFile::Test.split_and_parse_key(expected_key).collect do |k|
        test.get_cached_value(k)
      end

      actual_value = split_key.inject(response) do |_response, key|
        # If the key is an index, indicating element of a list
        if _response.empty? && key == '$body'
          _response
        else
          _response[key] || _response[key.to_s]
        end
      end
      actual_value.size == expected_value
    end
  end
end

# Validate that a field is `true`.
RSpec::Matchers.define :match_true_field do |field, test|

  match do |response|
    # Handle is_true: ''
    return !!response if field == ''

    split_key = TestFile::Test.split_and_parse_key(field).collect do |k|
      test.get_cached_value(k)
    end
    !!TestFile::Test.find_value_in_document(split_key, response)
  end
end

# Validate that a field is `false`.
RSpec::Matchers.define :match_false_field do |field, test|

  match do |response|
    # Handle is_false: ''
    return !response if field == ''
    split_key = TestFile::Test.split_and_parse_key(field).collect do |k|
      test.get_cached_value(k)
    end
    value_in_doc = TestFile::Test.find_value_in_document(split_key, response)
    value_in_doc == 0 || !value_in_doc
  end
end

# Validate that a field is `gte` than a given value.
RSpec::Matchers.define :match_gte_field do |expected_pairs, test|

  match do |response|
    expected_pairs.all? do |expected_key, expected_value|

      split_key = TestFile::Test.split_and_parse_key(expected_key).collect do |k|
        test.get_cached_value(k)
      end
      actual_value = split_key.inject(response) do |_response, key|

        # If the key is an index, indicating element of a list
        if _response.empty? && key == '$body'
          _response
        else
          _response[key] || _response[key]
        end
      end
      actual_value >= test.get_cached_value(expected_value)
    end
  end
end

# Validate that a field is `gt` than a given value.
RSpec::Matchers.define :match_gt_field do |expected_pairs, test|

  match do |response|
    expected_pairs.all? do |expected_key, expected_value|

      split_key = TestFile::Test.split_and_parse_key(expected_key).collect do |k|
        test.get_cached_value(k)
      end

      actual_value = split_key.inject(response) do |_response, key|
        # If the key is an index, indicating element of a list
        if _response.empty? && key == '$body'
          _response
        else
          _response[key] || _response[key.to_s]
        end
      end
      actual_value > test.get_cached_value(expected_value)
    end
  end
end

# Validate that a field is `lte` than a given value.
RSpec::Matchers.define :match_lte_field do |expected_pairs, test|

  match do |response|
    expected_pairs.all? do |expected_key, expected_value|

      split_key = TestFile::Test.split_and_parse_key(expected_key).collect do |k|
        test.get_cached_value(k)
      end

      actual_value = split_key.inject(response) do |_response, key|
        # If the key is an index, indicating element of a list
        if _response.empty? && key == '$body'
          _response
        else
          _response[key] || _response[key.to_s]
        end
      end
      actual_value <= test.get_cached_value(expected_value)
    end
  end
end

# Validate that a field is `lt` than a given value.
RSpec::Matchers.define :match_lt_field do |expected_pairs, test|

  match do |response|
    expected_pairs.all? do |expected_key, expected_value|

      split_key = TestFile::Test.split_and_parse_key(expected_key).collect do |k|
        test.get_cached_value(k)
      end

      actual_value = split_key.inject(response) do |_response, key|
        # If the key is an index, indicating element of a list
        if _response.empty? && key == '$body'
          _response
        else
          _response[key] || _response[key.to_s]
        end
      end
      actual_value < test.get_cached_value(expected_value)
    end
  end
end

# Match an arbitrary field of a response to a given value.
RSpec::Matchers.define :match_response do |pairs, test|

  match do |response|
    pairs = sanitize_pairs(pairs)
    if response.nil? || response.empty?
      logger = Logger.new($stdout)
      logger.error '=================================================='
      logger.error "[ERROR REPORT] - response is empty or nil"
      logger.error "Test: #{test}"
      logger.error '=================================================='
    end
    compare_pairs(pairs, response, test).empty?
  end

  failure_message do |response|
    "the actual response pair/value(s) #{@mismatched_pairs}" +
        " does not match the pair/value(s) in the response #{response}"
  end

  def sanitize_pairs(expected_pairs)
    # sql test returns results at '$body' key. See sql/translate.yml
    @pairs ||= expected_pairs['$body'] ? expected_pairs['$body'] : expected_pairs
  end

  def compare_pairs(expected_pairs, response, test)
    @mismatched_pairs = {}
    if expected_pairs.is_a?(String)
      @mismatched_pairs = expected_pairs unless compare_string_response(expected_pairs, response)
    else
      compare_hash(expected_pairs, response, test)
    end
    @mismatched_pairs
  end

  def compare_hash(expected_pairs, actual_hash, test)
    expected_pairs.each do |expected_key, expected_value|
      # Find the value to compare in the response
      split_key = TestFile::Test.split_and_parse_key(expected_key).collect do |k|
        # Sometimes the expected *key* is a cached value from a previous request.
        test.get_cached_value(k)
      end
      actual_value = TestFile::Test.find_value_in_document(split_key, actual_hash)
      # When the expected_key is ''
      actual_value = actual_hash if split_key.empty?
      # Sometimes the key includes dots. See watcher/put_watch/60_put_watch_with_action_condition.yml
      actual_value = TestFile::Test.find_value_in_document(expected_key, actual_hash) if actual_value.nil?

      # Sometimes the expected *value* is a cached value from a previous request.
      # See test api_key/10_basic.yml
      expected_value = test.get_cached_value(expected_value)

      case expected_value
      when Hash
        compare_hash(expected_value, actual_value, test)
      when Array
        unless compare_array(expected_value, actual_value, test, actual_hash)
          @mismatched_pairs.merge!(expected_key => expected_value)
        end
      when String
        unless compare_string(expected_value, actual_value, test, actual_hash)
          @mismatched_pairs.merge!(expected_key => expected_value)
        end
      else
        unless expected_value == actual_value
          @mismatched_pairs.merge!(expected_key => expected_value)
        end
      end
    end
  end

  def compare_string(expected, actual_value, test, response)
    # When you must match a regex. For example:
    #   match: {task: '/.+:\d+/'}
    if expected[0] == "/" && expected[-1] == "/"
      /#{expected.tr("/", "")}/ =~ actual_value
    elsif expected == ''
      actual_value == response
    else
      expected == actual_value
    end
  end

  def compare_array(expected, actual, test, response)
    expected.each_with_index do |value, i|
      case value
      when Hash
        return false unless compare_hash(value, actual[i], test)
      when Array
        return false unless compare_array(value, actual[i], test, response)
      when String
        return false unless compare_string(value, actual[i], test, response)
      end
    end
  end

  def compare_string_response(expected_string, response)
    regexp = Regexp.new(expected_string.strip[1..-2], Regexp::EXTENDED|Regexp::MULTILINE)
    regexp =~ response
  end
end

# Match that a request returned a given error.
RSpec::Matchers.define :match_error do |expected_error|

  match do |actual_error|
    # Remove surrounding '/' in string representing Regex
    expected_error = expected_error.chomp("/")
    expected_error = expected_error[1..-1] if expected_error =~ /^\//
    message = actual_error.message.tr("\\","")

    case expected_error
    when 'request_timeout'
      message =~ /\[408\]/
    when 'missing'
      message =~ /\[404\]/
    when 'conflict'
      message =~ /\[409\]/
    when 'request'
      message =~ /\[500\]/
    when 'bad_request'
      message =~ /\[400\]/
    when 'param'
      message =~ /\[400\]/ ||
          actual_error.is_a?(ArgumentError)
    when 'unauthorized'
      actual_error.is_a?(Elasticsearch::Transport::Transport::Errors::Unauthorized)
    when 'forbidden'
      actual_error.is_a?(Elasticsearch::Transport::Transport::Errors::Forbidden)
    else
      message =~ /#{expected_error}/
    end
  end
end
