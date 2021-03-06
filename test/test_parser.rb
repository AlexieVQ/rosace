require_relative 'test_helper'
require_relative '../lib/rosace'
require_relative '../lib/rosace/asd'
require_relative '../lib/rosace/parser'

class TestParser < Test::Unit::TestCase
	
	include Rosace::ASD

	def test_valid1
		assert_equal(
			Choice.new([
				Variant.new([
					Text.new("my text")
				])
			]),
			Rosace::Parser.parse!("my text")
		)
	end

	def test_valid2
		assert_equal(
			Choice.new([
				Variant.new([
					Text.new("my first variant")
				]),
				Variant.new([
					Text.new("my second variant")
				])
			]),
			Rosace::Parser.parse!("my first variant|my second variant")
		)
	end

	def test_valid3
		assert_equal(
			Choice.new([
				Variant.new([
					Text.new("my text, "),
					Choice.new([
						Variant.new([
							Text.new("choice 1")
						]),
						Variant.new([
							Text.new("choice 2")
						])
					])
				]),
				Variant.new([
					Text.new("my other text "),
					Optional.new(
						Choice.new([
							Variant.new([
								Text.new("print?")
							])
						])
					)
				])
			]),
			Rosace::Parser.parse!(
				"my text, (choice 1|choice 2)|my other text (print?)?"
			)
		)
	end

	def test_valid4
		assert_equal(
			Choice.new([
				Variant.new([
					Print.new(
						SymbolReading.new(:var)
					),
					Print.new(
						FunctionCall.new(:function, [
							Choice.new([
								Variant.new([
									Text.new("argument1")
								])
							]),
							Choice.new([
								Variant.new([
									Text.new("argument2, still")
								])
							])
						])
					)
				])
			]),
			Rosace::Parser.parse!(
				"{ var }{ function(argument1,argument2\\, still)}"
			)
		)
	end

	def test_valid5
		assert_equal(
			Choice.new([
				Variant.new([
					Assignment.new(
						:var,
						"=",
						Picker.new(:Rule, [
							Choice.new([
								Variant.new([
									Print.new(
										MethodCall.new(
											SymbolReading.new(:v0),
											:attr,
											[]
										)
									)
								]),
								Variant.new([
									Print.new(
										MethodCall.new(
											SymbolReading.new(:v1),
											:attr,
											[]
										)
									)
								])
							])
						])
					),
					Print.new(
						MethodCall.new(
							AssignmentExpr.new(
								Assignment.new(
									:var1,
									"=",
									MethodCall.new(
										SymbolReading.new(:var),
										:met,
										[Choice.new([
											Variant.new([
												Text.new("arg")
											])
										])]
									)
								)
							),
							:bar,
							[]
						)
					)
				])
			]),
			Rosace::Parser.parse!(
				"{var = Rule({v0.attr}|{v1.attr});
					/* foo */ `var1 = var.met(arg)`.bar;}"
			)
		)
	end
	
end