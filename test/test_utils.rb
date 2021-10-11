require_relative 'test_helper'
require_relative '../lib/rosace'
require_relative '../lib/rosace/utils'

class TestUtils < Test::Unit::TestCase
	
	def test_convert
		assert_equal(
			'test string',
			Rosace::Utils.convert('test string', :to_str, 'String')
		)
		assert_same(3, Rosace::Utils.convert(3, :to_int, 'Integer'))
		assert_equal(4, Rosace::Utils.convert(4.0, :to_i, 'Integer'))
		assert_equal(
			:MySymbol,
			Rosace::Utils.convert('MySymbol', :to_sym, 'Symbol')
		)
		assert_same(
			:TestSymbol,
			Rosace::Utils.convert(:TestSymbol, :to_sym, 'Symbol')
		)
		assert_raises(TypeError) do
			Rosace::Utils.convert(:MySymbol, :to_str, 'Symbol')
		end
	end

	def test_str
		assert_equal('my string', Rosace::Utils.str('my string'))
		assert_raises(TypeError) { Rosace::Utils.str(:MySymbol) }
	end

	def test_sym
		assert_same(:TestString, Rosace::Utils.sym('TestString'))
		assert_raises(TypeError) { Rosace::Utils.sym(3) }
	end

	def test_int
		assert_same(8, Rosace::Utils.int(8))
		assert_same(4, Rosace::Utils.int(4.2))
		assert_raise(TypeError) { Rosace::Utils.int('11') }
	end

	def test_check_type
		Rosace::Utils.check_type('My string', String)
		Rosace::Utils.check_type(8, Integer)
		Rosace::Utils.check_type(:Symbol, Symbol)
		Rosace::Utils.check_type(4.3, Object)
		Rosace::Utils.check_type([1, 2, 3], Enumerable)
		assert_raises(TypeError) do
			Rosace::Utils.check_type(4.2, Integer)
		end
		assert_raises(TypeError) do
			Rosace::Utils.check_type([4, 5, 6], Hash)
		end
	end
end