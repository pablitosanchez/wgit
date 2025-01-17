require_relative 'helpers/test_helper'

# We use a class rather than a Struct because a Struct instance doesn't
# have instance_variables which Wgit::Utils.to_h uses.
class Person
  attr_accessor :name, :age, :height

  def initialize
    @name = 'Bob'
    @age = 45
    @height = "5'11"
  end
end

# Test class for utility funcs.
class TestUtils < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @person = Person.new
    @to_h_result = {
      'name' => 'Bob',
      'age' => 45
    }
  end

  def test_to_h
    h = Wgit::Utils.to_h @person, ['@height']
    assert_equal @to_h_result, h
  end

  def test_to_h_with_symbols
    h = Wgit::Utils.to_h @person, ['@height'], false
    assert_equal({
                   name: 'Bob',
                   age: 45
                 }, h)
  end

  def test_each
    str = %w[hello goodbye]
    Wgit::Utils.each(str) { |el| el.replace(el + 1.to_s) }
    assert_equal %w[hello1 goodbye1], str

    str = 'hello'
    Wgit::Utils.each(str) { |el| el.replace(el + 1.to_s) }
    assert_equal 'hello1', str
  end

  def test_format_sentence_length
    sentence_limit = 10

    # Short sentence.
    sentence = 'For what'
    result =
      Wgit::Utils.format_sentence_length sentence.dup, 2, sentence_limit
    assert_equal sentence, result

    # Long sentence: index near start.
    sentence = 'For what of the flower if not for soil beneath it?'
    result =
      Wgit::Utils.format_sentence_length sentence.dup, 5, sentence_limit
    assert_equal 'For what o', result

    # Long sentence: index near end.
    result =
      Wgit::Utils.format_sentence_length sentence.dup, 48, sentence_limit
    assert_equal 'eneath it?', result

    # Long sentence: index near middle.
    result =
      Wgit::Utils.format_sentence_length sentence.dup, 23, sentence_limit
    assert_equal 'ower if no', result

    # Return full sentence.
    sentence = "For what of the flower if not for soil beneath it?\
                For what of the flower if not for soil beneath it?\
                For what of the flower if not for soil beneath it?"
    result = Wgit::Utils.format_sentence_length sentence.dup, 5, 0
    assert_equal sentence, result
  end

  def test_printf_search_results
    # Setup the test results data.
    search_text = 'Everest'
    results = []
    5.times do
      doc_hash = Wgit::DatabaseDefaultData.doc
      doc_hash['url'] = 'http://altitudejunkies.com/everest.html'
      results << Wgit::Document.new(doc_hash)
    end

    # Setup the temp file to write the printf output to.
    file_name = SecureRandom.uuid.split('-').last
    file_path = "#{Dir.tmpdir}/#{file_name}.txt"
    file = File.new file_path, 'w+'

    Wgit::Utils.printf_search_results results, search_text, false, 80, 5, file
    file.close

    # Assert the file contents against the expected output.
    text = IO.readlines(file_path).join
    assert_equal printf_expected_output, text
  end

  def test_process_str
    s = ' hello world '
    s2 = Wgit::Utils.process_str s

    assert_equal s.strip, s
    assert_equal s2, s
  end

  def test_process_arr
    a = ['', true, nil, true, false, ' hello world ']
    a2 = Wgit::Utils.process_arr a
    expected = [true, false, 'hello world']

    assert_equal expected, a
    assert_equal expected, a2
  end

  private

  def printf_expected_output
    "Altitude Junkies | Everest
Everest, Highest Peak, High Altitude, Altitude Junkies
e Summit for the hugely successful IMAX Everest film from the 1996 spring season
http://altitudejunkies.com/everest.html

Altitude Junkies | Everest
Everest, Highest Peak, High Altitude, Altitude Junkies
e Summit for the hugely successful IMAX Everest film from the 1996 spring season
http://altitudejunkies.com/everest.html

Altitude Junkies | Everest
Everest, Highest Peak, High Altitude, Altitude Junkies
e Summit for the hugely successful IMAX Everest film from the 1996 spring season
http://altitudejunkies.com/everest.html

Altitude Junkies | Everest
Everest, Highest Peak, High Altitude, Altitude Junkies
e Summit for the hugely successful IMAX Everest film from the 1996 spring season
http://altitudejunkies.com/everest.html

Altitude Junkies | Everest
Everest, Highest Peak, High Altitude, Altitude Junkies
e Summit for the hugely successful IMAX Everest film from the 1996 spring season
http://altitudejunkies.com/everest.html

"
  end
end
