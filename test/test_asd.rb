require_relative 'test_helper'
require_relative '../lib/rosace'
require_relative '../lib/rosace/asd'
require_relative '../lib/rosace/entity'
require_relative '../lib/rosace/context'
require_relative '../lib/rosace/function'
require_relative '../lib/rosace/evaluation_exception'

class TestASD < Test::Unit::TestCase

	include Rosace::ASD

	VALID_DIR1 = "test/valid_dir1/"
	ENUM = [:value1, :value2, :value3]

	def setup

		@valid_dir1 = {
			SimpleRule: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_rule.csv'

				attr_accessor :my_attr

				def my_method(arg)
					arg + "1"
				end

				def my_text
					value
				end
			end,

			WeightedRule: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'weighted_rule.csv'

				def pick?(min_weight)
					weight > min_weight.to_i
				end
			end,

			OptionalReference: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'optional_reference.csv'

				reference :entity_ref, :SimpleRule, :optional
			end,

			RequiredReference: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'required_reference.csv'

				reference :entity_ref, :SimpleRule, :required
			end,

			SimpleEnum: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_enum.csv'

				enum :value, *ENUM
			end,

			MultipleEnum: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'multiple_enum.csv'

				mult_enum :values, *ENUM
			end
		}
		@valid_dir1_gen = Rosace::Generator.new(
			path: VALID_DIR1,
			functions: [
				Rosace::Function::CAT,
				Rosace::Function::PICK,
			],
			rules: @valid_dir1.values
		)
		@valid_dir1_ctx = Rosace::Context.new(@valid_dir1_gen)
		@text1 = Text.new("my first text")
		@text1.set_location(:SimpleRule, 1, :attribute)
		@text2 = Text.new("my second text")
		@text2.set_location(:SimpleRule, 1, :attribute)
		@f1 = FunctionCall.new(:s, [@text2])
		@f1.set_location(:SimpleRule, 1, :attribute)
		@assignment1 = Assignment.new(:var1, "=", @f1)
		@assignment2 = Assignment.new(:var1, "||=", FunctionCall.new(:s, [@text1]))
		@assignment1.set_location(:SimpleRule, 1, :attribute)
		@var1 = SymbolReading .new(:var1)
		@var1.set_location(:SimpleRule, 1, :attribute)
		@print1 = Print.new(@var1)
		@print1.set_location(:SimpleRule, 1, :attribute)
		@variant1 = Variant.new([@text1])
		@variant1.set_location(:SimpleRule, 1, :attribute)
		@variant2 = Variant.new([@assignment1, @print1])
		@variant2.set_location(:SimpleRule, 1, :attribute)
		@choice = Choice.new([@variant1, @variant2])
		@choice.set_location(:SimpleRule, 1, :attribute)
		@ref1 = Reference.new(:SimpleRule, 2)
		@ref1.set_location(:SimpleRule, 1, :attribute)
		@predicate1 = Predicate.new(:var1)
		@predicate1.set_location(:SimpleRule, 1, :attribute)
		@method1 = MethodCall.new(@ref1, :my_method, [@text1])
		@method1.set_location(:SimpleRule, 1, :attribute)
		@optional1 = Optional.new(Choice.new([Variant.new([@print1])]))
		@optional1.set_location(:SimpleRule, 1, :attribute)
		@picker = Picker.new(:WeightedRule, [Text.new("5")])
		@picker.set_location(:SimpleRule, 1, :attribute)
		@setter1 = AttrSetter.new(@ref1, :my_attr, "=", @f1).tap do |s|
			s.set_location(:SimpleRule, 1, :attribute)
		end
		@setter2 = AttrSetter.new(@ref1, :attr2, "=", @f1).tap do |s|
			s.set_location(:SimpleRule, 1, :attribute)
		end
		@setter3 = AttrSetter.new(
			@ref1,
			:my_attr,
			"||=",
			FunctionCall.new(:s, [@text1])
		)
		@setter_expr = SetterExpr.new(@setter2).tap do |s|
			s.set_location(:SimpleRule, 1, :attribute)
		end
	end

	def test_eval1
		assert_equal("my second text", @variant2.try_eval(@valid_dir1_ctx))
		assert_empty(@predicate1.try_eval(@valid_dir1_ctx))
	end

	def test_eval2
		10.times do
			assert_equal(
				"my first text",
				Choice.new([
					Variant.new([@print1]),
					Variant.new([@text1])
				]).try_eval(@valid_dir1_ctx)
			)
		end
	end

	def test_eval2b
		assert_raise(Rosace::EvaluationException) do
			Choice.new([
				Variant.new([@print1])
			]).try_eval(@valid_dir1_ctx)
		end
	end
	
	def test_eval2c
		assert_raise(Rosace::EvaluationException) do
			@predicate1.try_eval(@valid_dir1_ctx)
		end
	end

	def test_eval3
		assert_equal(
			"simple entity 2",
			Print.new(MethodCall.new(
				@ref1,
				:my_text,
				[]
			)).try_eval(@valid_dir1_ctx)
		)
	end

	def test_eval3b
		assert_equal(
			"simple entity 2",
			Print.new(@ref1).try_eval(@valid_dir1_ctx)
		)
	end

	def test_eval3c
		assert_equal(
			"2",
			Print.new(MethodCall.new(
				@ref1,
				:id,
				[]
			)).try_eval(@valid_dir1_ctx)
		)
	end

	def test_eval3d
		assert_equal(
			"my first text1",
			Print.new(@method1).try_eval(@valid_dir1_ctx)
		)
	end

	def test_eval3e
		assert_equal(
			"my second text",
			AssignmentExpr.new(@assignment1).try_eval(@valid_dir1_ctx)
		)
	end

	def test_eval4
		10.times do
			assert_not_include(
				[3, 4],
				@picker.try_eval(@valid_dir1_ctx).id
			)
		end
		assert_raise(Rosace::EvaluationException) do
			Picker.new(
				:WeightedRule,
				[Text.new("20")]
			).try_eval(@valid_dir1_ctx)
		end
	end

	def test_eval5
		10.times do
			assert_equal("", @optional1.try_eval(@valid_dir1_ctx))
		end
		outs = []
		@assignment1.try_eval(@valid_dir1_ctx)
		100.times do
			outs << @optional1.try_eval(@valid_dir1_ctx)
		end
		assert_include(outs, "")
		assert_include(outs, "my second text")
	end

	def test_eval6
		assert_equal(
			"",
			SymbolReading.new(:s).try_eval(@valid_dir1_ctx)
		)
		assert_equal(
			@valid_dir1_ctx.entity(:SimpleRule, 2),
			SymbolReading.new(:self).tap do |sr|
				sr.set_location(:SimpleRule, 2, :value)
			end.try_eval(@valid_dir1_ctx)
		)
	end

	def test_eval7
		@setter1.try_eval(@valid_dir1_ctx)
		assert_equal(
			"my second text",
			@valid_dir1_ctx.entity(:SimpleRule, 2).my_attr
		)
		@setter2.try_eval(@valid_dir1_ctx)
		assert_equal(
			"my second text",
			@valid_dir1_ctx.entity(:SimpleRule, 2).attr2
		)
		assert_false(@valid_dir1_ctx.entity(:SimpleRule, 1).respond_to?(:attr2))
		assert_raise(Rosace::EvaluationException) do
			@setter2.try_eval(@valid_dir1_ctx)
		end
	end

	def test_eval7c
		assert_equal("my second text", @setter_expr.try_eval(@valid_dir1_ctx))
	end

	def test_eval8
		@assignment1.try_eval(@valid_dir1_ctx)
		assert_equal("my second text", @valid_dir1_ctx.variable(:var1))
		@assignment2.try_eval(@valid_dir1_ctx)
		assert_equal("my second text", @valid_dir1_ctx.variable(:var1))
	end

	def test_eval9
		@setter1.try_eval(@valid_dir1_ctx)
		@setter3.try_eval(@valid_dir1_ctx)
		assert_equal(
			"my second text",
			@valid_dir1_ctx.entity(:SimpleRule, 2).my_attr
		)
	end

	def test_verify
		assert_empty(@text1.verify(@valid_dir1_ctx))
		assert_empty(@f1.verify(@valid_dir1_ctx))
		assert_empty(@assignment1.verify(@valid_dir1_ctx))
		assert_empty(@var1.verify(@valid_dir1_ctx))
		assert_empty(@print1.verify(@valid_dir1_ctx))
		assert_empty(@variant1.verify(@valid_dir1_ctx))
		assert_empty(@choice.verify(@valid_dir1_ctx))
		assert_empty(@ref1.verify(@valid_dir1_ctx))
		assert_empty(@predicate1.verify(@valid_dir1_ctx))
		assert_empty(@method1.verify(@valid_dir1_ctx))
		assert_empty(@optional1.verify(@valid_dir1_ctx))
		assert_empty(@setter1.verify(@valid_dir1_ctx))
		assert_empty(@setter_expr.verify(@valid_dir1_ctx))
		assert_equal(
			1,
			FunctionCall.new(:function, []).tap do |f|
				f.set_location(:SimpleRule, 1, :attribute)
			end.verify(@valid_dir1_ctx).select do |message|
				message.level == 'ERROR'
			end.length
		)
		assert_equal(
			1,
			FunctionCall.new(:s, []).tap do |f|
				f.set_location(:SimpleRule, 1, :attribute)
			end.verify(@valid_dir1_ctx).
				select { |message| message.level == 'ERROR' }.length
		)
		assert_equal(
			1,
			FunctionCall.new(:s, [@text1, @text2]).tap do |f|
				f.set_location(:SimpleRule, 1, :attribute)
			end.verify(
				@valid_dir1_ctx
			).select { |message| message.level == 'ERROR' }.length
		)
		assert_equal(
			1,
			Picker.new(:WeightedRule, []).tap do |p|
				p.set_location(:SimpleRule, 1, :attribute)
			end.verify(
				@valid_dir1_ctx
			).select { |message| message.level == 'ERROR' }.length
		)
		assert_equal(
			1,
			Picker.new(:WeightedRule, [@text1, @text2]).tap do |p|
				p.set_location(:SimpleRule, 1, :attribute)
			end.verify(
				@valid_dir1_ctx
			).select { |message| message.level == 'ERROR' }.length
		)
		assert_equal(
			1,
			Picker.new(:NotARule, []).tap do |p|
				p.set_location(:SimpleRule, 1, :attribute)
			end.verify(
				@valid_dir1_ctx
			).select { |message| message.level == 'ERROR' }.length
		)
		assert_empty(AssignmentExpr.new(@assignment1).tap do |a|
			a.set_location(:SimpleRule, 1, :attribute)
		end.verify(
			@valid_dir1_ctx
		))
		assert_equal(
			1,
			Reference.new(:NotARule, 4).tap do |r|
				r.set_location(:SimpleRule, 1, :attribute)
			end.verify(
				@valid_dir1_ctx
			).select { |message| message.level == 'ERROR' }.length
		)
		assert_equal(
			1,
			Reference.new(:SimpleRule, 10).tap do |r|
				r.set_location(:SimpleRule, 1, :attribute)
			end.verify(
				@valid_dir1_ctx
			).select { |message| message.level == 'ERROR' }.length
		)
		assert_equal(
			1,
			Assignment.new(:self, "=", @ref1).tap do |a|
				a.set_location(:SimpleRule, 1, :attribute)
			end.verify(@valid_dir1_ctx).select do |message|
				message.level == 'ERROR'
			end.length
		)
		assert_equal(
			1,
			Assignment.new(:s, "=", @ref1).tap do |a|
				a.set_location(:SimpleRule, 1, :attribute)
			end.verify(@valid_dir1_ctx).select do |message|
				message.level == 'ERROR'
			end.length
		)
		assert_equal(
			1,
			SymbolReading.new(:s).tap do |sr|
				sr.set_location(:SimpleRule, 1, :attribute)
			end.verify(@valid_dir1_ctx).select do |message|
				message.level == 'WARNING'
			end.length
		)
	end

	def test_deterministic?
		@var1.verify(@valid_dir1_ctx)
		assert_true(@text1.deterministic?)
		assert_false(@f1.deterministic?)
		assert_false(@assignment1.deterministic?)
		assert_false(AssignmentExpr.new(@assignment1).deterministic?)
		assert_true(@var1.deterministic?)
		assert_true(@print1.deterministic?)
		assert_true(@variant1.deterministic?)
		assert_false(@variant2.deterministic?)
		assert_false(@choice.deterministic?)
		assert_true(@ref1.deterministic?)
		assert_true(@predicate1.deterministic?)
		assert_false(@method1.deterministic?)
		assert_true(@optional1.deterministic?)
		assert_false(SymbolReading.new(:s).deterministic?)
		assert_false(@setter1.deterministic?)
		assert_false(@setter_expr.deterministic?)
	end

	def test_to_s
		assert_equal("my first text", @text1.to_s)
		assert_equal("s(my second text)", @f1.to_s)
		assert_equal("{ var1 = s(my second text) }", @assignment1.to_s)
		assert_equal("var1", @var1.to_s)
		assert_equal("{ var1 }", @print1.to_s)
		assert_equal("my first text", @variant1.to_s)
		assert_equal("{ var1 = s(my second text) }{ var1 }", @variant2.to_s)
		assert_equal(
			"my first text|{ var1 = s(my second text) }{ var1 }",
			@choice.to_s
		)
		assert_equal("SimpleRule[2]", @ref1.to_s)
		assert_equal("{ var1! }", @predicate1.to_s)
		assert_equal("SimpleRule[2].my_method(my first text)", @method1.to_s)
		assert_equal("({ var1 })?", @optional1.to_s)
		assert_equal("WeightedRule(5)", @picker.to_s)
		assert_equal(
			"` var1 = s(my second text) `",
			AssignmentExpr.new(@assignment1).to_s
		)
		assert_equal(
			"{ SimpleRule[2].attr2 = s(my second text) }",
			@setter2.to_s
		)
		assert_equal(
			"` SimpleRule[2].attr2 = s(my second text) `",
			@setter_expr.to_s
		)
	end

	def test_node
		node = Node.new

		assert_true(node.deterministic?)
		assert_raise(Rosace::EvaluationException) do
			node.send(:eval, @valid_dir1_ctx)
		end

		assert_true(node.to_s.is_a?(String))
	end

	def test_equal
		assert_equal(Text.new("my first text"), @text1)
		assert_equal(Text.new("my second text"), @text2)
		assert_not_equal(@text1, @text2)
		assert_equal(FunctionCall.new(:s, [@text2]), @f1)
		assert_not_equal(FunctionCall.new(:s, [@text1]), @f1)
		assert_equal(Assignment.new(:var1, "=", @f1), @assignment1)
		assert_equal(SymbolReading.new(:var1), @var1)
		assert_equal(Print.new(@var1), @print1)
		assert_equal(Variant.new([@text1]), @variant1)
		assert_equal(Variant.new([@assignment1, @print1]), @variant2)
		assert_not_equal(@variant1, @variant2)
		assert_equal(Choice.new([@variant1, @variant2]), @choice)
		assert_equal(Reference.new(:SimpleRule, 2), @ref1)
		assert_equal(Predicate.new(:var1), @predicate1)
		assert_equal(
			MethodCall.new(@ref1, :my_method, [@text1]),
			@method1
		)
		assert_equal(
			Optional.new(Choice.new([Variant.new([@print1])])),
			@optional1
		)
		assert_equal(
			Picker.new(:WeightedRule, [Text.new("5")]),
			@picker
		)
		assert_equal(AttrSetter.new(@ref1, :my_attr, "=", @f1), @setter1)
		assert_equal(AttrSetter.new(@ref1, :attr2, "=", @f1), @setter2)
		assert_not_equal(@setter1, @setter2)
		assert_equal(SetterExpr.new(@setter2), @setter_expr)
		assert_equal(
			AssignmentExpr.new(@assignment1),
			AssignmentExpr.new(@assignment1)
		)
	end

	def test_chains
		assert_equal(
			@method1,
			chain_to_expression([@ref1, ChainPart.new(:my_method, [@text1])])
		)
		assert_equal(
			@setter1,
			expr_setter([@ref1, ChainPart.new(:my_attr, [])], "=", @f1)
		)
		assert_raise(Rattler::Runtime::SyntaxError) do
			expr_setter([nil, ChainPart.new(:attr, [@text1])], "=", @ref1)
		end
	end
	
end
