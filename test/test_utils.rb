require_relative 'test_helper'
require_relative '../lib/rand_text_core/utils'

class TestUtils < Test::Unit::TestCase
	
	def test_convert
		assert_equal(
			'test string',
			RandTextCore::Utils.convert('test string', :to_str, 'String')
		)
		assert_same(3, RandTextCore::Utils.convert(3, :to_int, 'Integer'))
		assert_equal(4, RandTextCore::Utils.convert(4.0, :to_i, 'Integer'))
		assert_equal(
			:MySymbol,
			RandTextCore::Utils.convert('MySymbol', :to_sym, 'Symbol')
		)
		assert_same(
			:TestSymbol,
			RandTextCore::Utils.convert(:TestSymbol, :to_sym, 'Symbol')
		)
		assert_raises(TypeError) do
			RandTextCore::Utils.convert(:MySymbol, :to_str, 'Symbol')
		end
	end

	def test_str
		assert_equal('my string', RandTextCore::Utils.str('my string'))
		assert_raises(TypeError) { RandTextCore::Utils.str(:MySymbol) }
	end

	def test_sym
		assert_same(:TestString, RandTextCore::Utils.sym('TestString'))
		assert_raises(TypeError) { RandTextCore::Utils.sym(3) }
	end

	def test_int
		assert_same(8, RandTextCore::Utils.int(8))
		assert_same(4, RandTextCore::Utils.int(4.2))
		assert_raise(TypeError) { RandTextCore::Utils.int('11') }
	end

	def test_check_type
		RandTextCore::Utils.check_type('My string', String)
		RandTextCore::Utils.check_type(8, Integer)
		RandTextCore::Utils.check_type(:Symbol, Symbol)
		RandTextCore::Utils.check_type(4.3, Object)
		RandTextCore::Utils.check_type([1, 2, 3], Enumerable)
		assert_raises(TypeError) do
			RandTextCore::Utils.check_type(4.2, Integer)
		end
		assert_raises(TypeError) do
			RandTextCore::Utils.check_type([4, 5, 6], Hash)
		end
	end
end