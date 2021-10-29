require_relative 'test_helper'
require_relative '../lib/rosace/context'
require_relative '../lib/rosace/entity'
require_relative '../lib/rosace/function'
require_relative '../lib/rosace/contextual_value'
require_relative '../lib/rosace/evaluation_exception'

class TestContext < Test::Unit::TestCase

	TEST_DIR = 'test/valid_dir1/'

	def setup
		@rules = {
			SimpleRule: Class.new(Rosace::Entity) do

				attr_accessor :my_var

				self.file = TEST_DIR + 'simple_rule.csv'

				def init
					@my_var = 0
				end

				def pick?(number)
					self.id <= number.to_i
				end
			end,
			WeightedRule: Class.new(Rosace::Entity) do
				self.file = TEST_DIR + 'weighted_rule.csv'
			end,
			RequiredReference: Class.new(Rosace::Entity) do
				self.file = TEST_DIR + 'required_reference.csv'
				reference :entity_ref, :SimpleRule, :required
			end,
			OptionalReference: Class.new(Rosace::Entity) do
				self.file = TEST_DIR + 'optional_reference.csv'
				reference :entity_ref, :SimpleRule, :optional
			end,
			SimpleEnum: Class.new(Rosace::Entity) do
				self.file = TEST_DIR + 'simple_enum.csv'
				enum :value, :value1, :value2, :value3
			end
		}
		@generator = Rosace::Generator.new(
			path: TEST_DIR,
			functions: [
				Rosace::Function.new(:ret_arg, ->(arg) do
					arg
				end, :concurrent),
				Rosace::Function.new(:add, ->(n1, n2) do
					Rosace::ContextualValue.new(
						(n1.value.to_i + n2.value.to_i).to_s,
						n1.context
					)
				end, :sequential),
				Rosace::Function.new(:exists, ->(arg) do
					unless arg.context.variable?(arg.value.to_sym)
						raise Rosace::EvaluationException
					end
					Rosace::ContextualValue.empty(arg.context)
				end, :concurrent),
				Rosace::Function.new(:join, ->(*args) do
					Rosace::ContextualValue.new(
						args.map { |arg| arg.value }.join(' '),
						args[0].context
					)
				end, :sequential)
			],
			rules: @rules.values
		)
		@generator.print_messages
		@context = Rosace::Context.new(@generator)
		string1 = "string 1"
		@context.tap do |t|
			t.store_variable!(:var1, string1)
			t.store_variable!(:var2, 2)
			t.store_variable!(:var3, t.entity(:SimpleRule, 3))
			t.store_variable!(:var4, string1)
			t.store_variable!(:var5, "string 1")
			t.store_variable!(:var6, string1)
		end
	end

	def test_variables
		assert_equal(6, @context.variables_number)
	end

	def test_variable?
		assert_true(@context.variable? :var1)
		assert_true(@context.variable? :var4)
		assert_false(@context.variable? :var7)
	end

	def test_invalid_variable?
		assert_raise(TypeError) { @context.variable? 2 }
	end

	def test_variable
		assert_equal("string 1", @context.variable(:var1))
		assert_equal(2, @context.variable(:var2))
		assert_equal(
			@context.entity(:SimpleRule, 3),
			@context.variable(:var3)
		)
		assert_equal("string 1", @context.variable(:var4))
		assert_equal("string 1", @context.variable(:var5))
		assert_equal("string 1", @context.variable(:var6))
		assert_nil(@context.variable(:var7))
		assert_same(@context.variable(:var1), @context.variable(:var4))
		assert_same(@context.variable(:var1), @context.variable(:var6))
		assert_not_same(@context.variable(:var1), @context.variable(:var5))
	end

	def test_invalid_variable
		assert_raise(TypeError) { @context.variable(2) }
	end

	def test_entity?
		assert_true(@context.entity?(:SimpleRule, 3))
		assert_false(@context.entity?(:SimpleRule, 11))
		assert_false(@context.entity?(:ComplexRule, 3))
	end

	def test_invalid_param_entity?
		assert_raise(TypeError) do
			@context.entity?(:SimpleRule, :v4)
		end
		assert_raise(TypeError) do
			@context.entity?(4, 3)
		end
	end

	def test_entity
		assert_equal(
			@rules[:SimpleRule].entities(@context)[3],
			@context.entity(:SimpleRule, 3)
		)
		assert_nil(@context.entity(:SimpleRule, 11))
		assert_nil(@context.entity(:ComplexRule, 3))
	end

	def test_invalid_entity
		assert_raise(TypeError) { @context.entity(:SimpleRule, :v4) }
		assert_raise(TypeError) { @context.entity(3, 5) }
	end

	def pick_test(rule, args, draw_nb)
		enum_draws = @rules[rule].entities(@context).values.
			each_with_object({}) do |element, hash|
			hash[element] = 0
		end
		0.upto(draw_nb) do
			enum_draws[@context.pick_entity(rule, *args)] += 1
		end
		assert_false(enum_draws.keys.any? do |element|
			(element.weight <= 0 || !element.pick?(*args)) &&
				enum_draws[element] > 0
		end)
		enum_total = enum_draws.keys.reduce(0) do |total, entity|
			total + (entity.pick?(*args) ? entity.weight : 0)
		end
		enum_means = enum_draws.keys.map do |entity|
			entity.pick?(*args) ? entity.weight.to_f / enum_total.to_f : 0.0
		end
		deviations = Array.new(@rules[rule].length) do |i|
			Math.sqrt(draw_nb.to_f * enum_means[i] * (1.0 - enum_means[i]))
		end
		@rules[rule].entities(@context).keys.each_with_index do |element, i|
			assert_in_delta(
				enum_means[i],
				enum_draws[element].to_f / draw_nb,
				deviations[i]
			)
		end
	end

	def test_pick_entity
		draw_nb = 1000
		pick_test(:SimpleRule, ["4"], draw_nb)
		pick_test(:WeightedRule, [""], draw_nb)
		pick_test(:SimpleRule, ["2"], draw_nb)
		assert_equal(
			@rules[:SimpleRule].entities(@context)[1],
			@context.pick_entity(:SimpleRule, "1")
		)
		assert_nil(@context.pick_entity(:SimpleRule, "0"))
		assert_nil(@context.pick_entity(:ComplexRule, ""))
	end

	def test_invalid_pick_entity
		assert_raise(TypeError) { @context.pick_entity(4) }
		assert_raise(TypeError) { @context.pick_entity(:SimpleRule, 3) }
	end

	def test_store_variable!
		@context.store_variable!(:var8, 8)
		assert_equal(8, @context.variable(:var8))
		assert_raise(Rosace::EvaluationException) do
			@context.store_variable!(:var2, 4)
		end
		assert_raise(Rosace::EvaluationException) do
			@context.store_variable!(:self, 8)
		end
		assert_raise(Rosace::EvaluationException) do
			@context.store_variable!(:add, 4)
		end
	end

	def test_invalid_set
		assert_raise(TypeError) { @context.store_variable!(4, 7) }
	end

	def test_reset
		@context.reset
		assert_equal(0, @context.variables_number)
		assert_nil(@context.variable(:var1))
		assert_nil(@context.variable(:var2))
		assert_nil(@context.variable(:var3))
		assert_nil(@context.variable(:var4))
		assert_nil(@context.variable(:var5))
		assert_nil(@context.variable(:var6))
	end

	def test_fork
		fork1 = @context.clone
		fork2 = @context.clone

		assert_not_same(
			@context.entity(:SimpleRule, 1),
			fork1.entity(:SimpleRule, 1)
		)
		assert_same(
			@context,
			@context.entity(:WeightedRule, 2).context
		)
		assert_same(
			fork1,
			fork1.entity(:WeightedRule, 2).context
		)
		assert_same(
			fork2,
			fork2.entity(:WeightedRule, 2).context
		)

		assert_equal(@context.variable(:var1), fork1.variable(:var1))
		assert_not_same(@context.variable(:var1), fork1.variable(:var1))
		assert_same(fork1.variable(:var1), fork1.variable(:var4))
		assert_not_same(fork1.variable(:var1), fork1.variable(:var5))
		assert_same(fork1.variable(:var1), fork1.variable(:var6))
		assert_equal(@rules[:SimpleRule].entities(@context)[3], fork1.variable(:var3))
		assert_same(fork1.entity(:SimpleRule, 3), fork1.variable(:var3))
		assert_not_same(@context.variable(:var3), fork1.variable(:var3))

		fork1.store_variable!(:var7, "string 2")
		fork2.store_variable!(:var7, "string 3")
		assert_nil(@context.variable(:var7))
		assert_equal("string 2", fork1.variable(:var7))
		assert_equal("string 3", fork2.variable(:var7))
		fork1.restore_state(@context)
		assert_nil(fork1.variable(:var7))
	end

	def test_rule
		assert_equal(@rules[:SimpleRule], @context.generator.rules[:SimpleRule])
	end

	def test_entities
		assert_equal(
			@rules[:SimpleRule].send(:entities, @context).values,
			@context.entities(:SimpleRule)
		)
	end

end
